# Service Configuration Variables
#
# Configuration for Kubernetes services: Cilium, Longhorn, FluxCD, Forgejo

# ============================================================================
# Cilium CNI Configuration
# ============================================================================

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.18.6"
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
  default     = "nfs://10.10.2.5:/mnt/tank/backups"
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

variable "postgresql_version" {
  description = "PostgreSQL Helm chart version (Bitnami)"
  type        = string
  default     = "18.2.0"
}

variable "forgejo_chart_version" {
  description = "Forgejo Helm chart version"
  type        = string
  default     = "16.0.1"
}

variable "forgejo_create_repo" {
  description = "Automatically create the FluxCD repository in Forgejo"
  type        = bool
  default     = true
}

# ============================================================================
# Weave GitOps Configuration (FluxCD Web UI)
# ============================================================================

variable "enable_weave_gitops" {
  description = "Enable Weave GitOps web UI for FluxCD"
  type        = bool
  default     = true
}

variable "weave_gitops_version" {
  description = "Weave GitOps Helm chart version"
  type        = string
  default     = "4.0.36"
}

variable "weave_gitops_ip" {
  description = "LoadBalancer IP for Weave GitOps UI"
  type        = string
  default     = "10.10.2.16"
}

variable "weave_gitops_admin_user" {
  description = "Weave GitOps admin username"
  type        = string
  default     = "admin"
}

variable "weave_gitops_password_hash" {
  description = "Weave GitOps admin password (bcrypt hash). Generate with: echo -n 'password' | gitops get bcrypt-hash"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Pangolin/Newt Configuration (WireGuard Tunnel)
# ============================================================================

variable "enable_pangolin" {
  description = "Enable Pangolin/Newt WireGuard tunnel (requires secrets/pangolin-creds.enc.yaml)"
  type        = bool
  default     = true
}

# ============================================================================
# cert-manager Configuration
# ============================================================================

variable "enable_cert_manager" {
  description = "Enable cert-manager namespace and Cloudflare API token secret (requires secrets/cloudflare-api-token.enc.yaml)"
  type        = bool
  default     = true
}
