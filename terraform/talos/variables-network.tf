# Network Configuration Variables
#
# Network settings, service LoadBalancer IPs, and DNS/NTP configuration

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
# Service LoadBalancer IPs (Important Services Range)
# ============================================================================

variable "important_services_ip_start" {
  description = "Start IP for services/apps LoadBalancer pool"
  type        = string
  default     = "10.10.2.11"
}

variable "important_services_ip_stop" {
  description = "End IP for services/apps LoadBalancer pool"
  type        = string
  default     = "10.10.2.150"
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
  description = "Static IP for Forgejo HTTP LoadBalancer (port 80). Must match kubernetes/infrastructure/values/forgejo-values.yaml"
  type        = string
  default     = "10.10.2.13"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.forgejo_ip))
    error_message = "forgejo_ip must be a valid IPv4 address."
  }
}

variable "forgejo_ssh_ip" {
  description = "Static IP for Forgejo SSH LoadBalancer"
  type        = string
  default     = "10.10.2.14"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.forgejo_ssh_ip))
    error_message = "forgejo_ssh_ip must be a valid IPv4 address."
  }
}

variable "fluxcd_webhook_ip" {
  description = "Static IP for FluxCD webhook receiver LoadBalancer"
  type        = string
  default     = "10.10.2.15"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.fluxcd_webhook_ip))
    error_message = "fluxcd_webhook_ip must be a valid IPv4 address."
  }
}
