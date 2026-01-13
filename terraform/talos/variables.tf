# Variables for Talos Kubernetes Cluster
#
# All input variables for the Talos single-node cluster

# ============================================================================
# Proxmox Configuration
# ============================================================================

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "pve"
}

# ============================================================================
# Talos Template
# ============================================================================

variable "talos_template_name" {
  description = "Name of the Talos template created by Packer"
  type        = string
  default     = "talos-1.12.1-nvidia-template"
}

variable "talos_version" {
  description = "Talos Linux version (must match template version)"
  type        = string
  default     = "v1.12.1"
}

variable "talos_schematic_id" {
  description = "Talos Factory schematic ID with required system extensions"
  type        = string
  default     = "b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321"

  validation {
    condition     = var.talos_schematic_id == "" || can(regex("^[a-f0-9]{64}$", var.talos_schematic_id))
    error_message = "Talos schematic ID must be a 64-character hexadecimal string."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy"
  type        = string
  default     = "v1.35.0"
}

# ============================================================================
# Cluster Configuration
# ============================================================================

variable "cluster_name" {
  description = "Talos/Kubernetes cluster name"
  type        = string
  default     = "homelab-k8s"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (defaults to node IP)"
  type        = string
  default     = ""
}

# ============================================================================
# Node Configuration
# ============================================================================

variable "node_name" {
  description = "Name for the Talos node VM"
  type        = string
  default     = "talos-node"
}

variable "node_vm_id" {
  description = "Proxmox VM ID for the Talos node"
  type        = number
  default     = 1000
}

variable "node_ip" {
  description = "Static IP address for the Talos node"
  type        = string
  default     = "10.10.2.10"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_ip))
    error_message = "node_ip must be a valid IPv4 address."
  }
}

variable "node_gateway" {
  description = "Network gateway for the Talos node"
  type        = string
  default     = "10.10.2.1"
}

variable "node_netmask" {
  description = "Network netmask (CIDR notation)"
  type        = number
  default     = 24
}

# ============================================================================
# VM Hardware Resources
# ============================================================================

variable "node_cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 8
}

variable "node_cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "node_cpu_type" {
  description = "CPU type (must be 'host' for Talos)"
  type        = string
  default     = "host"
}

variable "node_memory" {
  description = "Memory in MB"
  type        = number
  default     = 32768
}

variable "node_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 200
}

variable "node_disk_storage" {
  description = "Proxmox storage pool for node disk"
  type        = string
  default     = "tank"
}

# ============================================================================
# GPU Passthrough
# ============================================================================

variable "enable_gpu_passthrough" {
  description = "Enable NVIDIA GPU passthrough"
  type        = bool
  default     = true
}

variable "auto_install_gpu_device_plugin" {
  description = "Automatically install NVIDIA device plugin after bootstrap"
  type        = bool
  default     = true
}

variable "gpu_mapping" {
  description = "GPU resource mapping name from Proxmox"
  type        = string
  default     = "nvidia-gpu"
}

variable "gpu_pcie" {
  description = "Enable PCIe passthrough mode"
  type        = bool
  default     = true
}

variable "gpu_rombar" {
  description = "Enable GPU ROM bar"
  type        = bool
  default     = false
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_vlan" {
  description = "VLAN tag (0 for none)"
  type        = number
  default     = 0
}

variable "network_model" {
  description = "Network interface model"
  type        = string
  default     = "virtio"
}

variable "dns_servers" {
  description = "DNS servers for the node"
  type        = list(string)
  default     = ["10.10.2.1", "8.8.8.8"]
}

variable "ntp_servers" {
  description = "NTP servers for time synchronization"
  type        = list(string)
  default     = ["time.cloudflare.com"]
}

# ============================================================================
# Talos Configuration
# ============================================================================

variable "talos_config_patches" {
  description = "Additional Talos configuration patches (YAML)"
  type        = list(string)
  default     = []
}

variable "allow_scheduling_on_control_plane" {
  description = "Allow pod scheduling on control plane (required for single-node)"
  type        = bool
  default     = true
}

variable "install_disk" {
  description = "Disk device to install Talos on"
  type        = string
  default     = "/dev/sda"
}

# ============================================================================
# Feature Flags
# ============================================================================

variable "auto_bootstrap" {
  description = "Automatically bootstrap the cluster"
  type        = bool
  default     = true
}

variable "generate_kubeconfig" {
  description = "Generate kubeconfig file after bootstrap"
  type        = bool
  default     = true
}

variable "kubernetes_wait_timeout" {
  description = "Seconds to wait for Kubernetes API"
  type        = number
  default     = 300
}

variable "reset_on_destroy" {
  description = "Wipe Talos node when destroying"
  type        = bool
  default     = false
}

variable "enable_qemu_agent" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = true
}

# ============================================================================
# Tags and Metadata
# ============================================================================

variable "tags" {
  description = "Tags to apply to Proxmox VM"
  type        = list(string)
  default     = ["talos", "kubernetes", "nvidia-gpu"]
}

variable "description" {
  description = "Description for the Proxmox VM"
  type        = string
  default     = "Talos Linux single-node Kubernetes cluster with NVIDIA GPU support"
}
