# NixOS Golden Image: Complete Deployment Guide

**Date**: 2025-11-23
**Purpose**: Step-by-step guide for creating NixOS golden images with Packer and deploying VMs with Terraform

---

## Overview

This guide walks through the complete workflow:
1. **Day 0**: Prepare NixOS ISO and configuration files
2. **Day 1**: Build golden image template with Packer (declarative installation)
3. **Day 2**: Deploy production VMs from template with Terraform

**Total Time**: ~25-35 minutes (ISO download + installation + package downloads)

---

## Prerequisites

### Tools Required

```bash
# Verify tool versions
packer version    # Should be 1.14.2+
terraform version # Should be 1.9.0+
```

### Proxmox Access

- Proxmox VE 9.0 host
- API token with permissions: `PVEVMAdmin`, `PVEDatastoreUser`
- Storage pool (e.g., `tank`)
- Network bridge (e.g., `vmbr0`)

### Network Requirements

- Proxmox host has internet access (for downloading ISO and packages)
- DHCP enabled on network bridge OR static IP configuration
- DNS configured on Proxmox host

### NixOS Knowledge

Basic understanding of:
- Nix expression language
- NixOS configuration.nix structure
- Declarative system configuration

---

## Part 1: Day 0 - Prepare NixOS ISO and Configuration

### Step 1: Get Latest NixOS ISO

Visit https://nixos.org/download.html#nixos-iso and download the minimal ISO:

```bash
# NixOS Minimal ISO (recommended for servers)
# URL: https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso

# Or use unstable channel for latest packages
# URL: https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso
```

**Channels**:
- **24.05**: Stable release (recommended for production)
- **unstable**: Rolling release (latest packages, less stable)

### Step 2: Verify NixOS Configuration File

The Packer template uses a declarative configuration file located at `packer/nixos/http/configuration.nix`.

```bash
cd packer/nixos

# Verify configuration.nix exists
ls -la http/configuration.nix
```

**What configuration.nix defines**:
1. Bootloader (systemd-boot)
2. Network configuration
3. Users and authentication
4. System packages (openssh, qemu-guest-agent, cloud-init)
5. Services (sshd, qemu-guest-agent)
6. Firewall rules

**Sample configuration.nix structure**:
```nix
{ config, pkgs, ... }:

{
  # Boot loader
  boot.loader.systemd-boot.enable = true;

  # Network
  networking.useDHCP = true;

  # Users
  users.users.root.initialPassword = "nixos";

  # Packages
  environment.systemPackages = with pkgs; [
    vim git htop openssh qemu-guest-agent cloud-init
  ];

  # Services
  services.openssh.enable = true;
  services.qemuGuest.enable = true;

  # Cloud-init
  services.cloud-init.enable = true;
}
```

### Step 3: Understand NixOS Installation Process

NixOS installation is declarative:

1. Boot NixOS ISO
2. Partition disks
3. Generate hardware configuration
4. Create configuration.nix
5. Run `nixos-install` (builds system from configuration)
6. Reboot into installed system

The Packer template automates all these steps via `http/install.sh`.

---

## Part 2: Build Golden Image with Packer

### Step 1: Configure Packer Variables

```bash
cd packer/nixos

# Copy example configuration
cp nixos.auto.pkrvars.hcl.example nixos.auto.pkrvars.hcl

# Edit configuration
vim nixos.auto.pkrvars.hcl
```

**Required settings**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx"
proxmox_node     = "pve"
proxmox_skip_tls_verify = true

# NixOS ISO (choose stable or unstable)
nixos_iso_url = "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso"
nixos_iso_checksum = "file:https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso.sha256"

# Template Configuration
template_name        = "nixos-golden-template"
template_description = "NixOS 24.05 stable with cloud-init"
vm_id                = 9400

# VM Hardware
vm_cores  = 2
vm_memory = 2048
vm_disk_size    = "30G"  # NixOS needs more space for nix store
vm_disk_storage = "tank"
vm_cpu_type     = "host"

