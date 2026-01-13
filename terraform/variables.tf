# Terraform Variables for Talos Linux on Proxmox
#
# Define all input variables with descriptions, types, and defaults

# ============================================================================
# Proxmox Connection Variables
# ============================================================================

variable "proxmox_url" {
  description = "Proxmox API endpoint URL"
  type        = string
  default     = "https://pve.home-infra.net:8006/api2/json"
}

variable "proxmox_username" {
  description = "Proxmox username (format: user@pve for API-only access)"
  type        = string
  default     = "root@pve"
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Proxmox API token (recommended over password). Use TF_VAR_proxmox_api_token env var or set in terraform.tfvars"
  type        = string
  default     = null
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
  default     = true # Common for homelab with self-signed certs
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "pve"

  validation {
    condition     = var.proxmox_node != ""
    error_message = "Proxmox node name cannot be empty. Common values: 'pve', 'proxmox', or your custom node name."
  }
}

# ============================================================================
# Talos Template Variables
# ============================================================================

variable "talos_template_name" {
  description = "Name of the Talos template created by Packer"
  type        = string
  default     = "talos-1.12.1-nvidia-template"
  # Note: If you used timestamped template name, adjust this
}

variable "talos_version" {
  description = "Talos Linux version (must match template version)"
  type        = string
  default     = "v1.12.1"
}

variable "talos_schematic_id" {
  description = "Talos Factory schematic ID with required system extensions. REQUIRED for Longhorn storage (iscsi-tools, util-linux-tools). Generate at https://factory.talos.dev/"
  type        = string
  default     = "b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321"
  # Example: "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
  #
  # CRITICAL: This infrastructure uses Longhorn as primary storage, which REQUIRES:
  # - siderolabs/iscsi-tools (REQUIRED for Longhorn)
  # - siderolabs/util-linux-tools (REQUIRED for Longhorn)
  # - siderolabs/qemu-guest-agent (REQUIRED for Proxmox integration)
  #
  # Optional extensions for GPU workloads:
  # - nonfree-kmod-nvidia-production (optional, for GPU passthrough)
  # - nvidia-container-toolkit-production (optional, for GPU in Kubernetes)
  #
  # Generate schematic at: https://factory.talos.dev/
  # See packer/talos/README.md for detailed instructions

  validation {
    condition     = var.talos_schematic_id == "" || can(regex("^[a-f0-9]{64}$", var.talos_schematic_id))
    error_message = <<-EOT
      Talos schematic ID must be a 64-character hexadecimal string.

      IMPORTANT: This infrastructure uses Longhorn for storage, which REQUIRES
      a custom Talos image with iscsi-tools and util-linux-tools extensions.

      Generate schematic at: https://factory.talos.dev/
      See packer/talos/README.md for step-by-step instructions.
    EOT
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy (supported by Talos version)"
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
  description = "Kubernetes API endpoint (IP or DNS)"
  type        = string
  # Will be set to control plane node IP if not specified
  default = ""
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
  description = "Proxmox VM ID for the Talos node (changed from 100 to avoid conflict with traditional VMs)"
  type        = number
  default     = 1000

  validation {
    condition     = var.node_vm_id >= 100 && var.node_vm_id <= 999999999
    error_message = "VM ID must be between 100 and 999999999. Reserved ranges: Talos=1000-1999, Ubuntu=100-199, Debian=200-299, Arch=300-399, NixOS=400-499, Windows=500-599."
  }
}

variable "node_ip" {
  description = "Static IP address for the Talos node (REQUIRED)"
  type        = string
  # Example: "10.10.2.10"
  default = "" # Must be set by user

  validation {
    condition     = var.node_ip != "" && can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_ip))
    error_message = "node_ip is REQUIRED and must be a valid IPv4 address (e.g., '10.10.2.10'). Set in terraform.tfvars or via -var flag."
  }
}

variable "node_gateway" {
  description = "Network gateway for the Talos node"
  type        = string
  default     = "10.10.2.1"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_gateway))
    error_message = "node_gateway must be a valid IPv4 address (e.g., '10.10.2.1')."
  }
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
  default     = 8 # For production workload
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
  default     = 32768 # 32GB for AI/ML workloads

  validation {
    condition     = var.node_memory >= 16384
    error_message = "Single-node Talos with Longhorn requires minimum 16GB (16384MB) RAM. 24-32GB recommended for production workloads."
  }
}

variable "node_disk_size" {
  description = "Disk size in GB for the node"
  type        = number
  default     = 200 # 200GB for OS + containers + local ephemeral storage

  validation {
    condition     = var.node_disk_size >= 100
    error_message = "Talos disk size should be at least 100GB for production use (200GB+ recommended for Longhorn storage)."
  }
}

variable "node_disk_storage" {
  description = "Proxmox storage pool for node disk"
  type        = string
  default     = "tank"
}

# ============================================================================
# GPU Passthrough Configuration
# ============================================================================

variable "enable_gpu_passthrough" {
  description = "Enable NVIDIA GPU passthrough to this node"
  type        = bool
  default     = true # Set to false if not using GPU
}

variable "auto_install_gpu_operator" {
  description = "Automatically install NVIDIA GPU Operator after cluster bootstrap (requires enable_gpu_passthrough = true)"
  type        = bool
  default     = true
}

variable "gpu_pci_id" {
  description = "PCI ID of the GPU to passthrough (e.g., '07:00'). Used with METHOD 2 (password auth). Find with: lspci | grep -i nvidia"
  type        = string
  default     = "07:00" # NVIDIA RTX 4000 SFF Ada at 07:00.0 on this system
}

variable "gpu_mapping" {
  description = "GPU resource mapping name from Proxmox. Create in: Datacenter → Resource Mappings → Add → PCI Device"
  type        = string
  default     = "nvidia-gpu" # Resource mapping for NVIDIA RTX 4000 SFF at 07:00.0
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
  default     = ["10.10.2.1", "8.8.8.8"]
}

variable "dns_domain" {
  description = "DNS domain for all VMs"
  type        = string
  default     = "local"
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
  default     = true # Must be true for single-node cluster
}

variable "install_disk" {
  description = "Disk device to install Talos on"
  type        = string
  default     = "/dev/sda"
}

# ============================================================================
# External Storage Configuration (Optional - for Longhorn backups)
# ============================================================================

variable "nfs_server" {
  description = "NFS server IP or hostname for Longhorn backup target (optional)"
  type        = string
  default     = "" # Set to your NAS IP (e.g., "10.10.2.5")
  # Note: Primary storage is Longhorn. NFS is only used for backup destination.
}

variable "nfs_path" {
  description = "NFS export path for Longhorn backup target (optional)"
  type        = string
  default     = "/mnt/tank/longhorn-backups"
  # Note: This is for Longhorn backups, not for persistent volume provisioning.
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

variable "kubernetes_wait_timeout" {
  description = "Maximum seconds to wait for Kubernetes API to be ready"
  type        = number
  default     = 300 # 5 minutes
}

variable "reset_on_destroy" {
  description = "Reset (wipe) Talos node when destroying (resets STATE and EPHEMERAL partitions)"
  type        = bool
  default     = false # Safe default - don't wipe unless explicitly requested
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

# ============================================================================
# Traditional VMs Configuration
# ============================================================================
#
# Traditional VM variables have been moved to:
# - variables-traditional.tf  (shared variables: cloud-init, templates, etc.)
# - locals-vms.tf             (VM definitions with for_each pattern)
#
# See locals-vms.tf to enable/configure individual VMs.
#
