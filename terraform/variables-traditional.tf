# Traditional VM Shared Variables
#
# Variables shared across all traditional VMs (non-Talos).
# OS-specific settings are defined in locals-vms.tf per VM.
#
# ============================================================================
# Usage
# ============================================================================
#
# Set these in terraform.tfvars:
#
#   # Cloud-init defaults (applies to all Linux VMs)
#   cloud_init_user     = "wdiaz"
#   cloud_init_password = "your-secure-password"
#   cloud_init_ssh_keys = [
#     "ssh-ed25519 AAAA... user@host"
#   ]
#
#   # Windows admin (applies to all Windows VMs)
#   windows_admin_user     = "Administrator"
#   windows_admin_password = "YourSecureP@ss123!"
#
#   # Storage
#   default_storage = "tank"
#
# ============================================================================

# =============================================================================
# Template Names
# =============================================================================
# Update these after building templates with Packer

variable "ubuntu_template_name" {
  description = "Ubuntu Packer template name in Proxmox"
  type        = string
  default     = "ubuntu-2404-cloud-template"
}

variable "debian_template_name" {
  description = "Debian Packer template name in Proxmox"
  type        = string
  default     = "debian-13-cloud-template"
}

variable "arch_template_name" {
  description = "Arch Linux Packer template name in Proxmox"
  type        = string
  default     = "arch-cloud-template"
}

variable "nixos_template_name" {
  description = "NixOS Packer template name in Proxmox"
  type        = string
  default     = "nixos-cloud-template"
}

variable "windows_template_name" {
  description = "Windows Packer template name in Proxmox"
  type        = string
  default     = "windows-11-golden-template"
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
# Template Naming Convention:
# - Ubuntu:  ubuntu-2404-cloud-template
# - Debian:  debian-13-cloud-template
# - Arch:    arch-cloud-template
# - NixOS:   nixos-cloud-template
# - Windows: windows-11-template
#
# After Building Templates:
# 1. Update template names in terraform.tfvars if different
# 2. Verify templates exist: qm list | grep template
# 3. Enable VMs in locals-vms.tf
# 4. Deploy: terraform apply
#
