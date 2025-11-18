# Debian Golden Image Packer Template

This directory contains Packer configuration to build a Debian 12 (Bookworm) golden image for Proxmox VE 9.0 with cloud-init and QEMU guest agent support.

## Overview

Creates a production-ready Debian template with:
- **Debian 12 (Bookworm)** - Latest stable release
- **Cloud-init** - For automated VM customization
- **QEMU Guest Agent** - For Proxmox integration
- **SSH Server** - Pre-configured and enabled
- **Baseline packages** - Common utilities and tools
- **Minimal footprint** - ~20GB disk, 2GB RAM during build

## Prerequisites

### Tools Required

```bash
# Packer 1.14.2+
packer --version
```

### Proxmox Setup

Same as Talos template - see [main Packer README](../../packer/talos/README.md#proxmox-setup).

### Get Debian ISO Information

Visit https://www.debian.org/CD/netinst/ and get:
1. **ISO URL** - Direct link to netinst ISO
2. **SHA256 checksum** - For verification

Example for Debian 12.8.0:
```
URL: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso
SHA256: (get from debian.org)
```

## Quick Start

### 1. Copy Example Configuration

```bash
cd packer/debian
cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl
```

### 2. Edit Configuration

Edit `debian.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

# Debian ISO (get latest from debian.org)
debian_iso_url = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
debian_iso_checksum = "sha256:your-checksum-here"

# Storage
vm_disk_storage = "local-zfs"  # Your Proxmox storage pool
```

### 3. Initialize and Build

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build time**: 10-20 minutes depending on network speed and storage.

### 4. Verify Template

Check in Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `debian-12-golden-template-YYYYMMDD-hhmm`

## Using the Template

### Option 1: Clone Manually in Proxmox UI

1. Right-click template → Clone
2. Full clone (not linked)
3. Set VM name and resources
4. Start VM
5. Access via console or SSH (user: debian, password: debian - change immediately!)

### Option 2: Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "debian_vm" {
  name      = "debian-vm-01"
  node_name = "pve"

  clone {
    vm_id = 9001  # Template ID
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

### Option 3: Customize with Cloud-init

Create `user-data.yaml`:

```yaml
#cloud-config
hostname: my-debian-vm
fqdn: my-debian-vm.localdomain

users:
  - name: admin
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... your-key

packages:
  - vim
  - htop
  - docker.io

runcmd:
  - systemctl enable docker
  - systemctl start docker
```

Upload to Proxmox and assign to VM during clone.

## Customization

### Modify Preseed File

Edit `http/preseed.cfg` to change:
- **Partitioning scheme** - Change from `atomic` to custom
- **Package selection** - Add/remove packages
- **Locale/timezone** - Change from en_US/UTC
- **User credentials** - Change default user/password

### Add Provisioning Steps

Edit `debian.pkr.hcl` and add provisioner blocks:

```hcl
# Install Docker
provisioner "shell" {
  inline = [
    "sudo apt-get install -y docker.io",
    "sudo systemctl enable docker"
  ]
}

# Run Ansible
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/debian-baseline.yml"
}
```

### Change Disk Size

In `debian.auto.pkrvars.hcl`:

```hcl
vm_disk_size = "50G"  # Increase to 50GB
```

### Add Additional Packages

In `debian.pkr.hcl`, modify the baseline packages provisioner:

```hcl
provisioner "shell" {
  inline = [
    "sudo apt-get install -y",
    "  # ... existing packages ...",
    "  docker.io",
    "  nginx",
    "  postgresql"
  ]
}
```

## Post-Build Configuration

After deploying VMs from this template:

### 1. Run Ansible Baseline Playbook

```bash
# From ansible/ directory
ansible-playbook -i inventory/hosts.yml playbooks/debian-baseline.yml
```

This configures:
- Security hardening
- Additional packages
- User accounts and SSH keys
- Service configuration

### 2. Update and Harden

```bash
# On the VM
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
```

### 3. Configure Firewall

```bash
sudo apt install ufw
sudo ufw allow 22/tcp
sudo ufw enable
```

## Troubleshooting

### Issue: Preseed file not found

```
Error: Could not retrieve preseed file
```

**Solution**: Ensure HTTP server starts correctly:
- Check `http_directory = "http"` path is correct
- Verify `http/preseed.cfg` exists
- Try running with `PACKER_LOG=1 packer build .` for verbose output

### Issue: Installation hangs

```
Installation appears stuck at partitioning
```

**Solution**:
- Check preseed partitioning configuration
- Ensure disk size is adequate (minimum 10G)
- Verify no prompts are waiting for input

### Issue: Can't SSH to VM after build

```
Timeout waiting for SSH
```

**Solution**:
- Verify `ssh_username` and `ssh_password` match preseed config
- Check firewall allows SSH (port 22)
- Ensure SSH server installed and enabled in preseed late_command

### Issue: Cloud-init not working

```
Cloud-init configuration not applied
```

**Solution**:
- Verify cloud-init installed: `dpkg -l | grep cloud-init`
- Check cloud-init services enabled: `systemctl status cloud-init`
- Review logs: `sudo cloud-init status --long`

### Issue: QEMU guest agent not responding

```
qm agent <vmid> ping
# Returns: connection failed
```

**Solution**:
- Verify installed: `dpkg -l | grep qemu-guest-agent`
- Check service: `systemctl status qemu-guest-agent`
- Ensure enabled in VM config: `qm config <vmid> | grep agent`

## Template Details

### Installed Packages

**Base System**:
- `qemu-guest-agent` - Proxmox integration
- `cloud-init` - Automated configuration
- `cloud-initramfs-growroot` - Root filesystem expansion
- `sudo` - Privilege escalation
- `openssh-server` - SSH access

**Utilities**:
- `vim` - Text editor
- `curl`, `wget` - Download tools
- `git` - Version control
- `htop` - Process monitor
- `net-tools` - Network utilities
- `dnsutils` - DNS tools
- `python3`, `python3-pip` - Python runtime

### Cloud-init Configuration

The template includes cloud-init with:
- Network configuration support (DHCP or static)
- User and SSH key management
- Package installation on first boot
- Custom scripts execution

### QEMU Guest Agent

Enabled and configured for:
- VM status reporting to Proxmox
- Graceful shutdown/reboot
- IP address discovery
- Filesystem quiescing for snapshots

## Best Practices

1. **Update Template Regularly**
   - Rebuild monthly with latest Debian updates
   - Update ISO URL to latest point release
   - Test new template before replacing production

2. **Use Cloud-init for Customization**
   - Don't modify template directly
   - Use cloud-init user-data for VM-specific config
   - Keep template generic and reusable

3. **Baseline Configuration with Ansible**
   - Use Ansible for consistent configuration
   - Version control playbooks
   - Test in dev before production

4. **Security Hardening**
   - Change default passwords immediately
   - Disable password authentication (use SSH keys)
   - Enable automatic security updates
   - Configure firewall

5. **Documentation**
   - Document custom provisioning steps
   - Track template versions
   - Note security considerations

## Resources

- **Debian Documentation**: https://www.debian.org/doc/
- **Cloud-init Docs**: https://cloudinit.readthedocs.io/
- **Debian Preseed**: https://www.debian.org/releases/stable/amd64/apb.html
- **Packer Proxmox Builder**: https://www.packer.io/plugins/builders/proxmox

## Next Steps

After building the Debian template:

1. Test deployment with cloud-init
2. Create Ansible baseline playbook
3. Document custom configurations
4. Build templates for other OSes (Ubuntu, Arch, etc.)

See `../../terraform/` for deploying VMs from this template.
