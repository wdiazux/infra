# Provider Configuration
#
# Proxmox provider for traditional VMs

provider "proxmox" {
  endpoint  = local.secrets.proxmox_url
  api_token = local.secrets.proxmox_api_token
  insecure  = local.secrets.proxmox_tls_insecure
}
