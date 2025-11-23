# Debian Cloud Image Packer Template (PREFERRED METHOD)

This directory contains configuration for building Debian 12 (Bookworm) golden images from **official Debian cloud images**. This is the **preferred and recommended approach** for creating Debian templates in Proxmox.

## Why Cloud Images? (Preferred Method)

### ✅ Advantages over ISO Build
- **⚡ Much faster**: 5-10 minutes vs 20-30 minutes
- **🎯 Simpler**: No preseed complexity
- **✅ More reliable**: Official pre-built images
- **🔄 Industry standard**: How production environments work
- **📦 Pre-configured**: cloud-init and qemu-guest-agent already installed
- **🔒 Security**: Regular official updates, minimal attack surface

### 📊 Comparison

| Method | Build Time | Complexity | Reliability | Use Case |
|--------|------------|------------|-------------|----------|
| **Cloud Image** | 5-10 min | Low | High | **Production (Recommended)** |
| ISO Build | 20-30 min | High | Medium | Custom partitioning, learning |

### Note About ISO Templates

**ISO-based Debian templates have been removed** in favor of this cloud image approach. The cloud image method is faster, simpler, and follows industry best practices.

If you absolutely need custom disk partitioning or non-standard filesystem layouts, you can create a custom ISO template, but for 95% of use cases, **cloud images are the better choice**.

## Prerequisites

### Tools Required

```bash
# Packer 1.14.2+
packer --version
```

### Proxmox Setup

Access to Proxmox VE 9.0 host with:
- API token or password authentication
- Storage pool (e.g., local-zfs)
- Network bridge (e.g., vmbr0)

## Quick Start

### Step 1: Import Cloud Image (One-Time Setup)

Run the import script **on your Proxmox host**:

```bash
# Copy script to Proxmox host
scp import-cloud-image.sh root@proxmox:/root/

# SSH to Proxmox
ssh root@proxmox

# Run import script (creates base VM with ID 9110)
chmod +x import-cloud-image.sh
./import-cloud-image.sh

# Or specify custom VM ID
./import-cloud-image.sh 9110
```

This creates a base VM (`debian-12-cloud-base`) that Packer will clone and customize.

**What the script does:**
1. Downloads official Debian 12 cloud image
2. Verifies SHA512 checksum
3. Imports to Proxmox as VM disk
4. Configures VM with cloud-init
5. Enables QEMU guest agent
6. Sets up default user (debian/debian)

### Step 2: Configure Packer

```bash
cd packer/debian

# Copy example configuration
cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl

# Edit configuration
vim debian.auto.pkrvars.hcl
```

Key settings:
```hcl
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

cloud_image_vm_id = 9110  # Base VM created by import script
vm_id             = 9112  # Template VM ID (must be different)

vm_disk_storage = "local-zfs"
```

### Step 3: Build Template

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template (5-10 minutes)
packer build .
```

### Step 4: Verify Template

Check Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `debian-12-cloud-template-YYYYMMDD-hhmm`

## Using the Template

### Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "debian" {
  name      = "debian-prod-01"
  node_name = "pve"

  clone {
    vm_id = 9112  # Cloud image template
    full  = true
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
  }

  # Cloud-init configuration
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id

    ip_config {
      ipv4 {
        address = "192.168.1.110/24"
        gateway = "192.168.1.1"
      }
    }
  }
}
```

### Customize with Cloud-init

The template includes cloud-init pre-configured. Create `user-data`:

```yaml
#cloud-config
hostname: production-server
fqdn: production-server.domain.local

users:
  - name: admin
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... your-key

packages:
  - nginx
  - docker.io
  - postgresql

runcmd:
  - systemctl enable --now docker
  - systemctl enable --now postgresql
```

## Customization

### Add Packages to Template

Edit `debian.pkr.hcl` provisioner:

```hcl
provisioner "shell" {
  inline = [
    "sudo apt-get install -y",
    "  docker.io",
    "  nginx",
    "  postgresql",
    "  redis-server"
  ]
}
```

### Run Ansible Playbook

Add ansible provisioner to `debian.pkr.hcl`:

```hcl
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/debian-baseline.yml"
  user          = "debian"
}
```

## Troubleshooting

### Issue: Import script fails

```
Error: Cannot download cloud image
```

**Solution**:
- Check internet connectivity on Proxmox host
- Verify URL is correct (Debian URLs change with releases)
- Try manual download: `wget <url>`
- Check https://cloud.debian.org/images/cloud/ for latest

### Issue: Packer can't find base VM

```
Error: VM with ID 9110 not found
```

**Solution**:
- Verify import script completed successfully
- Check VM exists: `qm list | grep 9110`
- Verify `cloud_image_vm_id` matches in variables

### Issue: SSH timeout during Packer build

```
Timeout waiting for SSH
```

**Solution**:
- Start base VM manually to test: `qm start 9110`
- Check it gets IP: `qm guest cmd 9110 network-get-interfaces`
- Test SSH: `ssh debian@<ip>` (password: debian)
- Check firewall allows port 22

## Best Practices

### 1. Keep Base Image Updated

Rebuild monthly to include latest security updates:

```bash
# On Proxmox host, update base image
qm destroy 9110
./import-cloud-image.sh 9110

# Then rebuild template
packer build .
```

### 2. Use Version Tags

Tag templates with date/version:

```hcl
template_name = "debian-12-cloud-template-v${formatdate("YYYYMMDD", timestamp())}"
```

### 3. Separate Base from Customization

- **Base VM** (9110): Official cloud image, rarely changes
- **Template** (9112): Customized with packages, updated frequently
- **Production VMs**: Cloned from template

## Resources

- **Debian Cloud Images**: https://cloud.debian.org/images/cloud/
- **Cloud-init Docs**: https://cloudinit.readthedocs.io/
- **Proxmox Cloud-Init**: https://pve.proxmox.com/wiki/Cloud-Init_Support
- **Packer Proxmox Plugin**: https://www.packer.io/plugins/builders/proxmox/clone

## Next Steps

1. ✅ Import cloud image to Proxmox
2. ✅ Build customized template with Packer
3. Test deployment with cloud-init
4. Create Ansible baseline playbook
5. Set up automated monthly rebuilds

See `../ubuntu/` for Ubuntu cloud image template (same approach).
