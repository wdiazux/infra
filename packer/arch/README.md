# Arch Linux Golden Image Packer Template

This directory contains Packer configuration to build an Arch Linux golden image for Proxmox VE 9.0 with cloud-init and QEMU guest agent support.

## Overview

Creates a production-ready Arch Linux template with:
- **Arch Linux** - Latest rolling release
- **Cloud-init** - For automated VM customization
- **QEMU Guest Agent** - For Proxmox integration
- **SSH Server** - Pre-configured and enabled
- **Baseline packages** - Common utilities and tools
- **Minimal footprint** - ~20GB disk, 2GB RAM during build
- **UEFI boot** - Modern boot system with systemd-boot

## Prerequisites

### Tools Required

```bash
# Packer 1.14.2+
packer --version
```

### Proxmox Setup

Same as Talos template - see [main Packer README](../../packer/talos/README.md#proxmox-setup).

### Get Arch Linux ISO Information

Visit https://archlinux.org/download/ and get the latest ISO:
- **ISO URL**: Always use "latest" link for rolling release
- **Checksum**: Automatically verified from sha256sums.txt

Example:
```
URL: https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso
Checksum: file:https://mirror.rackspace.com/archlinux/iso/latest/sha256sums.txt
```

## Quick Start

### 1. Copy Example Configuration

```bash
cd packer/arch
cp arch.auto.pkrvars.hcl.example arch.auto.pkrvars.hcl
```

### 2. Edit Configuration

Edit `arch.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

# Arch ISO (always use latest for rolling release)
arch_iso_url = "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
arch_iso_checksum = "file:https://mirror.rackspace.com/archlinux/iso/latest/sha256sums.txt"

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

**Build time**: 15-25 minutes depending on network speed and storage.

### 4. Verify Template

Check in Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `arch-linux-golden-template-YYYYMMDD-hhmm`

## Using the Template

### Option 1: Clone Manually in Proxmox UI

1. Right-click template → Clone
2. Full clone (not linked)
3. Set VM name and resources
4. Start VM
5. Access via console or SSH (user: root, password: arch - change immediately!)

### Option 2: Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "arch_vm" {
  name      = "arch-vm-01"
  node_name = "pve"

  clone {
    vm_id = 9003  # Template ID
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
        address = "192.168.1.130/24"
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
hostname: my-arch-vm
fqdn: my-arch-vm.localdomain

users:
  - name: admin
    groups: wheel
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... your-key

packages:
  - vim
  - htop
  - docker

runcmd:
  - systemctl enable docker
  - systemctl start docker
```

Upload to Proxmox and assign to VM during clone.

## Customization

### Modify Installation Script

Edit `http/install.sh` to change:
- **Partitioning scheme** - Modify disk layout
- **Package selection** - Add/remove packages
- **Locale/timezone** - Change from en_US/UTC
- **Root password** - Change default password
- **Bootloader** - Switch from systemd-boot to GRUB

### Add Provisioning Steps

Edit `arch.pkr.hcl` and add provisioner blocks:

```hcl
# Install Docker
provisioner "shell" {
  inline = [
    "pacman -S --noconfirm docker",
    "systemctl enable docker"
  ]
}

# Run Ansible
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/arch-baseline.yml"
}
```

### Change Disk Size

In `arch.auto.pkrvars.hcl`:

```hcl
vm_disk_size = "50G"  # Increase to 50GB
```

### Add Additional Packages

In `http/install.sh`, modify the pacman install command:

```bash
pacman -Sy --noconfirm \
    # ... existing packages ... \
    docker \
    nginx \
    postgresql
```

## Post-Build Configuration

After deploying VMs from this template:

### 1. Run Ansible Baseline Playbook

```bash
# From ansible/ directory
ansible-playbook -i inventory/hosts.yml playbooks/arch-baseline.yml
```

This configures:
- Security hardening
- Additional packages
- User accounts and SSH keys
- Service configuration

### 2. Update and Harden

```bash
# On the VM
pacman -Syu  # Full system upgrade
```

### 3. Configure Firewall

```bash
pacman -S ufw
ufw allow 22/tcp
ufw enable
```

## Troubleshooting

### Issue: Installation script fails

```
Error running installation script
```

**Solution**:
- Check `http/install.sh` exists and is executable
- Verify script syntax: `bash -n http/install.sh`
- Review Packer logs with `PACKER_LOG=1 packer build .`

### Issue: Can't SSH to VM during build

```
Timeout waiting for SSH
```

**Solution**:
- Verify boot_command sets root password correctly
- Ensure SSH is started: check boot_command includes `systemctl start sshd`
- Increase ssh_timeout if network is slow

### Issue: System won't boot after installation

```
VM fails to boot or drops to emergency shell
```

**Solution**:
- Check bootloader was installed: verify systemd-boot configuration
- Ensure partitions formatted correctly
- Review installation script for errors
- Check UEFI firmware is available on Proxmox

### Issue: Cloud-init not working

```
Cloud-init configuration not applied
```

**Solution**:
- Verify cloud-init installed: `pacman -Q cloud-init`
- Check cloud-init services enabled: `systemctl status cloud-init`
- Review logs: `cloud-init status --long`
- Ensure datasource configured in `/etc/cloud/cloud.cfg.d/`

### Issue: QEMU guest agent not responding

```
qm agent <vmid> ping
# Returns: connection failed
```

**Solution**:
- Verify installed: `pacman -Q qemu-guest-agent`
- Check service: `systemctl status qemu-guest-agent`
- Ensure enabled in VM config: `qm config <vmid> | grep agent`

### Issue: Pacman keyring errors

```
Signature errors when installing packages
```

**Solution**:
- Initialize keyring: `pacman-key --init`
- Populate keyring: `pacman-key --populate archlinux`
- Update keyring: `pacman -Sy archlinux-keyring`

## Template Details

### Installed Packages

**Base System**:
- `base`, `base-devel` - Core system packages
- `linux`, `linux-firmware` - Kernel and firmware
- `qemu-guest-agent` - Proxmox integration
- `cloud-init`, `cloud-guest-utils` - Automated configuration
- `sudo` - Privilege escalation
- `openssh` - SSH access

**Utilities**:
- `vim` - Text editor
- `curl`, `wget` - Download tools
- `git` - Version control
- `htop` - Process monitor
- `net-tools` - Network utilities
- `dnsutils` - DNS tools
- `python`, `python-pip` - Python runtime
- `networkmanager`, `dhcpcd` - Network management

### Bootloader

Uses **systemd-boot** (not GRUB) for:
- Faster boot times
- Simpler configuration
- Native UEFI integration
- Minimal dependencies

### Cloud-init Configuration

The template includes cloud-init with:
- Network configuration support (DHCP or static)
- User and SSH key management
- Package installation on first boot
- Custom scripts execution
- NoCloud and ConfigDrive datasources

### QEMU Guest Agent

Enabled and configured for:
- VM status reporting to Proxmox
- Graceful shutdown/reboot
- IP address discovery
- Filesystem quiescing for snapshots

## Best Practices

1. **Update Template Regularly**
   - **IMPORTANT**: Rebuild monthly (Arch is rolling release!)
   - Always use latest ISO
   - Test new template before replacing production
   - Keep track of major package updates

2. **Use Cloud-init for Customization**
   - Don't modify template directly
   - Use cloud-init user-data for VM-specific config
   - Keep template generic and reusable

3. **Baseline Configuration with Ansible**
   - Use Ansible for consistent configuration
   - Version control playbooks
   - Test in dev before production

4. **Security Hardening**
   - Change default root password immediately
   - Create non-root user with sudo access
   - Disable root SSH login
   - Enable automatic security updates
   - Configure firewall

5. **Documentation**
   - Document custom provisioning steps
   - Track template versions and build dates
   - Note Arch-specific considerations

## Resources

- **Arch Linux Documentation**: https://wiki.archlinux.org/
- **Arch Installation Guide**: https://wiki.archlinux.org/title/Installation_guide
- **Cloud-init Docs**: https://cloudinit.readthedocs.io/
- **Systemd-boot**: https://wiki.archlinux.org/title/Systemd-boot
- **Packer Proxmox Builder**: https://www.packer.io/plugins/builders/proxmox

## Important Notes

### Rolling Release Considerations

Arch Linux is a rolling release distribution, which means:
- No version numbers (always "latest")
- Continuous updates to all packages
- **Must rebuild template regularly** (monthly recommended)
- May encounter breaking changes between builds
- Read Arch news before major updates: https://archlinux.org/news/

### AUR (Arch User Repository)

This template does NOT include AUR helper (yay, paru). To add:

```bash
# After VM deployment, as regular user (not root)
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Package Management

Unlike Debian/Ubuntu, Arch uses:
- `pacman` - Package manager
- `makepkg` - Build packages from source
- AUR - Community package repository

Key commands:
```bash
pacman -Syu          # Full system upgrade
pacman -S package    # Install package
pacman -R package    # Remove package
pacman -Ss keyword   # Search packages
```

## Next Steps

After building the Arch template:

1. Test deployment with cloud-init
2. Create Ansible baseline playbook specific to Arch
3. Document custom configurations
4. Set up automated rebuild schedule (monthly)
5. Build templates for other OSes (NixOS, Windows, etc.)

See `../../terraform/` for deploying VMs from this template.
