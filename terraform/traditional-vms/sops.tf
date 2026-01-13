# SOPS Encrypted Secrets Integration
#
# Loads encrypted credentials from SOPS-encrypted YAML files.

# Load SOPS-encrypted Proxmox credentials
data "sops_file" "proxmox_secrets" {
  source_file = "${path.module}/../../secrets/proxmox-creds.enc.yaml"
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

    # SSH public key for VM templates
    ssh_public_key = data.sops_file.proxmox_secrets.data["ssh_public_key"]

    # Cloud-init credentials (with fallback to variables)
    cloud_init_user     = try(data.sops_file.proxmox_secrets.data["cloud_init_user"], var.cloud_init_user)
    cloud_init_password = try(data.sops_file.proxmox_secrets.data["cloud_init_password"], var.cloud_init_password)

    # Windows credentials (with fallback to variables)
    windows_admin_user     = try(data.sops_file.proxmox_secrets.data["windows_admin_user"], var.windows_admin_user)
    windows_admin_password = try(data.sops_file.proxmox_secrets.data["windows_admin_password"], var.windows_admin_password)

    # Computed values
    proxmox_api_token = "${data.sops_file.proxmox_secrets.data["proxmox_user"]}!${data.sops_file.proxmox_secrets.data["proxmox_token_id"]}=${data.sops_file.proxmox_secrets.data["proxmox_token_secret"]}"
  }
}
