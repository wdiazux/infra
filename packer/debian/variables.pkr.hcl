# Packer Variables for Debian Golden Image
#
# This file defines variables for building a Debian stable golden image
# for Proxmox VE 9.0

# Proxmox Connection
variable "proxmox_url" {
  type        = string
  description = "Proxmox API endpoint URL"
  default     = "https://proxmox.local:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username (format: user@pam or user@pve)"
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

# Debian Version
variable "debian_version" {
  type        = string
  description = "Debian version (12 = Bookworm, 11 = Bullseye)"
  default     = "12"
}

variable "debian_iso_url" {
  type        = string
  description = "URL to Debian ISO"
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
}

variable "debian_iso_checksum" {
  type        = string
  description = "SHA256 checksum of Debian ISO (file: reference auto-validates against official checksums)"
  default     = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "debian-12-golden-template"
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Debian 12 (Bookworm) golden image with cloud-init"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9001
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "debian-build"
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

# User Configuration (created during installation)
variable "default_username" {
  type        = string
  description = "Default user to create"
  default     = "admin"
}

variable "default_password" {
  type        = string
  description = "Default user password (will be changeable via cloud-init)"
  default     = "changeme"
  sensitive   = true
}
