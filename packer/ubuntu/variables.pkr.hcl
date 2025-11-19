# Packer Variables for Ubuntu Golden Image
#
# This file defines variables for building Ubuntu LTS golden image
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

# Ubuntu Version
variable "ubuntu_version" {
  type        = string
  description = "Ubuntu version (24.04 = Noble, 22.04 = Jammy)"
  default     = "24.04"
}

variable "ubuntu_iso_url" {
  type        = string
  description = "URL to Ubuntu ISO"
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
}

variable "ubuntu_iso_checksum" {
  type        = string
  description = "SHA256 checksum of Ubuntu ISO (file: reference auto-validates against official checksums)"
  default     = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "ubuntu-24.04-golden-template"
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Ubuntu 24.04 LTS (Noble) golden image with cloud-init"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9002
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "ubuntu-build"
}

variable "vm_cpu_type" {
  type        = string
  description = "CPU type"
  default     = "host"
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

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
  default     = "20G"
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

# SSH Configuration
variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "wdiaz"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning"
  default     = "wdiaz"
  sensitive   = true
}

variable "ssh_timeout" {
  type        = string
  description = "SSH timeout"
  default     = "20m"
}
