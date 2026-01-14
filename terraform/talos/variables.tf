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
  default     = false
}

variable "git_provider" {
  description = "Git provider for FluxCD (forgejo, github, gitlab)"
  type        = string
  default     = "forgejo"

  validation {
    condition     = contains(["forgejo", "gitea", "github", "gitlab"], var.git_provider)
    error_message = "git_provider must be one of: forgejo, gitea, github, gitlab"
  }
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
  default     = false
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
