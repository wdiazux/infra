# Talos Linux Packer Template for Proxmox VE 9.0
#
# This template creates a Proxmox template from a custom Talos Factory image
# with Longhorn storage support, Proxmox integration, and optional GPU support.
#
# Build process:
# 1. Generate schematic at https://factory.talos.dev/ with extensions:
#    REQUIRED EXTENSIONS:
#    - siderolabs/qemu-guest-agent (REQUIRED for Proxmox VM integration)
#    - siderolabs/iscsi-tools (REQUIRED for Longhorn storage)
#    - siderolabs/util-linux-tools (REQUIRED for Longhorn storage)
#
#    OPTIONAL EXTENSIONS (for GPU workloads):
#    - nonfree-kmod-nvidia-production (optional, for NVIDIA GPU passthrough)
#    - nvidia-container-toolkit-production (optional, for GPU in Kubernetes)
#
# 2. Set your schematic ID and Proxmox credentials in variables or .auto.pkrvars.hcl
# 3. Run: packer init .
# 4. Run: packer build .
#
# CRITICAL: Without iscsi-tools and util-linux-tools, Longhorn will fail to create volumes!

packer {
  required_version = "~> 1.14.3"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3"  # Latest version as of Dec 2025
    }
  }
}

# Local variables for computed values
locals {
  # Construct Talos Factory ISO URL from schematic ID and version
  talos_iso_url = var.talos_iso_url != "" ? var.talos_iso_url : "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.iso"

  # Construct image URL for alternative approach (raw disk image)
  talos_raw_image_url = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.raw.xz"

  # Template name (no timestamp - Terraform expects exact name)
  template_name = var.template_name
}

# Proxmox ISO Builder
# This approach downloads the Talos ISO and creates a VM template
source "proxmox-iso" "talos" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username  # Token ID format: user@realm!tokenid
  token                    = var.proxmox_token     # Just the token secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM configuration
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = local.template_name
  template_description = "${var.template_description} (built ${formatdate("YYYY-MM-DD", timestamp())})"

  # ISO configuration - Download from Talos Factory
  iso_url          = local.talos_iso_url
  iso_checksum     = var.talos_iso_checksum
  iso_storage_pool = "local"
  unmount_iso      = true

  # CPU configuration - MUST be 'host' for Talos v1.0+ and Cilium
  cpu_type = var.vm_cpu_type
  cores    = var.vm_cores
  sockets  = var.vm_sockets

  # Memory configuration
  memory = var.vm_memory

  # Disk configuration
  disks {
    type         = var.vm_disk_type
    storage_pool = var.vm_disk_storage
    disk_size    = var.vm_disk_size
    format       = "raw"
    cache_mode   = "writethrough"
    io_thread    = true
    discard      = true  # Enable TRIM for ZFS storage efficiency
  }

  # Network configuration
  network_adapters {
    model  = var.vm_network_model
    bridge = var.vm_network_bridge
    vlan_tag = var.vm_network_vlan > 0 ? var.vm_network_vlan : null
  }

  # SCSI controller (for virtio-scsi disk)
  scsi_controller = "virtio-scsi-single"

  # QEMU Agent (supported via Talos extension)
  qemu_agent = true

  # EFI/BIOS configuration
  bios = "ovmf"  # UEFI boot
  efi_config {
    efi_storage_pool = var.vm_disk_storage
    efi_type         = "4m"
  }

  # Boot configuration
  boot_wait = var.boot_wait
  boot_command = [
    # Talos boots automatically from ISO
    # No interactive installation - machine config applied via talosctl after deployment
  ]

  # SSH configuration (Talos doesn't use SSH, but Packer requires this)
  # Packer will timeout and continue - this is expected behavior
  ssh_timeout  = var.ssh_timeout
  ssh_username = "root"  # Placeholder, Talos has no SSH

  # Skip SSH connection (Talos doesn't have SSH)
  # Packer will wait for boot, then proceed to create template
  communicator = "none"

  # Cloud-init drive (not used by Talos, but some Proxmox configs expect it)
  # Talos uses machine config via API instead
  cloud_init              = false
  cloud_init_storage_pool = var.vm_disk_storage

  # Template settings
  os = "l26"  # Linux kernel 2.6+

  # Additional Proxmox VM options for Talos
  # These can be overridden in Terraform when deploying from template
  machine = "q35"  # Modern machine type

  # Protect the template from accidental deletion
  # protection = false  # Set to true in production
}

