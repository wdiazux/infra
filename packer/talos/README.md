# Talos Linux Template for Proxmox

Creates a Talos Linux v1.12.1 template for Proxmox VE using the **direct disk image import** approach from Talos Factory.

## Overview

Unlike traditional Linux distributions that use Packer for customization, Talos Linux templates are created by **directly importing pre-built disk images** from Talos Factory. This approach is recommended by Sidero Labs because:

- Talos has **no SSH** - Packer's communicator model doesn't work
- Talos requires **no customization** - it's configured via API after deployment
- Talos Factory provides **pre-built images** with custom extensions
- Direct import is **simpler and faster** than ISO-based workflows

**Why not Packer?** Packer's value is automating OS installation and running provisioners (Ansible, shell scripts). Talos doesn't need either - the Factory image is ready to use, and all configuration happens via `talosctl` after deployment.

## Architecture

```
Talos Factory (factory.talos.dev)
    |
    v
Generate Schematic (select extensions)
    |
    v
import-talos-image.sh (download + import)
    |
    v
Template 9000 (talos-1.12.1-nvidia-template)
    |
    v
Terraform/Manual Deploy (clone template)
    |
    v
talosctl apply-config (configure node)
```

## Prerequisites

### Proxmox Setup

1. **API access** or SSH access to Proxmox host
2. **Storage pool**: ZFS or other storage (default: `tank`)
3. **Network bridge**: For VM networking (default: `vmbr0`)
4. **IOMMU**: Enable in BIOS for GPU passthrough (optional)

### Generate Talos Factory Schematic

1. Visit https://factory.talos.dev/
2. Select **Platform**: Metal (or Nocloud for cloud-init-like behavior)
3. Select **Version**: v1.12.1
4. Add **REQUIRED** extensions:
   - `siderolabs/qemu-guest-agent` - Proxmox integration
   - `siderolabs/iscsi-tools` - Longhorn storage
   - `siderolabs/util-linux-tools` - Longhorn volume operations
5. Add **OPTIONAL** extensions (for GPU workloads):
   - `siderolabs/nonfree-kmod-nvidia-production` - NVIDIA drivers
   - `siderolabs/nvidia-container-toolkit-production` - GPU containers
   - `siderolabs/zfs` - ZFS support
   - `siderolabs/amd-ucode` - AMD microcode updates
6. Click **Generate** and copy the **Schematic ID** (64-character hex string)

**Important**: Without `iscsi-tools` and `util-linux-tools`, Longhorn storage will fail to create volumes.

## Quick Start

### Step 1: Edit Import Script Configuration

Edit `import-talos-image.sh` with your values:

```bash
# Configuration
VM_ID="${1:-9000}"
TALOS_VERSION="v1.12.1"
SCHEMATIC_ID="your-64-char-schematic-id-here"
STORAGE_POOL="tank"
BRIDGE="vmbr0"
```

### Step 2: Run Import Script on Proxmox Host

```bash
# Copy script to Proxmox host
scp import-talos-image.sh root@pve:/tmp/

# SSH to Proxmox and run
ssh root@pve
cd /tmp
chmod +x import-talos-image.sh
./import-talos-image.sh

# Or specify custom VM ID
./import-talos-image.sh 9001
```

### Step 3: Verify Template

```bash
# Check template exists
qm list | grep talos

# View template configuration
qm config 9000
```

## What the Script Does

1. **Downloads** the Talos disk image from Factory (`nocloud-amd64.raw.xz`)
2. **Decompresses** the image
3. **Creates** a VM with proper settings (UEFI, q35, virtio-scsi)
4. **Imports** the disk image to your storage pool
5. **Configures** boot order and resizes disk to 150GB
6. **Converts** the VM to a template

## Using the Template

### Option 1: Terraform (Recommended)

Use the Terraform configuration in `terraform/`:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform will:
- Clone template to create VM
- Generate Talos machine secrets
- Apply machine configuration
- Bootstrap Kubernetes

### Option 2: Manual Deployment

```bash
# Clone template
qm clone 9000 100 --name talos-node --full

# Adjust resources
qm set 100 --memory 32768 --cores 8

# Add GPU passthrough (optional)
qm set 100 --hostpci0 07:00,pcie=1,rombar=0

# Start VM
qm start 100

# Wait for DHCP, then apply Talos config
talosctl gen config homelab https://<vm-ip>:6443
talosctl apply-config --insecure --nodes <vm-ip> --file controlplane.yaml
talosctl bootstrap --nodes <vm-ip>
talosctl kubeconfig --nodes <vm-ip>
```

