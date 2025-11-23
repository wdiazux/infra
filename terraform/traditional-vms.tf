# Traditional VM Deployments
#
# This file deploys traditional Linux and Windows VMs from Packer templates
# using the generic proxmox-vm module

# ============================================================================
# Ubuntu VM
# ============================================================================

module "ubuntu_vm" {
  source = "./modules/proxmox-vm"

  # Enable/disable this VM
  count = var.deploy_ubuntu_vm ? 1 : 0

  # Proxmox configuration
  proxmox_node  = var.proxmox_node
  template_name = var.ubuntu_template_name

  # VM identification
  vm_name     = var.ubuntu_vm_name
  vm_id       = var.ubuntu_vm_id
  description = "Ubuntu 24.04 LTS VM - General purpose development and testing"
  tags        = concat(["ubuntu", "linux", "lts"], var.common_tags)

  # Hardware configuration
  cpu_type   = var.ubuntu_cpu_type
  cpu_cores  = var.ubuntu_cpu_cores
  memory     = var.ubuntu_memory

  disks = [{
    datastore_id = var.ubuntu_disk_storage
    size         = var.ubuntu_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]

  network_devices = [{
    bridge = var.network_bridge
    model  = "virtio"
  }]

  # Cloud-init configuration
  enable_cloud_init    = var.enable_cloud_init
  cloud_init_datastore = var.ubuntu_disk_storage
  cloud_init_user      = var.cloud_init_user
  cloud_init_password  = var.cloud_init_password
  cloud_init_ssh_keys  = var.cloud_init_ssh_keys

  ip_configs = [{
    address = var.ubuntu_ip_address
    gateway = var.ubuntu_ip_address != "dhcp" ? var.default_gateway : null
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  # Boot configuration
  bios_type         = "ovmf"  # UEFI
  efi_disk_datastore = var.ubuntu_disk_storage
  machine_type      = "q35"
  scsi_hardware     = "virtio-scsi-single"

  # QEMU Agent
  enable_qemu_agent = true

  # Startup configuration
  # NOTE: startup_order starts at 20 to leave room for Talos node (startup_order=1)
  # and any other infrastructure VMs that should start before traditional workload VMs
  on_boot            = var.ubuntu_on_boot
  startup_order      = 20
  startup_up_delay   = 30
  startup_down_delay = 30
}

# ============================================================================
# Debian VM
# ============================================================================

module "debian_vm" {
  source = "./modules/proxmox-vm"

  # Enable/disable this VM
  count = var.deploy_debian_vm ? 1 : 0

  # Proxmox configuration
  proxmox_node  = var.proxmox_node
  template_name = var.debian_template_name

  # VM identification
  vm_name     = var.debian_vm_name
  vm_id       = var.debian_vm_id
  description = "Debian 12 (Bookworm) VM - Stable server workloads"
  tags        = concat(["debian", "linux", "stable"], var.common_tags)

  # Hardware configuration
  cpu_type   = var.debian_cpu_type
  cpu_cores  = var.debian_cpu_cores
  memory     = var.debian_memory

  disks = [{
    datastore_id = var.debian_disk_storage
    size         = var.debian_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]

  network_devices = [{
    bridge = var.network_bridge
    model  = "virtio"
  }]

  # Cloud-init configuration
  enable_cloud_init    = var.enable_cloud_init
  cloud_init_datastore = var.debian_disk_storage
  cloud_init_user      = var.cloud_init_user
  cloud_init_password  = var.cloud_init_password
  cloud_init_ssh_keys  = var.cloud_init_ssh_keys

  ip_configs = [{
    address = var.debian_ip_address
    gateway = var.debian_ip_address != "dhcp" ? var.default_gateway : null
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  # Boot configuration
  bios_type          = "ovmf"  # UEFI
  efi_disk_datastore = var.debian_disk_storage
  machine_type       = "q35"
  scsi_hardware      = "virtio-scsi-single"

  # QEMU Agent
  enable_qemu_agent = true

  # Startup configuration
  on_boot            = var.debian_on_boot
  startup_order      = 21
  startup_up_delay   = 30
  startup_down_delay = 30
}

# ============================================================================
# Arch Linux VM
# ============================================================================

module "arch_vm" {
  source = "./modules/proxmox-vm"

  # Enable/disable this VM
  count = var.deploy_arch_vm ? 1 : 0

  # Proxmox configuration
  proxmox_node  = var.proxmox_node
  template_name = var.arch_template_name

  # VM identification
  vm_name     = var.arch_vm_name
  vm_id       = var.arch_vm_id
  description = "Arch Linux VM - Rolling release, bleeding edge packages"
  tags        = concat(["arch", "linux", "rolling"], var.common_tags)

  # Hardware configuration
  cpu_type   = var.arch_cpu_type
  cpu_cores  = var.arch_cpu_cores
  memory     = var.arch_memory

  disks = [{
    datastore_id = var.arch_disk_storage
    size         = var.arch_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]

  network_devices = [{
    bridge = var.network_bridge
    model  = "virtio"
  }]

  # Cloud-init configuration
  enable_cloud_init    = var.enable_cloud_init
  cloud_init_datastore = var.arch_disk_storage
  cloud_init_user      = var.cloud_init_user
  cloud_init_password  = var.cloud_init_password
  cloud_init_ssh_keys  = var.cloud_init_ssh_keys

  ip_configs = [{
    address = var.arch_ip_address
    gateway = var.arch_ip_address != "dhcp" ? var.default_gateway : null
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  # Boot configuration
  bios_type          = "ovmf"  # UEFI
  efi_disk_datastore = var.arch_disk_storage
  machine_type       = "q35"
  scsi_hardware      = "virtio-scsi-single"

  # QEMU Agent
  enable_qemu_agent = true

  # Startup configuration
  on_boot            = var.arch_on_boot
  startup_order      = 22
  startup_up_delay   = 30
  startup_down_delay = 30
}

# ============================================================================
# NixOS VM
# ============================================================================

module "nixos_vm" {
  source = "./modules/proxmox-vm"

  # Enable/disable this VM
  count = var.deploy_nixos_vm ? 1 : 0

  # Proxmox configuration
  proxmox_node  = var.proxmox_node
  template_name = var.nixos_template_name

  # VM identification
  vm_name     = var.nixos_vm_name
  vm_id       = var.nixos_vm_id
  description = "NixOS VM - Declarative configuration management"
  tags        = concat(["nixos", "linux", "declarative"], var.common_tags)

  # Hardware configuration
  cpu_type   = var.nixos_cpu_type
  cpu_cores  = var.nixos_cpu_cores
  memory     = var.nixos_memory

  disks = [{
    datastore_id = var.nixos_disk_storage
    size         = var.nixos_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]

  network_devices = [{
    bridge = var.network_bridge
    model  = "virtio"
  }]

  # Cloud-init configuration
  enable_cloud_init    = var.enable_cloud_init
  cloud_init_datastore = var.nixos_disk_storage
  cloud_init_user      = var.cloud_init_user
  cloud_init_password  = var.cloud_init_password
  cloud_init_ssh_keys  = var.cloud_init_ssh_keys

  ip_configs = [{
    address = var.nixos_ip_address
    gateway = var.nixos_ip_address != "dhcp" ? var.default_gateway : null
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  # Boot configuration
  bios_type          = "ovmf"  # UEFI
  efi_disk_datastore = var.nixos_disk_storage
  machine_type       = "q35"
  scsi_hardware      = "virtio-scsi-single"

  # QEMU Agent
  enable_qemu_agent = true

  # Startup configuration
  on_boot            = var.nixos_on_boot
  startup_order      = 23
  startup_up_delay   = 30
  startup_down_delay = 30
}

# ============================================================================
# Windows 11 VM
# ============================================================================

module "windows_vm" {
  source = "./modules/proxmox-vm"

  # Enable/disable this VM
  count = var.deploy_windows_vm ? 1 : 0

  # Proxmox configuration
  proxmox_node  = var.proxmox_node
  template_name = var.windows_template_name

  # VM identification
  vm_name     = var.windows_vm_name
  vm_id       = var.windows_vm_id
  description = "Windows 11 (24H2) VM - Windows workloads and desktop applications"
  tags        = concat(["windows", "windows11", "desktop"], var.common_tags)

  # Hardware configuration
  cpu_type   = var.windows_cpu_type
  cpu_cores  = var.windows_cpu_cores
  memory     = var.windows_memory

  disks = [{
    datastore_id = var.windows_disk_storage
    size         = var.windows_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }]

  network_devices = [{
    bridge = var.network_bridge
    model  = "virtio"
  }]

  # Cloud-init configuration (Cloudbase-Init for Windows)
  enable_cloud_init    = var.enable_cloud_init
  cloud_init_datastore = var.windows_disk_storage
  cloud_init_user      = var.windows_cloud_init_user
  cloud_init_password  = var.windows_cloud_init_password
  cloud_init_ssh_keys  = []  # Windows doesn't use SSH keys via cloud-init

  ip_configs = [{
    address = var.windows_ip_address
    gateway = var.windows_ip_address != "dhcp" ? var.default_gateway : null
  }]

  dns_servers = var.dns_servers
  dns_domain  = var.dns_domain

  # Boot configuration
  bios_type          = "ovmf"  # UEFI
  efi_disk_datastore = var.windows_disk_storage
  machine_type       = "q35"
  scsi_hardware      = "virtio-scsi-single"

  # QEMU Agent
  enable_qemu_agent = true

  # Startup configuration
  on_boot            = var.windows_on_boot
  startup_order      = 24
  startup_up_delay   = 60   # Windows takes longer to boot
  startup_down_delay = 60   # Windows takes longer to shutdown
}

# ============================================================================
# Notes
# ============================================================================

# Template Names:
# - Packer builds templates with timestamps (e.g., "ubuntu-24.04-golden-template-20251118-1234")
# - Update template_name variables after Packer builds
# - Or use data source to find latest template automatically
#
# VM IDs:
# - Ubuntu:  100-199 range
# - Debian:  200-299 range
# - Arch:    300-399 range
# - NixOS:   400-499 range
# - Windows: 500-599 range
#
# IP Addresses:
# - Set to "dhcp" for automatic assignment
# - Or use static: "192.168.1.100/24"
#
# Deployment Control:
# - Set deploy_*_vm = false to skip deployment
# - Use terraform apply -target=module.ubuntu_vm to deploy specific VMs
#
# Cloud-init:
# - All templates have cloud-init (Linux) or Cloudbase-Init (Windows)
# - User/password set here override template defaults
# - SSH keys recommended for Linux VMs
#
# Resource Allocation:
# - Adjust CPU/memory based on available resources (96GB total)
# - See CLAUDE.md for resource allocation examples
# - Remember: Talos gets GPU, traditional VMs do not
