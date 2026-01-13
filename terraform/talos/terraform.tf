# Terraform and Provider Version Requirements
#
# Talos Kubernetes cluster on Proxmox VE

terraform {
  required_version = ">= 1.14.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.92.0"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10.0"
    }

    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1.1"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.3"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
  }

  # Backend configuration for remote state (optional)
  # For homelab: Local state is acceptable
  # backend "s3" { ... }
}