# Network
vm_network_bridge = "vmbr0"

# SSH Configuration (for Packer provisioning)
ssh_username = "root"
ssh_password = "nixos"  # Changed after first boot via cloud-init
ssh_timeout  = "30m"    # NixOS install can take time
```

### Step 2: Build the Template

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build Process**:
1. Packer creates VM and attaches NixOS ISO
2. Boots into NixOS live environment
3. Sets root password and starts SSH
4. Runs install.sh:
   - Partitions disk (UEFI boot + root)
   - Mounts partitions
   - Generates hardware-configuration.nix
   - Copies configuration.nix from HTTP server
   - Runs `nixos-install` (downloads and builds system)
5. Reboots into installed NixOS
6. Updates system (`nixos-rebuild switch --upgrade`)
7. Configures cloud-init
8. Cleans up and converts VM to template

**Build Time**: ~25-35 minutes (NixOS builds everything from source/cache)

**Watch Progress**:
- Open Proxmox UI → VM 9400 → Console
- You'll see: Live boot → Partitioning → nixos-install → Reboot → Configuration

**Note**: First build downloads many packages - subsequent builds are faster due to caching.

### Step 3: Verify Template

```bash
# SSH to Proxmox host
ssh root@proxmox

# List templates
qm list | grep -i template
# Should show: nixos-golden-template

# Check template configuration
qm config 9400

# Verify it's marked as template
qm config 9400 | grep template
# Should show: template: 1

# Verify cloud-init drive exists
qm config 9400 | grep ide2
# Should show: ide2: tank:vm-9400-cloudinit
```

---

## Part 3: Deploy VM with Terraform

### Step 1: Configure Terraform Variables

```bash
cd ../../terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Key settings for NixOS VM**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx"
proxmox_node     = "pve"

# NixOS VM Configuration
deploy_nixos_vm    = true
nixos_template_name = "nixos-golden-template"
nixos_vm_name      = "nixos-prod-01"
nixos_vm_id        = 400

# Resources
nixos_cores  = 4
nixos_memory = 8192  # 8GB RAM

# Networking
nixos_ip      = "192.168.1.130"
nixos_netmask = "24"
nixos_gateway = "192.168.1.1"
dns_servers   = ["8.8.8.8", "1.1.1.1"]

# Cloud-init User
nixos_user     = "wdiaz"
nixos_password = "your-secure-password"  # Change this!
```

### Step 2: Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

**Terraform will**:
1. Look up template "nixos-golden-template" on Proxmox
2. Clone template → create new VM (ID 400)
3. Configure resources (4 cores, 8GB RAM)
4. Apply cloud-init configuration (hostname, IP, user)
5. Start VM

**Deploy Time**: ~2-3 minutes

### Step 3: Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Should show:
# nixos_vm_id = "400"
# nixos_vm_ip = "192.168.1.130"
# nixos_vm_name = "nixos-prod-01"
```

**In Proxmox UI**:
1. Navigate to VM 400
2. Check console - should show boot process
3. Verify cloud-init ran: `Console → systemctl status cloud-init`

**Test SSH Access**:
```bash
# Wait ~60 seconds for cloud-init to complete
sleep 60

# SSH to new VM
ssh wdiaz@192.168.1.130

# Verify NixOS version
nixos-version

# Check current configuration
cat /etc/nixos/configuration.nix

# Verify system packages
which vim git htop
```

---

## Part 4: Managing NixOS VMs

### Declarative Configuration

NixOS uses `/etc/nixos/configuration.nix` to define entire system state:

```bash
# SSH to VM
ssh wdiaz@192.168.1.130

# Edit configuration
sudo vim /etc/nixos/configuration.nix
```

**Example: Add packages**:
```nix
environment.systemPackages = with pkgs; [
  vim
  git
  htop
  docker
  postgresql
  nginx
];
```

**Apply changes**:
```bash
# Rebuild and switch to new configuration
sudo nixos-rebuild switch

# Or test without switching permanently
sudo nixos-rebuild test

# Or build but don't activate (for testing)
sudo nixos-rebuild build
```

