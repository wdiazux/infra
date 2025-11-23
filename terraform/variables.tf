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
  default     = true  # Common for homelab with self-signed certs
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
  default     = "talos-1.11.4-nvidia-template"
  # Note: If you used timestamped template name, adjust this
}

variable "talos_version" {
  description = "Talos Linux version (must match template version)"
  type        = string
  default     = "v1.11.4"
}

variable "talos_schematic_id" {
  description = "Talos Factory schematic ID with required system extensions. REQUIRED for Longhorn storage (iscsi-tools, util-linux-tools). Generate at https://factory.talos.dev/"
  type        = string
  default     = ""
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
  # Example: "192.168.1.100"
  default = ""  # Must be set by user

  validation {
    condition     = var.node_ip != "" && can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_ip))
    error_message = "node_ip is REQUIRED and must be a valid IPv4 address (e.g., '192.168.1.100'). Set in terraform.tfvars or via -var flag."
  }
}

variable "node_gateway" {
  description = "Network gateway for the Talos node"
  type        = string
  default     = "192.168.1.1"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_gateway))
    error_message = "node_gateway must be a valid IPv4 address (e.g., '192.168.1.1')."
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

  validation {
    condition     = var.node_memory >= 16384
    error_message = "Single-node Talos with Longhorn requires minimum 16GB (16384MB) RAM. 24-32GB recommended for production workloads."
  }
}

