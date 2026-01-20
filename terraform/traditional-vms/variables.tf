# Traditional VM Shared Variables
#
# Variables shared across all traditional VMs (non-Talos).
# OS-specific settings are defined in locals.tf per VM.

# =============================================================================
# Proxmox Configuration
# =============================================================================

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "pve"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["10.10.2.1", "8.8.8.8"]
}

variable "dns_domain" {
  description = "DNS domain"
  type        = string
  default     = "local"
}

# =============================================================================
# Template Names
# =============================================================================
# Update these after building templates with Packer

variable "ubuntu_template_name" {
  description = "Ubuntu Packer template name in Proxmox"
  type        = string
  default     = "ubuntu-2404-cloud-template-v1.0.0"
}

variable "debian_template_name" {
  description = "Debian Packer template name in Proxmox"
  type        = string
  default     = "debian-13-cloud-template-v1.0.0"
}

variable "arch_template_name" {
  description = "Arch Linux Packer template name in Proxmox"
  type        = string
  default     = "arch-cloud-template-v1.0.0"
}

variable "nixos_template_name" {
  description = "NixOS Packer template name in Proxmox"
  type        = string
  default     = "nixos-cloud-template-v1.0.0"
}

variable "windows_template_name" {
  description = "Windows Packer template name in Proxmox"
  type        = string
  default     = "windows-11-cloud-template-v1.0.0"
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "default_storage" {
  description = "Default Proxmox storage pool for VM disks"
  type        = string
  default     = "tank"
}

# =============================================================================
# Cloud-init Configuration (Linux VMs)
# =============================================================================
#
# NOTE: Credentials are loaded from SOPS-encrypted secrets by default.
# These variables serve as fallback if secrets are not found in SOPS.
# See sops.tf for the SOPS integration.
#

variable "enable_cloud_init" {
  description = "Enable cloud-init for VM provisioning"
  type        = bool
  default     = true
}

variable "cloud_init_user" {
  description = "Fallback username if not in SOPS secrets"
  type        = string
  default     = "wdiaz"
}

variable "cloud_init_password" {
  description = "Fallback password if not in SOPS secrets (prefer SOPS)"
  type        = string
  default     = "" # Empty = require SOPS
  sensitive   = true
}

variable "cloud_init_ssh_keys" {
  description = "Additional SSH keys (primary key comes from SOPS)"
  type        = list(string)
  default     = []
}

# =============================================================================
# Windows Configuration
# =============================================================================
#
# NOTE: Credentials are loaded from SOPS-encrypted secrets by default.
# These variables serve as fallback if secrets are not found in SOPS.
#

variable "windows_admin_user" {
  description = "Fallback admin username if not in SOPS secrets"
  type        = string
  default     = "Administrator"
}

variable "windows_admin_password" {
  description = "Fallback admin password if not in SOPS secrets (prefer SOPS)"
  type        = string
  default     = "" # Empty = require SOPS
  sensitive   = true
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "default_gateway" {
  description = "Default gateway for static IP configurations"
  type        = string
  default     = "10.10.2.1"
}

# =============================================================================
# Common Tags
# =============================================================================

variable "common_tags" {
  description = "Tags applied to all traditional VMs"
  type        = list(string)
  default     = ["traditional-vm", "packer-template"]
}

# =============================================================================
# Notes
# =============================================================================
#
# Security Best Practices:
# - Never commit passwords to git
# - Use environment variables: export TF_VAR_cloud_init_password="..."
# - Or use .tfvars file (git-ignored): cloud_init_password = "..."
# - SSH keys are preferred over passwords for Linux VMs
#
# Template Naming Convention (with semantic versioning):
# - Ubuntu:  ubuntu-2404-cloud-template-v1.0.0
# - Debian:  debian-13-cloud-template-v1.0.0
# - Arch:    arch-cloud-template-v1.0.0
# - NixOS:   nixos-cloud-template-v1.0.0
# - Windows: windows-11-cloud-template-v1.0.0
#
# After Building Templates:
# 1. Update template names in terraform.tfvars if different
# 2. Verify templates exist: qm list | grep template
# 3. Enable VMs in locals-vms.tf
# 4. Deploy: terraform apply
#