### Update System

NixOS updates are declarative:

```bash
# Update channel (stable to latest stable, or stable to unstable)
sudo nix-channel --list
sudo nix-channel --update

# Rebuild with updated packages
sudo nixos-rebuild switch --upgrade

# Verify new generation
nixos-version
```

### Rollback System

NixOS keeps all previous configurations:

```bash
# List all system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or boot into specific generation from GRUB menu
```

### Garbage Collection

Clean up old generations and packages:

```bash
# Delete old generations (keep last 5)
sudo nix-collect-garbage --delete-older-than 5d

# Delete all old generations and optimize store
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

---

## Troubleshooting

### Issue: nixos-install fails during Packer build

**Symptoms**:
```
error: unable to download <package>
```

**Solutions**:
1. Check internet connectivity on Proxmox host
2. Verify DNS is working
3. Try different NixOS channel/mirror
4. Increase `ssh_timeout` in `nixos.auto.pkrvars.hcl` to "45m"
5. Check `/var/log/nixos-install.log` for detailed errors

### Issue: Packer SSH timeout after reboot

**Symptoms**:
```
Timeout waiting for SSH after reboot
```

**Solutions**:
1. Increase `ssh_timeout` to "30m" (NixOS boot can be slow first time)
2. Check SSH service started: View Proxmox console
3. Verify sshd is enabled in configuration.nix
4. Ensure DHCP is available on network bridge

### Issue: Terraform can't find template

**Symptoms**:
```
Error: Template 'nixos-golden-template' not found
```

**Solutions**:
1. Verify template exists: `ssh root@proxmox 'qm list | grep 9400'`
2. Check template name matches exactly
3. Ensure VM 9400 is marked as template: `qm config 9400 | grep template`
4. Rebuild template: `cd packer/nixos && packer build .`

### Issue: Cloud-init not working

**Symptoms**:
- Cloud-init user not created
- Network not configured

**Solutions**:
1. Verify cloud-init is enabled in configuration.nix:
   ```nix
   services.cloud-init.enable = true;
   services.cloud-init.network.enable = true;
   ```
2. Check cloud-init status: `ssh root@192.168.1.130 'cloud-init status --long'`
3. View cloud-init logs: `journalctl -u cloud-init`
4. Ensure cloud-init drive exists: `qm config 400 | grep ide2`

### Issue: nixos-rebuild fails

**Symptoms**:
```
error: unable to build derivation
```

**Solutions**:
1. Update channel: `sudo nix-channel --update`
2. Clear nix cache: `sudo nix-collect-garbage -d`
3. Check syntax in configuration.nix: `sudo nixos-rebuild dry-build`
4. Review error message for specific package issues
5. Rollback to previous working generation: `sudo nixos-rebuild switch --rollback`

### Issue: Disk space full

**Symptoms**:
```
error: No space left on device
```

**Solutions**:
1. NixOS stores all packages and generations - can use a lot of space
2. Clean up old generations: `sudo nix-collect-garbage --delete-older-than 7d`
3. Delete all old and optimize: `sudo nix-collect-garbage -d && sudo nix-store --optimise`
4. Increase disk size in template: Rebuild with larger `vm_disk_size`

---

## Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│           Day 0: Prepare NixOS ISO and Config               │
├─────────────────────────────────────────────────────────────┤
│ 1. Download NixOS minimal ISO (stable or unstable)          │
│ 2. Verify configuration.nix exists in http/ directory       │
│ 3. Review install.sh script                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         Day 1: Build Golden Image (25-35 min)               │
├─────────────────────────────────────────────────────────────┤
│ cd packer/nixos                                              │
│ cp nixos.auto.pkrvars.hcl.example nixos.auto.pkrvars.hcl   │
│ vim nixos.auto.pkrvars.hcl  # Set ISO URL and Proxmox config│
│ packer init .                                                │
│ packer build .                                               │
│ → Boots NixOS ISO                                            │
│ → Runs install.sh (partitions, generates hardware config)   │
│ → Copies configuration.nix from HTTP server                 │
│ → Runs nixos-install (builds entire system declaratively)   │
│ → Reboots into installed NixOS                              │
│ → Updates system (nixos-rebuild switch --upgrade)           │
│ → Configures cloud-init                                     │
│ → Creates template "nixos-golden-template"                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│          Day 2: Deploy Production VMs (2-3 min)             │
├─────────────────────────────────────────────────────────────┤
│ cd terraform                                                 │
│ cp terraform.tfvars.example terraform.tfvars                │
│ vim terraform.tfvars  # Configure VM settings                │
│ terraform init                                               │
│ terraform apply                                              │
│ → Clones template → creates VM (ID 400)                     │
│ → Configures resources (cores, RAM, disk)                   │
│ → Applies cloud-init (network, user, packages)              │
│ → Starts VM                                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│            Day 3: Manage Declaratively                       │
├─────────────────────────────────────────────────────────────┤
│ • Edit /etc/nixos/configuration.nix                         │
│ • Run: sudo nixos-rebuild switch                            │
│ • System updates with full rollback capability              │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Use Stable Channel for Production

```bash
# Stick with stable releases for servers
sudo nix-channel --add https://nixos.org/channels/nixos-24.05 nixos
sudo nix-channel --update

