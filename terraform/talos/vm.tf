# Talos Virtual Machine on Proxmox
#
# This file creates the Talos VM by cloning the Packer-created template
# with optional NVIDIA GPU passthrough.

# ============================================================================
# Data Sources
# ============================================================================

# Look up the Talos template created by Packer
data "proxmox_virtual_environment_vms" "talos_template" {
  node_name = var.proxmox_node

  filter {
    name   = "name"
    values = [var.talos_template_name]
  }

  filter {
    name   = "template"
    values = [true]
  }
}

# ============================================================================
# Virtual Machine Resource
# ============================================================================

# Create Talos VM by cloning the template
resource "proxmox_virtual_environment_vm" "talos_node" {
  name        = var.node_name
  description = var.description
  tags        = var.tags

  node_name = var.proxmox_node
  vm_id     = var.node_vm_id

  # Clone from Packer template
  clone {
    vm_id = data.proxmox_virtual_environment_vms.talos_template.vms[0].vm_id
    full  = true # Full clone (not linked)
  }

  # CPU configuration
  cpu {
    type    = var.node_cpu_type # Must be 'host'
    cores   = var.node_cpu_cores
    sockets = var.node_cpu_sockets
  }

  # Memory configuration
  memory {
    dedicated = var.node_memory
  }

  # Disk configuration
  disk {
    datastore_id = var.node_disk_storage
    size         = var.node_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  # Network configuration
  network_device {
    bridge  = var.network_bridge
    model   = var.network_model
    vlan_id = var.network_vlan > 0 ? var.network_vlan : null
  }

  # QEMU Guest Agent
  agent {
    enabled = var.enable_qemu_agent
    trim    = true
    type    = "virtio"
  }

  # GPU Passthrough (if enabled)
  # NOTE: This works together with the NVIDIA GPU sysctls in machine config
  # to enable GPU passthrough for AI/ML workloads
  #
  # CRITICAL AUTHENTICATION REQUIREMENT:
  # The 'id' parameter is NOT compatible with API token authentication.
  # You MUST use ONE of the following methods:
  #
  # METHOD 1 (RECOMMENDED): Use 'mapping' parameter with resource mapping
  #   1. Create GPU resource mapping in Proxmox UI:
  #      Datacenter -> Resource Mappings -> Add -> PCI Device
  #      Name: "gpu" (or your choice)
  #      Path: 0000:XX:YY.0 (your GPU PCI ID)
  #   2. Uncomment 'mapping = var.gpu_mapping' below
  #   3. Comment out or remove 'id' parameter
  #   4. Set gpu_mapping variable to "gpu" (or your mapping name)
  #
  # METHOD 2: Use password authentication instead of API token
  #   1. In versions.tf, uncomment password auth and comment out api_token
  #   2. Keep 'id' parameter as-is below
  #
  # See: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#hostpci
  #
  dynamic "hostpci" {
    for_each = var.enable_gpu_passthrough ? [1] : []
    content {
      device = "hostpci0"
      # Use GPU resource mapping (works with API token)
      # Alternative: id = "0000:07:00.0" for direct PCI ID (requires password auth)
      mapping = var.gpu_mapping
      pcie    = var.gpu_pcie
      rombar  = var.gpu_rombar # Boolean: true enables ROM bar, false disables
    }
  }

  # BIOS/EFI configuration
  bios = "ovmf"

  efi_disk {
    datastore_id      = var.node_disk_storage
    file_format       = "raw"
    type              = "4m"
    # IMPORTANT: Must be false for Talos - it doesn't support UEFI Secure Boot
    # with Microsoft keys. Setting to true causes "Access Denied" boot failure.
    pre_enrolled_keys = false
  }

  # Boot order
  boot_order = ["scsi0"]

  # Machine type
  machine = "q35"

  # On boot behavior
  on_boot = true

  # SCSI hardware
  scsi_hardware = "virtio-scsi-single"

  # Startup/shutdown order
  startup {
    order      = 1
    up_delay   = 30
    down_delay = 30
  }

  # Lifecycle
  lifecycle {
    precondition {
      condition     = length(data.proxmox_virtual_environment_vms.talos_template.vms) > 0
      error_message = "Talos template '${var.talos_template_name}' not found on Proxmox node '${var.proxmox_node}'. Build the template with Packer first."
    }

    ignore_changes = [
      # Ignore changes to template-derived attributes
      clone,
    ]
  }

  # Depends on template existence
  depends_on = [
    data.proxmox_virtual_environment_vms.talos_template
  ]
}
