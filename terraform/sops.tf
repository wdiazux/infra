# SOPS Encrypted Secrets Integration
#
# This file loads encrypted credentials from SOPS-encrypted YAML files.
# Secrets are encrypted with Age and stored in ../secrets/*.enc.yaml
#
# Prerequisites:
# 1. SOPS installed: https://github.com/getsops/sops
# 2. Age key available: export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
# 3. Encrypted secrets file exists: ../secrets/proxmox-creds.enc.yaml
#
# Usage:
#   Secrets are available via: local.secrets.<key>
#   Example: local.secrets.proxmox_url
#
# ============================================================================
# SOPS Data Source
# ============================================================================

# Load SOPS-encrypted Proxmox credentials
data "sops_file" "proxmox_secrets" {
  source_file = "${path.module}/../secrets/proxmox-creds.enc.yaml"
}

# ============================================================================
# Locals for Easy Access
# ============================================================================
#
# Use local.secrets.* throughout the configuration instead of variables
# for any sensitive values that should come from SOPS.
#

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

    # Cloud-init credentials for traditional VMs (with fallback to variables)
    cloud_init_user     = try(data.sops_file.proxmox_secrets.data["cloud_init_user"], var.cloud_init_user)
    cloud_init_password = try(data.sops_file.proxmox_secrets.data["cloud_init_password"], var.cloud_init_password)

    # Windows credentials (with fallback to variables)
    windows_admin_user     = try(data.sops_file.proxmox_secrets.data["windows_admin_user"], var.windows_admin_user)
    windows_admin_password = try(data.sops_file.proxmox_secrets.data["windows_admin_password"], var.windows_admin_password)

    # Computed values
    proxmox_api_token = "${data.sops_file.proxmox_secrets.data["proxmox_user"]}!${data.sops_file.proxmox_secrets.data["proxmox_token_id"]}=${data.sops_file.proxmox_secrets.data["proxmox_token_secret"]}"
  }
}

# ============================================================================
# Notes
# ============================================================================
#
# Adding new secrets:
# 1. Edit the encrypted file: sops ../secrets/proxmox-creds.enc.yaml
# 2. Add your new key-value pair
# 3. Save and exit (SOPS re-encrypts automatically)
# 4. Add the key to the locals.secrets map above
#
# Available secrets in proxmox-creds.enc.yaml:
# - proxmox_url: API endpoint URL
# - proxmox_user: User for authentication (e.g., terraform@pve)
# - proxmox_token_id: API token ID
# - proxmox_token_secret: API token secret
# - proxmox_node: Proxmox node name
# - proxmox_storage_pool: Default storage pool (e.g., tank)
# - proxmox_tls_insecure: Skip TLS verification (boolean)
# - ssh_public_key: SSH public key for VM templates
#
# To add cloud-init credentials, run:
#   sops ../secrets/proxmox-creds.enc.yaml
# And add:
#   cloud_init_user: "wdiaz"
#   cloud_init_password: "your-secure-password"
#
