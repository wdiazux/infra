# Packer Variables for Windows 11 Golden Image
#
# This file defines variables for building Windows 11 golden image
# for Proxmox VE 9.0

# Proxmox Connection
variable "proxmox_url" {
  type        = string
  description = "Proxmox API endpoint URL"
  default     = "https://proxmox.local:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username"
  default     = "root@pam"
  sensitive   = true
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token"
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
  default     = "windows-11-golden-template"
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
  default     = 4096
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
  default     = "60G"
}

variable "vm_disk_storage" {
  type        = string
  description = "Proxmox storage pool"
  default     = "local-zfs"
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
  description = "WinRM password for provisioning"
  default     = "P@ssw0rd!"
  sensitive   = true
}

variable "winrm_timeout" {
  type        = string
  description = "WinRM timeout"
  default     = "60m"
}
