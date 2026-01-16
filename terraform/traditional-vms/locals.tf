# Traditional VM Definitions
#
# This file defines all traditional VMs (non-Talos) using a locals map.
# VMs are deployed using for_each in vm-traditional.tf for safe add/remove operations.
#
# ============================================================================
# Quick Start
# ============================================================================
#
# 1. Enable a VM by setting enabled = true
# 2. Deploy all enabled VMs:
#    terraform apply
#
# 3. Deploy specific VM:
#    terraform apply -target='module.traditional_vm["ubuntu-dev"]'
#
# 4. Destroy specific VM:
#    terraform destroy -target='module.traditional_vm["ubuntu-dev"]'
#
# 5. List deployed VMs:
#    terraform state list | grep traditional_vm
#
# ============================================================================
# Adding a New VM
# ============================================================================
#
# 1. Add entry to local.traditional_vms map below
# 2. Run: terraform plan (review changes)
# 3. Run: terraform apply
#
# Example - Add second Ubuntu VM:
#   "ubuntu-ci" = {
#     enabled       = true
#     description   = "Ubuntu CI/CD runner"
#     os_type       = "ubuntu"
#     template_name = "ubuntu-2404-cloud-template"
#     vm_id         = 101
#     ...
#   }
#
# ============================================================================
# VM ID Allocation
# ============================================================================
#
# Range       | OS Type    | Notes
# ------------|------------|---------------------------
# 100-199     | Ubuntu     | Development, CI/CD
# 200-299     | Debian     | Production servers
# 300-399     | Arch       | Development, testing
# 400-499     | NixOS      | Declarative config lab
# 500-599     | Windows    | Desktop, gaming, apps
# 1000-1999   | Talos      | Kubernetes (separate config)
#
# ============================================================================

