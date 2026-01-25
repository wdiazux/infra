# Ubuntu Cloud Image Packer Template

Builds a customized Ubuntu 24.04 LTS template for Proxmox VE 9.0 using official Ubuntu cloud images.

## Overview

This template uses the **cloud image approach** (preferred method) which is much faster than building from ISO:
- **Build time**: 5-10 minutes (vs 20-30 minutes with ISO)
- **Method**: Clone official cloud image → Customize with Ansible → Convert to template

## Architecture

```
Ubuntu Cloud Image (download)
    ↓
Base VM 9100 (import-cloud-image.sh)
    ↓
Packer Build (customize with Ansible)
    ↓
Template 9102 (ready for cloning)
    ↓
Production VMs (clone from template)
```

### Component Responsibilities

- **Packer + Ansible provisioner**: Installs baseline packages in golden image
- **Terraform**: Deploys VMs from golden image
- **Ansible baseline role**: Instance-specific configuration (hostnames, IPs, secrets)

## Prerequisites

- Ansible 2.17.0+ installed on Packer build machine
- Ansible collections: `ansible-galaxy collection install -r ../../ansible/requirements.yml`
- Proxmox VE 9.0
- Storage pool: `tank` (or update variables)

## Quick Start

### 1. Create Base VM (One-time Setup)

Run the import script on the Proxmox host:

```bash
# Copy script to Proxmox host
scp import-cloud-image.sh root@pve.home-infra.net:/tmp/

# SSH to Proxmox and run
ssh root@pve.home-infra.net
cd /tmp
./import-cloud-image.sh 9100
```

This will:
- Download Ubuntu 24.04 cloud image
- Verify checksum
- Install and enable qemu-guest-agent
- Configure SSH for password authentication
- Create base VM with ID 9100

### 2. Build Template

Set variables in `ubuntu.auto.pkrvars.hcl`, then build:

```bash
packer init .
packer validate .
packer build .
```

### 3. Use Template

The template is now available in Proxmox:
- **Template ID**: 9102
- **Template Name**: ubuntu-2404-cloud-template-v1.0.0

Clone VMs from the template and customize with cloud-init.

## Configuration

### VM IDs

- **9100**: Base VM (ubuntu-2404-cloud-base)
- **9102**: Template (ubuntu-2404-cloud-template-v1.0.0)

### Default Settings

- **Cores**: 2
- **Memory**: 2048 MB
- **Disk**: 20GB (resized from 2GB cloud image)
- **Network**: vmbr0 (DHCP)
- **Storage**: tank
- **SSH User**: ubuntu
- **SSH Password**: ubuntu (default, change in production)

### Customization

Edit `ubuntu.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url  = "https://pve.home-infra.net:8006/api2/json"
proxmox_node = "pve"

# Ubuntu version
ubuntu_version = "24.04"

# Base VM ID (from import-cloud-image.sh)
cloud_image_vm_id = 9100

# Template configuration
template_name    = "ubuntu-2404-cloud-template"
template_version = "1.0.0"  # Results in: ubuntu-2404-cloud-template-v1.0.0
vm_id            = 9102

# Hardware
vm_cores        = 2
vm_memory       = 2048
vm_disk_storage = "tank"

# SSH public key (optional)
ssh_public_key = ""
```

## Ansible Provisioning

The Packer build runs: `ansible/packer_provisioning/install_baseline_packages.yml`

**Installed packages**:
- build-essential, git, vim, curl, wget
- net-tools, dnsutils, htop, tree
- python3-pip, python3-dev
- zip, unzip, rsync, tmux

**Post-install tasks**:
- SSH key configuration
- Template cleanup (machine-id reset, temp files, cloud-init data)

## Deployment Workflow

After building the template:

1. **Clone VM from template** (via Proxmox UI or Terraform)
2. **Customize with cloud-init**:
   - Set hostname
   - Configure network (static IP or DHCP)
   - Add SSH keys
   - Set passwords
3. **Run Ansible baseline role** for instance-specific configuration
4. **Deploy applications** with Ansible or other tools

## Maintenance

### Rebuilding Template

To update the template with latest packages:

```bash
# Option 1: If base VM 9100 exists (fast)
packer build .

# Option 2: If base VM deleted (slower)
# 1. Re-run import-cloud-image.sh on Proxmox host
# 2. Then run packer build
```

### Cleanup Base VM (Optional)

After successful template creation, you can delete the base VM to save storage:

```bash
ssh root@pve.home-infra.net "qm destroy 9100 --purge"
```

**Note**: Keeping the base VM allows for faster template rebuilds.

## Troubleshooting

### Cloud-init not ready

If Packer fails waiting for cloud-init:
- Check base VM 9100 boots correctly
- Verify qemu-guest-agent is running
- Check network connectivity (DHCP working)

### SSH authentication fails

- Default password is `ubuntu`
- Password authentication is enabled in import script
- Check `ssh_password` in variables

### Package installation fails

- APT cache may be stale: rebuild base VM
- Network issues: check Proxmox network configuration
- Repository mirrors: check `/etc/apt/sources.list`

## Files

- `ubuntu.pkr.hcl` - Main Packer template
- `variables.pkr.hcl` - Variable definitions
- `ubuntu.auto.pkrvars.hcl` - Variable values (customize this)
- `import-cloud-image.sh` - Base VM creation script (run on Proxmox host)
- `README.md` - This file

## Related Documentation

- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [Packer Proxmox Clone Builder](https://www.packer.io/plugins/builders/proxmox/clone)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
