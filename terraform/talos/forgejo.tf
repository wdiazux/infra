# Forgejo Deployment and Token Generation
#
# Deploys in-cluster Forgejo and automatically generates an access token
# for FluxCD bootstrap. Solves the chicken-and-egg problem of needing
# Git credentials before FluxCD can manage Forgejo.
#
# Bootstrap Flow:
# 1. Talos cluster ready with Cilium + Longhorn
# 2. Forgejo deployed via Helm with admin credentials from SOPS
# 3. Wait for Forgejo to be ready
# 4. Generate access token via Forgejo API (requires BasicAuth)
# 5. Create Kubernetes secret for FluxCD
# 6. FluxCD bootstrap uses the generated token
#
# Prerequisites:
# - secrets/git-creds.enc.yaml with forgejo_admin_password

# ============================================================================
# Forgejo Namespace
# ============================================================================

resource "kubernetes_namespace" "forgejo" {
  count = var.enable_forgejo ? 1 : 0

  metadata {
    name = "forgejo"
    labels = {
      "app.kubernetes.io/name"       = "forgejo"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    null_resource.wait_for_cilium
  ]
}

# ============================================================================
# Forgejo Helm Release
# ============================================================================

resource "helm_release" "forgejo" {
  count = var.enable_forgejo ? 1 : 0

  name             = "forgejo"
  repository       = "oci://codeberg.org/forgejo-contrib"
  chart            = "forgejo"
  version          = var.forgejo_chart_version
  namespace        = kubernetes_namespace.forgejo[0].metadata[0].name
  create_namespace = false

  # Use values file from kubernetes/forgejo/
  values = [file("${path.module}/../../kubernetes/forgejo/forgejo-values.yaml")]

  # Admin credentials from SOPS (override values file)
  set {
    name  = "gitea.admin.username"
    value = local.git_secrets.forgejo_admin_username
  }

  set_sensitive {
    name  = "gitea.admin.password"
    value = local.git_secrets.forgejo_admin_password
  }

  set {
    name  = "gitea.admin.email"
    value = local.git_secrets.forgejo_admin_email
  }

  # Wait for Forgejo to be fully ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    helm_release.longhorn,
    kubernetes_namespace.forgejo
  ]
}

# ============================================================================
# Wait for Forgejo API to be Ready
# ============================================================================

resource "null_resource" "wait_for_forgejo" {
  count = var.enable_forgejo ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Forgejo API to be ready..."

      # Port-forward to Forgejo service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/forgejo-http -n forgejo 3000:3000 &
      PF_PID=$!

      # Cleanup on exit
      trap "kill $PF_PID 2>/dev/null" EXIT

      # Wait for port-forward to be ready
      sleep 5

      # Poll Forgejo API
      for i in $(seq 1 60); do
        if curl -s http://localhost:3000/api/v1/version 2>/dev/null | grep -q "version"; then
          echo "Forgejo API is ready!"
          exit 0
        fi
        echo "Waiting for Forgejo API... ($i/60)"
        sleep 10
      done

      echo "Error: Timeout waiting for Forgejo API"
      exit 1
    EOT
  }

  depends_on = [
    helm_release.forgejo
  ]
}

# ============================================================================
# Generate Forgejo Access Token for FluxCD
# ============================================================================

