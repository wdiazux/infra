# Arch Linux Golden Image Packer Template for Proxmox VE 9.0
#
# This template creates an Arch Linux golden image with cloud-init
# for use as a template in Proxmox

packer {
  required_version = "~> 1.14.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.2.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Local variables
locals {
  timestamp = formatdate("YYYYMMDD", timestamp())
  template_name = var.template_name
}

# Proxmox ISO Builder
source "proxmox-iso" "arch" {
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
  iso_url          = var.arch_iso_url
  iso_checksum     = var.arch_iso_checksum
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

  # BIOS (UEFI for Arch Linux)
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.vm_disk_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # Boot configuration for Arch Linux
  boot_wait = "10s"
  boot_command = [
    "<enter><wait30>",
    "passwd<enter><wait>",
    "${var.ssh_password}<enter><wait>",
    "${var.ssh_password}<enter><wait>",
    "systemctl start sshd<enter><wait>",
    "ip addr show<enter><wait>"
  ]

  # HTTP server for installation script
  http_directory = "http"
  http_port_min  = 8102
  http_port_max  = 8102

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
  name    = "arch-proxmox-template"
  sources = ["source.proxmox-iso.arch"]

  # Run installation script
  provisioner "shell" {
    script = "${path.root}/http/install.sh"
  }

  # Reboot into installed system
  provisioner "shell" {
    inline = ["reboot"]
    expect_disconnect = true
  }

  # Wait for system to come back up
  provisioner "shell" {
    pause_before = "30s"
    inline = [
      "echo 'System rebooted successfully!'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "pacman -Syu --noconfirm"
    ]
  }

  # Install baseline packages with Ansible
  provisioner "ansible" {
    playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
    user          = "root"
    use_proxy     = false

    # Ansible variables passed to playbook
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python"
    ]
  }

  # Configure cloud-init
  provisioner "shell" {
    inline = [
      "systemctl enable cloud-init",
      "systemctl enable cloud-init-local",
      "systemctl enable cloud-config",
      "systemctl enable cloud-final"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "pacman -Scc --noconfirm",
      "rm -rf /tmp/*",
      "rm -rf /var/tmp/*",
      "cloud-init clean --logs --seed",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",
      "ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sync"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      arch_version     = "rolling"
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
# PREREQUISITES:
# - Ansible 2.16+ installed on Packer build machine
# - Ansible collections: ansible-galaxy collection install -r ../../ansible/requirements.yml
#
# BUILD:
# 1. Ensure http/install.sh exists with installation script
# 2. Set variables in arch.auto.pkrvars.hcl
# 3. Run: packer init .
# 4. Run: packer validate .
# 5. Run: packer build .
#
# Architecture:
# - install.sh: Installs essential packages needed for boot (openssh, qemu-guest-agent, cloud-init)
# - Packer + Ansible provisioner: Installs baseline packages in golden image
# - Terraform: Deploys VMs from golden image
# - Ansible baseline role: Instance-specific configuration (hostnames, IPs, secrets)
#
# After building:
# - Template available in Proxmox with baseline packages pre-installed
# - Clone VMs from template
# - Customize with cloud-init (user-data, network-config)
# - Configure with Ansible baseline role for instance-specific settings
#
# Note: Arch Linux is a rolling release - rebuild template regularly
# to keep up with latest packages and security updates
