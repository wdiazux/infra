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
  description = "Proxmox node name"
  default     = "pve"
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
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "arch-golden-template"  # Must match Terraform variable
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Arch Linux golden image with cloud-init"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9302
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
