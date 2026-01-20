# Packer Variables for Arch Linux Golden Image
#
# This file defines variables for building Arch Linux golden image
# for Proxmox VE 9.0

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

# Cloud Image Base VM
variable "cloud_image_vm_id" {
  type        = number
  description = "VM ID of imported cloud image (created by import-cloud-image.sh)"
  default     = 9300

  validation {
    condition     = var.cloud_image_vm_id >= 100 && var.cloud_image_vm_id <= 999999999
    error_message = "Cloud image VM ID must be between 100 and 999999999."
  }
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "arch-cloud-template"

  validation {
    condition     = length(var.template_name) > 0 && length(var.template_name) <= 63
    error_message = "Template name must be 1-63 characters."
  }
}

variable "template_version" {
  type        = string
  description = "Semantic version for template (e.g., 1.0.0)"
  default     = "1.0.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.template_version))
    error_message = "Template version must follow semantic versioning (e.g., 1.0.0)."
  }
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Arch Linux golden image with cloud-init"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template (must be 100-999999999)"
  default     = 9302

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "VM ID must be between 100 and 999999999 (Proxmox limits)."
  }
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "arch-cloud-build"
}

variable "vm_cpu_type" {
  type        = string
  description = "CPU type"
  default     = "host"
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

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
  default     = "20G"
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
variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "root"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning"
  default     = "arch"
  sensitive   = true
}

variable "ssh_timeout" {
  type        = string
  description = "SSH timeout"
  default     = "5m"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to add to the template (optional)"
  default     = ""
}

# Build Configuration
variable "debug_mode" {
  type        = bool
  description = "Enable verbose Ansible output for debugging"
  default     = false
}
