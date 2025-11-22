# Debian Cloud Image Packer Template for Proxmox VE 9.0
# PREFERRED METHOD - Uses official Debian cloud image (much faster than ISO)
#
# This template clones Debian cloud image and customizes it for Proxmox

packer {
  required_version = "~> 1.14.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.2"  # Fixed: CPU bug in 1.2.0, use 1.2.2+
    }
  }
}

# Local variables
locals {
  timestamp = formatdate("YYYYMMDD", timestamp())
  template_name = "${var.template_name}-${local.timestamp}"
}

# Proxmox clone builder
source "proxmox-clone" "debian-cloud" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # Clone from uploaded cloud image VM
  clone_vm_id = var.cloud_image_vm_id

  # VM configuration
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = local.template_name
  template_description = "${var.template_description} (built ${formatdate("YYYY-MM-DD", timestamp())})"

  # CPU configuration
  cores   = var.vm_cores
  sockets = 1

  # Memory
  memory = var.vm_memory

  # Network configuration
  network_adapters {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }

  # QEMU Agent (already in cloud image)
  qemu_agent = true

  # Cloud-init (already in cloud image)
  cloud_init              = true
  cloud_init_storage_pool = var.vm_disk_storage

  # SSH configuration
  ssh_username = "debian"
  ssh_password = var.ssh_password
  ssh_timeout  = "10m"

  # Template settings
  os = "l26"
}

# Build configuration
build {
  name    = "debian-cloud-proxmox-template"
  sources = ["source.proxmox-clone.debian-cloud"]

  # Wait for cloud-init to be ready
  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "echo 'Cloud-init ready!'"
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

  # Install additional packages (cloud-init and qemu-guest-agent already installed)
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y",
      "  vim",
      "  curl",
      "  wget",
      "  git",
      "  htop",
      "  net-tools",
      "  dnsutils",
      "  python3",
      "  python3-pip"
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
      debian_version   = var.debian_version
      build_time       = timestamp()
      template_name    = local.template_name
      proxmox_node     = var.proxmox_node
      cloud_image      = true
      cloud_init       = true
      qemu_agent       = true
    }
  }
}

# Usage Notes:
#
# SETUP (One-time):
# 1. Run import-cloud-image.sh on Proxmox host to create base VM
#    ./import-cloud-image.sh 9110
#
# BUILD:
# 1. Set variables in debian-cloud.auto.pkrvars.hcl
# 2. Run: packer init .
# 3. Run: packer validate .
# 4. Run: packer build .
#
# Build time: 5-10 minutes (much faster than ISO!)
#
# After building:
# - Template available in Proxmox
# - Clone VMs from template
# - Customize with cloud-init (user-data, network-config)
# - Configure with Ansible for baseline setup
