# FluxCD Bootstrap
#
# Automatically bootstraps FluxCD for GitOps management after the cluster
# is ready. FluxCD will then manage all Kubernetes resources from Git.
#
# Supported Git Providers:
# - forgejo: Self-hosted Forgejo/Gitea (flux bootstrap git)
# - github: GitHub (flux bootstrap github)
# - gitlab: GitLab (flux bootstrap gitlab)
#
# Token Sources (in order of precedence):
# 1. Auto-generated from in-cluster Gitea (if enable_gitea=true)
# 2. SOPS-encrypted git-creds.enc.yaml
# 3. TF_VAR_git_token environment variable
#
# Prerequisites:
# - For in-cluster Gitea: enable_gitea=true, gitea_admin_password in SOPS
# - For external Git: git_token in SOPS or TF_VAR_git_token env var

# ============================================================================
# Computed Token Value
# ============================================================================

locals {
  # Use auto-generated token from Gitea if enabled, otherwise use SOPS/variable
  fluxcd_git_token = var.enable_gitea ? (
    try(trimspace(data.local_file.gitea_flux_token[0].content), "")
    ) : (
    try(local.git_secrets.git_token, var.git_token)
  )

  # Git settings (prefer SOPS, fall back to variables)
  fluxcd_git_hostname   = try(local.git_secrets.git_hostname, var.git_hostname)
  fluxcd_git_owner      = try(local.git_secrets.git_owner, var.git_owner)
  fluxcd_git_repository = try(local.git_secrets.git_repository, var.git_repository)
  fluxcd_git_provider   = try(local.git_secrets.git_provider, var.git_provider)
}

# ============================================================================
# FluxCD Bootstrap
# ============================================================================

resource "null_resource" "flux_bootstrap" {
  count = var.auto_bootstrap && var.enable_fluxcd ? 1 : 0

  triggers = {
    # Re-run if git settings change
    git_owner      = local.fluxcd_git_owner
    git_repository = local.fluxcd_git_repository
    git_provider   = local.fluxcd_git_provider
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Bootstrapping FluxCD with provider: ${local.fluxcd_git_provider}..."

      # Check if flux is installed
      if ! command -v flux &> /dev/null; then
        echo "Error: flux CLI not found. Install with: nix-shell or brew install fluxcd/tap/flux"
        exit 1
      fi

      # Validate token
      if [ -z "$FLUX_GIT_TOKEN" ]; then
        echo "Error: Git token is empty. Check SOPS secrets or enable_gitea configuration."
        exit 1
      fi

      # Check prerequisites
      if ! flux check --pre --kubeconfig=${local.kubeconfig_path}; then
        echo "Warning: FluxCD prerequisites check failed, attempting bootstrap anyway..."
      fi

      # Bootstrap based on provider
      case "${local.fluxcd_git_provider}" in
        forgejo|gitea)
          echo "Using Gitea bootstrap for Forgejo/Gitea..."
          echo "  Hostname: ${local.fluxcd_git_hostname}"
          echo "  Owner: ${local.fluxcd_git_owner}"
          echo "  Repository: ${local.fluxcd_git_repository}"

          # Set token for flux CLI
          export GITEA_TOKEN="$FLUX_GIT_TOKEN"

          flux bootstrap gitea \
            --kubeconfig=${local.kubeconfig_path} \
            --hostname=${local.fluxcd_git_hostname} \
            --owner=${local.fluxcd_git_owner} \
            --repository=${local.fluxcd_git_repository} \
            --branch=${var.git_branch} \
            --path=${var.fluxcd_path} \
            --personal=${var.git_personal} \
            --private=${var.git_private}
          ;;
        github)
          echo "Using GitHub bootstrap..."
          export GITHUB_TOKEN="$FLUX_GIT_TOKEN"

          flux bootstrap github \
            --kubeconfig=${local.kubeconfig_path} \
            --owner=${local.fluxcd_git_owner} \
            --repository=${local.fluxcd_git_repository} \
            --path=${var.fluxcd_path} \
            --branch=${var.git_branch} \
            --personal=${var.git_personal} \
            --private=${var.git_private}
          ;;
        gitlab)
          echo "Using GitLab bootstrap..."
          export GITLAB_TOKEN="$FLUX_GIT_TOKEN"

          flux bootstrap gitlab \
            --kubeconfig=${local.kubeconfig_path} \
            --owner=${local.fluxcd_git_owner} \
            --repository=${local.fluxcd_git_repository} \
            --path=${var.fluxcd_path} \
            --branch=${var.git_branch} \
            --personal=${var.git_personal}
          ;;
        *)
          echo "Error: Unknown git provider: ${local.fluxcd_git_provider}"
          exit 1
          ;;
      esac

      echo "FluxCD bootstrap complete!"
    EOT

    environment = {
      FLUX_GIT_TOKEN = local.fluxcd_git_token
    }
  }

  depends_on = [
    helm_release.longhorn,
    null_resource.install_nvidia_device_plugin,
    # Wait for Gitea token generation if using in-cluster Gitea
    null_resource.gitea_generate_token,
    null_resource.gitea_create_repo
  ]
}

# ============================================================================
# FluxCD Verification
# ============================================================================

resource "null_resource" "flux_verify" {
  count = var.auto_bootstrap && var.enable_fluxcd ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying FluxCD installation..."
      sleep 30  # Wait for FluxCD to reconcile

      # Check FluxCD status
      kubectl --kubeconfig=${local.kubeconfig_path} get pods -n flux-system

      # Check kustomizations
      flux get kustomizations --kubeconfig=${local.kubeconfig_path} -A

      echo "FluxCD verification complete!"
    EOT
  }

  depends_on = [
    null_resource.flux_bootstrap
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# FluxCD Bootstrap Flow:
# 1. Terraform creates VM and bootstraps Talos
# 2. Cilium installed via inlineManifest (node becomes Ready)
# 3. Longhorn installed via Helm
# 4. FluxCD bootstrapped via CLI
# 5. FluxCD syncs kubernetes/clusters/homelab/
# 6. FluxCD manages all subsequent deployments
#
# Manual bootstrap examples:
#
# Forgejo/Gitea:
#   export GITEA_TOKEN=<token>
#   flux bootstrap gitea \
#     --hostname=git.home-infra.net \
#     --owner=<username> \
#     --repository=infra \
#     --branch=main \
#     --path=kubernetes/clusters/homelab \
#     --personal
#
# GitHub:
#   export GITHUB_TOKEN=<token>
#   flux bootstrap github \
#     --owner=<github-user> \
#     --repository=infra \
#     --path=kubernetes/clusters/homelab \
#     --personal
#
# Verification:
#   flux check
#   flux get all -A
#   kubectl get pods -n flux-system
