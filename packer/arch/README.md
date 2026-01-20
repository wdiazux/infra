# Arch Linux Golden Image Packer Template

This directory contains Packer configuration to build an Arch Linux golden image for Proxmox VE 9.0 using the **official Arch Linux cloud image** (PREFERRED METHOD).

## Overview

Creates a production-ready Arch Linux template with:
- **Arch Linux** - Latest rolling release (official cloud image)
- **Cloud-init** - Pre-configured for automated VM customization
- **QEMU Guest Agent** - Pre-installed for Proxmox integration
- **SSH Server** - Pre-configured and enabled
- **Baseline packages** - Installed via Ansible provisioning
- **Fast build** - 5-10 minutes (vs 20-30 min with ISO approach)

## Why Cloud Image?

✅ **Much faster** - No full OS installation
✅ **Official base** - Maintained by Arch Linux team
✅ **Pre-configured** - Cloud-init and qemu-guest-agent already installed
✅ **Consistent** - Same workflow as Ubuntu/Debian templates
✅ **No boot issues** - Avoids BIOS/boot order complexity

## Prerequisites

### Tools Required

All tools are available in the Nix development environment:

```bash
# Enter Nix shell (from project root)
nix-shell

# Verify tools
packer --version  # 1.14.3+
ansible --version # 2.17.0+
```

### Proxmox Setup

1. **API Token**: Create Proxmox API token with appropriate permissions
2. **Storage**: ZFS pool or other storage for VM disks (default: `tank`)
3. **Network**: Bridge for VM networking (default: `vmbr0`)

### libguestfs-tools (On Proxmox Host)

The import script uses `virt-customize` to configure the cloud image before importing:

```bash
# On Proxmox host
apt-get update && apt-get install -y libguestfs-tools
```

## Quick Start

### Step 1: Import Official Cloud Image (One-Time Setup)

This creates a base VM (ID 9300) that Packer will clone.

**Option A: Execute on Proxmox host directly**

```bash
# SSH to Proxmox host
ssh root@pve.home-infra.net

# Run import script
cd /tmp
wget https://raw.githubusercontent.com/your-repo/infra/main/packer/arch/import-cloud-image.sh
chmod +x import-cloud-image.sh
./import-cloud-image.sh
```

**Option B: Execute remotely from workstation**

```bash
# From your workstation (in project directory)
cd packer/arch

# Copy script to Proxmox
scp import-cloud-image.sh root@pve.home-infra.net:/tmp/

# Execute remotely
ssh root@pve.home-infra.net 'cd /tmp && chmod +x import-cloud-image.sh && ./import-cloud-image.sh'
```

**What this does:**
1. Downloads official Arch cloud image (558MB, ~1-2 minutes)
2. Verifies SHA256 checksum
3. Customizes image with `virt-customize` (SSH password authentication)
4. Imports to Proxmox as VM 9300 (`arch-cloud-base`)
5. Configures cloud-init, networking, and resizes disk to 20GB

**Output:**
```
==> ✅ Arch Linux cloud image imported successfully!

Base VM created: 9300 (arch-cloud-base)

Next steps:
1. Start VM to test: qm start 9300
2. Find IP: qm guest cmd 9300 network-get-interfaces
3. SSH: ssh arch@<ip> (password: arch)
4. Stop VM: qm stop 9300
5. Use Packer to customize and create template
```

### Step 2: Configure Packer Variables

```bash
cd packer/arch
cp arch.auto.pkrvars.hcl.example arch.auto.pkrvars.hcl
```

Edit `arch.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url  = "https://pve.home-infra.net:8006/api2/json"
proxmox_username = "packer@pve!packer-token"  # Token ID
proxmox_token = "your-token-secret-here"
proxmox_node = "pve"

# Cloud image base VM (created by import-cloud-image.sh)
cloud_image_vm_id = 9300

# Template configuration
vm_id            = 9302  # Template will be created with this ID
template_name    = "arch-cloud-template"
template_version = "1.0.0"  # Results in: arch-cloud-template-v1.0.0

# Storage
vm_disk_storage = "tank"

# SSH public key (optional, will be added to template)
ssh_public_key = "ssh-rsa AAAAB3Nza... your-key-here"
```

### Step 3: Build Golden Template

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build time**: 5-10 minutes

**What happens:**
1. Packer clones base VM 9300 → creates build VM 9302
2. Starts VM and waits for cloud-init to complete
3. Runs Ansible playbook to install baseline packages
4. Configures SSH keys and system settings
5. Cleans up (machine-id reset, temp files, cloud-init data)
6. Converts to Proxmox template

### Step 4: Verify Template

Check in Proxmox UI or CLI:

```bash
# List templates
ssh root@pve.home-infra.net 'qm list | grep template'

# View template config
ssh root@pve.home-infra.net 'qm config 9302'
```

## Using the Template

### Option 1: Clone Manually in Proxmox UI

