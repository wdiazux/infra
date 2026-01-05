# Debian Cloud Image Packer Template for Proxmox VE 9.0
# PREFERRED METHOD - Uses official Debian cloud image (much faster than ISO)
#
# This template clones Debian cloud image and customizes it for Proxmox

packer {
  required_version = "~> 1.14.3"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3"  # Latest version as of Dec 2025
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Local variables for computed values
locals {
  # Template name (no timestamp - Terraform expects exact name)
  template_name = var.template_name
}

# Proxmox clone builder
source "proxmox-clone" "debian" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username  # Token ID format: user@realm!tokenid
  token                    = var.proxmox_token     # Just the token secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # Clone from uploaded cloud image VM
  clone_vm_id = var.cloud_image_vm_id
  full_clone  = true  # Use full clone instead of linked clone

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
  cloud_init_disk_type    = "scsi"  # Better performance than default "ide"

  # Force IP configuration via cloud-init (DHCP)
  ipconfig {
    ip = "dhcp"
  }

  # DNS configuration
  nameserver = "10.10.2.1"

  # SSH configuration
  ssh_username = "debian"
  ssh_password = var.ssh_password
  ssh_timeout  = "5m"

  # Add handshake attempts
  ssh_handshake_attempts = 50

  # Template settings
  os = "l26"
}

# Build configuration
build {
  name    = "debian-cloud-proxmox-template"
  sources = ["source.proxmox-clone.debian"]

  # Wait for cloud-init to be ready
  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "echo 'Cloud-init ready!'"
    ]
    # Accept exit code 2 (degraded/done) due to Proxmox cloud-init deprecation warnings
    valid_exit_codes = [0, 2]
  }

  # Install baseline packages, configure SSH keys, and cleanup with Ansible
  # This provisioner handles:
  #   1. Package installation (via OS-specific tasks)
  #   2. SSH key configuration (idempotent, from SOPS or direct variable)
  #   3. Template cleanup (machine-id reset, temp files, cloud-init data)
  provisioner "ansible" {
    playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
    user          = "debian"
    use_proxy     = false

    # Use SFTP for file transfer (recommended by Packer, replaces deprecated SCP)
    use_sftp = true

    # Ansible variables and SSH configuration
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "ansible_password=${var.ssh_password}",
      "--extra-vars", "packer_ssh_user=debian",
      "--extra-vars", "ssh_public_key=${var.ssh_public_key}",
      "--ssh-common-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
      "-vv"  # Verbose output for debugging
    ]

    # Use password authentication via sshpass (already in Nix shell.nix)
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_SSH_ARGS=-o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no"
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
# PREREQUISITES:
# - Ansible 2.16+ installed on Packer build machine
# - Ansible collections: ansible-galaxy collection install -r ../../ansible/requirements.yml
#
# SETUP (One-time):
# 1. Run import-cloud-image.sh on Proxmox host to create base VM
#    ./import-cloud-image.sh 9110
#
# BUILD:
# 1. Set variables in debian.auto.pkrvars.hcl
# 2. Run: packer init .
# 3. Run: packer validate .
# 4. Run: packer build .
#
# Build time: 5-10 minutes (much faster than ISO!)
#
# Architecture:
# - Packer + Ansible provisioner: Installs baseline packages in golden image
# - Terraform: Deploys VMs from golden image
# - Ansible baseline role: Instance-specific configuration (hostnames, IPs, secrets)
#
# After building:
# - Template available in Proxmox with baseline packages pre-installed
# - Clone VMs from template
# - Customize with cloud-init (user-data, network-config)
# - Configure with Ansible baseline role for instance-specific settings
