# NixOS Cloud Image Packer Template for Proxmox VE 9.0
# PREFERRED METHOD - Uses official NixOS Proxmox image from Hydra (much faster than ISO)
#
# This template clones NixOS cloud image and prepares it as a Proxmox template.
# NixOS is declarative - all configuration is done via /etc/nixos/configuration.nix
# No Ansible provisioning needed - NixOS manages its own packages and configuration.

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

  # SSH configuration
  ssh_username = "nixos"
  ssh_password = var.ssh_password
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

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Cloud-init ready!'"
    ]
    # Accept exit code 2 (degraded/done) due to cloud-init warnings
    valid_exit_codes = [0, 2]
  }

  # NixOS-specific configuration
  # Note: We don't use Ansible for NixOS - all config is declarative via configuration.nix
  provisioner "shell" {
    inline = [
      "echo 'Preparing NixOS template...'",

      # Ensure SSH allows password auth (for Packer/initial access)
      "sudo sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true",

      # Display current NixOS version
      "nixos-version",

      # Update channels
      "sudo nix-channel --update || true",

      "echo 'NixOS template preparation complete!'"
    ]
  }

  # Add SSH public key if provided
  provisioner "shell" {
    inline = [
      "if [ -n '${var.ssh_public_key}' ]; then",
      "  echo 'Adding SSH public key to template...'",
      "  mkdir -p ~/.ssh",
      "  echo '${var.ssh_public_key}' >> ~/.ssh/authorized_keys",
      "  chmod 700 ~/.ssh",
      "  chmod 600 ~/.ssh/authorized_keys",
      "  echo 'SSH public key added successfully'",
      "else",
      "  echo 'No SSH public key provided, skipping...'",
      "fi"
    ]
  }

  # Clean up for template
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up for template...'",

      # Clean nix store (remove old generations)
      "sudo nix-collect-garbage -d || true",

      # Clean temporary files
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",

      # Clean cloud-init for re-initialization on clone
      "sudo cloud-init clean --logs --seed || true",

      # Reset machine-id for unique ID on clone
      "sudo truncate -s 0 /etc/machine-id",

      # Clear shell history
      "history -c || true",
      "rm -f ~/.bash_history",

      # Sync filesystem
      "sync",

      "echo 'Template cleanup complete!'"
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
      note          = "NixOS is declarative - configure via /etc/nixos/configuration.nix"
    }
  }
}

# See README.md for usage instructions