1. Navigate to template in Proxmox UI
2. Right-click → Clone
3. Choose full clone (not linked)
4. Set VM ID, name, and resources
5. Configure cloud-init settings (user, password, SSH keys)
6. Start VM

### Option 2: Clone via CLI

```bash
# Clone template
qm clone 9302 201 --name arch-vm-01 --full

# Configure cloud-init
qm set 201 --ciuser wdiaz --cipassword yourpassword
qm set 201 --sshkeys ~/.ssh/id_ed25519.pub
qm set 201 --ipconfig0 ip=dhcp

# Start VM
qm start 201

# Get IP address
qm guest cmd 201 network-get-interfaces
```

### Option 3: Deploy with Terraform

Use the Terraform Proxmox provider to deploy VMs from this template. See `terraform/` directory for examples.

## Customization

### Modifying Packages

Edit the Ansible playbook to add/remove packages:

```bash
# Arch-specific package list
vim ../../ansible/packer-provisioning/tasks/archlinux_packages.yml
```

Then rebuild the template:

```bash
packer build .
```

### Modifying Cloud Image Import

Edit `import-cloud-image.sh` to change:
- VM ID (default: 9300)
- Disk size (default: 20GB)
- Memory/CPU allocation
- Network configuration
- SSH configuration

## Troubleshooting

### Base VM not found

```
Error: clone_vm_id 9300 does not exist
```

**Solution**: Run `import-cloud-image.sh` first (Step 1)

### Cloud-init timeout

```
Error: cloud-init status --wait timed out
```

**Solution**:
1. Check VM network connectivity (DHCP enabled?)
2. Verify cloud-init is enabled in base image
3. Start base VM manually and check logs: `journalctl -u cloud-init`

### SSH connection refused

**Solution**:
1. Verify SSH password authentication is enabled
2. Check firewall rules on Proxmox
3. Verify cloud-init completed: `cloud-init status`

### Ansible fails to connect

```
Error: unreachable: Failed to connect to the host via ssh
```

**Solution**:
1. Verify `ssh_password` in `arch.auto.pkrvars.hcl`
2. Check VM is running and accessible
3. Test manual SSH: `ssh arch@<vm-ip>`

## Files

```
packer/arch/
├── arch.pkr.hcl                  # Main Packer template (proxmox-clone)
├── variables.pkr.hcl             # Variable definitions
├── arch.auto.pkrvars.hcl         # Your environment config
├── import-cloud-image.sh         # Import official cloud image script
└── README.md                     # This file
```

## Build Process Details

### Phase 1: Import Cloud Image (One-Time)

```
import-cloud-image.sh
├── Download official Arch cloud image (558MB)
├── Verify SHA256 checksum
├── Customize with virt-customize
│   ├── Enable SSH password authentication
│   └── Disable root login (security)
├── Create Proxmox VM (ID 9300)
├── Import disk to storage pool
├── Configure cloud-init drive
├── Resize disk to 20GB
└── Configure VM settings (CPU, memory, network)
```

### Phase 2: Packer Build

```
packer build
├── Clone base VM 9300 → build VM 9302
├── Start VM and wait for cloud-init
├── Ansible provisioning
│   ├── Update system (pacman -Syu)
│   ├── Install baseline packages
│   ├── Configure SSH keys
│   └── Template cleanup
├── Shutdown VM
└── Convert to template
```

## Network Configuration

**Default settings:**
- **Bridge**: vmbr0
- **IP**: DHCP (configurable via cloud-init)
- **DNS**: 10.10.2.1 (gateway)

**VM ID allocation:**
- **9300**: Base cloud image (import-cloud-image.sh)
- **9302**: Golden template (packer build)
- **201+**: Cloned VMs (your VMs)

## References

- **Official Arch Cloud Images**: https://mirror.pkgbuild.com/images/
- **Arch Linux on VPS**: https://wiki.archlinux.org/title/Arch_Linux_on_a_VPS
- **Cloud-init Documentation**: https://cloudinit.readthedocs.io/
- **Proxmox Cloud-Init**: https://pve.proxmox.com/wiki/Cloud-Init_Support
- **Packer Proxmox Builder**: https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox

## Comparison: Cloud Image vs ISO

| Aspect | Cloud Image (Current) | ISO (Old Approach) |
|--------|----------------------|-------------------|
| **Build Time** | 5-10 minutes | 20-30 minutes |
| **Approach** | Clone and customize | Full installation |
| **Boot Issues** | None | BIOS/boot order complexity |
| **Cloud-init** | Pre-configured | Manual setup |
| **qemu-guest-agent** | Pre-installed | Manual installation |
| **Base Image** | Official Arch team | Manual installation |
| **Maintenance** | Updates from Arch team | Manual updates |

## Version History

- **2026-01-05**: Converted to official cloud image approach (proxmox-clone)
- **2025-12-15**: Initial ISO-based approach

---

**Last Updated**: 2026-01-05
**Approach**: Official Cloud Image (PREFERRED)
**Build Time**: ~5-10 minutes
**Base VM ID**: 9300
**Template ID**: 9302
