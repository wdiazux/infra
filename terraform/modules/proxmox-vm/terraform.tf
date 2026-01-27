# Terraform configuration for proxmox-vm module

terraform {
  required_version = ">= 1.14.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.93.0, < 1.0.0"
    }
  }
}
