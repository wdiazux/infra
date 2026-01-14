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

      echo "ERROR: Timeout waiting for Forgejo API"
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
      set -e

      # Pre-flight checks
      for cmd in kubectl curl jq; do
        if ! command -v $cmd &>/dev/null; then
          echo "ERROR: Required command '$cmd' not found. Install via nix-shell."
          exit 1
        fi
      done

      echo "Generating Forgejo access token for FluxCD..."

      # Create temp netrc file with secure permissions from start (avoids race condition)
      NETRC_FILE=$(umask 077 && mktemp)
      cat > "$NETRC_FILE" << NETRC
machine localhost
login $FORGEJO_ADMIN_USER
password $FORGEJO_ADMIN_PASS
NETRC

      # Port-forward to Forgejo service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/forgejo-http -n forgejo 3000:3000 &
      PF_PID=$!

      # Cleanup on exit (port-forward and netrc file)
      cleanup() {
        kill $PF_PID 2>/dev/null || true
        rm -f "$NETRC_FILE"
      }
      trap cleanup EXIT

      # Wait for port-forward to be ready
      echo "Waiting for port-forward..."
      for i in $(seq 1 30); do
        if curl -s -o /dev/null -w "" "http://localhost:3000/api/v1/version" 2>/dev/null; then
          echo "Port-forward ready."
          break
        fi
        sleep 1
      done

      # Token name with timestamp to avoid conflicts
      TOKEN_NAME="flux-$(date +%Y%m%d-%H%M%S)"

      # URL-encode the username to prevent injection
      ENCODED_USER=$(printf '%s' "$FORGEJO_ADMIN_USER" | jq -sRr @uri)

      # Create JSON payload safely using jq (prevents shell injection)
      JSON_PAYLOAD=$(jq -n --arg name "$TOKEN_NAME" \
        '{name: $name, scopes: ["write:repository", "read:user", "read:organization"]}')

      # Create token via Forgejo API (using netrc for secure auth)
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --netrc-file "$NETRC_FILE" \
        -d "$JSON_PAYLOAD" \
        "http://localhost:3000/api/v1/users/$ENCODED_USER/tokens")

      # Extract token (sha1 field)
      TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "WARNING: Failed to create Forgejo token with name $TOKEN_NAME"
        echo "Response: $RESPONSE"

        # Check if token already exists (409 conflict)
        if echo "$RESPONSE" | grep -q "already exist"; then
          echo "Token with similar name may already exist. Trying with random suffix..."
          TOKEN_NAME="flux-$(date +%s)"
          JSON_PAYLOAD=$(jq -n --arg name "$TOKEN_NAME" \
            '{name: $name, scopes: ["write:repository", "read:user", "read:organization"]}')
          RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            --netrc-file "$NETRC_FILE" \
            -d "$JSON_PAYLOAD" \
            "http://localhost:3000/api/v1/users/$ENCODED_USER/tokens")
          TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')
        fi

        if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
          echo "ERROR: Failed to create Forgejo token."
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
      set -e
      echo "Creating Forgejo repository: $REPO_NAME..."

      # Create temp netrc file with secure permissions from start (avoids race condition)
      NETRC_FILE=$(umask 077 && mktemp)
      cat > "$NETRC_FILE" << NETRC
machine localhost
login $FORGEJO_ADMIN_USER
password $FORGEJO_ADMIN_PASS
NETRC

      # Port-forward to Forgejo service
      kubectl --kubeconfig=${local.kubeconfig_path} port-forward \
        svc/forgejo-http -n forgejo 3000:3000 &
      PF_PID=$!

      # Cleanup on exit (port-forward and netrc file)
      cleanup() {
        kill $PF_PID 2>/dev/null || true
        rm -f "$NETRC_FILE"
      }
      trap cleanup EXIT

      sleep 5

      # URL-encode variables to prevent injection
      ENCODED_USER=$(printf '%s' "$FORGEJO_ADMIN_USER" | jq -sRr @uri)
      ENCODED_REPO=$(printf '%s' "$REPO_NAME" | jq -sRr @uri)

      # Check if repo already exists
      REPO_CHECK=$(curl -s -o /dev/null -w "%%{http_code}" \
        --netrc-file "$NETRC_FILE" \
        "http://localhost:3000/api/v1/repos/$ENCODED_USER/$ENCODED_REPO")

      if [ "$REPO_CHECK" = "200" ]; then
        echo "Repository already exists, skipping creation"
        exit 0
      fi

      # Create JSON payload safely using jq (prevents shell injection)
      JSON_PAYLOAD=$(jq -n \
        --arg name "$REPO_NAME" \
        --argjson private "$REPO_PRIVATE" \
        '{name: $name, private: $private, description: "Infrastructure as Code managed by FluxCD"}')

      # Create repository
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --netrc-file "$NETRC_FILE" \
        -d "$JSON_PAYLOAD" \
        "http://localhost:3000/api/v1/user/repos")

      # Check response using jq for safe parsing
      CREATED_NAME=$(echo "$RESPONSE" | jq -r '.name // empty')
      if [ "$CREATED_NAME" = "$REPO_NAME" ]; then
        echo "Repository created successfully!"
      else
        echo "WARNING: Repository creation response: $RESPONSE"
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
