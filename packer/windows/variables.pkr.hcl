# Packer Variables for Windows Server Golden Image
#
# This file defines variables for building Windows Server 2022 golden image
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
  description = "URL to Windows Server ISO"
  default     = "https://software-download.microsoft.com/download/sg/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
}

variable "windows_iso_checksum" {
  type        = string
  description = "SHA256 checksum of Windows ISO"
  default     = "sha256:3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255e31"
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
  default     = "windows-server-2022-golden-template"
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Windows Server 2022 golden image with Cloudbase-Init"
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
