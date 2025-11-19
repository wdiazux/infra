# Generic Proxmox VM Module
#
# This module creates a VM by cloning a Packer-created template
# Supports cloud-init configuration for traditional Linux VMs and Windows

# ============================================================================
# Data Sources
# ============================================================================

# Look up the template by name
data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node

  filter {
    name   = "name"
    values = [var.template_name]
  }

  filter {
    name   = "template"
    values = [true]
  }
}

# ============================================================================
# Virtual Machine Resource
# ============================================================================

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.description
  tags        = var.tags

  node_name = var.proxmox_node
  vm_id     = var.vm_id

  # Clone from template
  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    full  = true  # Full clone (not linked)
  }

  # CPU configuration
  cpu {
    type    = var.cpu_type
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
  }

  # Memory configuration
  memory {
    dedicated = var.memory
  }

  # Disk configuration
  dynamic "disk" {
    for_each = var.disks
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
      interface    = disk.value.interface
      iothread     = lookup(disk.value, "iothread", true)
      discard      = lookup(disk.value, "discard", "on")
      ssd          = lookup(disk.value, "ssd", true)
    }
  }

  # Network configuration
  dynamic "network_device" {
    for_each = var.network_devices
    content {
      bridge  = network_device.value.bridge
      model   = lookup(network_device.value, "model", "virtio")
      vlan_id = lookup(network_device.value, "vlan_id", null)
    }
  }

  # QEMU Guest Agent
  agent {
    enabled = var.enable_qemu_agent
    trim    = true
    type    = "virtio"
  }

  # Cloud-init configuration (if enabled)
  dynamic "initialization" {
    for_each = var.enable_cloud_init ? [1] : []
    content {
      datastore_id = var.cloud_init_datastore

      # User configuration
      dynamic "user_account" {
        for_each = var.cloud_init_user != "" ? [1] : []
        content {
          username = var.cloud_init_user
          password = var.cloud_init_password
          keys     = var.cloud_init_ssh_keys
        }
      }

      # IP configuration
      dynamic "ip_config" {
        for_each = var.ip_configs
        content {
          ipv4 {
            address = lookup(ip_config.value, "address", "dhcp")
            gateway = lookup(ip_config.value, "gateway", null)
          }
        }
      }

      # DNS configuration
      dns {
        servers = var.dns_servers
        domain  = var.dns_domain
      }
    }
  }

  # BIOS/EFI configuration
  bios = var.bios_type

  # EFI configuration (if UEFI)
  dynamic "efi_disk" {
    for_each = var.bios_type == "ovmf" ? [1] : []
    content {
      datastore_id      = var.efi_disk_datastore
      file_format       = "raw"
      type              = "4m"
      pre_enrolled_keys = true
    }
  }

  # Boot order
  boot_order = var.boot_order

  # Machine type
  machine = var.machine_type

  # On boot behavior
  on_boot = var.on_boot

  # SCSI hardware
  scsi_hardware = var.scsi_hardware

  # Startup/shutdown order
  startup {
    order      = var.startup_order
    up_delay   = var.startup_up_delay
    down_delay = var.startup_down_delay
  }

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to template-derived attributes
      clone,
    ]
  }

  # Depends on template existence
  depends_on = [
    data.proxmox_virtual_environment_vms.template
  ]
}
