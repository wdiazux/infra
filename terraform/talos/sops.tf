# SOPS Encrypted Secrets Integration
#
# Loads encrypted credentials from SOPS-encrypted YAML files.

# Load SOPS-encrypted Proxmox credentials
data "sops_file" "proxmox_secrets" {
  source_file = "${path.module}/../../secrets/proxmox-creds.enc.yaml"
}

# Load SOPS-encrypted Git credentials (for Gitea/FluxCD)
data "sops_file" "git_secrets" {
  count       = var.enable_gitea || var.enable_fluxcd ? 1 : 0
  source_file = "${path.module}/../../secrets/git-creds.enc.yaml"
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

  # Git/Gitea secrets (loaded only when needed)
  git_secrets = var.enable_gitea || var.enable_fluxcd ? {
    # Git provider settings
    git_provider   = try(data.sops_file.git_secrets[0].data["git_provider"], var.git_provider)
    git_hostname   = try(data.sops_file.git_secrets[0].data["git_hostname"], var.git_hostname)
    git_owner      = try(data.sops_file.git_secrets[0].data["git_owner"], var.git_owner)
    git_repository = try(data.sops_file.git_secrets[0].data["git_repository"], var.git_repository)
    git_token      = try(data.sops_file.git_secrets[0].data["git_token"], var.git_token)

    # Gitea admin credentials (for in-cluster Gitea)
    gitea_admin_username = try(data.sops_file.git_secrets[0].data["gitea_admin_username"], "gitea_admin")
    gitea_admin_password = try(data.sops_file.git_secrets[0].data["gitea_admin_password"], "")
    gitea_admin_email    = try(data.sops_file.git_secrets[0].data["gitea_admin_email"], "admin@home-infra.net")
  } : {}
}
