# Gitea Deployment and Token Generation
#
# Deploys in-cluster Gitea and automatically generates an access token
# for FluxCD bootstrap. Solves the chicken-and-egg problem of needing
# Git credentials before FluxCD can manage Gitea.
#
# Bootstrap Flow:
# 1. Talos cluster ready with Cilium + Longhorn
# 2. Gitea deployed via Helm with admin credentials from SOPS
# 3. Wait for Gitea to be ready
# 4. Generate access token via Gitea API (requires BasicAuth)
# 5. Create Kubernetes secret for FluxCD
# 6. FluxCD bootstrap uses the generated token
#
# Prerequisites:
# - secrets/git-creds.enc.yaml with gitea_admin_password

# ============================================================================
# Gitea Namespace
# ============================================================================

resource "kubernetes_namespace" "gitea" {
  count = var.enable_gitea ? 1 : 0

  metadata {
    name = "gitea"
    labels = {
      "app.kubernetes.io/name"       = "gitea"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    null_resource.wait_for_cilium
  ]
}

# ============================================================================
# Gitea Helm Release
# ============================================================================

resource "helm_release" "gitea" {
  count = var.enable_gitea ? 1 : 0

  name             = "gitea"
  repository       = "https://dl.gitea.com/charts/"
  chart            = "gitea"
  version          = var.gitea_chart_version
  namespace        = kubernetes_namespace.gitea[0].metadata[0].name
  create_namespace = false

  # Use values file from kubernetes/gitea/
  values = [file("${path.module}/../../kubernetes/gitea/gitea-values.yaml")]

  # Admin credentials from SOPS (override values file)
  set {
    name  = "gitea.admin.username"
    value = local.git_secrets.gitea_admin_username
  }

  set_sensitive {
    name  = "gitea.admin.password"
    value = local.git_secrets.gitea_admin_password
  }

  set {
    name  = "gitea.admin.email"
    value = local.git_secrets.gitea_admin_email
  }

  # Wait for Gitea to be fully ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    helm_release.longhorn,
    kubernetes_namespace.gitea
  ]
}

# ============================================================================
# Wait for Gitea API to be Ready
# ============================================================================

resource "null_resource" "wait_for_gitea" {
  count = var.enable_gitea ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Gitea API to be ready..."

      # Port-forward to Gitea service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/gitea-http -n gitea 3000:3000 &
      PF_PID=$!

      # Cleanup on exit
      trap "kill $PF_PID 2>/dev/null" EXIT

      # Wait for port-forward to be ready
      sleep 5

      # Poll Gitea API
      for i in $(seq 1 60); do
        if curl -s http://localhost:3000/api/v1/version 2>/dev/null | grep -q "version"; then
          echo "Gitea API is ready!"
          exit 0
        fi
        echo "Waiting for Gitea API... ($i/60)"
        sleep 10
      done

      echo "Error: Timeout waiting for Gitea API"
      exit 1
    EOT
  }

  depends_on = [
    helm_release.gitea
  ]
}

# ============================================================================
# Generate Gitea Access Token for FluxCD
# ============================================================================