resource "null_resource" "forgejo_generate_token" {
  count = var.enable_forgejo && var.enable_fluxcd ? 1 : 0

  triggers = {
    # Re-run if admin credentials change
    admin_user = local.git_secrets.forgejo_admin_username
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Generating Forgejo access token for FluxCD..."

      # Port-forward to Forgejo service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/forgejo-http -n forgejo 3000:3000 &
      PF_PID=$!

      # Cleanup on exit
      trap "kill $PF_PID 2>/dev/null" EXIT

      # Wait for port-forward
      sleep 5

      # Token name with timestamp to avoid conflicts
      TOKEN_NAME="flux-$(date +%Y%m%d-%H%M%S)"

      # Create token via Forgejo API
      # NOTE: Token creation requires BasicAuth with password, not token auth!
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "$FORGEJO_ADMIN_USER:$FORGEJO_ADMIN_PASS" \
        -d "{\"name\":\"$TOKEN_NAME\",\"scopes\":[\"write:repository\",\"read:user\",\"read:organization\"]}" \
        "http://localhost:3000/api/v1/users/$FORGEJO_ADMIN_USER/tokens")

      # Extract token (sha1 field)
      TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Error: Failed to create Forgejo token"
        echo "Response: $RESPONSE"

        # Check if token already exists (409 conflict)
        if echo "$RESPONSE" | grep -q "already exist"; then
          echo "Token with similar name may already exist. Trying with random suffix..."
          TOKEN_NAME="flux-$(date +%s)"
          RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u "$FORGEJO_ADMIN_USER:$FORGEJO_ADMIN_PASS" \
            -d "{\"name\":\"$TOKEN_NAME\",\"scopes\":[\"write:repository\",\"read:user\",\"read:organization\"]}" \
            "http://localhost:3000/api/v1/users/$FORGEJO_ADMIN_USER/tokens")
          TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')
        fi

        if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
          exit 1
        fi
      fi

      # Save token to file for FluxCD bootstrap
      echo "$TOKEN" > ${path.module}/.forgejo-flux-token
      chmod 600 ${path.module}/.forgejo-flux-token

      echo "Forgejo access token created successfully: $TOKEN_NAME"
    EOT

    environment = {
      FORGEJO_ADMIN_USER = local.git_secrets.forgejo_admin_username
      FORGEJO_ADMIN_PASS = local.git_secrets.forgejo_admin_password
    }
  }

  depends_on = [
    null_resource.wait_for_forgejo
  ]
}

# ============================================================================
# Read Generated Token
# ============================================================================

data "local_file" "forgejo_flux_token" {
  count    = var.enable_forgejo && var.enable_fluxcd ? 1 : 0
  filename = "${path.module}/.forgejo-flux-token"

  depends_on = [
    null_resource.forgejo_generate_token
  ]
}

# ============================================================================
# Create Repository (Optional)
# ============================================================================

resource "null_resource" "forgejo_create_repo" {
  count = var.enable_forgejo && var.forgejo_create_repo ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating Forgejo repository: $REPO_NAME..."

      # Port-forward to Forgejo service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/forgejo-http -n forgejo 3000:3000 &
      PF_PID=$!

      trap "kill $PF_PID 2>/dev/null" EXIT
      sleep 5

      # Check if repo already exists
      REPO_CHECK=$(curl -s -o /dev/null -w "%%{http_code}" \
        -u "$FORGEJO_ADMIN_USER:$FORGEJO_ADMIN_PASS" \
        "http://localhost:3000/api/v1/repos/$FORGEJO_ADMIN_USER/$REPO_NAME")

      if [ "$REPO_CHECK" = "200" ]; then
        echo "Repository already exists, skipping creation"
        exit 0
      fi

      # Create repository
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "$FORGEJO_ADMIN_USER:$FORGEJO_ADMIN_PASS" \
        -d "{\"name\":\"$REPO_NAME\",\"private\":$REPO_PRIVATE,\"description\":\"Infrastructure as Code managed by FluxCD\"}" \
        "http://localhost:3000/api/v1/user/repos")

      if echo "$RESPONSE" | grep -q "\"name\":\"$REPO_NAME\""; then
        echo "Repository created successfully!"
      else
        echo "Warning: Repository creation response: $RESPONSE"
      fi
    EOT

    environment = {
      FORGEJO_ADMIN_USER = local.git_secrets.forgejo_admin_username
      FORGEJO_ADMIN_PASS = local.git_secrets.forgejo_admin_password
      REPO_NAME          = var.git_repository
      REPO_PRIVATE       = var.git_private ? "true" : "false"
    }
  }

  depends_on = [
    null_resource.forgejo_generate_token
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Token Generation:
# - Forgejo API requires BasicAuth (username:password) for token creation
# - Token auth CANNOT be used to create new tokens (API limitation)
# - Token is saved to .forgejo-flux-token (gitignored)
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
#     "http://forgejo:3000/api/v1/users/admin/tokens"
#
# Verification:
#   kubectl get pods -n forgejo
#   kubectl logs -n forgejo deployment/forgejo
#   curl -H "Authorization: token <token>" http://forgejo:3000/api/v1/user
