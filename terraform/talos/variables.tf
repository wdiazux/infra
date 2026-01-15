# Variables for Talos Kubernetes Cluster
#
# Core cluster and VM configuration variables.
# See also:
#   - variables-network.tf  - Network and service LoadBalancer IPs
#   - variables-services.tf - Service configurations (Cilium, Longhorn, FluxCD, Forgejo)

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

  validation {
    condition     = var.node_vm_id >= 100 && var.node_vm_id <= 999999999
    error_message = "node_vm_id must be between 100 and 999999999 (Proxmox valid range)."
  }
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

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_gateway))
    error_message = "node_gateway must be a valid IPv4 address."
  }
}

variable "node_netmask" {
  description = "Network netmask (CIDR notation)"
  type        = number
  default     = 24

  validation {
    condition     = var.node_netmask >= 1 && var.node_netmask <= 32
    error_message = "node_netmask must be between 1 and 32."
  }
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

  validation {
    condition     = var.node_cpu_type == "host"
    error_message = "node_cpu_type must be 'host' for Talos Linux (required for kernel compatibility)."
  }
}

variable "node_memory" {
  description = "Memory in MB"
  type        = number
  default     = 32768

  validation {
    condition     = var.node_memory >= 4096
    error_message = "node_memory must be at least 4096 MB (4GB) for Talos+Kubernetes."
  }
}

variable "node_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 200

  validation {
    condition     = var.node_disk_size >= 50
    error_message = "node_disk_size must be at least 50 GB for Talos+Kubernetes+Longhorn."
  }
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

variable "nvidia_device_plugin_version" {
  description = "NVIDIA device plugin version"
  type        = string
  default     = "v0.18.1"
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
