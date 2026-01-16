# Terraform and Provider Version Requirements
#
# Talos Kubernetes cluster on Proxmox VE

terraform {
  required_version = ">= 1.14.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93.0"
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

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36.0"
    }

  }

  # Backend configuration for remote state (optional)
  # For homelab: Local state is acceptable
  # backend "s3" { ... }
}
