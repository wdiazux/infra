# Packer Variables for Windows 11 Golden Image
#
# This file defines variables for building Windows 11 golden image
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
  description = "Proxmox node name"
  default     = "pve"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification"
  default     = true
}

# Windows ISO
variable "windows_iso_url" {
  type        = string
  description = "URL to Windows 11 ISO"
  default     = "https://software-download.microsoft.com/download/pr/Win11_24H2_English_x64.iso"
}

variable "windows_iso_checksum" {
  type        = string
  description = "SHA256 checksum of Windows 11 ISO"
  default     = "sha256:ebbc79106715f44f5020f77bd90721b17c5a877cbc15a3535b99155493a1bb3f"
}

# VirtIO drivers ISO
variable "virtio_iso_url" {
  type        = string
  description = "URL to VirtIO drivers ISO"
  default     = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso"
}

variable "virtio_iso_checksum" {
  type        = string
  description = "Checksum of VirtIO ISO (use 'none' to skip)"
  default     = "none"
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "windows-11-cloud-template"
}

variable "template_version" {
  type        = string
  description = "Semantic version for template (e.g., 1.0.0)"
  default     = "1.0.0"
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Windows 11 (24H2) golden image with Cloudbase-Init"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9005
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "windows-build"
}

variable "vm_cpu_type" {
  type        = string
  description = "CPU type"
  default     = "host"
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 4
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB"
  default     = 5120 # 5GB - Windows 11 requires 4GB minimum, extra for install
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
  default     = "60G"
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

# WinRM Configuration
variable "winrm_username" {
  type        = string
  description = "WinRM username for provisioning"
  default     = "Administrator"
}

variable "winrm_password" {
  type        = string
  description = "WinRM password for provisioning (provide via PKR_VAR_winrm_password)"
  default     = null
  sensitive   = true

  validation {
    condition     = var.winrm_password != null && var.winrm_password != ""
    error_message = "winrm_password must be provided via PKR_VAR_winrm_password environment variable or .auto.pkrvars.hcl file."
  }
}

variable "winrm_timeout" {
  type        = string
  description = "WinRM timeout"
  default     = "60m"
}
