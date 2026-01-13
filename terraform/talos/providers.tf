# Provider Configuration
#
# Proxmox and Talos provider setup

# Proxmox Provider
provider "proxmox" {
  endpoint  = local.secrets.proxmox_url
  api_token = local.secrets.proxmox_api_token
  insecure  = local.secrets.proxmox_tls_insecure
}

# Talos Provider
provider "talos" {
  # No explicit configuration needed
  # Uses endpoints from talos_machine_configuration resources
}
