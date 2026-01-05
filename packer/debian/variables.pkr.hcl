# Packer Variables for Debian Cloud Image Template
#
# This uses official Debian cloud image (PREFERRED METHOD)
# Much faster than building from ISO (5-10 min vs 20-30 min)

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

# Debian Version
variable "debian_version" {
  type        = string
  description = "Debian version"
  default     = "13"
}

# Cloud Image Base VM
variable "cloud_image_vm_id" {
  type        = number
  description = "VM ID of imported cloud image (created by import-cloud-image.sh)"
  default     = 9110
}

# Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the Proxmox template"
  default     = "debian-13-cloud-template"
}

variable "template_description" {
  type        = string
  description = "Description for the template"
  default     = "Debian 13 (Trixie) cloud image with customizations"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9112
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "debian-cloud-build"
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
variable "ssh_password" {
  type        = string
  description = "SSH password (default from cloud image)"
  default     = "debian"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to add to the template (optional)"
  default     = ""
}

variable "ssh_public_key_file" {
  type        = string
  description = "Path to SSH public key file (e.g., ~/.ssh/id_rsa.pub)"
  default     = ""
}