# Use unstable only for development/testing
```

### 2. Keep Configuration Under Version Control

```bash
# Store configuration.nix in Git
cd /etc/nixos
sudo git init
sudo git add configuration.nix hardware-configuration.nix
sudo git commit -m "Initial NixOS configuration"
```

### 3. Test Changes Before Applying

```bash
# Test new configuration without committing
sudo nixos-rebuild test

# If everything works, make it permanent
sudo nixos-rebuild switch

# If something breaks, just reboot (test config is temporary)
```

### 4. Regular Garbage Collection

```bash
# Monthly: Clean up old generations
sudo nix-collect-garbage --delete-older-than 30d

# After major updates: Full cleanup
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

### 5. Rebuild Template Quarterly

NixOS stable releases every 6 months:

```bash
# When new stable release is out, rebuild template
cd packer/nixos
# Update nixos_iso_url to new stable version
vim nixos.auto.pkrvars.hcl
packer build .
```

---

## NixOS-Specific Considerations

### Declarative Configuration

**Everything is code**:
- Package installation
- Service configuration
- User accounts
- Firewall rules
- System settings

**Advantages**:
- ✅ Reproducible systems
- ✅ Easy to version control
- ✅ Atomic upgrades and rollbacks
- ✅ No configuration drift

**Learning Curve**:
- ⚠️ Nix expression language
- ⚠️ Different from traditional Linux
- ⚠️ Requires understanding of NixOS module system

### Nix Store

All packages live in `/nix/store`:

```bash
# View nix store
ls /nix/store | head -20

# Disk usage
du -sh /nix/store

# Optimize store (deduplicate files)
sudo nix-store --optimise
```

**Implications**:
- Larger disk usage than traditional distros
- Multiple versions of same package can coexist
- Old generations keep their dependencies

### Generations and Rollback

Every `nixos-rebuild switch` creates a new generation:

```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Boot into specific generation (GRUB menu)
# Or: sudo /nix/var/nix/profiles/system-42-link/bin/switch-to-configuration switch
```

---

## Next Steps

1. ✅ Complete NixOS deployment
2. Learn Nix expression language: https://nixos.org/guides/nix-pills/
3. Explore NixOS options: `man configuration.nix`
4. Set up automated configuration backups (Git)
5. Build templates for other OS (Debian, Ubuntu, Arch, Windows)

---

## Related Documentation

- **Packer NixOS Template**: `packer/nixos/README.md`
- **Terraform Configuration**: `terraform/README.md`
- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **NixOS Wiki**: https://nixos.wiki/
- **Nix Pills**: https://nixos.org/guides/nix-pills/ (great tutorial)

---

**Last Updated**: 2025-11-23
**Maintained By**: wdiazux
