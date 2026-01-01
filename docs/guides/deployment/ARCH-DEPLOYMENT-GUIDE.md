# Arch Linux Golden Image: Complete Deployment Guide

**Date**: 2025-11-23
**Purpose**: Step-by-step guide for creating Arch Linux golden images with Packer and deploying VMs with Terraform

---

## Overview

This guide walks through the complete workflow:
1. **Day 0**: Prepare Arch Linux ISO and installation script
2. **Day 1**: Build golden image template with Packer (ISO-based install)
3. **Day 2**: Deploy production VMs from template with Terraform

**Total Time**: ~20-30 minutes (ISO download + installation + package updates)

---

## Prerequisites

### Tools Required

```bash
# Verify tool versions
packer version    # Should be 1.14.2+
terraform version # Should be 1.9.0+
ansible --version # Should be 2.16+
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

---

## Part 1: Day 0 - Prepare Arch Linux ISO

### Step 1: Get Latest Arch Linux ISO

Visit https://archlinux.org/download/ and find a mirror:

```bash
# Example mirror URLs (choose one closest to you)
# USA: https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso
# Europe: https://mirror.init7.net/archlinux/iso/latest/archlinux-x86_64.iso
# Asia: https://mirror.xtom.com.hk/archlinux/iso/latest/archlinux-x86_64.iso
```

**Note**: Arch Linux is a rolling release - always use the latest ISO.

### Step 2: Verify Installation Script

The Packer template uses an automated installation script located at `packer/arch/http/install.sh`.

```bash
cd packer/arch

# Verify install.sh exists
ls -la http/install.sh

# The script should be executable
chmod +x http/install.sh
```

**What install.sh does**:
1. Partitions disk (UEFI boot partition + root partition)
2. Formats partitions (FAT32 for boot, ext4 for root)
3. Installs base system with pacstrap
4. Configures fstab, timezone, locale
5. Installs essential packages: openssh, qemu-guest-agent, cloud-init, sudo
6. Enables systemd services
7. Sets up root password

---

## Part 2: Build Golden Image with Packer

### Step 1: Configure Packer Variables

```bash
cd packer/arch

# Copy example configuration
cp arch.auto.pkrvars.hcl.example arch.auto.pkrvars.hcl

# Edit configuration
vim arch.auto.pkrvars.hcl
```

**Required settings**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx"
proxmox_node     = "pve"
proxmox_skip_tls_verify = true

# Arch Linux ISO (always use latest)
arch_iso_url = "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
arch_iso_checksum = "file:https://mirror.rackspace.com/archlinux/iso/latest/sha256sums.txt"

# Template Configuration
template_name        = "arch-linux-golden-template"
template_description = "Arch Linux rolling release with cloud-init"
vm_id                = 9300

# VM Hardware
vm_cores  = 2
vm_memory = 2048
vm_disk_size    = "20G"
vm_disk_storage = "tank"
vm_cpu_type     = "host"

# Network
vm_network_bridge = "vmbr0"

# SSH Configuration (for Packer provisioning)
ssh_username = "root"
ssh_password = "arch"  # Changed after first boot via cloud-init
ssh_timeout  = "20m"   # Arch install can take time
```

### Step 2: Install Ansible Collections

```bash
cd ../../ansible

# Install required Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### Step 3: Build the Template

```bash
cd ../packer/arch

# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build Process**:
1. Packer creates VM and attaches Arch ISO
2. Boots into Arch live environment
3. Sets root password and starts SSH
4. Runs install.sh to install Arch to disk
5. Reboots into installed system
6. Runs pacman -Syu to update all packages
7. Runs Ansible playbook to install baseline packages
8. Configures cloud-init
9. Cleans up and converts VM to template

**Build Time**: ~20-30 minutes (depends on mirror speed and package updates)

**Watch Progress**:
- Open Proxmox UI → VM 9300 → Console
- You'll see: Live boot → Installation → Reboot → Updates → Provisioning

### Step 4: Verify Template

```bash
# SSH to Proxmox host
ssh root@proxmox

# List templates
qm list | grep -i template
# Should show: arch-linux-golden-template

# Check template configuration
qm config 9300

# Verify it's marked as template
qm config 9300 | grep template
# Should show: template: 1

# Verify cloud-init drive exists
qm config 9300 | grep ide2
# Should show: ide2: tank:vm-9300-cloudinit
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

**Key settings for Arch VM**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx"
proxmox_node     = "pve"

# Arch VM Configuration
deploy_arch_vm    = true
arch_template_name = "arch-linux-golden-template"
arch_vm_name      = "arch-prod-01"
arch_vm_id        = 300

# Resources
arch_cores  = 4
arch_memory = 8192  # 8GB RAM

# Networking
arch_ip      = "192.168.1.120"
arch_netmask = "24"
arch_gateway = "192.168.1.1"
dns_servers  = ["8.8.8.8", "1.1.1.1"]

# Cloud-init User
arch_user     = "wdiaz"
arch_password = "your-secure-password"  # Change this!
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
1. Look up template "arch-linux-golden-template" on Proxmox
2. Clone template → create new VM (ID 300)
3. Configure resources (4 cores, 8GB RAM)
4. Apply cloud-init configuration (hostname, IP, user)
5. Start VM

**Deploy Time**: ~2-3 minutes

### Step 3: Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Should show:
# arch_vm_id = "300"
# arch_vm_ip = "192.168.1.120"
# arch_vm_name = "arch-prod-01"
```