variable "node_disk_size" {
  description = "Disk size in GB for the node"
  type        = number
  default     = 200  # 200GB for OS + containers + local ephemeral storage

  validation {
    condition     = var.node_disk_size >= 100
    error_message = "Talos disk size should be at least 100GB for production use (200GB+ recommended for Longhorn storage)."
  }
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
  default     = true  # Must be true for single-node cluster
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
  default     = ""  # Set to your NAS IP (e.g., "192.168.1.100")
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
# Variables for deploying traditional Linux and Windows VMs from Packer templates

# Common Variables
# ----------------------------------------------------------------------------

variable "common_tags" {
  description = "Common tags to apply to all traditional VMs"
  type        = list(string)
  default     = ["traditional-vm", "packer-template"]
}

variable "enable_cloud_init" {
  description = "Enable cloud-init for traditional VMs"
  type        = bool
  default     = true
}

variable "cloud_init_user" {
  description = "Default cloud-init username for traditional VMs"
  type        = string
  default     = "wdiaz"
}

variable "cloud_init_password" {
  description = "Default cloud-init password for traditional VMs"
  type        = string
  default     = "changeme"
  sensitive   = true
}

variable "cloud_init_ssh_keys" {
  description = "List of SSH public keys for cloud-init"
  type        = list(string)
  default     = []
}

variable "default_gateway" {
  description = "Default gateway for static IP configurations"
  type        = string
  default     = "192.168.1.1"
}

# Ubuntu VM Configuration
# ----------------------------------------------------------------------------

variable "deploy_ubuntu_vm" {
  description = "Deploy Ubuntu VM"
  type        = bool
  default     = false
}

variable "ubuntu_template_name" {
  description = "Ubuntu Packer template name"
  type        = string
  default     = "ubuntu-2404-cloud-template"
}

variable "ubuntu_vm_name" {
  description = "Ubuntu VM name"
  type        = string
  default     = "ubuntu-dev"
}

variable "ubuntu_vm_id" {
  description = "Ubuntu VM ID"
  type        = number
  default     = 100
}

variable "ubuntu_cpu_type" {
  description = "Ubuntu CPU type"
  type        = string
  default     = "host"
}

variable "ubuntu_cpu_cores" {
  description = "Ubuntu CPU cores"
  type        = number
  default     = 4
}

variable "ubuntu_memory" {
  description = "Ubuntu memory in MB"
  type        = number
  default     = 8192
}

variable "ubuntu_disk_size" {
  description = "Ubuntu disk size in GB"
  type        = number
  default     = 40
}

variable "ubuntu_disk_storage" {
  description = "Ubuntu disk storage pool"
  type        = string
  default     = "local-zfs"
}

variable "ubuntu_ip_address" {
  description = "Ubuntu IP address (e.g., '192.168.1.100/24' or 'dhcp')"
  type        = string
  default     = "dhcp"
}

variable "ubuntu_on_boot" {
  description = "Start Ubuntu VM on boot"
  type        = bool
  default     = true
}

# Debian VM Configuration
# ----------------------------------------------------------------------------

variable "deploy_debian_vm" {
  description = "Deploy Debian VM"
  type        = bool
  default     = false
}

variable "debian_template_name" {
  description = "Debian Packer template name"
  type        = string
  default     = "debian-12-cloud-template"
}

variable "debian_vm_name" {
  description = "Debian VM name"
  type        = string
  default     = "debian-prod"
}

variable "debian_vm_id" {
  description = "Debian VM ID"
  type        = number
  default     = 200
}

variable "debian_cpu_type" {
  description = "Debian CPU type"
  type        = string
  default     = "host"
}

variable "debian_cpu_cores" {
  description = "Debian CPU cores"
  type        = number
  default     = 4
}

variable "debian_memory" {
  description = "Debian memory in MB"
  type        = number
  default     = 8192
}

variable "debian_disk_size" {
  description = "Debian disk size in GB"
  type        = number
  default     = 40
}

variable "debian_disk_storage" {
  description = "Debian disk storage pool"
  type        = string
  default     = "local-zfs"
}

variable "debian_ip_address" {
  description = "Debian IP address (e.g., '192.168.1.101/24' or 'dhcp')"
  type        = string
  default     = "dhcp"
}

variable "debian_on_boot" {
  description = "Start Debian VM on boot"
  type        = bool
  default     = true
}

# Arch Linux VM Configuration
# ----------------------------------------------------------------------------

variable "deploy_arch_vm" {
  description = "Deploy Arch Linux VM"
  type        = bool
  default     = false
}

variable "arch_template_name" {
  description = "Arch Linux Packer template name"
  type        = string
  default     = "arch-golden-template"
}

variable "arch_vm_name" {
  description = "Arch Linux VM name"
  type        = string
  default     = "arch-dev"
}

variable "arch_vm_id" {
  description = "Arch Linux VM ID"
  type        = number
  default     = 300
}

variable "arch_cpu_type" {
  description = "Arch Linux CPU type"
  type        = string
  default     = "host"
}

variable "arch_cpu_cores" {
  description = "Arch Linux CPU cores"
  type        = number
  default     = 2
}

variable "arch_memory" {
  description = "Arch Linux memory in MB"
  type        = number
  default     = 4096
}

variable "arch_disk_size" {
  description = "Arch Linux disk size in GB"
  type        = number
  default     = 30
}

variable "arch_disk_storage" {
  description = "Arch Linux disk storage pool"
  type        = string
  default     = "local-zfs"
}

variable "arch_ip_address" {
  description = "Arch Linux IP address (e.g., '192.168.1.102/24' or 'dhcp')"
  type        = string
  default     = "dhcp"
}

variable "arch_on_boot" {
  description = "Start Arch Linux VM on boot"
  type        = bool
  default     = true
}

# NixOS VM Configuration
# ----------------------------------------------------------------------------

variable "deploy_nixos_vm" {
  description = "Deploy NixOS VM"
  type        = bool
  default     = false
}

variable "nixos_template_name" {
  description = "NixOS Packer template name"
  type        = string
  default     = "nixos-golden-template"
}

variable "nixos_vm_name" {
  description = "NixOS VM name"
  type        = string
  default     = "nixos-lab"
}

variable "nixos_vm_id" {
  description = "NixOS VM ID"
  type        = number
  default     = 400
}

variable "nixos_cpu_type" {
  description = "NixOS CPU type"
  type        = string
  default     = "host"
}

variable "nixos_cpu_cores" {
  description = "NixOS CPU cores"
  type        = number
  default     = 2
}

variable "nixos_memory" {
  description = "NixOS memory in MB"
  type        = number
  default     = 4096
}

variable "nixos_disk_size" {
  description = "NixOS disk size in GB"
  type        = number
  default     = 30
}

variable "nixos_disk_storage" {
  description = "NixOS disk storage pool"
  type        = string
  default     = "local-zfs"
}

variable "nixos_ip_address" {
  description = "NixOS IP address (e.g., '192.168.1.103/24' or 'dhcp')"
  type        = string
  default     = "dhcp"
}

variable "nixos_on_boot" {
  description = "Start NixOS VM on boot"
  type        = bool
  default     = true
}

# Windows 11 VM Configuration
# ----------------------------------------------------------------------------

variable "deploy_windows_vm" {
  description = "Deploy Windows 11 VM"
  type        = bool
  default     = false
}

variable "windows_template_name" {
  description = "Windows 11 Packer template name"
  type        = string
  default     = "windows-11-golden-template"
}

variable "windows_vm_name" {
  description = "Windows 11 VM name"
  type        = string
  default     = "windows-11"
}

variable "windows_vm_id" {
  description = "Windows 11 VM ID"
  type        = number
  default     = 500
}

variable "windows_cpu_type" {
  description = "Windows 11 CPU type"
  type        = string
  default     = "host"
}

variable "windows_cpu_cores" {
  description = "Windows 11 CPU cores"
  type        = number
  default     = 4
}

variable "windows_memory" {
  description = "Windows 11 memory in MB"
  type        = number
  default     = 8192
}

variable "windows_disk_size" {
  description = "Windows 11 disk size in GB"
  type        = number
  default     = 100
}

variable "windows_disk_storage" {
  description = "Windows 11 disk storage pool"
  type        = string
  default     = "local-zfs"
}

variable "windows_ip_address" {
  description = "Windows 11 IP address (e.g., '192.168.1.104/24' or 'dhcp')"
  type        = string
  default     = "dhcp"
}

variable "windows_cloud_init_user" {
  description = "Windows 11 cloud-init (Cloudbase-Init) username"
  type        = string
  default     = "Administrator"
}

variable "windows_cloud_init_password" {
  description = "Windows 11 cloud-init (Cloudbase-Init) password"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "windows_on_boot" {
  description = "Start Windows 11 VM on boot"
  type        = bool
  default     = true
}

# Notes for Traditional VMs:
# - All VMs are disabled by default (deploy_*_vm = false)
# - Enable specific VMs in terraform.tfvars
# - Template names must match Packer output exactly
# - VM IDs must be unique across entire Proxmox cluster
# - Use DHCP or static IPs based on your network setup
# - Resource allocation examples in CLAUDE.md
# - Total available: ~76GB RAM, 10-11 cores (after Proxmox/Talos)
