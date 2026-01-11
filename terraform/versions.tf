# Terraform and Provider Version Requirements
#
# This file specifies the required Terraform version and provider versions
# for deploying Talos Linux on Proxmox VE 9.0

terraform {
  required_version = ">= 1.14.2"

  required_providers {
    # Proxmox provider for VM management
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.89.1"
    }

    # Talos provider for machine configuration and cluster bootstrapping
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }

    # Local provider for writing kubeconfig/talosconfig files
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.3"
    }

    # Null provider for running local commands and provisioners
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
  }

  # Backend configuration for remote state (optional for homelab)
  # Uncomment and configure if using remote state (S3, GitLab, Terraform Cloud, etc.)
  #
  # backend "s3" {
  #   bucket         = "terraform-state"
  #   key            = "talos/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
  #
  # For homelab: Local state is acceptable (simpler setup)
  # State file stored in: terraform.tfstate (in .gitignore)
}

# Proxmox Provider Configuration
provider "proxmox" {
  endpoint = var.proxmox_url
  username = var.proxmox_username

  # Authentication Method Selection:
  #
  # Option 1: API Token (recommended for most operations)
  api_token = var.proxmox_api_token

  # Option 2: Password (required for GPU passthrough with PCI ID parameter)
  # If using GPU passthrough, uncomment this and comment out api_token above:
  # password = var.proxmox_password
  #
  # Note: Some GPU passthrough configurations require password authentication.
  # If you encounter "403 Forbidden" errors with GPU setup, switch to password auth.

  insecure = var.proxmox_insecure # For self-signed certs

  # Optional SSH configuration for certain operations
  # ssh {
  #   agent    = true
  #   username = "root"
  # }
}

# Talos Provider Configuration
provider "talos" {
  # No explicit configuration needed
  # Uses endpoints from talos_machine_configuration resources
}

# Notes:
# - Proxmox provider (bpg/proxmox) is the most feature-complete and actively maintained
# - Talos provider (siderolabs/talos) is official and HashiCorp-verified
# - Use API tokens instead of passwords for better security
# - Local state is acceptable for homelab (no need for remote backend)
# - For multi-user or production: Use remote backend with state locking