# Build configuration
build {
  name    = "talos-proxmox-template"
  sources = ["source.proxmox-iso.talos"]

  # No provisioning needed - Talos is immutable and configured via machine config API
  # All customization happens after deployment via talosctl

  # Post-processor: Create template documentation
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      talos_version    = var.talos_version
      schematic_id     = var.talos_schematic_id
      build_time       = timestamp()
      proxmox_node     = var.proxmox_node
      template_name    = local.template_name
      disk_size        = var.vm_disk_size
      cpu_type         = var.vm_cpu_type
      nvidia_support   = true
      qemu_agent      = true
    }
  }
}

# Usage Notes:
#
# Prerequisites:
# 1. Generate Talos Factory schematic:
#    - Go to https://factory.talos.dev/
#    - Select platform: "Metal" (for Talos 1.8.0+)
#    - Add REQUIRED extensions:
#      * siderolabs/qemu-guest-agent (REQUIRED - Proxmox integration)
#      * siderolabs/iscsi-tools (REQUIRED - Longhorn storage)
#      * siderolabs/util-linux-tools (REQUIRED - Longhorn storage)
#    - Add OPTIONAL extensions (for GPU workloads):
#      * nonfree-kmod-nvidia-production (optional - NVIDIA GPU drivers)
#      * nvidia-container-toolkit-production (optional - NVIDIA container runtime)
#    - Copy the schematic ID (format: abc123def456...)
#
# 2. Set variables in talos.auto.pkrvars.hcl:
#    proxmox_url         = "https://your-proxmox:8006/api2/json"
  username                 = var.proxmox_username  # Token ID format: user@realm!tokenid
  token                    = var.proxmox_token     # Just the token secret
#    proxmox_username    = "root@pam"
#    proxmox_token       = "PVEAPIToken=user@pam!token=secret"
#    proxmox_node        = "pve"
#    talos_version       = "v1.11.5"
#    talos_schematic_id  = "your-schematic-id-here"  # Must include required extensions!
#
# 3. Initialize Packer:
#    cd packer/talos
#    packer init .
#
# 4. Validate template:
#    packer validate .
#
# 5. Build template:
#    packer build .
#
# After Building:
# - Template will be available in Proxmox with name: talos-1.11.5-nvidia-template-YYYYMMDD-hhmm
# - Use Terraform to deploy VMs from this template
# - Apply Talos machine configuration via talosctl
# - Configure GPU passthrough in Terraform (IOMMU, PCI device passthrough)
# - Bootstrap Kubernetes with: talosctl bootstrap
# - Install Cilium CNI and NVIDIA GPU Operator
#
# Important Notes:
# - CPU type MUST be 'host' for Talos v1.0+ (x86-64-v2 requirement) and Cilium
# - Talos has no SSH access - all config via talosctl and machine config API
# - GPU passthrough configured in Terraform, not in this Packer template
# - Single GPU can only be assigned to ONE VM at a time
# - For single-node cluster: kubectl taint nodes --all node-role.kubernetes.io/control-plane-
# - PRIMARY STORAGE: Longhorn v1.7+ (requires iscsi-tools and util-linux-tools extensions)
# - BACKUP STORAGE: NFS CSI driver for Longhorn backup target (external NAS)
#
# Troubleshooting:
# - If Packer times out waiting for SSH: This is expected - Talos doesn't have SSH
# - Set communicator = "none" to skip SSH wait
# - Verify schematic ID is correct at factory.talos.dev
# - Check Proxmox API token has sufficient permissions (PVEVMAdmin, PVEDatastoreUser)
# - Ensure Proxmox node has internet access to download Talos image
