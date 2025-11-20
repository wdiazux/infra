# Windows Server 2022 Golden Image Packer Template for Proxmox VE 9.0
#
# This template creates a Windows Server 2022 golden image with Cloudbase-Init
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
source "proxmox-iso" "windows" {
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
  iso_file         = "local:iso/windows-server-2022.iso"  # Upload manually to Proxmox
  iso_storage_pool = "local"
  unmount_iso      = true

  # Additional ISOs (VirtIO drivers)
  additional_iso_files {
    device           = "ide3"
    iso_file         = "local:iso/virtio-win.iso"  # Upload manually to Proxmox
    iso_storage_pool = "local"
    unmount_iso      = true
  }

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

  # BIOS (UEFI for Windows)
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.vm_disk_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # Boot configuration
  boot_wait = "5s"
  boot_command = ["<spacebar>"]

  # HTTP server for autounattend.xml and scripts
  http_directory = "http"
  http_port_min  = 8104
  http_port_max  = 8104

  # WinRM configuration (instead of SSH)
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = var.winrm_timeout
  winrm_use_ssl  = false
  winrm_insecure = true

  # Template settings
  os = "win11"  # Windows 11/Server 2022
}

# Build configuration
build {
  name    = "windows-proxmox-template"
  sources = ["source.proxmox-iso.windows"]

  # Wait for WinRM to be ready
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
  }

  # Install Windows updates (optional, can take 30+ minutes)
  # provisioner "windows-update" {
  #   search_criteria = "IsInstalled=0"
  #   filters = [
  #     "exclude:$_.Title -like '*Preview*'",
  #     "include:$true"
  #   ]
  #   update_limit = 25
  # }

  # Install Cloudbase-Init
  provisioner "powershell" {
    script = "${path.root}/scripts/install-cloudbase-init.ps1"
  }

  # Install baseline packages with Ansible
  provisioner "ansible" {
    playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
    user          = "Administrator"
    use_proxy     = false

    # Ansible variables for Windows/WinRM
    extra_arguments = [
      "--connection", "winrm",
      "--extra-vars", "ansible_connection=winrm ansible_winrm_server_cert_validation=ignore ansible_shell_type=powershell"
    ]
  }

  # Cleanup
  provisioner "powershell" {
    script = "${path.root}/scripts/cleanup.ps1"
  }

  # Run Sysprep (generalizes the image)
  provisioner "powershell" {
    inline = [
      "& 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\conf\\Unattend.xml'",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select-Object ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10 } else { break } }"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      windows_version  = "Server 2022"
      build_time       = timestamp()
      template_name    = local.template_name
      proxmox_node     = var.proxmox_node
      disk_size        = var.vm_disk_size
      cloudbase_init   = true
      qemu_agent       = true
    }
  }
}

# Usage Notes:
#
# 1. Upload Windows Server 2022 ISO to Proxmox storage (local:iso/)
# 2. Upload VirtIO drivers ISO to Proxmox storage (local:iso/)
# 3. Create autounattend.xml in http/ directory
# 4. Set variables in windows.auto.pkrvars.hcl
# 5. Run: packer init .
# 6. Run: packer validate .
# 7. Run: packer build .
#
# After building:
# - Template available in Proxmox
# - Clone VMs from template
# - Customize with Cloudbase-Init (similar to cloud-init)
# - Configure with PowerShell DSC or Ansible for baseline setup
#
# Note: Windows builds take significantly longer than Linux (30-90 minutes)
# Consider enabling Windows Update provisioner for production templates
