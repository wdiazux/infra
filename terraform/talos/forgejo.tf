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
      # Allow privileged pods for forgejo-runner (docker-in-docker)
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
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

  # Use values file from kubernetes/infrastructure/values/
  values = [file("${path.module}/../../kubernetes/infrastructure/values/forgejo-values.yaml")]

  # Admin credentials from SOPS (override values file)
  set = [
    {
      name  = "gitea.admin.username"
      value = local.git_secrets.forgejo_admin_username
    },
    {
      name  = "gitea.admin.email"
      value = local.git_secrets.forgejo_admin_email
    },
    # Service IPs (override values file with Terraform variables)
    {
      name  = "service.http.loadBalancerIP"
      value = var.forgejo_ip
    },
    {
      name  = "service.ssh.loadBalancerIP"
      value = var.forgejo_ssh_ip
    },
    # ROOT_URL uses the domain name (must match browser access for CSRF validation)
    # HTTPS because users access via Gateway API with TLS termination
    {
      name  = "gitea.config.server.ROOT_URL"
      value = "https://${var.git_hostname}/"
    },
    # PostgreSQL database - CNPG (CloudNative-PG)
    # Host must be set explicitly to use CNPG instead of Bitnami subchart
    {
      name  = "gitea.config.database.HOST"
      value = "forgejo-postgresql-rw.forgejo.svc.cluster.local:5432"
    },
    {
      name  = "gitea.config.database.USER"
      value = local.git_secrets.postgresql_username
    },
  ]

  set_sensitive = [
    {
      name  = "gitea.admin.password"
      value = local.git_secrets.forgejo_admin_password
    },
    {
      name  = "gitea.config.database.PASSWD"
      value = local.git_secrets.postgresql_password
    },
  ]

  # Wait for Forgejo to be fully ready
  # Note: Forgejo can take 12+ minutes on first startup due to init containers
  wait          = true
  wait_for_jobs = true
  timeout       = 900

  depends_on = [
    helm_release.longhorn,
    kubernetes_namespace.forgejo,
    terraform_data.forgejo_pre_destroy # Pre-destroy runs cleanup before uninstall
  ]
}

# ============================================================================
# Wait for Forgejo API to be Ready
# ============================================================================

resource "null_resource" "wait_for_forgejo" {
  count = var.enable_forgejo ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      if ! command -v kubectl &>/dev/null; then
        echo "ERROR: kubectl not found. Install via nix-shell."
        exit 1
      fi

      echo "Waiting for Forgejo API to be ready..."

      # Use LoadBalancer IP directly (more reliable than port-forward)
      FORGEJO_URL="http://${var.forgejo_ip}/api/v1/version"

      # Poll Forgejo API
      for i in $(seq 1 60); do
        if curl -s "$FORGEJO_URL" 2>/dev/null | grep -q "version"; then
          echo "Forgejo API is ready!"
          exit 0
        fi
        echo "Waiting for Forgejo API... ($i/60)"
        sleep 5
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
    command = "${path.module}/scripts/forgejo-generate-token.sh"

    environment = {
      FORGEJO_ADMIN_USER = local.git_secrets.forgejo_admin_username
      FORGEJO_ADMIN_PASS = local.git_secrets.forgejo_admin_password
      FORGEJO_IP         = var.forgejo_ip
      TOKEN_FILE         = "${path.module}/.forgejo-flux-token"
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
    command = "${path.module}/scripts/forgejo-create-repo.sh"

    environment = {
      FORGEJO_ADMIN_USER = local.git_secrets.forgejo_admin_username
      FORGEJO_ADMIN_PASS = local.git_secrets.forgejo_admin_password
      FORGEJO_IP         = var.forgejo_ip
      REPO_NAME          = var.git_repository
      REPO_PRIVATE       = var.git_private ? "true" : "false"
    }
  }

  depends_on = [
    null_resource.forgejo_generate_token
  ]
}

# ============================================================================
# Push Local Infra Repository to Forgejo
# ============================================================================
# After creating the empty repo in Forgejo, push the local infra content
# so FluxCD can sync from it. This is the critical step that makes
# GitOps work - all kubernetes/ manifests must be in Forgejo.

resource "null_resource" "forgejo_push_repo" {
  count = var.enable_forgejo && var.forgejo_create_repo ? 1 : 0

  triggers = {
    # Re-run if repository changes
    repo_name = var.git_repository
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/forgejo-push-repo.sh"

    environment = {
      GIT_USER   = local.git_secrets.forgejo_admin_username
      GIT_TOKEN  = trimspace(data.local_file.forgejo_flux_token[0].content)
      FORGEJO_IP = var.forgejo_ip
      REPO_NAME  = var.git_repository
      GIT_BRANCH = var.git_branch
      REPO_ROOT  = "${path.module}/../.."
    }
  }

  depends_on = [
    null_resource.forgejo_create_repo,
    data.local_file.forgejo_flux_token
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
