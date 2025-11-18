# NixOS Golden Image Packer Template

This directory contains Packer configuration to build a NixOS 24.05 golden image for Proxmox VE 9.0 with cloud-init and QEMU guest agent support.

## Overview

Creates a production-ready NixOS template with:
- **NixOS 24.05** - Latest stable release
- **Declarative configuration** - Entire system defined in configuration.nix
- **Cloud-init** - For automated VM customization
- **QEMU Guest Agent** - For Proxmox integration
- **SSH Server** - Pre-configured and enabled
- **Nix package manager** - Reproducible package management
- **Minimal footprint** - ~20GB disk, 2GB RAM during build
- **UEFI boot** - Modern boot system with systemd-boot

## What Makes NixOS Different

NixOS is **declarative** - the entire system is defined in `/etc/nixos/configuration.nix`:
- **Reproducible**: Same config = same system
- **Atomic upgrades**: Rollback if something breaks
- **No dependency hell**: Each package has its own dependencies
- **Functional**: System configuration is a pure function

**Traditional Linux**:
```bash
apt install nginx
systemctl enable nginx
vim /etc/nginx/nginx.conf
```

**NixOS**:
```nix
services.nginx.enable = true;
# Config changes go in configuration.nix, then:
nixos-rebuild switch
```

## Prerequisites

### Tools Required

```bash
# Packer 1.14.2+
packer --version
```

### Proxmox Setup

