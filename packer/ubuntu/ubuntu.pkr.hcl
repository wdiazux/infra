# Ubuntu Golden Image Packer Template for Proxmox VE 9.0
#
# This template creates an Ubuntu 24.04 LTS golden image with cloud-init
# for use as a template in Proxmox

packer {
  required_version = "~> 1.14.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.2"  # Fixed: CPU bug in 1.2.0, use 1.2.2+
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Local variables for computed values
locals {
  timestamp = formatdate("YYYYMMDD", timestamp())
  # Use static template name for homelab simplicity (no timestamp)
  # This ensures Terraform always finds the template without manual updates
  template_name = var.template_name
}

# Proxmox ISO Builder
source "proxmox-iso" "ubuntu" {
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
  iso_url          = var.ubuntu_iso_url
  iso_checksum     = var.ubuntu_iso_checksum
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

  # BIOS (UEFI for Ubuntu 24.04)
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.vm_disk_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # Boot configuration for Ubuntu autoinstall
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  # HTTP server for autoinstall files
  http_directory = "http"
  http_port_min  = 8101
  http_port_max  = 8101

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
  name    = "ubuntu-proxmox-template"
  sources = ["source.proxmox-iso.ubuntu"]

  # Wait for cloud-init to be ready
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "echo 'Cloud-init finished!'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get dist-upgrade -y"
    ]
  }

  # Install essential packages (needed for boot and provisioning)
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y",
      "  qemu-guest-agent",
      "  cloud-init",
      "  cloud-initramfs-growroot",
      "  sudo",
      "  openssh-server"
    ]
  }

  # Install baseline packages with Ansible
  provisioner "ansible" {
    playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
    user          = "ubuntu"
    use_proxy     = false

    # Ansible variables passed to playbook
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3"
    ]
  }

  # Configure QEMU guest agent
  provisioner "shell" {
    inline = [
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent"
    ]
  }

  # Configure cloud-init
  provisioner "shell" {
    inline = [
      "sudo systemctl enable cloud-init",
      "sudo systemctl enable cloud-init-local",
      "sudo systemctl enable cloud-config",
      "sudo systemctl enable cloud-final"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo cloud-init clean --logs --seed",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo sync"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      ubuntu_version   = var.ubuntu_version
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
# 1. Create autoinstall files in http/ directory (user-data, meta-data)
# 2. Set variables in ubuntu.auto.pkrvars.hcl
# 3. Run: packer init .
# 4. Run: packer validate .
# 5. Run: packer build .
#
# Architecture:
# - ISO install: Installs essential packages (qemu-guest-agent, cloud-init, openssh-server)
# - Packer + Ansible provisioner: Installs baseline packages in golden image
# - Terraform: Deploys VMs from golden image
# - Ansible baseline role: Instance-specific configuration (hostnames, IPs, secrets)
#
# After building:
# - Template available in Proxmox with baseline packages pre-installed
# - Clone VMs from template
# - Customize with cloud-init (user-data, network-config)
# - Configure with Ansible baseline role for instance-specific settings
# - Configure with Ansible for baseline setup
#
# Cloud-init customization example:
# - Set hostname, users, SSH keys via cloud-init
# - Network configuration via cloud-init
# - Run baseline Ansible playbook after first boot
