# Packer Variables for NixOS Cloud Image
#
# This file defines variables for building NixOS golden image
# using the cloud image approach (proxmox-clone builder)

# Proxmox Connection
variable "proxmox_url" {
  type        = string
  description = "Proxmox API endpoint URL"
  default     = env("PROXMOX_URL")
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox token ID (format: user@realm!tokenid)"
  default     = env("PROXMOX_USERNAME")
  sensitive   = true
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret"
  default     = env("PROXMOX_TOKEN")
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
  default     = "pve"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification"
  default     = true
}

# Cloud Image Configuration
variable "cloud_image_vm_id" {
  type        = number
  description = "VM ID of the base cloud image (created by import-cloud-image.sh)"
  default     = 9200
}

# NixOS Version (for documentation/tracking)
variable "nixos_version" {
  type        = string
  description = "NixOS version (25.11 = current development)"
  default     = "25.11"
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "nixos-golden-template"
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "NixOS 25.11 golden image with cloud-init (declarative configuration)"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9202
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "nixos-build"
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB"
  default     = 2048
}

variable "vm_disk_storage" {
  type        = string
  description = "Proxmox storage pool"
  default     = "tank"
}

variable "vm_network_bridge" {
  type        = string
  description = "Network bridge"
  default     = "vmbr0"
}

# SSH Configuration
variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning (default NixOS cloud image password)"
  default     = "nixos"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to add to the template (optional)"
  default     = ""
}
