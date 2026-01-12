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
      version = "~> 0.92.0"
    }

    # Talos provider for machine configuration and cluster bootstrapping
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10.0"
    }

    # SOPS provider for encrypted secrets management
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1.1"
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
#
# Credentials are loaded from SOPS-encrypted secrets file.
# See sops.tf for the data source configuration.
# To use variables instead, replace local.secrets.* with var.*
#
provider "proxmox" {
  endpoint = local.secrets.proxmox_url
  username = local.secrets.proxmox_user

  # API Token authentication (from SOPS-encrypted secrets)
  api_token = local.secrets.proxmox_api_token

  # Skip TLS verification for self-signed certificates
  insecure = local.secrets.proxmox_tls_insecure

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
