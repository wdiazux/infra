# NixOS Golden Image Packer Template for Proxmox VE 9.0
#
# This template creates a NixOS golden image with cloud-init
# for use as a template in Proxmox

packer {
  required_version = "~> 1.14.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.2.0"
    }
  }
}

# Local variables
locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
  template_name = "${var.template_name}-${local.timestamp}"
}

# Proxmox ISO Builder
source "proxmox-iso" "nixos" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM configuration
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = local.template_name
  template_description = "${var.template_description} (built ${formatdate("YYYY-MM-DD", timestamp())})"

  # ISO configuration
  iso_url          = var.nixos_iso_url
  iso_checksum     = var.nixos_iso_checksum
  iso_storage_pool = "local"
  unmount_iso      = true

  # CPU configuration
  cpu_type = var.vm_cpu_type
  cores    = var.vm_cores
  sockets  = 1

  # Memory
  memory = var.vm_memory

  # Disk configuration
  disks {
    type         = "scsi"
    storage_pool = var.vm_disk_storage
    disk_size    = var.vm_disk_size
    format       = "raw"
    cache_mode   = "writethrough"
    io_thread    = true
  }

  # Network configuration
  network_adapters {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }

  # SCSI controller
  scsi_controller = "virtio-scsi-single"

  # QEMU Agent
  qemu_agent = true

  # BIOS (UEFI for NixOS)
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.vm_disk_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # Boot configuration for NixOS
  boot_wait = "10s"
  boot_command = [
    "<enter><wait30>",
    "sudo su -<enter><wait>",
    "passwd<enter><wait>",
    "${var.ssh_password}<enter><wait>",
    "${var.ssh_password}<enter><wait>",
    "systemctl start sshd<enter><wait>",
    "ip addr show<enter><wait>"
  ]

  # HTTP server for configuration files
  http_directory = "http"
  http_port_min  = 8103
  http_port_max  = 8103

  # SSH configuration
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  # Cloud-init
  cloud_init              = true
  cloud_init_storage_pool = var.vm_disk_storage

  # Template settings
  os = "l26"  # Linux 2.6+ kernel
}

# Build configuration
build {
  name    = "nixos-proxmox-template"
  sources = ["source.proxmox-iso.nixos"]

  # Run installation script
  provisioner "shell" {
    script = "${path.root}/http/install.sh"
    environment_vars = [
      "PACKER_HTTP_ADDR={{ .HTTPIP }}:{{ .HTTPPort }}"
    ]
  }

  # Reboot into installed system
  provisioner "shell" {
    inline = ["reboot"]
    expect_disconnect = true
  }

  # Wait for system to come back up
  provisioner "shell" {
    pause_before = "60s"
    inline = [
      "echo 'System rebooted successfully!'"
    ]
  }

  # Update system and rebuild
  provisioner "shell" {
    inline = [
      "nixos-rebuild switch --upgrade"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "nix-collect-garbage -d",
      "rm -rf /tmp/*",
      "rm -rf /var/tmp/*",
      "cloud-init clean --logs --seed || true",
      "truncate -s 0 /etc/machine-id",
      "sync"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      nixos_version    = var.nixos_version
      build_time       = timestamp()
      template_name    = local.template_name
      proxmox_node     = var.proxmox_node
      disk_size        = var.vm_disk_size
      cloud_init       = true
      qemu_agent       = true
    }
  }
}

# Usage Notes:
#
# 1. Ensure http/install.sh and http/configuration.nix exist
# 2. Set variables in nixos.auto.pkrvars.hcl
# 3. Run: packer init .
# 4. Run: packer validate .
# 5. Run: packer build .
#
# After building:
# - Template available in Proxmox
# - Clone VMs from template
# - Customize with cloud-init (user-data, network-config)
# - Further configure with NixOS declarative configuration
#
# Note: NixOS uses declarative configuration
# To modify the system, edit /etc/nixos/configuration.nix and run:
# nixos-rebuild switch
