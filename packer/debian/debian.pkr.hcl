# Debian Cloud Image Packer Template for Proxmox VE 9.0
# PREFERRED METHOD - Uses official Debian cloud image (much faster than ISO)
#
# This template clones Debian cloud image and customizes it for Proxmox

packer {
  required_version = "~> 1.14.3"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3" # Latest version as of Dec 2025
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
  cloud_init_disk_type    = "scsi" # Better performance than default "ide"

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

  # Console configuration
  # Use standard VGA for console access (not serial)
  # This prevents "starting serial terminal" message in console
  vga {
    type = "std"
  }

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
    timeout          = "5m"
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
    timeout       = "15m"

    # Use SFTP for file transfer (recommended by Packer, replaces deprecated SCP)
    use_sftp = true

    # Ansible variables and SSH configuration
    # Verbosity controlled by debug_mode variable
    extra_arguments = var.debug_mode ? [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "ansible_password=${var.ssh_password}",
      "--extra-vars", "packer_ssh_user=debian",
      "--extra-vars", "ssh_public_key=${var.ssh_public_key}",
      "--ssh-common-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30",
      "-vv"
    ] : [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "ansible_password=${var.ssh_password}",
      "--extra-vars", "packer_ssh_user=debian",
      "--extra-vars", "ssh_public_key=${var.ssh_public_key}",
      "--ssh-common-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30"
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
      debian_version = var.debian_version
      build_time     = timestamp()
      template_name  = local.template_name
      proxmox_node   = var.proxmox_node
      cloud_image    = true
      cloud_init     = true
      qemu_agent     = true
    }
  }
}

# See README.md for usage instructions