Same as Talos template - see [main Packer README](../../packer/talos/README.md#proxmox-setup).

### Get NixOS ISO Information

Visit https://nixos.org/download and get:
1. **ISO URL** - Minimal ISO recommended for templates
2. **SHA256 checksum** - Automatically verified

Example for NixOS 24.05:
```
URL: https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso
Checksum: file:https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso.sha256
```

## Quick Start

### 1. Copy Example Configuration

```bash
cd packer/nixos
cp nixos.auto.pkrvars.hcl.example nixos.auto.pkrvars.hcl
```

### 2. Edit Configuration

Edit `nixos.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

# NixOS ISO
nixos_iso_url = "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso"
nixos_iso_checksum = "file:https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso.sha256"

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

**Build time**: 20-30 minutes depending on network speed and storage.

### 4. Verify Template

Check in Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `nixos-golden-template-YYYYMMDD-hhmm`

## Using the Template

### Option 1: Clone Manually in Proxmox UI

1. Right-click template → Clone
2. Full clone (not linked)
3. Set VM name and resources
4. Start VM
5. Access via console or SSH (user: root, password: nixos - change immediately!)

### Option 2: Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "nixos_vm" {
  name      = "nixos-vm-01"
  node_name = "pve"

  clone {
    vm_id = 9004  # Template ID
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
        address = "192.168.1.140/24"
        gateway = "192.168.1.1"
      }
    }
  }
}
```

### Option 3: Customize with NixOS Configuration

After deployment, edit `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:
{
  # Import hardware config
  imports = [ ./hardware-configuration.nix ];

  # Hostname
  networking.hostName = "my-nixos-vm";

  # Users
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2E... your-key"
    ];
  };

  # Services
  services.openssh.enable = true;
  virtualisation.docker.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    docker
  ];

  system.stateVersion = "24.05";
}
```

Then apply:
```bash
nixos-rebuild switch
```

## Customization

### Modify Base Configuration

Edit `http/configuration.nix` to change:
- **Package selection** - Add/remove packages
- **Services** - Enable/disable services
- **Locale/timezone** - Change from en_US/UTC
- **Users** - Add default users
- **Network configuration** - Customize networking

### Add Provisioning Steps

Edit `nixos.pkr.hcl` and add provisioner blocks:

```hcl
# Install additional packages
provisioner "shell" {
  inline = [
    "nix-env -iA nixos.docker nixos.nginx"
  ]
}

# Run Ansible (for additional configuration)
provisioner "ansible" {
  playbook_file = "../../ansible/playbooks/nixos-baseline.yml"
}
```

### Change Disk Size

In `nixos.auto.pkrvars.hcl`:

```hcl
vm_disk_size = "50G"  # Increase to 50GB
```

### Add Additional Packages to Base Image

In `http/configuration.nix`, modify environment.systemPackages:

```nix
environment.systemPackages = with pkgs; [
  # ... existing packages ...
  docker
  nginx
  postgresql
];
```

## Post-Build Configuration

After deploying VMs from this template:

### 1. Customize with configuration.nix

```bash
# On the VM, edit configuration
vim /etc/nixos/configuration.nix

# Apply changes
nixos-rebuild switch

# Test changes before applying permanently
nixos-rebuild test
```

### 2. Update System

```bash
# Update channels
nix-channel --update

# Rebuild with latest packages
nixos-rebuild switch --upgrade
```

### 3. Rollback if Needed

NixOS keeps previous generations:
```bash
# List available generations
nixos-rebuild list-generations

# Rollback to previous generation
nixos-rebuild switch --rollback

# Or select specific generation
nixos-rebuild switch --rollback --generation 5
```

## Troubleshooting

### Issue: Installation script fails

```
Error running installation script
```

**Solution**:
- Check `http/install.sh` and `http/configuration.nix` exist
- Verify script syntax: `bash -n http/install.sh`
- Review Packer logs with `PACKER_LOG=1 packer build .`
- Ensure configuration.nix is valid: `nix-instantiate --parse http/configuration.nix`

### Issue: Can't SSH to VM during build

```
Timeout waiting for SSH
```

**Solution**:
- Verify boot_command sets root password correctly
- Ensure SSH is started: check boot_command includes `systemctl start sshd`
- Increase ssh_timeout if network is slow
- Check NixOS ISO booted properly in Proxmox console

### Issue: System won't boot after installation

```
VM fails to boot or drops to emergency shell
```

**Solution**:
- Check bootloader was installed: verify systemd-boot configuration
- Ensure fileSystems config in configuration.nix matches partitions
- Review installation script for errors
- Check UEFI firmware is available on Proxmox

### Issue: Cloud-init not working

```
Cloud-init configuration not applied
```

**Solution**:
- Verify cloud-init enabled in configuration.nix: `services.cloud-init.enable = true;`
- Check cloud-init services: `systemctl status cloud-init`
- Review logs: `cloud-init status --long`
- Ensure qemu-guest-agent is running

### Issue: QEMU guest agent not responding

```
qm agent <vmid> ping
# Returns: connection failed
```

**Solution**:
- Verify enabled in configuration.nix: `services.qemuGuest.enable = true;`
- Check service: `systemctl status qemu-guest-agent`
- Ensure enabled in VM config: `qm config <vmid> | grep agent`

### Issue: Configuration build fails

```
nixos-rebuild switch fails
```

**Solution**:
- Check syntax: `nix-instantiate --parse /etc/nixos/configuration.nix`
- Review error messages - NixOS errors are usually descriptive
- Use `nixos-rebuild switch --show-trace` for detailed error info
- Rollback to previous generation if needed

## Template Details

### Installed Packages

**Base System**:
- NixOS base system
- Linux kernel and firmware
- `qemu-guest-agent` - Proxmox integration
- `cloud-init`, `cloud-utils` - Automated configuration
- `openssh` - SSH access

**Utilities**:
- `vim` - Text editor
- `curl`, `wget` - Download tools
- `git` - Version control
- `htop` - Process monitor
- `neofetch` - System information

**Note**: Add more packages by editing `/etc/nixos/configuration.nix` and running `nixos-rebuild switch`

### Bootloader

Uses **systemd-boot** (not GRUB) for:
- Faster boot times
- Simpler configuration
- Native UEFI integration
- Generation selection at boot

### Cloud-init Configuration

The template includes cloud-init with:
- Network configuration support
- User and SSH key management
- Package installation on first boot
- Integration with NixOS declarative config

### QEMU Guest Agent

Enabled and configured for:
- VM status reporting to Proxmox
- Graceful shutdown/reboot
- IP address discovery
- Filesystem quiescing for snapshots

## NixOS-Specific Concepts

### Generations

Every time you run `nixos-rebuild switch`, NixOS creates a new "generation":
- Previous generations are kept (can be removed with `nix-collect-garbage`)
- Rollback to any previous generation
- Atomic upgrades - either fully succeeds or fails
- Boot menu shows available generations

### Channels

NixOS channels are release branches:
```bash
# List channels
nix-channel --list

# Add a channel
nix-channel --add https://nixos.org/channels/nixos-24.05 nixos

# Update channels
nix-channel --update
```

### Nix Store

All packages are stored in `/nix/store`:
- Immutable - never modified after installation
- Hash-based naming prevents conflicts
- Shared between system and users
- Garbage collected with `nix-collect-garbage`

### Configuration Management

Everything in `/etc/nixos/configuration.nix`:
```nix
{ config, pkgs, ... }:
{
  # System packages
  environment.systemPackages = with pkgs; [ vim git htop ];

  # Services
  services.nginx.enable = true;
  services.postgresql.enable = true;

  # Users
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
```

## Best Practices

1. **Version Control configuration.nix**
   - Keep `/etc/nixos/configuration.nix` in Git
   - Track all changes
   - Easy to replicate systems

2. **Test Before Applying**
   - Use `nixos-rebuild test` to try changes temporarily
   - Use `nixos-rebuild switch` when satisfied
   - Keep previous generations for rollback

3. **Regular Updates**
   - Update channels: `nix-channel --update`
   - Rebuild: `nixos-rebuild switch --upgrade`
   - Clean up old generations: `nix-collect-garbage -d`

4. **Use Declarative Configuration**
   - Don't install packages imperatively (`nix-env -i`)
   - Add everything to configuration.nix
   - Makes system reproducible

5. **Documentation**
   - Document custom configurations
   - Track NixOS version (system.stateVersion)
   - Note any imperative changes (temporary)

## Resources

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **NixOS Options**: https://search.nixos.org/options
- **Nix Packages**: https://search.nixos.org/packages
- **NixOS Wiki**: https://nixos.wiki/
- **Nix Pills**: https://nixos.org/guides/nix-pills/ (excellent tutorial)
- **Packer Proxmox Builder**: https://www.packer.io/plugins/builders/proxmox

## Important Notes

### Learning Curve

NixOS has a steeper learning curve than traditional Linux:
- New concepts: derivations, channels, generations
- Nix language for configuration
- Different approach to package management

**Worth it for**:
- Reproducible systems
- Easy rollbacks
- No dependency conflicts
- Infrastructure as Code

### Immutability

Most of the filesystem is read-only:
- `/nix/store` - Immutable package store
- `/etc` - Generated from configuration.nix
- `/home` - User data (mutable)
- `/var` - Variable data (mutable)

### Package Availability

- **30,000+ packages** in Nix package repository
- Most common software available
- Can run non-NixOS binaries with `steam-run` or `nix-ld`
- Nix flakes for pinning dependencies

## Next Steps

After building the NixOS template:

1. Test deployment with cloud-init
2. Create example configuration.nix for common use cases
3. Version control your NixOS configurations
4. Build VMs from template and customize declaratively

See `../../terraform/` for deploying VMs from this template.