resource "null_resource" "gitea_generate_token" {
  count = var.enable_gitea && var.enable_fluxcd ? 1 : 0

  triggers = {
    # Re-run if admin credentials change
    admin_user = local.git_secrets.gitea_admin_username
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Generating Gitea access token for FluxCD..."

      # Port-forward to Gitea service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/gitea-http -n gitea 3000:3000 &
      PF_PID=$!

      # Cleanup on exit
      trap "kill $PF_PID 2>/dev/null" EXIT

      # Wait for port-forward
      sleep 5

      # Token name with timestamp to avoid conflicts
      TOKEN_NAME="flux-$(date +%Y%m%d-%H%M%S)"

      # Create token via Gitea API
      # NOTE: Token creation requires BasicAuth with password, not token auth!
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASS" \
        -d "{\"name\":\"$TOKEN_NAME\",\"scopes\":[\"write:repository\",\"read:user\",\"read:organization\"]}" \
        "http://localhost:3000/api/v1/users/$GITEA_ADMIN_USER/tokens")

      # Extract token (sha1 field)
      TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Error: Failed to create Gitea token"
        echo "Response: $RESPONSE"

        # Check if token already exists (409 conflict)
        if echo "$RESPONSE" | grep -q "already exist"; then
          echo "Token with similar name may already exist. Trying with random suffix..."
          TOKEN_NAME="flux-$(date +%s)"
          RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASS" \
            -d "{\"name\":\"$TOKEN_NAME\",\"scopes\":[\"write:repository\",\"read:user\",\"read:organization\"]}" \
            "http://localhost:3000/api/v1/users/$GITEA_ADMIN_USER/tokens")
          TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')
        fi

        if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
          exit 1
        fi
      fi

      # Save token to file for FluxCD bootstrap
      echo "$TOKEN" > ${path.module}/.gitea-flux-token
      chmod 600 ${path.module}/.gitea-flux-token

      echo "Gitea access token created successfully: $TOKEN_NAME"
    EOT

    environment = {
      GITEA_ADMIN_USER = local.git_secrets.gitea_admin_username
      GITEA_ADMIN_PASS = local.git_secrets.gitea_admin_password
    }
  }

  depends_on = [
    null_resource.wait_for_gitea
  ]
}

# ============================================================================
# Read Generated Token
# ============================================================================

data "local_file" "gitea_flux_token" {
  count    = var.enable_gitea && var.enable_fluxcd ? 1 : 0
  filename = "${path.module}/.gitea-flux-token"

  depends_on = [
    null_resource.gitea_generate_token
  ]
}

# ============================================================================
# Create Repository (Optional)
# ============================================================================

resource "null_resource" "gitea_create_repo" {
  count = var.enable_gitea && var.gitea_create_repo ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating Gitea repository: $REPO_NAME..."

      # Port-forward to Gitea service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/gitea-http -n gitea 3000:3000 &
      PF_PID=$!

      trap "kill $PF_PID 2>/dev/null" EXIT
      sleep 5

      # Check if repo already exists
      REPO_CHECK=$(curl -s -o /dev/null -w "%%{http_code}" \
        -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASS" \
        "http://localhost:3000/api/v1/repos/$GITEA_ADMIN_USER/$REPO_NAME")

      if [ "$REPO_CHECK" = "200" ]; then
        echo "Repository already exists, skipping creation"
        exit 0
      fi

      # Create repository
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "$GITEA_ADMIN_USER:$GITEA_ADMIN_PASS" \
        -d "{\"name\":\"$REPO_NAME\",\"private\":$REPO_PRIVATE,\"description\":\"Infrastructure as Code managed by FluxCD\"}" \
        "http://localhost:3000/api/v1/user/repos")

      if echo "$RESPONSE" | grep -q "\"name\":\"$REPO_NAME\""; then
        echo "Repository created successfully!"
      else
        echo "Warning: Repository creation response: $RESPONSE"
      fi
    EOT

    environment = {
      GITEA_ADMIN_USER = local.git_secrets.gitea_admin_username
      GITEA_ADMIN_PASS = local.git_secrets.gitea_admin_password
      REPO_NAME        = var.git_repository
      REPO_PRIVATE     = var.git_private ? "true" : "false"
    }
  }

  depends_on = [
    null_resource.gitea_generate_token
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Token Generation:
# - Gitea API requires BasicAuth (username:password) for token creation
# - Token auth CANNOT be used to create new tokens (API limitation)
# - Token is saved to .gitea-flux-token (gitignored)
#
# Scopes:
# - write:repository - Create/push to repos
# - read:user - Read user info
# - read:organization - Read org info (if using orgs)
#
# Manual token creation:
#   curl -X POST \
#     -H "Content-Type: application/json" \
#     -u "admin:password" \
#     -d '{"name":"flux","scopes":["write:repository"]}' \
#     "http://gitea:3000/api/v1/users/admin/tokens"
#
# Verification:
#   kubectl get pods -n gitea
#   kubectl logs -n gitea deployment/gitea
#   curl -H "Authorization: token <token>" http://gitea:3000/api/v1/user
