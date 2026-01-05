# Packer Variables for Talos Linux Golden Image
#
# This file defines variables for building a custom Talos Linux image
# with NVIDIA GPU support and qemu-guest-agent for Proxmox VE 9.0

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
  description = "Proxmox API token (format: PVEAPIToken=user@pve!token=secret)"
  default     = env("PROXMOX_TOKEN")
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name where the VM will be created"
  default     = "pve"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Skip TLS certificate verification (only for homelab with self-signed certs)"
  default     = true
}

# Talos Image Configuration
variable "talos_version" {
  type        = string
  description = "Talos Linux version to download"
  default     = "v1.11.5"
}

variable "talos_schematic_id" {
  type        = string
  description = "Talos Factory schematic ID with custom extensions (generate at factory.talos.dev)"
  # This schematic includes:
  # - siderolabs/qemu-guest-agent (Proxmox integration)
  # - nonfree-kmod-nvidia-production (NVIDIA GPU drivers)
  # - nvidia-container-toolkit-production (NVIDIA container runtime)
  #
  # Generate your own at: https://factory.talos.dev/
  # Select extensions, choose "metal" platform, and copy the schematic ID
  default = ""  # Must be set by user after generating at factory.talos.dev
}

variable "talos_iso_url" {
  type        = string
  description = "URL to download custom Talos ISO from Factory"
  # Format: https://factory.talos.dev/image/{schematic_id}/{version}/metal-amd64.iso
  default = ""  # Constructed from schematic_id and version
}

variable "talos_iso_checksum" {
  type        = string
  description = "SHA256 checksum of the Talos ISO (optional, use 'none' to skip)"
  default     = "none"
}

# VM Template Configuration
variable "template_name" {
  type        = string
  description = "Name for the resulting Proxmox template"
  default     = "talos-1.11.5-nvidia-template"
}

variable "template_description" {
  type        = string
  description = "Description for the Proxmox template"
  default     = "Talos Linux v1.11.5 with NVIDIA GPU support and qemu-guest-agent"
}

# VM Hardware Resources
variable "vm_id" {
  type        = number
  description = "VM ID for the template (must be unique in Proxmox)"
  default     = 9000
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
  default     = "talos-build"
}

variable "vm_cpu_type" {
  type        = string
  description = "CPU type (must be 'host' for Talos v1.0+ x86-64-v2 support and Cilium)"
  default     = "host"
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 4
}

variable "vm_sockets" {
  type        = number
  description = "Number of CPU sockets"
  default     = 1
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB"
  default     = 8192  # 8GB for building, can be adjusted in Terraform later
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size (e.g., 100G, 200G)"
  default     = "150G"  # Sufficient for OS, containers, and local ephemeral storage
}

variable "vm_disk_storage" {
  type        = string
  description = "Proxmox storage pool for VM disk"
  default     = "tank"
}

variable "vm_disk_type" {
  type        = string
  description = "Disk controller type"
  default     = "scsi"
}

variable "vm_network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "vm_network_model" {
  type        = string
  description = "Network card model"
  default     = "virtio"
}

variable "vm_network_vlan" {
  type        = number
  description = "VLAN tag (0 for none)"
  default     = 0
}

# Build Configuration
variable "ssh_timeout" {
  type        = string
  description = "Timeout for SSH connection (Talos doesn't use SSH, but Packer needs this)"
  default     = "30m"
}

variable "boot_wait" {
  type        = string
  description = "Time to wait after starting VM before connecting"
  default     = "10s"
}

# GPU Passthrough Configuration (optional, configured in Terraform)
# These variables document what will be configured in Terraform, not in Packer
# Packer builds the image; Terraform configures the VM with GPU passthrough

# variable "enable_gpu_passthrough" {
#   type        = bool
#   description = "Enable NVIDIA GPU passthrough (configured in Terraform, not Packer)"
#   default     = false
# }

# Notes:
# - Talos Factory schematic ID must be generated at https://factory.talos.dev/
# - Include extensions: qemu-guest-agent, nonfree-kmod-nvidia-production, nvidia-container-toolkit-production
# - Choose "metal" platform (for Talos 1.8.0+)
# - CPU type must be "host" for Talos v1.0+ and Cilium compatibility
# - GPU passthrough is configured in Terraform, not in this Packer template
# - Single GPU can only be assigned to ONE VM at a time (no vGPU on consumer cards)
# - Adjust vm_disk_size based on your workload (150G minimum recommended)