**In Proxmox UI**:
1. Navigate to VM 300
2. Check console - should show boot process
3. Verify cloud-init ran: `Console → systemctl status cloud-init`

**Test SSH Access**:
```bash
# Wait ~60 seconds for cloud-init to complete
sleep 60

# SSH to new VM
ssh wdiaz@192.168.1.120

# Verify baseline packages installed
htop
vim --version
git --version
python --version

# Verify Arch is up to date
uname -r
pacman -Qu  # Should show no updates (just built)
```

---

## Part 4: Post-Deployment Configuration (Optional)

### Option 1: Update System Packages

Arch is a rolling release - update regularly:

```bash
# SSH to VM
ssh wdiaz@192.168.1.120

# Update all packages
sudo pacman -Syu

# Clean package cache
sudo pacman -Scc
```

### Option 2: Install AUR Helper (yay)

For access to Arch User Repository:

```bash
# Install dependencies
sudo pacman -S base-devel git

# Clone yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay

# Build and install
makepkg -si

# Test yay
yay --version
```

### Option 3: Run Ansible Baseline Role

For instance-specific configuration:

```bash
cd ../../ansible

# Update inventory with new VM
vim inventory/production.ini

# Add:
# [arch_vms]
# arch-prod-01 ansible_host=192.168.1.120 ansible_user=wdiaz

# Run baseline playbook
ansible-playbook -i inventory/production.ini playbooks/baseline.yml
```

---

## Troubleshooting

### Issue: Packer build fails during install.sh

**Symptoms**:
```
Failed to execute install.sh
```

**Solutions**:
1. Verify install.sh exists: `ls -la packer/arch/http/install.sh`
2. Check script is executable: `chmod +x packer/arch/http/install.sh`
3. Review install.sh for syntax errors
4. Check Proxmox console for detailed error messages
5. Verify network connectivity during install

### Issue: Packer SSH timeout after reboot

**Symptoms**:
```
Timeout waiting for SSH after reboot
```

**Solutions**:
1. Increase `ssh_timeout` in `arch.auto.pkrvars.hcl` to "30m"
2. Check SSH service started: View Proxmox console, look for "sshd" in logs
3. Verify network configuration in install.sh
4. Ensure DHCP is available on network bridge
5. Check firewall settings on Proxmox host

### Issue: pacman -Syu fails during build

**Symptoms**:
```
Error: failed to synchronize all databases
```

**Solutions**:
1. Check internet connectivity on Proxmox host
2. Try different Arch mirror in ISO
3. Verify DNS is working: `systemctl status systemd-resolved`
4. Temporarily disable pacman signature checking (not recommended for production)
5. Wait and retry - mirrors occasionally have issues

### Issue: Terraform can't find template

**Symptoms**:
```
Error: Template 'arch-linux-golden-template' not found
```

**Solutions**:
1. Verify template exists: `ssh root@proxmox 'qm list | grep 9300'`
2. Check template name matches exactly
3. Ensure VM 9300 is marked as template: `qm config 9300 | grep template`
4. Rebuild template: `cd packer/arch && packer build .`

### Issue: Cloud-init not configuring user

**Symptoms**:
- Can't SSH with cloud-init user
- Only root account exists

**Solutions**:
1. Verify cloud-init is installed: `ssh root@192.168.1.120 'cloud-init --version'`
2. Check cloud-init status: `cloud-init status --long`
3. View cloud-init logs: `cat /var/log/cloud-init.log`
4. Ensure cloud-init services are enabled:
   ```bash
   systemctl status cloud-init
   systemctl status cloud-init-local
   systemctl status cloud-config
   systemctl status cloud-final
   ```
5. Verify cloud-init configuration in Terraform

### Issue: Rolling release breaks after update

**Symptoms**:
- System won't boot after pacman -Syu
- Missing dependencies

**Solutions**:
1. Boot into Arch ISO (attach to VM in Proxmox)
2. Mount root partition: `mount /dev/sda2 /mnt`
3. Arch-chroot into system: `arch-chroot /mnt`
4. Roll back problematic package: `pacman -U /var/cache/pacman/pkg/package-version.pkg.tar.zst`
5. Fix dependencies: `pacman -Syu`
6. Exit chroot and reboot
7. **Prevention**: Rebuild golden image monthly to avoid large update jumps

---

## Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│              Day 0: Prepare Arch Linux ISO                  │
├─────────────────────────────────────────────────────────────┤
│ 1. Download latest Arch ISO from mirror                     │
│ 2. Verify install.sh script exists                          │
│ 3. Get ISO checksum URL                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         Day 1: Build Golden Image (20-30 min)               │
├─────────────────────────────────────────────────────────────┤
│ cd packer/arch                                               │
│ cp arch.auto.pkrvars.hcl.example arch.auto.pkrvars.hcl     │
│ vim arch.auto.pkrvars.hcl  # Set ISO URL and Proxmox config │
│ packer init .                                                │
│ packer build .                                               │
│ → Boots Arch ISO                                             │
│ → Runs install.sh (partitions, installs base system)        │
│ → Reboots into installed Arch                               │
│ → Updates packages (pacman -Syu)                            │
│ → Runs Ansible provisioning (baseline packages)             │
│ → Configures cloud-init                                     │
│ → Creates template "arch-linux-golden-template"             │
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
│ → Clones template → creates VM (ID 300)                     │
│ → Configures resources (cores, RAM, disk)                   │
│ → Applies cloud-init (network, user, packages)              │
│ → Starts VM                                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│            Optional: Post-Deployment Config                  │
├─────────────────────────────────────────────────────────────┤
│ • Update system packages (pacman -Syu)                       │
│ • Install AUR helper (yay)                                   │
│ • Run Ansible baseline playbook                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Rebuild Template Monthly

Arch is a rolling release - keep templates fresh:

```bash
# Rebuild template monthly
cd packer/arch
packer build .

# Deploy new VMs from updated template
cd ../../terraform
terraform apply
```

**Why**: Prevents large update jumps that can cause breakage.

### 2. Test Updates in Staging First

Before updating production VMs:

```bash
# Deploy test VM
terraform apply -var="arch_vm_name=arch-test-01" -var="arch_vm_id=399"

# Update test VM
ssh wdiaz@<test-vm-ip> 'sudo pacman -Syu'

# Test applications
# If successful, update production

# Destroy test VM
terraform destroy -target=proxmox_virtual_environment_vm.arch
```

### 3. Use Snapshots Before Major Updates

```bash
# In Proxmox UI or CLI
qm snapshot 300 before-update --description "Before pacman -Syu $(date)"

# Update
ssh wdiaz@192.168.1.120 'sudo pacman -Syu'

# If successful, delete snapshot
# If failed, restore snapshot
```

### 4. Pin Critical Packages (Optional)

For production stability:

```bash
# Prevent specific packages from updating
sudo vim /etc/pacman.conf

# Add:
# IgnorePkg = linux linux-headers

# Update everything except ignored packages
sudo pacman -Syu
```

### 5. Monitor Arch News

Before major updates:

```bash
# Visit: https://archlinux.org/news/
# Read latest announcements for manual intervention requirements
```

---

## Arch Linux-Specific Considerations

### Rolling Release Nature

**Advantages**:
- ✅ Latest packages always available
- ✅ No version upgrades needed (unlike Ubuntu 22.04 → 24.04)
- ✅ Cutting-edge software

**Disadvantages**:
- ⚠️ Occasional breakage from updates
- ⚠️ Requires more maintenance
- ⚠️ Not ideal for "set and forget" servers

**Recommendation**: Use Arch for:
- Development workstations
- Testing latest software
- Learning Linux internals
- Environments where you can tolerate occasional issues

For production servers requiring stability, consider Debian or Ubuntu LTS instead.

### AUR (Arch User Repository)

The AUR provides community-maintained packages not in official repos:

```bash
# Install AUR helper (yay) on deployed VM
sudo pacman -S base-devel git
cd /tmp && git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si

# Install AUR packages
yay -S google-chrome
yay -S visual-studio-code-bin
```

**Security Note**: AUR packages are community-maintained. Review PKGBUILD before installing.

### Systemd-boot (Default Bootloader)

Arch uses systemd-boot instead of GRUB:

```bash
# List boot entries
bootctl list

# Update systemd-boot
sudo bootctl update

# View boot configuration
cat /boot/loader/loader.conf
```

---

## Next Steps

1. ✅ Complete Arch Linux deployment
2. Install AUR helper (yay) for additional packages
3. Set up automated monthly template rebuilds
4. Configure backup strategy (Proxmox snapshots + external backup)
5. Build templates for other OS (Debian, Ubuntu, NixOS, Windows)

---

## Related Documentation

- **Packer Arch Template**: `packer/arch/README.md`
- **Terraform Configuration**: `terraform/README.md`
- **Ansible Baseline Role**: `ansible/roles/baseline/README.md`
- **Arch Linux Wiki**: https://wiki.archlinux.org/
- **Arch Installation Guide**: https://wiki.archlinux.org/title/Installation_guide

---

**Last Updated**: 2025-11-23
**Maintained By**: wdiazux
