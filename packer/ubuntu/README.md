# Ubuntu Cloud Image Packer Template (PREFERRED METHOD)

This directory contains configuration for building Ubuntu 24.04 LTS golden images from **official Ubuntu cloud images**. This is the **preferred and recommended approach** for creating Ubuntu templates in Proxmox.

## Why Cloud Images? (Preferred Method)

### ✅ Advantages over ISO Build
- **⚡ Much faster**: 5-10 minutes vs 20-30 minutes
- **🎯 Simpler**: No autoinstall/preseed complexity
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

**ISO-based Ubuntu templates have been removed** in favor of this cloud image approach. The cloud image method is faster, simpler, and follows industry best practices.

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

# Run import script (creates base VM with ID 9100)
chmod +x import-cloud-image.sh
./import-cloud-image.sh

# Or specify custom VM ID
./import-cloud-image.sh 9100
```

This creates a base VM (`ubuntu-2404-cloud-base`) that Packer will clone and customize.

**What the script does:**
1. Downloads official Ubuntu 24.04 cloud image
2. Verifies SHA256 checksum
3. Imports to Proxmox as VM disk
4. Configures VM with cloud-init
5. Enables QEMU guest agent
6. Sets up default user (ubuntu/ubuntu)

### Step 2: Configure Packer

```bash
cd packer/ubuntu

# Copy example configuration
cp ubuntu.auto.pkrvars.hcl.example ubuntu.auto.pkrvars.hcl

# Edit configuration
vim ubuntu.auto.pkrvars.hcl
```

Key settings:
```hcl
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

cloud_image_vm_id = 9100  # Base VM created by import script
vm_id             = 9102  # Template VM ID (must be different)

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

Should see: `ubuntu-2404-cloud-template-YYYYMMDD-hhmm`

## Using the Template

### Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "ubuntu" {
  name      = "ubuntu-prod-01"
  node_name = "pve"

  clone {
    vm_id = 9102  # Cloud image template
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
        address = "192.168.1.100/24"
        gateway = "192.168.1.1"
      }
    }
  }
}
```

### Clone Manually in Proxmox UI

1. Right-click template → Clone
2. Full clone (not linked)
3. Set VM resources
4. Configure cloud-init (user-data, network)
5. Start VM

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

Edit `ubuntu.pkr.hcl` provisioner:

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

Add ansible provisioner to `ubuntu.pkr.hcl`:

```hcl
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/ubuntu-baseline.yml"
  user          = "ubuntu"
}
```

### Change Base Cloud Image

Edit `import-cloud-image.sh` to use different version:

```bash
# For Ubuntu 22.04
UBUNTU_VERSION="22.04"

# For daily builds (testing)
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/daily/server/releases/24.04/release/..."
```

## Comparison: Cloud Image vs ISO

### Build Time Breakdown

**Cloud Image Method:**
```
Download cloud image:     1-2 min (one-time)
Import to Proxmox:        1 min   (one-time)
Packer customization:     5-10 min
----------------------------------------
Total first time:         7-13 min
Total subsequent builds:  5-10 min
```

**ISO Method:**
```
Download ISO:             2-3 min (one-time)
OS installation:          10-15 min
Package installation:     3-5 min
Configuration:            2-3 min
----------------------------------------
Total every build:        15-23 min
```

### Features Comparison

| Feature | Cloud Image | ISO Build |
|---------|-------------|-----------|
| cloud-init | ✅ Pre-installed | ⚠️ Need to install |
| qemu-guest-agent | ✅ Pre-installed | ⚠️ Need to install |
| Minimal packages | ✅ Yes | ⚠️ Depends on selection |
| Custom partitioning | ❌ Fixed layout | ✅ Full control |
| Learning value | Low | High |
| Production use | ✅ Recommended | ⚠️ Overkill |

## Troubleshooting

### Issue: Import script fails

```
Error: Cannot download cloud image
```

**Solution**:
- Check internet connectivity on Proxmox host
- Verify URL is correct
- Try manual download: `wget <url>`

### Issue: Packer can't find base VM

```
Error: VM with ID 9100 not found
```

**Solution**:
- Verify import script completed successfully
- Check VM exists: `qm list | grep 9100`
- Verify `cloud_image_vm_id` matches in variables

### Issue: SSH timeout during Packer build

```
Timeout waiting for SSH
```

**Solution**:
- Start base VM manually to test: `qm start 9100`
- Check it gets IP: `qm guest cmd 9100 network-get-interfaces`
- Test SSH: `ssh ubuntu@<ip>` (password: ubuntu)
- Check firewall allows port 22

### Issue: Cloud-init not working after clone

```
Cloud-init configuration not applied
```

**Solution**:
- Verify cloud-init drive exists: `qm config <vmid> | grep ide2`
- Check cloud-init logs: `cloud-init status --long`
- Ensure user-data provided during VM clone
- Review Proxmox cloud-init configuration

## Best Practices

### 1. Keep Base Image Updated

Rebuild monthly to include latest security updates:

```bash
# On Proxmox host, update base image
qm destroy 9100
./import-cloud-image.sh 9100

