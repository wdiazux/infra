# Packer Variables for NixOS Golden Image
#
# This file defines variables for building NixOS golden image
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

# NixOS Version
variable "nixos_version" {
  type        = string
  description = "NixOS version (24.05 = latest stable)"
  default     = "24.05"
}

variable "nixos_iso_url" {
  type        = string
  description = "URL to NixOS ISO"
  default     = "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso"
}

variable "nixos_iso_checksum" {
  type        = string
  description = "SHA256 checksum of NixOS ISO"
  default     = "file:https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso.sha256"
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
  default     = "NixOS 24.05 golden image with cloud-init"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9004
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "nixos-build"
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
  default     = "root"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning"
  default     = "nixos"
  sensitive   = true
}

variable "ssh_timeout" {
  type        = string
  description = "SSH timeout"
  default     = "20m"
}
