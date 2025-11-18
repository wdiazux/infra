# Terraform Variables for Talos Linux on Proxmox
#
# Define all input variables with descriptions, types, and defaults

# ============================================================================
# Proxmox Connection Variables
# ============================================================================

variable "proxmox_url" {
  description = "Proxmox API endpoint URL"
  type        = string
  default     = "https://proxmox.local:8006/api2/json"
}

variable "proxmox_username" {
  description = "Proxmox username (format: user@pam or user@pve)"
  type        = string
  default     = "root@pam"
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Proxmox API token (recommended over password)"
  type        = string
  default     = env("PROXMOX_API_TOKEN")
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox password (use api_token instead if possible)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for self-signed certificates"
  type        = bool
  default     = true  # Common for homelab with self-signed certs
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "pve"
}

# ============================================================================
# Talos Template Variables
# ============================================================================

variable "talos_template_name" {
  description = "Name of the Talos template created by Packer"
  type        = string
  default     = "talos-1.11.4-nvidia-template"
  # Note: If you used timestamped template name, adjust this
}

variable "talos_version" {
  description = "Talos Linux version (must match template version)"
  type        = string
  default     = "v1.11.4"
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy (supported by Talos version)"
  type        = string
  default     = "v1.31.0"
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
  description = "Kubernetes API endpoint (IP or DNS)"
  type        = string
  # Will be set to control plane node IP if not specified
  default = ""
}

variable "cluster_vip" {
  description = "Virtual IP for cluster endpoint (optional, for multi-node HA)"
  type        = string
  default     = ""  # Not needed for single-node
}

# ============================================================================
# Single Node Configuration
# ============================================================================

variable "node_name" {
  description = "Name for the Talos node VM"
  type        = string
  default     = "talos-node"
}

variable "node_vm_id" {
  description = "Proxmox VM ID for the node"
  type        = number
  default     = 100
}

variable "node_ip" {
  description = "Static IP address for the Talos node"
  type        = string
  # Example: "192.168.1.100"
  default = ""  # Must be set by user
}

variable "node_gateway" {
  description = "Network gateway for the Talos node"
  type        = string
  default     = "192.168.1.1"
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
  description = "Number of CPU cores for the node"
  type        = number
  default     = 8  # For production workload
}

variable "node_cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "node_cpu_type" {
  description = "CPU type (must be 'host' for Talos v1.0+)"
  type        = string
  default     = "host"

  validation {
    condition     = var.node_cpu_type == "host"
    error_message = "CPU type must be 'host' for Talos v1.0+ x86-64-v2 support and Cilium compatibility."
  }
}

variable "node_memory" {
  description = "Memory in MB for the node"
  type        = number
  default     = 32768  # 32GB for AI/ML workloads
}

variable "node_disk_size" {
  description = "Disk size in GB for the node"
  type        = number
  default     = 200  # 200GB for OS + containers + local ephemeral storage
}

variable "node_disk_storage" {
  description = "Proxmox storage pool for node disk"
  type        = string
  default     = "local-zfs"
}

# ============================================================================
# GPU Passthrough Configuration
# ============================================================================

variable "enable_gpu_passthrough" {
  description = "Enable NVIDIA GPU passthrough to this node"
  type        = bool
  default     = true  # Set to false if not using GPU
}

variable "gpu_pci_id" {
  description = "PCI ID of the GPU to passthrough (e.g., '01:00')"
  type        = string
  default     = "01:00"  # Adjust based on your system (lspci output)
}

variable "gpu_pcie" {
  description = "Enable PCIe passthrough mode"
  type        = bool
  default     = true
}

variable "gpu_rombar" {
  description = "Enable GPU ROM bar (false recommended for GPU passthrough)"
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
  default     = ["8.8.8.8", "8.8.4.4"]
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
  default     = true  # Must be true for single-node cluster
}

variable "install_disk" {
  description = "Disk device to install Talos on"
  type        = string
  default     = "/dev/sda"
}

# ============================================================================
# External Storage Configuration
# ============================================================================

variable "nfs_server" {
  description = "NFS server IP or hostname for persistent storage"
  type        = string
  default     = ""  # Set to your NAS IP (e.g., "192.168.1.100")
}

variable "nfs_path" {
  description = "NFS export path for Kubernetes persistent volumes"
  type        = string
  default     = "/mnt/tank/k8s-storage"
}

# ============================================================================
# Cilium CNI Configuration
# ============================================================================

variable "install_cilium" {
  description = "Install Cilium CNI after cluster bootstrap"
  type        = bool
  default     = true
}

variable "cilium_version" {
  description = "Cilium version to install"
  type        = string
  default     = "1.18.0"
}

# ============================================================================
# Feature Flags
# ============================================================================

variable "auto_bootstrap" {
  description = "Automatically bootstrap the cluster after creation"
  type        = bool
  default     = true
}

variable "generate_kubeconfig" {
  description = "Generate kubeconfig file after bootstrap"
  type        = bool
  default     = true
}

variable "enable_qemu_agent" {
  description = "Enable QEMU guest agent (included in template)"
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

# Notes:
# - All variables have sensible defaults for homelab single-node setup
# - Sensitive variables (passwords, tokens) use sensitive = true
# - Environment variables can be used: env("VAR_NAME")
# - Override defaults in terraform.tfvars or via -var flags
# - SOPS-encrypted secrets can be loaded via data source
# - GPU passthrough requires IOMMU enabled in BIOS/GRUB
# - Single node requires allow_scheduling_on_control_plane = true
# - NFS server must be reachable from Talos node for persistent storage
