# Windows 11 Golden Image Packer Template for Proxmox VE 9.0
#
# This template creates a Windows 11 golden image with Cloudbase-Init
# for use as a template in Proxmox

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
  # Use static template name for homelab simplicity (no timestamp)
  # This ensures Terraform always finds the template without manual updates
  template_name = var.template_name
}

# Proxmox ISO Builder
source "proxmox-iso" "windows" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username # Token ID format: user@realm!tokenid
  token                    = var.proxmox_token    # Just the token secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM configuration
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = local.template_name
  template_description = "${var.template_description} (built ${formatdate("YYYY-MM-DD", timestamp())})"

  # Boot ISO (Windows 11 installation media)
  boot_iso {
    type             = "sata"
    iso_file         = "local:iso/windows-11.iso" # Upload manually to Proxmox
    iso_storage_pool = "local"
    unmount          = true
  }

  # Additional ISOs (VirtIO drivers)
  additional_iso_files {
    type             = "sata"
    iso_file         = "local:iso/virtio-win.iso" # Upload manually to Proxmox
    iso_storage_pool = "local"
    unmount          = true
  }

  # Autounattend.xml and scripts (delivered via CD)
  additional_iso_files {
    type = "sata"
    cd_files = [
      "${path.root}/http/autounattend.xml",
      "${path.root}/scripts/setup-winrm.ps1"
    ]
    cd_label         = "OEMDRV"
    iso_storage_pool = "local"
    unmount          = true
  }

  # CPU configuration
  cpu_type = var.vm_cpu_type
  cores    = var.vm_cores
  sockets  = 1

  # Memory
  memory = var.vm_memory

  # Machine type (q35 recommended for Windows 11 UEFI)
  machine = "q35"

  # Disk configuration (Proxmox best practices)
  disks {
    type         = "scsi"
    storage_pool = var.vm_disk_storage
    disk_size    = var.vm_disk_size
    format       = "raw"
    cache_mode   = "writeback" # Best performance per Proxmox docs
    io_thread    = true
    discard      = true # Enable TRIM for ZFS storage efficiency
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

  # TPM 2.0 (required for Windows 11)
  tpm_config {
    tpm_storage_pool = var.vm_disk_storage
    tpm_version      = "v2.0"
  }

  # Boot configuration
  boot_wait    = "5s"
  boot_command = ["<spacebar>"]

  # WinRM configuration (instead of SSH)
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = var.winrm_timeout
  winrm_use_ssl  = false
  winrm_insecure = true

  # Template settings
  os = "win11" # Windows 11/Server 2022
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

  # Install VirtIO drivers and QEMU Guest Agent (Proxmox recommended method)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing VirtIO drivers and QEMU Guest Agent...'",
      "# Find VirtIO ISO drive letter",
      "$virtioVolume = Get-Volume | Where-Object { $_.FileSystemLabel -like 'virtio-win*' }",
      "if ($virtioVolume) {",
      "  $virtioPath = $virtioVolume.DriveLetter",
      "} else {",
      "  # Fallback: search for the installer on available drives",
      "  $virtioPath = (Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path \"$($_.Root)virtio-win-gt-x64.msi\" } | Select-Object -First 1).Root.TrimEnd('\\\\')",
      "  if (-not $virtioPath) { $virtioPath = 'E' }",
      "}",
      "Write-Host \"VirtIO drive: $virtioPath\"",
      "",
      "# Install VirtIO Guest Tools (includes drivers + QEMU agent)",
      "$installerPath = \"$${virtioPath}:\\virtio-win-gt-x64.msi\"",
      "if (Test-Path $installerPath) {",
      "  Write-Host \"Installing from: $installerPath\"",
      "  Start-Process msiexec.exe -ArgumentList '/i', $installerPath, '/quiet', '/norestart' -Wait",
      "  Write-Host 'VirtIO Guest Tools installed successfully!'",
      "} else {",
      "  Write-Host \"Warning: VirtIO installer not found at $installerPath\"",
      "  Write-Host 'Trying alternative location...'",
      "  # Try guest-agent only as fallback",
      "  $gaPath = \"$${virtioPath}:\\guest-agent\\qemu-ga-x86_64.msi\"",
      "  if (Test-Path $gaPath) {",
      "    Start-Process msiexec.exe -ArgumentList '/i', $gaPath, '/quiet', '/norestart' -Wait",
      "    Write-Host 'QEMU Guest Agent installed!'",
      "  }",
      "}"
    ]
  }

  # Debloat Windows (remove bloatware, disable telemetry)
  provisioner "powershell" {
    script = "${path.root}/scripts/debloat.ps1"
  }

  # Cleanup
  provisioner "powershell" {
    script = "${path.root}/scripts/cleanup.ps1"
  }

  # Run Sysprep (generalizes the image for cloning)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running Sysprep to generalize the image...'",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /unattend:'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\conf\\Unattend.xml'",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select-Object ImageState; Write-Host \"Image State: $($imageState.ImageState)\"; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Start-Sleep -s 10 } else { break } }",
      "Write-Host 'Sysprep complete!'"
    ]
  }

  # Post-processor: Create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      windows_version = "Windows 11"
      build_time      = timestamp()
      template_name   = local.template_name
      proxmox_node    = var.proxmox_node
      disk_size       = var.vm_disk_size
      cloudbase_init  = true
      qemu_agent      = true
    }
  }
}

# Usage Notes:
#
# 1. Upload Windows 11 ISO to Proxmox storage (local:iso/)
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
# Note: Windows builds take significantly longer than Linux (40-90 minutes)
# Consider enabling Windows Update provisioner for production templates
