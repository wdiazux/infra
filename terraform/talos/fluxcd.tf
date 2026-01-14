# FluxCD Bootstrap for Forgejo
#
# Automatically bootstraps FluxCD for GitOps management after the cluster
# is ready. FluxCD will then manage all Kubernetes resources from Git.
#
# Bootstrap Flow:
# 1. Talos cluster ready with Cilium (inline manifest)
# 2. Longhorn installed via Helm
# 3. Forgejo installed via Helm (if enable_forgejo=true)
# 4. Forgejo token auto-generated
# 5. FluxCD bootstrapped to Forgejo repository
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
  fluxcd_git_hostname   = try(local.git_secrets.git_hostname, var.git_hostname)
  fluxcd_git_owner      = try(local.git_secrets.git_owner, var.git_owner)
  fluxcd_git_repository = try(local.git_secrets.git_repository, var.git_repository)
}

# ============================================================================
# FluxCD Bootstrap
# ============================================================================

resource "null_resource" "flux_bootstrap" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_owner      = local.fluxcd_git_owner
    git_repository = local.fluxcd_git_repository
    git_hostname   = local.fluxcd_git_hostname
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== FluxCD Bootstrap for Forgejo ==="
      echo "Hostname: ${local.fluxcd_git_hostname}"
      echo "Owner: ${local.fluxcd_git_owner}"
      echo "Repository: ${local.fluxcd_git_repository}"
      echo "Path: ${var.fluxcd_path}"

      # Validate flux CLI
      if ! command -v flux &> /dev/null; then
        echo "Error: flux CLI not found. Install via nix-shell."
        exit 1
      fi

      # Validate token
      if [ -z "$GITEA_TOKEN" ]; then
        echo "Error: Git token is empty."
        echo "For in-cluster Forgejo: ensure enable_forgejo=true and forgejo_admin_password is set"
        echo "For external Forgejo: ensure git_token is set in git-creds.enc.yaml"
        exit 1
      fi

      # Pre-flight check
      flux check --pre --kubeconfig=${local.kubeconfig_path} || true

      # Bootstrap FluxCD to Forgejo
      # Note: Forgejo is API-compatible with Gitea, so we use 'flux bootstrap gitea'
      flux bootstrap gitea \
        --kubeconfig=${local.kubeconfig_path} \
        --hostname=${local.fluxcd_git_hostname} \
        --owner=${local.fluxcd_git_owner} \
        --repository=${local.fluxcd_git_repository} \
        --branch=${var.git_branch} \
        --path=${var.fluxcd_path} \
        --personal=${var.git_personal} \
        --private=${var.git_private} \
        --token-auth

      echo "=== FluxCD Bootstrap Complete ==="
    EOT

    environment = {
      GITEA_TOKEN = local.fluxcd_git_token
    }
  }

  depends_on = [
    helm_release.longhorn,
    null_resource.forgejo_generate_token,
    null_resource.forgejo_create_repo
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

      echo "=== Kustomizations ==="
      flux get kustomizations --kubeconfig=${local.kubeconfig_path} -A || true

      echo "=== FluxCD Verification Complete ==="
    EOT
  }

  depends_on = [
    null_resource.flux_bootstrap
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
    command = <<-EOT
      echo "Creating SOPS Age secret for FluxCD..."

      # Check if secret already exists
      if kubectl --kubeconfig=${local.kubeconfig_path} get secret sops-age -n flux-system &>/dev/null; then
        echo "sops-age secret already exists, skipping"
        exit 0
      fi

      # Create the secret
      kubectl --kubeconfig=${local.kubeconfig_path} create secret generic sops-age \
        --namespace=flux-system \
        --from-file=age.agekey=${var.sops_age_key_file}

      echo "SOPS Age secret created successfully"
    EOT
  }

  depends_on = [
    null_resource.flux_bootstrap
  ]
}
