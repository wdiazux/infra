# FluxCD Bootstrap for Forgejo (HTTP)
#
# Automatically bootstraps FluxCD for GitOps management after the cluster
# is ready. FluxCD will then manage all Kubernetes resources from Git.
#
# NOTE: Standard `flux bootstrap gitea` requires HTTPS. Since in-cluster
# Forgejo runs on HTTP, we use manual installation approach:
# 1. Install FluxCD components with `flux install`
# 2. Create Git credentials secret
# 3. Create GitRepository source (HTTP)
# 4. Create Kustomization to sync from path
#
# Bootstrap Flow:
# 1. Talos cluster ready with Cilium (inline manifest)
# 2. Longhorn installed via Helm
# 3. Forgejo installed via Helm (if enable_forgejo=true)
# 4. Forgejo token auto-generated
# 5. FluxCD installed and configured for HTTP Forgejo
# 6. FluxCD syncs kubernetes/clusters/homelab/
#
# Token Sources:
# - Auto-generated from in-cluster Forgejo (if enable_forgejo=true)
# - OR from SOPS-encrypted git-creds.enc.yaml (external Forgejo)

# ============================================================================
# Computed Values
# ============================================================================

locals {
  # Git token: auto-generated from Forgejo or from SOPS
  fluxcd_git_token = var.enable_forgejo ? (
    try(trimspace(data.local_file.forgejo_flux_token[0].content), "")
    ) : (
    try(local.git_secrets.git_token, var.git_token)
  )

  # Git settings (prefer SOPS, fall back to variables)
  fluxcd_git_repository = try(local.git_secrets.git_repository, var.git_repository)

  # Git owner: use Forgejo admin when in-cluster, otherwise from SOPS/variables
  # This ensures repo owner matches who created the repo
  fluxcd_git_owner = var.enable_forgejo ? (
    try(local.git_secrets.forgejo_admin_username, "forgejo_admin")
    ) : (
    try(local.git_secrets.git_owner, var.git_owner)
  )

  # HTTP URL for in-cluster Forgejo (used when enable_forgejo=true)
  forgejo_http_url = "http://${var.forgejo_ip}/${local.fluxcd_git_owner}/${local.fluxcd_git_repository}.git"
}

# ============================================================================
# FluxCD Installation (Controllers)
# ============================================================================

resource "null_resource" "flux_install" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    # Re-run if we want to update flux
    flux_version = "latest"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/fluxcd-install.sh"

    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
  }

  depends_on = [
    helm_release.longhorn,
    null_resource.forgejo_generate_token,
    null_resource.forgejo_push_repo,
    terraform_data.fluxcd_pre_destroy # Pre-destroy runs cleanup before uninstall
  ]
}

# ============================================================================
# FluxCD Git Credentials Secret
# ============================================================================

resource "null_resource" "flux_git_secret" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_owner      = local.fluxcd_git_owner
    git_repository = local.fluxcd_git_repository
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/fluxcd-git-secret.sh"

    environment = {
      KUBECONFIG = local.kubeconfig_path
      GIT_OWNER  = local.fluxcd_git_owner
      GIT_TOKEN  = local.fluxcd_git_token
    }
  }

  depends_on = [
    null_resource.flux_install
  ]
}

# ============================================================================
# FluxCD GitRepository Source (HTTP)
# ============================================================================

resource "null_resource" "flux_git_repository" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_url  = local.forgejo_http_url
    git_path = var.fluxcd_path
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/fluxcd-git-repository.sh"

    environment = {
      KUBECONFIG = local.kubeconfig_path
      GIT_URL    = local.forgejo_http_url
      GIT_BRANCH = var.git_branch
    }
  }

  depends_on = [
    null_resource.flux_git_secret
  ]
}

# ============================================================================
# FluxCD Kustomization (Sync from Path)
# ============================================================================

resource "null_resource" "flux_kustomization" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_path = var.fluxcd_path
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/fluxcd-kustomization.sh"

    environment = {
      KUBECONFIG  = local.kubeconfig_path
      FLUXCD_PATH = var.fluxcd_path
    }
  }

  depends_on = [
    null_resource.flux_git_repository,
    null_resource.create_sops_age_secret
  ]
}

# ============================================================================
# FluxCD Verification
# ============================================================================

resource "null_resource" "flux_verify" {
  count = var.enable_fluxcd ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for FluxCD to reconcile..."
      sleep 30

      echo "=== FluxCD Status ==="
      kubectl --kubeconfig=${local.kubeconfig_path} get pods -n flux-system

      echo "=== GitRepository Status ==="
      flux get sources git --kubeconfig=${local.kubeconfig_path} -A || true

      echo "=== Kustomizations ==="
      flux get kustomizations --kubeconfig=${local.kubeconfig_path} -A || true

      echo "=== FluxCD Verification Complete ==="
    EOT
  }

  depends_on = [
    null_resource.flux_kustomization
  ]
}

# ============================================================================
# SOPS Age Secret for Application Secrets
# ============================================================================
# Creates the sops-age secret that FluxCD uses to decrypt encrypted secrets.
# This enables GitOps for secrets: encrypt with SOPS, commit to Git, FluxCD decrypts.

resource "null_resource" "create_sops_age_secret" {
  count = var.enable_fluxcd && var.sops_age_key_file != "" ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/fluxcd-sops-secret.sh"

    environment = {
      KUBECONFIG        = local.kubeconfig_path
      SOPS_AGE_KEY_FILE = pathexpand(var.sops_age_key_file)
    }
  }

  depends_on = [
    null_resource.flux_install
  ]
}