# Then rebuild template
packer build .
```

### 2. Use Version Tags

Tag templates with date/version:

```hcl
template_name = "ubuntu-2404-cloud-template-v${formatdate("YYYYMMDD", timestamp())}"
```

### 3. Separate Base from Customization

- **Base VM** (9100): Official cloud image, rarely changes
- **Template** (9102): Customized with packages, updated frequently
- **Production VMs**: Cloned from template

### 4. Test Before Production

```bash
# Test template
qm clone 9102 999 --name test-vm --full
qm start 999
# Test functionality
qm destroy 999
```

### 5. Document Customizations

Keep list of:
- Packages installed
- Configuration changes
- Ansible playbooks applied
- Last rebuild date

## Advanced Usage

### Automated Monthly Rebuilds

Create cron job on Proxmox host:

```bash
# /etc/cron.d/packer-rebuild
0 2 1 * * root cd /root/packer/ubuntu-cloud && ./import-cloud-image.sh 9100 && packer build .
```

### Multiple Ubuntu Versions

Create separate base VMs for different versions:

```bash
./import-cloud-image.sh 9100  # 24.04 LTS
./import-cloud-image.sh 9101  # 22.04 LTS
```

Update Packer variables for each version.

### Integration with CI/CD

```yaml
# .github/workflows/build-template.yml
name: Build Ubuntu Template
on:
  schedule:
    - cron: '0 2 1 * *'  # Monthly
  workflow_dispatch:

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Build template
        run: |
          cd packer/ubuntu-cloud
          packer build .
```

## Resources

- **Ubuntu Cloud Images**: https://cloud-images.ubuntu.com/
- **Cloud-init Docs**: https://cloudinit.readthedocs.io/
- **Proxmox Cloud-Init**: https://pve.proxmox.com/wiki/Cloud-Init_Support
- **Packer Proxmox Plugin**: https://www.packer.io/plugins/builders/proxmox/clone

## Migration from ISO Build

If you're currently using ISO-based templates:

### 1. Build Cloud Image Template

```bash
# Import cloud image
./import-cloud-image.sh 9100

# Build template
packer build .
```

### 2. Test Side-by-Side

Deploy test VMs from both templates and compare:
- Boot time
- Package versions
- Functionality
- Cloud-init behavior

### 3. Gradual Migration

- **New deployments**: Use cloud image template
- **Existing VMs**: Keep ISO template as fallback
- **After validation**: Deprecate ISO template

### 4. Update Documentation

Update deployment docs to reference new template ID and cloud-init configuration.

## Next Steps

1. ✅ Import cloud image to Proxmox
2. ✅ Build customized template with Packer
3. Test deployment with cloud-init
4. Create Ansible baseline playbook
5. Set up automated monthly rebuilds
6. Create similar template for Debian

See `../debian/` for Debian cloud image template.
