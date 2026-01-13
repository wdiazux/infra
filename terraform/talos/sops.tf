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

    # Computed values
    proxmox_api_token = "${data.sops_file.proxmox_secrets.data["proxmox_user"]}!${data.sops_file.proxmox_secrets.data["proxmox_token_id"]}=${data.sops_file.proxmox_secrets.data["proxmox_token_secret"]}"
  }
}