locals {
  # ===========================================================================
  # Traditional VMs Definition Map
  # ===========================================================================
  #
  # Each VM is defined with all its configuration.
  # Set enabled = false to skip deployment without removing the definition.
  #
  # Benefits of this approach:
  # - Safe to add/remove VMs (for_each uses keys, not indices)
  # - All VM configs in one place for easy review
  # - Can deploy multiple VMs of same OS type
  # - Easy to enable/disable without deletion
  #
  traditional_vms = {

    # =========================================================================
    # Ubuntu VMs (ID Range: 100-199)
    # =========================================================================

    "ubuntu-dev" = {
      enabled       = false # Set to true to deploy
      description   = "Ubuntu 24.04 LTS - General purpose development"
      os_type       = "ubuntu"
      template_name = var.ubuntu_template_name
      vm_id         = 100

      # Hardware
      cpu_type  = "host"
      cpu_cores = 4
      memory    = 8192 # 8GB
      disk_size = 40   # GB

      # Storage
      disk_storage = var.default_storage

      # Boot configuration (defaults for UEFI systems)
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      # Network
      ip_address = "dhcp" # Or "10.10.2.151/24" for static
      on_boot    = true
      tags       = ["ubuntu", "linux", "lts", "development"]

      # Startup order (lower = starts first)
      startup_order = 20
    }

    "ubuntu-test" = {
      enabled       = false # Disabled
      description   = "Ubuntu 24.04 - Lightweight test VM"
      os_type       = "ubuntu"
      template_name = var.ubuntu_template_name
      vm_id         = 101

      cpu_type  = "host"
      cpu_cores = 2
      memory    = 2048 # 2GB - minimal for testing
      disk_size = 25   # 25GB (template is ~22GB)

      disk_storage   = var.default_storage
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      ip_address    = "dhcp"
      on_boot       = false # Don't auto-start
      tags          = ["ubuntu", "linux", "test", "ephemeral"]
      startup_order = 99 # Start last
    }

    # =========================================================================
    # Debian VMs (ID Range: 200-299)
    # =========================================================================

    "debian-prod" = {
      enabled       = false
      description   = "Debian 13 (Trixie) - Stable production server"
      os_type       = "debian"
      template_name = var.debian_template_name
      vm_id         = 200

      cpu_type  = "host"
      cpu_cores = 4
      memory    = 8192
      disk_size = 40

      disk_storage   = var.default_storage
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      ip_address    = "dhcp"
      on_boot       = true
      tags          = ["debian", "linux", "stable", "production"]
      startup_order = 21
    }

    "debian-test" = {
      enabled       = false # Disabled
      description   = "Debian 13 - Lightweight test VM"
      os_type       = "debian"
      template_name = var.debian_template_name
      vm_id         = 201

      cpu_type  = "host"
      cpu_cores = 2
      memory    = 2048 # 2GB - minimal for testing
      disk_size = 25   # 25GB (template is 21GB)

      disk_storage   = var.default_storage
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      ip_address    = "dhcp"
      on_boot       = false # Don't auto-start
      tags          = ["debian", "linux", "test", "ephemeral"]
      startup_order = 99 # Start last
    }

    # =========================================================================
    # Arch Linux VMs (ID Range: 300-399)
    # =========================================================================

    "arch-dev" = {
      enabled       = false
      description   = "Arch Linux - Rolling release development"
      os_type       = "arch"
      template_name = var.arch_template_name
      vm_id         = 300

      cpu_type  = "host"
      cpu_cores = 2
      memory    = 4096 # 4GB
      disk_size = 30

      disk_storage   = var.default_storage
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      ip_address    = "dhcp"
      on_boot       = true
      tags          = ["arch", "linux", "rolling", "development"]
      startup_order = 22
    }

    "arch-test" = {
      enabled       = false # Disabled
      description   = "Arch Linux - Lightweight test VM"
      os_type       = "arch"
      template_name = var.arch_template_name
      vm_id         = 301

      cpu_type  = "host"
      cpu_cores = 2
      memory    = 2048 # 2GB - minimal for testing
      disk_size = 25   # 25GB (template is 20GB)

      disk_storage   = var.default_storage
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      ip_address    = "dhcp"
      on_boot       = false # Don't auto-start
      tags          = ["arch", "linux", "test", "ephemeral"]
      startup_order = 99 # Start last
    }

    # =========================================================================
    # NixOS VMs (ID Range: 400-499)
    # =========================================================================

    "nixos-lab" = {
      enabled       = false
      description   = "NixOS - Declarative configuration lab"
      os_type       = "nixos"
      template_name = var.nixos_template_name
      vm_id         = 400

      cpu_type  = "host"
      cpu_cores = 2
      memory    = 4096
      disk_size = 30

      disk_storage = var.default_storage

      # NixOS cloud image uses SeaBIOS and virtio0 (not UEFI/scsi0)
      bios_type      = "seabios"
      disk_interface = "virtio0"

      ip_address    = "dhcp"
      on_boot       = true
      tags          = ["nixos", "linux", "declarative"]
      startup_order = 23
    }

    "nixos-test" = {
      enabled       = false # Disabled
      description   = "NixOS - Lightweight test VM"
      os_type       = "nixos"
      template_name = var.nixos_template_name
      vm_id         = 401

      cpu_type  = "host"
      cpu_cores = 2
      memory    = 2048 # 2GB - minimal for testing
      disk_size = 25   # 25GB (template is 20GB)

      disk_storage = var.default_storage

      # NixOS cloud image uses SeaBIOS and virtio0 (not UEFI/scsi0)
      bios_type      = "seabios"
      disk_interface = "virtio0"

      ip_address    = "dhcp"
      on_boot       = false # Don't auto-start
      tags          = ["nixos", "linux", "test", "ephemeral"]
      startup_order = 99 # Start last
    }

    # =========================================================================
    # Windows VMs (ID Range: 500-599)
    # =========================================================================

    "windows-desktop" = {
      enabled       = false
      description   = "Windows 11 - Desktop applications"
      os_type       = "windows"
      template_name = var.windows_template_name
      vm_id         = 500

      cpu_type  = "host"
      cpu_cores = 4
      memory    = 8192
      disk_size = 100 # Windows needs more space

      disk_storage   = var.default_storage
      bios_type      = "ovmf"
      disk_interface = "scsi0"

      ip_address    = "dhcp"
      on_boot       = true
      tags          = ["windows", "windows11", "desktop"]
      startup_order = 24
    }
  }

  # ===========================================================================
  # Filtered Maps (for use in for_each)
  # ===========================================================================

  # Only enabled VMs (used by for_each in vm-traditional.tf)
  enabled_vms = { for k, v in local.traditional_vms : k => v if v.enabled }

  # VMs by OS type (useful for OS-specific operations)
  ubuntu_vms  = { for k, v in local.enabled_vms : k => v if v.os_type == "ubuntu" }
  debian_vms  = { for k, v in local.enabled_vms : k => v if v.os_type == "debian" }
  arch_vms    = { for k, v in local.enabled_vms : k => v if v.os_type == "arch" }
  nixos_vms   = { for k, v in local.enabled_vms : k => v if v.os_type == "nixos" }
  windows_vms = { for k, v in local.enabled_vms : k => v if v.os_type == "windows" }

  # Count of enabled VMs by type
  vm_counts = {
    total   = length(local.enabled_vms)
    ubuntu  = length(local.ubuntu_vms)
    debian  = length(local.debian_vms)
    arch    = length(local.arch_vms)
    nixos   = length(local.nixos_vms)
    windows = length(local.windows_vms)
  }
}
