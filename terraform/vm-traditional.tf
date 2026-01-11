# Traditional VM Deployment (for_each pattern)
#
# Deploys all enabled VMs from local.traditional_vms using for_each.
# This pattern allows safe add/remove of VMs without cascade destruction.
#
# ============================================================================
# Usage Examples
# ============================================================================
#
# Deploy all enabled VMs:
#   terraform apply
#
# Deploy specific VM only:
#   terraform apply -target='module.traditional_vm["ubuntu-dev"]'
#
# Destroy specific VM only:
#   terraform destroy -target='module.traditional_vm["ubuntu-dev"]'
#
# Plan changes for specific VM:
#   terraform plan -target='module.traditional_vm["debian-prod"]'
#
# Show state of all traditional VMs:
#   terraform state list | grep traditional_vm
#
# Show details of specific VM:
#   terraform state show 'module.traditional_vm["ubuntu-dev"]'
#
# ============================================================================
# How for_each Works
# ============================================================================
#
# Unlike count (index-based), for_each uses map keys:
# - Removing "arch-dev" only destroys that VM
# - Other VMs remain untouched
# - Safe to reorder, add, or remove entries
#
# ============================================================================

module "traditional_vm" {
  source = "./modules/proxmox-vm"

  # Loop over all enabled VMs from locals-vms.tf
  for_each = local.enabled_vms

  # Proxmox configuration
  proxmox_node  = var.proxmox_node
  template_name = each.value.template_name

  # VM identification
  vm_name     = each.key
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = concat(each.value.tags, var.common_tags)

  # Hardware configuration
  cpu_type  = each.value.cpu_type
  cpu_cores = each.value.cpu_cores
  memory    = each.value.memory

  # Disk configuration
  disks = [{
    datastore_id = each.value.disk_storage
    size         = each.value.disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]

  # Network configuration
  network_devices = [{
    bridge = var.network_bridge
    model  = "virtio"
  }]

  # Cloud-init configuration
  enable_cloud_init    = var.enable_cloud_init
  cloud_init_datastore = each.value.disk_storage

  # Use Windows-specific credentials or default Linux credentials
  cloud_init_user     = each.value.os_type == "windows" ? var.windows_admin_user : var.cloud_init_user
  cloud_init_password = each.value.os_type == "windows" ? var.windows_admin_password : var.cloud_init_password
  cloud_init_ssh_keys = each.value.os_type == "windows" ? [] : var.cloud_init_ssh_keys

  # IP configuration
  ip_configs = [{
    address = each.value.ip_address
    gateway = each.value.ip_address != "dhcp" ? var.default_gateway : null
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  # Boot configuration
  bios_type          = "ovmf" # UEFI for all VMs
  efi_disk_datastore = each.value.disk_storage
  machine_type       = "q35"
  scsi_hardware      = "virtio-scsi-single"

  # QEMU Agent (required for IP reporting)
  enable_qemu_agent = true

  # Startup configuration
  on_boot            = each.value.on_boot
  startup_order      = each.value.startup_order
  startup_up_delay   = each.value.os_type == "windows" ? 60 : 30
  startup_down_delay = each.value.os_type == "windows" ? 60 : 30
}

# ============================================================================
# Notes
# ============================================================================
#
# Template Prerequisites:
# - Each template must exist in Proxmox before deployment
# - Build templates: cd packer/<os> && packer build .
# - Verify: qm list | grep template
#
# Adding Multiple VMs of Same Type:
# - Add new entry in locals-vms.tf with unique key and vm_id
# - Example: "ubuntu-ci" with vm_id = 101
#
# Changing VM Configuration:
# - Edit values in locals-vms.tf
# - Run: terraform plan (review changes)
# - Run: terraform apply
# - Note: Some changes may require VM recreation (disk size increase is safe)
#
# Disabling Without Deleting:
# - Set enabled = false in locals-vms.tf
# - Run: terraform apply (will destroy the VM)
# - Definition remains for easy re-enabling later
#
# Resource Allocation:
# - Total system: 96GB RAM, 12 cores
# - Talos reserves: ~32GB RAM, 8 cores
# - Available for traditional VMs: ~64GB RAM, 4 cores
# - Plan accordingly when enabling multiple VMs
#
