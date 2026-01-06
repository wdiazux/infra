# NixOS Cloud Image Packer Template for Proxmox VE 9.0
# PREFERRED METHOD - Uses official NixOS Proxmox image from Hydra (much faster than ISO)
#
# This template clones NixOS cloud image and applies custom configuration.nix
# to create a golden image with packages and settings baked in.

packer {
  required_version = "~> 1.14.3"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3" # Latest version as of Dec 2025
    }
  }
}

# Local variables for computed values
locals {
  # Template name (no timestamp - Terraform expects exact name)
  template_name = var.template_name
}

# Proxmox clone builder
source "proxmox-clone" "nixos" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username # Token ID format: user@realm!tokenid
  token                    = var.proxmox_token    # Just the token secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # Clone from uploaded cloud image VM
  clone_vm_id = var.cloud_image_vm_id
  full_clone  = true # Use full clone instead of linked clone

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

  # Disk configuration
  scsi_controller = "virtio-scsi-single"

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
  cloud_init_disk_type    = "scsi"

  # Force IP configuration via cloud-init (DHCP)
  ipconfig {
    ip = "dhcp"
  }

  # DNS configuration
  nameserver = "10.10.2.1"

  # SSH configuration - use root (no password required)
  ssh_username = "root"
  ssh_password = ""
  ssh_timeout  = "5m"

  # Add handshake attempts
  ssh_handshake_attempts = 50

  # Console configuration
  vga {
    type = "std"
  }

  # Template settings
  os = "l26" # Linux 2.6+ kernel
}

# Build configuration
build {
  name    = "nixos-proxmox-template"
  sources = ["source.proxmox-clone.nixos"]

  # Display NixOS version
  provisioner "shell" {
    inline = [
      "echo '=== NixOS Golden Image Build ==='",
      "nixos-version",
      "uname -a"
    ]
  }

  # Upload custom configuration files
  provisioner "file" {
    source      = "${path.root}/config/configuration.nix"
    destination = "/etc/nixos/configuration.nix"
  }

  provisioner "file" {
    source      = "${path.root}/config/hardware-configuration.nix"
    destination = "/etc/nixos/hardware-configuration.nix"
  }

  # Apply NixOS configuration
  provisioner "shell" {
    inline = [
      "echo '==> Applying NixOS configuration...'",
      "nixos-rebuild switch",
      "echo '==> NixOS configuration applied successfully!'",

      "echo '==> Running garbage collection...'",
      "nix-collect-garbage -d",
      "echo '==> Garbage collection complete!'",

      "echo '==> Resetting cloud-init for fresh run on clone...'",
      "/run/current-system/sw/bin/cloud-init clean --logs || rm -rf /var/lib/cloud/{instance,instances,data,sem}/*",
      "truncate -s 0 /etc/hostname",
      "truncate -s 0 /etc/machine-id",
      "echo '==> Cloud-init reset complete!'"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      nixos_version = var.nixos_version
      build_time    = timestamp()
      template_name = local.template_name
      proxmox_node  = var.proxmox_node
      cloud_init    = true
      qemu_agent    = true
      custom_config = true
      note          = "Golden image with custom configuration.nix applied"
    }
  }
}

# See README.md for usage instructions
