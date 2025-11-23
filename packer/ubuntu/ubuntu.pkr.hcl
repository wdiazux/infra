# Ubuntu Cloud Image Packer Template for Proxmox VE 9.0
# PREFERRED METHOD - Uses official Ubuntu cloud image (much faster than ISO)
#
# This template downloads Ubuntu cloud image and customizes it for Proxmox

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
  # Template name (no timestamp - Terraform expects exact name)
  template_name = var.template_name

  # Cloud image URL and checksum
  cloud_image_url = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  cloud_image_checksum = "file:https://cloud-images.ubuntu.com/releases/24.04/release/SHA256SUMS"
}

# Download and import cloud image
source "proxmox-clone" "ubuntu" {
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
  ssh_username = "ubuntu"
  ssh_password = var.ssh_password
  ssh_timeout  = "10m"

  # Template settings
  os = "l26"
}

# Build configuration
build {
  name    = "ubuntu-cloud-proxmox-template"
  sources = ["source.proxmox-clone.ubuntu"]

  # Wait for cloud-init to be ready
  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "echo 'Cloud-init ready!'"
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
# 1. Download Ubuntu cloud image:
#    wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
#
# 2. Import to Proxmox (run on Proxmox host):
#    qm create 9000 --name ubuntu-cloud-base --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
#    qm importdisk 9000 ubuntu-24.04-server-cloudimg-amd64.img local-zfs
#    qm set 9000 --scsihw virtio-scsi-single --scsi0 local-zfs:vm-9000-disk-0
#    qm set 9000 --boot order=scsi0
#    qm set 9000 --ide2 local-zfs:cloudinit
#    qm set 9000 --serial0 socket --vga serial0
#    qm set 9000 --agent enabled=1
#    qm set 9000 --ciuser ubuntu --cipassword ubuntu
#
# 3. Set cloud_image_vm_id = 9000 in variables
#
# BUILD:
# 1. Set variables in ubuntu.auto.pkrvars.hcl
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