## Configuration

### Default Settings

| Setting | Value | Notes |
|---------|-------|-------|
| VM ID | 9000 | Configurable via CLI argument |
| CPU | 2 cores, host type | `host` required for Talos |
| Memory | 4096 MB | Increase when cloning |
| Disk | 150 GB | Resized during import |
| BIOS | OVMF (UEFI) | Required for Talos |
| Machine | q35 | Better PCIe support |
| SCSI | virtio-scsi-single | With IO thread |
| Network | virtio on vmbr0 | |
| Tags | talos,kubernetes,nvidia-gpu | |

### Included Extensions (Current Schematic)

- `siderolabs/qemu-guest-agent` - Proxmox integration
- `siderolabs/iscsi-tools` - Longhorn storage
- `siderolabs/util-linux-tools` - Longhorn volumes
- `siderolabs/nonfree-kmod-nvidia-production` - NVIDIA GPU
- `siderolabs/nvidia-container-toolkit-production` - GPU containers
- `siderolabs/zfs` - ZFS support
- `siderolabs/nfs-utils` - NFS client
- `siderolabs/amd-ucode` - AMD microcode
- `siderolabs/thunderbolt` - Thunderbolt support
- `siderolabs/uinput` - Input device support
- `siderolabs/newt` - Network configuration

## Updating Talos Version

1. Generate new schematic at factory.talos.dev with desired version
2. Update `import-talos-image.sh`:
   ```bash
   TALOS_VERSION="v1.13.0"
   SCHEMATIC_ID="new-schematic-id"
   ```
3. Delete old template: `qm destroy 9000 --purge`
4. Run import script: `./import-talos-image.sh`
5. Test before production use

## Troubleshooting

### "VM already exists"

```bash
# Delete existing VM/template
qm destroy 9000 --purge
```

### Download fails

- Verify schematic ID is correct (64-character hex string)
- Ensure Proxmox has internet access
- Test manually: `wget https://factory.talos.dev/image/{schematic}/{version}/nocloud-amd64.raw.xz`

### Template boots to maintenance mode

This is **expected behavior**. Talos waits in maintenance mode until it receives a machine configuration via `talosctl apply-config`.

### QEMU guest agent not responding

Verify your schematic includes `siderolabs/qemu-guest-agent` extension. Regenerate if needed.

### Longhorn volumes fail

Missing extensions. Regenerate schematic with:
- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`

## Files

```
packer/talos/
├── import-talos-image.sh    # Main import script (run on Proxmox)
└── README.md                # This file
```

## Why Not Packer?

Sidero Labs (Talos creators) explicitly recommend against Packer for Talos images:

> "Packer automates old practices instead of eliminating them."

**Packer's value proposition:**
1. Automate OS installation from ISO
2. Run provisioners (Ansible, shell) to customize
3. Create reusable golden image

**Why Talos doesn't need this:**
1. Talos Factory provides pre-built, ready-to-use disk images
2. Talos has no SSH, no shell - can't run provisioners
3. All configuration happens via API (`talosctl`) after deployment
4. The Factory image IS the golden image

**Community approaches that use Packer** work around this by booting a helper OS (Arch Linux), downloading the Talos image, and `dd`-ing it to disk - complex and fragile. Direct import is simpler.

## References

- **Talos Documentation**: https://www.talos.dev/
- **Talos Factory**: https://factory.talos.dev/
- **Talos on Proxmox**: https://www.talos.dev/v1.12/talos-guides/install/virtualized-platforms/proxmox/
- **System Extensions**: https://github.com/siderolabs/extensions
- **Why Not Packer**: https://www.siderolabs.com/blog/linux-artifacts-without-packer-and-bash/

## Version History

- **2026-01-11**: Switched from Packer to direct disk image import (recommended approach)
- **2026-01-10**: Updated to Talos v1.12.1
- **2025-11-23**: Initial Packer template (deprecated)

---

**Last Updated**: 2026-01-11
**Talos Version**: v1.12.1
**Template ID**: 9000
**Build Time**: ~2-5 minutes
