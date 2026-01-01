# Variables for Proxmox VM Module

# ============================================================================
# Required Variables
# ============================================================================

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name where VM will be created"
}

variable "template_name" {
  type        = string
  description = "Name of the Packer template to clone from"
}

variable "vm_name" {
  type        = string
  description = "Name for the VM"
}

variable "vm_id" {
  type        = number
  description = "Unique VM ID"
}

# ============================================================================
# Hardware Configuration
# ============================================================================

variable "cpu_type" {
  type        = string
  description = "CPU type (e.g., 'host', 'kvm64')"
  default     = "host"
}

variable "cpu_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "cpu_sockets" {
  type        = number
  description = "Number of CPU sockets"
  default     = 1
}

variable "memory" {
  type        = number
  description = "Memory in MB"
  default     = 2048
}

variable "disks" {
  type = list(object({
    datastore_id = string
    size         = number
    interface    = string
    iothread     = optional(bool, true)
    discard      = optional(string, "on")
    ssd          = optional(bool, true)
  }))
  description = "List of disk configurations"
  default = [{
    datastore_id = "tank"
    size         = 20
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]
}

variable "network_devices" {
  type = list(object({
    bridge  = string
    model   = optional(string, "virtio")
    vlan_id = optional(number, null)
  }))
  description = "List of network device configurations"
  default = [{
    bridge = "vmbr0"
    model  = "virtio"
  }]
}

# ============================================================================
# BIOS and Boot Configuration
# ============================================================================

variable "bios_type" {
  type        = string
  description = "BIOS type: 'seabios' (legacy) or 'ovmf' (UEFI)"
  default     = "ovmf"
}

variable "efi_disk_datastore" {
  type        = string
  description = "Datastore for EFI disk (only used if bios_type = 'ovmf')"
  default     = "tank"
}

variable "boot_order" {
  type        = list(string)
  description = "Boot order (e.g., ['scsi0', 'net0'])"
  default     = ["scsi0"]
}

variable "machine_type" {
  type        = string
  description = "Machine type (e.g., 'q35', 'i440fx')"
  default     = "q35"
}

variable "scsi_hardware" {
  type        = string
  description = "SCSI controller type"
  default     = "virtio-scsi-single"
}

# ============================================================================
# Cloud-init Configuration
# ============================================================================

variable "enable_cloud_init" {
  type        = bool
  description = "Enable cloud-init configuration"
  default     = true
}

variable "cloud_init_datastore" {
  type        = string
  description = "Datastore for cloud-init drive"
  default     = "tank"
}

variable "cloud_init_user" {
  type        = string
  description = "Cloud-init username (empty to skip user creation)"
  default     = ""
}

variable "cloud_init_password" {
  type        = string
  description = "Cloud-init password (hashed or plain)"
  default     = ""
  sensitive   = true
}

variable "cloud_init_ssh_keys" {
  type        = list(string)
  description = "List of SSH public keys for cloud-init"
  default     = []
}

variable "ip_configs" {
  type = list(object({
    address = optional(string, "dhcp")
    gateway = optional(string, null)
  }))
  description = "IP configuration for each network interface"
  default = [{
    address = "dhcp"
  }]
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers for cloud-init"
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "dns_domain" {
  type        = string
  description = "DNS domain for cloud-init"
  default     = "local"
}

# ============================================================================
# QEMU Guest Agent
# ============================================================================

variable "enable_qemu_agent" {
  type        = bool
  description = "Enable QEMU guest agent"
  default     = true
}

# ============================================================================
# Metadata and Lifecycle
# ============================================================================

variable "description" {
  type        = string
  description = "VM description"
  default     = ""
}

variable "tags" {
  type        = list(string)
  description = "List of tags for the VM"
  default     = []
}

variable "on_boot" {
  type        = bool
  description = "Start VM on boot"
  default     = true
}

variable "startup_order" {
  type        = number
  description = "Startup order (lower numbers start first)"
  default     = 10
}

variable "startup_up_delay" {
  type        = number
  description = "Startup delay in seconds"
  default     = 30
}

variable "startup_down_delay" {
  type        = number
  description = "Shutdown delay in seconds"
  default     = 30
}
