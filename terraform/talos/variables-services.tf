# Service Configuration Variables
#
# Configuration for Kubernetes services: Cilium, Longhorn, FluxCD, Forgejo

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

variable "enable_longhorn_backups" {
  description = "Enable Longhorn NFS backups (requires secrets/nas-backup-creds.enc.yaml)"
  type        = bool
  default     = true
}

variable "longhorn_backup_target" {
  description = "Longhorn backup target URL (NFS)"
  type        = string
  default     = "nfs://10.10.2.5:/mnt/tank/backups/longhorn"
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

# ============================================================================
# Pangolin/Newt Configuration (WireGuard Tunnel)
# ============================================================================

variable "enable_pangolin" {
  description = "Enable Pangolin/Newt WireGuard tunnel (requires secrets/pangolin-creds.enc.yaml)"
  type        = bool
  default     = true
}
