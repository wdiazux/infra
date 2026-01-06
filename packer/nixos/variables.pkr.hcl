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
  description = "Proxmox node name (lowercase letters, numbers, hyphens only)"
  default     = "pve"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.proxmox_node))
    error_message = "Node name must contain only lowercase letters, numbers, and hyphens."
  }
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

  validation {
    condition     = var.cloud_image_vm_id >= 100 && var.cloud_image_vm_id <= 999999999
    error_message = "Cloud image VM ID must be between 100 and 999999999."
  }
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

  validation {
    condition     = length(var.template_name) > 0 && length(var.template_name) <= 63
    error_message = "Template name must be 1-63 characters."
  }
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "NixOS 25.11 golden image with cloud-init (declarative configuration)"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template (must be 100-999999999)"
  default     = 9202

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "VM ID must be between 100 and 999999999 (Proxmox limits)."
  }
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "nixos-build"
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores (1-128)"
  default     = 2

  validation {
    condition     = var.vm_cores >= 1 && var.vm_cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB (minimum 512MB)"
  default     = 2048

  validation {
    condition     = var.vm_memory >= 512
    error_message = "Memory must be at least 512MB."
  }
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

# Note: SSH keys are configured in config/configuration.nix
