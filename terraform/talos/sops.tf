# SOPS Encrypted Secrets Integration
#
# Loads encrypted credentials from SOPS-encrypted YAML files.

# Load SOPS-encrypted Proxmox credentials
data "sops_file" "proxmox_secrets" {
  source_file = "${path.module}/../../secrets/proxmox-creds.enc.yaml"
}

# Load SOPS-encrypted Git credentials (for Forgejo/FluxCD)
data "sops_file" "git_secrets" {
  count       = var.enable_forgejo || var.enable_fluxcd ? 1 : 0
  source_file = "${path.module}/../../secrets/git-creds.enc.yaml"
}

# Load SOPS-encrypted NAS backup credentials (for Longhorn)
data "sops_file" "nas_backup_secrets" {
  count       = var.enable_longhorn_backups ? 1 : 0
  source_file = "${path.module}/../../secrets/nas-backup-creds.enc.yaml"
}

# Load SOPS-encrypted Pangolin credentials (for Newt tunnel)
data "sops_file" "pangolin_secrets" {
  count       = var.enable_pangolin ? 1 : 0
  source_file = "${path.module}/../../secrets/pangolin-creds.enc.yaml"
}

locals {
  # SOPS-decrypted secrets
  secrets = {
    # Proxmox connection
    proxmox_url          = data.sops_file.proxmox_secrets.data["proxmox_url"]
    proxmox_user         = data.sops_file.proxmox_secrets.data["proxmox_user"]
    proxmox_token_id     = data.sops_file.proxmox_secrets.data["proxmox_token_id"]
    proxmox_token_secret = data.sops_file.proxmox_secrets.data["proxmox_token_secret"]
    proxmox_node         = data.sops_file.proxmox_secrets.data["proxmox_node"]
    proxmox_storage_pool = data.sops_file.proxmox_secrets.data["proxmox_storage_pool"]
    proxmox_tls_insecure = tobool(data.sops_file.proxmox_secrets.data["proxmox_tls_insecure"])

    # Computed values
    proxmox_api_token = "${data.sops_file.proxmox_secrets.data["proxmox_user"]}!${data.sops_file.proxmox_secrets.data["proxmox_token_id"]}=${data.sops_file.proxmox_secrets.data["proxmox_token_secret"]}"
  }

  # Git/Forgejo secrets (loaded only when needed)
  git_secrets = var.enable_forgejo || var.enable_fluxcd ? {
    # Git settings (Forgejo-only)
    git_hostname   = try(data.sops_file.git_secrets[0].data["git_hostname"], var.git_hostname)
    git_owner      = try(data.sops_file.git_secrets[0].data["git_owner"], var.git_owner)
    git_repository = try(data.sops_file.git_secrets[0].data["git_repository"], var.git_repository)
    git_token      = try(data.sops_file.git_secrets[0].data["git_token"], var.git_token)

    # Forgejo admin credentials (for in-cluster Forgejo)
    forgejo_admin_username = try(data.sops_file.git_secrets[0].data["forgejo_admin_username"], "forgejo_admin")
    forgejo_admin_password = try(data.sops_file.git_secrets[0].data["forgejo_admin_password"], "")
    forgejo_admin_email    = try(data.sops_file.git_secrets[0].data["forgejo_admin_email"], "admin@home-infra.net")

    # Weave GitOps admin password hash
    weave_gitops_password_hash = try(data.sops_file.git_secrets[0].data["weave_gitops_password_hash"], var.weave_gitops_password_hash)
  } : {}
}
