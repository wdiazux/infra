# Terraform and Provider Version Requirements
#
# Traditional VMs (Ubuntu, Debian, Arch, NixOS, Windows) on Proxmox VE

terraform {
  required_version = ">= 1.14.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93.0"
    }

    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1.1"
    }
  }
}
