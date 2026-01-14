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

# ============================================================================
# Cilium CNI Configuration
# ============================================================================

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.18.5"
}

variable "cilium_lb_pool_cidr" {
  description = "CIDR for Cilium L2 LoadBalancer IP pool"
  type        = string
  default     = "10.10.2.240/28"

  validation {
    condition     = can(cidrhost(var.cilium_lb_pool_cidr, 0))
    error_message = "cilium_lb_pool_cidr must be a valid CIDR notation."
  }
}

# ============================================================================
# Service LoadBalancer IPs (Important Services Range)
# ============================================================================

variable "important_services_ip_start" {
  description = "Start IP for important services LoadBalancer pool"
  type        = string
  default     = "10.10.2.11"
}

variable "important_services_ip_stop" {
  description = "End IP for important services LoadBalancer pool"
  type        = string
  default     = "10.10.2.20"
}

variable "hubble_ui_ip" {
  description = "Static IP for Cilium Hubble UI LoadBalancer"
  type        = string
  default     = "10.10.2.11"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.hubble_ui_ip))
    error_message = "hubble_ui_ip must be a valid IPv4 address."
  }
}

variable "longhorn_ui_ip" {
  description = "Static IP for Longhorn UI LoadBalancer"
  type        = string
  default     = "10.10.2.12"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.longhorn_ui_ip))
    error_message = "longhorn_ui_ip must be a valid IPv4 address."
  }
}

variable "forgejo_ip" {
  description = "Static IP for Forgejo LoadBalancer (HTTP and SSH)"
  type        = string
  default     = "10.10.2.13"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.forgejo_ip))
    error_message = "forgejo_ip must be a valid IPv4 address."
  }
}

variable "fluxcd_webhook_ip" {
  description = "Static IP for FluxCD webhook receiver LoadBalancer"
  type        = string
  default     = "10.10.2.14"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.fluxcd_webhook_ip))
    error_message = "fluxcd_webhook_ip must be a valid IPv4 address."
  }
}

# ============================================================================
# Longhorn Storage Configuration
# ============================================================================

variable "longhorn_version" {
  description = "Longhorn Helm chart version"
  type        = string
  default     = "1.10.1"
}

# ============================================================================
# FluxCD Configuration
# ============================================================================

variable "enable_fluxcd" {
  description = "Enable FluxCD GitOps bootstrap"
  type        = bool
  default     = true
}

variable "sops_age_key_file" {
  description = "Path to SOPS Age key file for FluxCD secret decryption"
  type        = string
  default     = ""
  # Example: ~/.config/sops/age/keys.txt
  # If set, creates sops-age secret in flux-system namespace
}

variable "git_token" {
  description = "Git personal access token for FluxCD bootstrap"
  type        = string
  default     = ""
  sensitive   = true
}

variable "git_hostname" {
  description = "Git server hostname for FluxCD (used with forgejo/gitea)"
  type        = string
  default     = "git.home-infra.net"
  # Example: git.home-infra.net or forgejo.example.com
}

variable "git_owner" {
  description = "Git owner (username or organization) for FluxCD"
  type        = string
  default     = ""
}

variable "git_repository" {
  description = "Git repository name for FluxCD"
  type        = string
  default     = "infra"
}

variable "git_branch" {
  description = "Git branch for FluxCD"
  type        = string
  default     = "main"
}

variable "git_personal" {
  description = "Use personal account (not organization)"
  type        = bool
  default     = true
}

variable "git_private" {
  description = "Repository is private"
  type        = bool
  default     = false
}

variable "fluxcd_path" {
  description = "Path in repository for FluxCD cluster config"
  type        = string
  default     = "kubernetes/clusters/homelab"
}

# ============================================================================
# Forgejo Configuration (In-Cluster)
# ============================================================================

variable "enable_forgejo" {
  description = "Enable in-cluster Forgejo deployment"
  type        = bool
  default     = true
}

variable "forgejo_chart_version" {
  description = "Forgejo Helm chart version"
  type        = string
  default     = "10.0.0"
}

variable "forgejo_create_repo" {
  description = "Automatically create the FluxCD repository in Forgejo"
  type        = bool
  default     = true
}
