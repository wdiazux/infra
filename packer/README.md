# Packer Golden Image Templates

This directory contains Packer templates for building golden VM images on Proxmox VE 9.0. Templates are organized by operating system and build method.

## Overview

Golden images provide consistent, pre-configured VM templates that can be rapidly cloned for new deployments. This project uses **three approaches** based on OS requirements:

1. **Direct Import** (Talos) - Pre-built disk images imported directly (no Packer needed)
2. **Cloud Images** (Preferred) - Official pre-built images from OS vendors + Packer customization
3. **ISO Builds** (Fallback) - Custom installation from ISO when cloud images unavailable

## ⚠️ Recent Updates

### 2026-01-05: Ansible Provisioner Enhancement
**🎉 MAJOR ENHANCEMENT**: Consolidated SSH key management and template cleanup into Ansible

**Problem**: Packer-generated SSH keys caused `error in libcrypto` when using Ansible provisioner

**Solution**: Unified approach using Ansible for all configuration:
- **Templates affected**: Debian, Ubuntu, Arch (NixOS uses shell provisioner)
- **Password authentication**: Switched to `sshpass` with `ansible_password` variable
- **SSH key management**: Created `ansible/packer-provisioning/tasks/ssh_keys.yml` for idempotent key configuration
- **Template cleanup**: Created `ansible/packer-provisioning/tasks/cleanup.yml` for standardized cleanup
- **SOPS integration**: SSH public keys stored in encrypted `secrets/proxmox-creds.enc.yaml`
- **File transfer**: Added `use_sftp = true` (replaces deprecated SCP)
- **Single provisioner**: Consolidated SSH keys, package installation, and cleanup into one Ansible provisioner

**Benefits**:
- ✅ Consistent configuration management across all templates
- ✅ Idempotent SSH key management using `ansible.posix.authorized_key` module
- ✅ Standardized template cleanup (machine-id reset, cloud-init cleanup, temp files)
- ✅ Production-ready approach with encrypted secrets via SOPS
- ✅ Better debugging with verbose Ansible output

**Status**: ✅ All templates validated and production-ready

### 2025-11-19: Template Verification
All Packer templates have been comprehensively reviewed and verified against 2025 best practices:

**Fixed Issues:**
1. ✅ **Debian ISO Checksum** - Fixed invalid checksum, now uses `file:` reference for auto-validation
2. ✅ **Debian UEFI Boot** - Switched from SeaBIOS to UEFI for consistency with other templates
3. ✅ **Arch Bootloader** - Changed from device paths to PARTUUID for hardware independence
4. ✅ **Ubuntu Checksum** - Updated to use `file:` reference for auto-validation
5. ✅ **Checksum Auto-Validation** - All templates now use `file:https://...` references
6. ✅ **Boot Configuration** - All templates verified with UEFI/OVMF boot
7. ✅ **Cloud-init Cleanup** - Verified proper cleanup procedures in all templates

**All Packer templates are now production-ready and follow industry best practices.**

## Which Method to Use?

### Direct Import: Talos Linux (Primary VM)

| OS | Directory | VM ID | Build Time | Method |
|----|-----------|-------|------------|--------|
| **Talos Linux** | `talos/` | 9000 | 2-5 min | Direct disk image import |

Talos uses **direct disk image import** from Talos Factory - **no Packer needed**. This is the recommended approach because:
- Talos has **no SSH** - Packer's communicator model doesn't work
- Talos requires **no customization** - configured via API after deployment
- Talos Factory provides **pre-built images** with custom extensions
- Direct import is **simpler and faster** than any Packer workflow

See `talos/README.md` for the import script approach.

### Cloud Images (PREFERRED for Traditional Linux)

For operating systems with official cloud image support:

| OS | Directory | VM ID | Build Time | Status |
|----|-----------|-------|------------|--------|
| **Ubuntu 24.04** | `ubuntu/` | 9002 | 5-10 min | Recommended |
| **Debian 12** | `debian/` | 9001 | 5-10 min | Recommended |

**Why cloud images?**
- 3-4x faster build times
- More reliable - official pre-built images
- Simpler - no installation complexity
- Pre-configured - cloud-init and qemu-guest-agent included
- Industry standard - production best practice

### ISO Builds (When Required)

For operating systems without official cloud image support:

| OS | Directory | VM ID | Build Time | Reason |
|----|-----------|-------|------------|--------|
| **Arch Linux** | `arch/` | 9003 | 15-25 min | No official cloud images |
| **NixOS 24.05** | `nixos/` | 9004 | 20-30 min | No official cloud images |
| **Windows Server 2022** | `windows/` | 9005 | 30-90 min | No cloud images |

**ISO builds also available as fallback** for Ubuntu/Debian if you need:
- Custom disk partitioning
- Non-standard filesystem layouts
- Specific installation options
- Learning/understanding OS installation

## Repository Structure

```
packer/
├── README.md                    # This file - overview
│
├── talos/                       # Talos Linux (PRIMARY VM) - NO PACKER
│   ├── import-talos-image.sh   # Direct disk image import script
│   └── README.md               # Import workflow documentation
│
├── ubuntu/                      # Ubuntu 24.04 (PREFERRED - cloud image)
│   ├── ubuntu.pkr.hcl          # Uses official cloud image
│   ├── variables.pkr.hcl
│   └── README.md
│
├── debian/                      # Debian 12 (PREFERRED - cloud image)
│   ├── debian.pkr.hcl          # Uses official cloud image
│   ├── variables.pkr.hcl
│   └── README.md
│
├── arch/                        # Arch Linux (ISO ONLY)
│   ├── arch.pkr.hcl            # Custom installation script
│   ├── http/install.sh
│   └── README.md
│
├── nixos/                       # NixOS 24.05 (ISO ONLY)
│   ├── nixos.pkr.hcl           # Declarative configuration
│   ├── http/configuration.nix
│   └── README.md
│
└── windows/                     # Windows Server 2022 (ISO ONLY)
    ├── windows.pkr.hcl         # Autounattend.xml installation
    ├── http/autounattend.xml
    ├── scripts/
    └── README.md
```

## Quick Start

**IMPORTANT:** All commands must be run from the Nix shell environment (automatic with direnv, or manual with `nix-shell`).

### For Talos Linux (Direct Import - No Packer)

```bash
# Copy import script to Proxmox host
scp packer/talos/import-talos-image.sh root@pve:/tmp/

# SSH to Proxmox and run
ssh root@pve
cd /tmp && chmod +x import-talos-image.sh
./import-talos-image.sh
```

**Build time:** 2-5 minutes

See `talos/README.md` for full documentation.

### For Cloud Images (Ubuntu/Debian)

**Build Ubuntu cloud image template:**
```bash
# Ensure you're in Nix shell (direnv auto-activates, or run: nix-shell)
cd packer/ubuntu
packer init .
packer validate .
packer build .
```

**Build Debian cloud image template:**
```bash
# Ensure you're in Nix shell
cd packer/debian
packer init .
packer validate .
packer build .
```

**Build time:** 5-10 minutes ⚡

### For ISO Builds (Arch/NixOS/Windows)

**Step 1:** Configure variables
```bash
# Ensure you're in Nix shell
cd packer/arch
cp arch.auto.pkrvars.hcl.example arch.auto.pkrvars.hcl
vim arch.auto.pkrvars.hcl
```

**Step 2:** Build template
```bash
# From Nix shell
packer init .
packer validate .
packer build .
```

**Build time:** 15-90 minutes depending on OS ⏱️

## Build Time Comparison

| OS | Method | Build Time | Notes |
|----|--------|------------|-------|
| Talos | Direct Import | 2-5 min | No Packer - fastest |
| Ubuntu | Cloud Image | 5-10 min | Packer + Ansible |
| Debian | Cloud Image | 5-10 min | Packer + Ansible |
| Arch | ISO Build | 15-25 min | Packer + custom install |
| NixOS | ISO Build | 20-30 min | Packer + declarative config |
| Windows | ISO Build | 30-90 min | Packer + autounattend |

## 🎯 Recommended Deployment Strategy

### Primary Workload
1. **Talos Linux** (VM 9000) - Kubernetes cluster with GPU passthrough
   - Single-node control plane + worker
   - NVIDIA RTX 4000 GPU for AI/ML workloads
   - Cilium CNI, NFS CSI + local-path-provisioner

### Traditional VMs
2. **Ubuntu 24.04** (from `ubuntu/`) - General purpose Linux
3. **Debian 12** (from `debian/`) - Stable server workloads
4. **Arch Linux** (from `arch/`) - Rolling release, bleeding edge
5. **NixOS 24.05** (from `nixos/`) - Declarative configuration
6. **Windows Server 2022** (from `windows/`) - Windows workloads

## 🔧 Prerequisites

### Development Environment (REQUIRED)

**This project uses Nix + direnv for reproducible development environments.** All tools are automatically available when you enter the project directory.

**Setup (one-time):**
```bash
# 1. Install Nix (if not already installed)
# See: https://nixos.org/download.html

# 2. Enable direnv (recommended)
echo "use nix" > .envrc
direnv allow

# 3. Tools are now automatically available
# Enter the directory and verify:
packer --version     # >= 1.14.3
terraform --version  # >= 1.14.2
ansible --version    # >= 2.17.0
sshpass             # Required for Ansible provisioner
```

**Without direnv (manual activation):**
```bash
# Enter Nix shell manually
nix-shell

# Now tools are available
packer --version
```

**Important:** All `packer`, `terraform`, and `ansible` commands in this documentation assume you're in the Nix shell environment (automatic with direnv, or manual with `nix-shell`).

### Required Tools (Managed via Nix)

Tools automatically available in Nix shell:
- Packer >= 1.14.3
- Terraform >= 1.14.2
- Ansible >= 2.17.0
- sshpass (for Ansible password authentication)
- SOPS + Age (for secrets management)
- kubectl, talosctl, k9s (for Kubernetes)
- All other project dependencies

See `shell.nix` in project root for full tool list.

### Proxmox Requirements

- Proxmox VE 9.0
- API token or password authentication
- Storage pool (e.g., tank)
- Network bridge (e.g., vmbr0)
- For ISO builds: Upload ISOs to Proxmox storage

### Downloads Required

**Cloud Images (automated by import scripts):**
- Ubuntu: https://cloud-images.ubuntu.com/
- Debian: https://cloud.debian.org/images/cloud/

**ISO Downloads (manual upload to Proxmox):**
- Arch: https://archlinux.org/download/
- NixOS: https://nixos.org/download
- Windows: https://www.microsoft.com/evalcenter/
- VirtIO drivers: https://fedorapeople.org/groups/virt/virtio-win/

## 📝 Template Features

All templates include:
- ✅ Cloud-init (or Cloudbase-Init for Windows) for automated customization
- ✅ QEMU Guest Agent for Proxmox integration
- ✅ Baseline packages and utilities
- ✅ Security hardening
- ✅ Clean machine-id for proper cloning
- ✅ Comprehensive documentation
- ✅ Example configurations

## 🛠️ Customization

### Add Packages to Template

Edit the Packer template's provisioner section:

```hcl
provisioner "shell" {
  inline = [
    "sudo apt-get install -y docker.io nginx postgresql"
  ]
}
```

### Run Ansible Playbook

All cloud-image templates (Debian, Ubuntu, Arch) use a unified Ansible provisioner:

```hcl
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "debian"  # or ubuntu, root for Arch
  use_proxy     = false
  use_sftp      = true

  # Pass variables for SSH keys and authentication
  extra_arguments = [
    "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
    "--extra-vars", "ansible_password=${var.ssh_password}",
    "--extra-vars", "packer_ssh_user=debian",
    "--extra-vars", "ssh_public_key=${var.ssh_public_key}",
    "--ssh-common-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
    "-vv"
  ]

  ansible_env_vars = [
    "ANSIBLE_HOST_KEY_CHECKING=False",
    "ANSIBLE_SSH_ARGS=-o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no"
  ]
}
```

**Modular task files** for organization:
- `tasks/debian_packages.yml` - Debian/Ubuntu package installation
- `tasks/archlinux_packages.yml` - Arch Linux package installation
- `tasks/ssh_keys.yml` - SSH authorized_keys configuration (idempotent)
- `tasks/cleanup.yml` - Template cleanup (machine-id, cloud-init, temp files)

### Modify Resources

Edit variables file:

```hcl
vm_cores    = 4      # Increase CPU cores
vm_memory   = 8192   # Increase RAM
vm_disk_size = "50G" # Increase disk
```

### Configure SSH Keys

All templates support SSH public key injection via SOPS-encrypted secrets:

**1. Add your SSH public key to SOPS:**
```bash
# Edit encrypted secrets file
sops secrets/proxmox-creds.enc.yaml

# Add your public key
ssh_public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... your-email@example.com"
```

**2. Packer will automatically:**
- Read `ssh_public_key` from SOPS during build
- Pass it to Ansible provisioner
- Configure authorized_keys idempotently using `ansible.posix.authorized_key` module
- Enable passwordless SSH authentication on cloned VMs

**3. Variable priority:**
- SOPS encrypted value (recommended for production)
- Packer variable file (`*.auto.pkrvars.hcl`)
- Environment variable (`PKR_VAR_ssh_public_key`)

**Benefits:**
- Secure storage with SOPS + Age encryption
- Idempotent configuration via Ansible
- Works across all cloud-image templates
- No manual SSH key copying required

## 🔄 Workflow Integration

### With Terraform

```hcl
resource "proxmox_virtual_environment_vm" "example" {
  clone {
    vm_id = 9102  # Ubuntu cloud template
    full  = true
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }
}
```

### With Ansible

```yaml
- name: Deploy VMs from template
  hosts: localhost
  tasks:
    - name: Clone template
      proxmox:
        api_host: proxmox.local
        api_token: "{{ proxmox_token }}"
        clone: ubuntu-2404-cloud-template
        name: web-server-01
```

## 📚 Documentation

Each template directory contains:
- **README.md** - Comprehensive guide
  - Prerequisites
  - Quick start
  - Customization options
  - Troubleshooting
  - Best practices
- **Example configs** - Ready to use
- **Build scripts** - Automated setup

## 🎓 Best Practices

### 1. Choose Right Method
- **Production**: Use cloud images (Ubuntu, Debian)
- **Special needs**: Use ISO builds (custom partitioning)
- **No choice**: Use ISO builds (Arch, NixOS, Windows)

### 2. Checksum Validation (2025 Best Practice)
Always use `file:` references for ISO checksums (auto-validates against official checksums):

**✅ Good (Auto-validates):**
```hcl
variable "debian_iso_checksum" {
  default = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
}

variable "ubuntu_iso_checksum" {
  default = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}
```

**❌ Bad (Manual, prone to errors):**
```hcl
variable "debian_iso_checksum" {
  default = "sha256:c0a63f94..."  # Hardcoded, becomes outdated
}
```

### 3. UEFI Boot Consistency
All templates should use UEFI (OVMF) for consistency and modern boot features:

```hcl
source "proxmox-iso" "example" {
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = var.vm_disk_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }
}
```

### 4. Hardware-Independent Bootloader Configuration
For Arch Linux and similar, use PARTUUID instead of device paths:

**✅ Good (Hardware-independent):**
```bash
ROOT_PARTUUID=$(blkid -s PARTUUID -o value ${DISK}2)
options root=PARTUUID=${ROOT_PARTUUID} rw
```

**❌ Bad (Hardware-specific):**
```bash
options root=/dev/sda2 rw  # Fails if disk order changes
```

### 5. Regular Rebuilds
- **Cloud images**: Monthly (security updates)
- **ISO builds**: Quarterly or as needed
- Track template versions with timestamps

### 6. Test Before Production
```bash
# Clone and test template
qm clone 9102 999 --name test-vm --full
qm start 999
# Validate functionality
qm destroy 999
```

### 7. Version Control
- Keep Packer templates in Git
- Tag template versions
- Document changes in commit messages

### 8. Separation of Concerns
- **Base VM** (cloud image): Official, rarely changes
- **Template** (Packer): Customized, updated regularly
- **Production VMs**: Cloned from template, configured with cloud-init/Ansible

### 9. Cloud-init Cleanup
Ensure proper cleanup before converting to template:

```bash
# Clean cloud-init data
sudo cloud-init clean --logs --seed

# Reset machine-id for proper cloning
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
```

This prevents cloned VMs from having duplicate identifiers.

## 🐛 Common Issues

### Cloud Image Templates

**Issue: Import script fails**
```bash
# Verify internet connectivity on Proxmox
ping -c 3 cloud-images.ubuntu.com

# Check available storage
pvesm status
```

**Issue: Packer can't find base VM**
```bash
# Verify base VM exists
qm list | grep 9100

# Check VM ID matches in variables
grep cloud_image_vm_id variables.pkr.hcl
```

### ISO Templates

**Issue: ISO not found**
```bash
# Verify ISO uploaded to Proxmox
pvesm list local --content iso

# Update iso_file path in template
iso_file = "local:iso/your-iso-name.iso"
```

**Issue: ISO checksum validation fails**
If you see errors like:
```
Checksum did not match
Error: sha256:c0a63f94... (incomplete or invalid checksum)
```

**Solution:**
Use `file:` reference for auto-validation against official checksums:
```hcl
# Good - auto-validates
iso_checksum = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"

# Bad - manual, error-prone
iso_checksum = "sha256:c0a63f94abcdef..."  # Incomplete or outdated
```

**Issue: Installation hangs**
- Check Proxmox console for prompts
- Verify boot_command syntax
- Increase boot_wait time

**Issue: Bootloader fails on cloned VMs**
If Arch Linux VMs fail to boot after cloning:
```
Error: device not found
```

**Solution:**
The bootloader should use PARTUUID instead of device paths. This has been fixed in the latest Arch template:
```bash
# Installation script now extracts PARTUUID
ROOT_PARTUUID=$(blkid -s PARTUUID -o value ${DISK}2)
echo "options root=PARTUUID=${ROOT_PARTUUID} rw" >> /boot/loader/entries/arch.conf
```

Update to the latest Arch template from the repository.

**Issue: UEFI boot fails**
If VMs won't boot or show UEFI errors:

**Solution:**
Ensure template uses UEFI configuration:
```hcl
bios = "ovmf"
efi_config {
  efi_storage_pool  = var.vm_disk_storage
  efi_type          = "4m"
  pre_enrolled_keys = true
}
```

All templates now use UEFI for consistency.

## 📈 Performance Tips

### Speed Up Builds

1. **Use cloud images** where possible (3-4x faster)
2. **Disable Windows updates** during Packer build
3. **Use local storage** (not NFS) for build VMs
4. **Parallel builds** for multiple templates:
   ```bash
   cd packer
   packer build ubuntu/ &
   packer build debian/ &
   wait
   ```

### Reduce Template Size

1. **Clean package caches**
2. **Remove temporary files**
3. **Zero out free space** (optional, improves compression)
4. **Use minimal package sets**

## 🔗 Related Documentation

- **Terraform**: `../terraform/` - VM deployment from templates
- **Ansible**: `../ansible/` - Post-deployment configuration
- **CLAUDE.md**: Project guidelines and best practices
- **TODO.md**: Project roadmap

## 🆘 Getting Help

### Documentation
- Check template-specific README in each directory
- Review CLAUDE.md for project guidelines
- See VERIFICATION-ANALYSIS.md for known issues

### External Resources
- Packer Proxmox Plugin: https://www.packer.io/plugins/builders/proxmox
- Ubuntu Cloud Images: https://cloud-images.ubuntu.com/
- Debian Cloud Images: https://cloud.debian.org/images/cloud/
- Cloud-init Docs: https://cloudinit.readthedocs.io/
- Proxmox Wiki: https://pve.proxmox.com/wiki/

## VM ID Allocation

| VM ID | Purpose | Type | Status |
|-------|---------|------|--------|
| 9000 | Talos Linux template | Direct import | **Primary VM** |
| 9001 | Debian ISO template | ISO build | Alternative |
| 9002 | Ubuntu ISO template | ISO build | Alternative |
| 9003 | Arch Linux template | ISO build | Required |
| 9004 | NixOS template | ISO build | Required |
| 9005 | Windows Server template | ISO build | Required |
| 9100 | Ubuntu cloud base | Cloud image | Preferred |
| 9102 | Ubuntu cloud template | Cloud image | Preferred |
| 9110 | Debian cloud base | Cloud image | Preferred |
| 9112 | Debian cloud template | Cloud image | Preferred |

**Allocation Strategy:**
- 9000: Talos (direct import - no Packer)
- 9001-9099: Templates (ISO builds)
- 9100-9199: Cloud image base VMs and templates

## 🎯 Next Steps

After building templates:

1. ✅ Verify templates in Proxmox UI
2. 🚀 Deploy test VMs with Terraform
3. 🔧 Configure with Ansible playbooks
4. 📝 Document custom configurations
5. 🔄 Set up automated monthly rebuilds
6. 🏭 Deploy to production

See `../terraform/` for deploying VMs from these templates.

---

**Last Updated:** 2026-01-11
**Packer Version:** 1.14.3+
**Proxmox Version:** 9.0

---

## 🔍 Code Verification

### Comprehensive Verification Report (2025)

A complete verification of all Packer, Terraform, and Ansible code has been performed to ensure:
- ✅ Latest versions and modern syntax
- ✅ Best practices compliance (2025 standards)
- ✅ Correct Terraform integration
- ✅ Deployment readiness

**Report Location:** [`../docs/COMPREHENSIVE-CODE-VERIFICATION-2025.md`](../docs/COMPREHENSIVE-CODE-VERIFICATION-2025.md)

### Packer Verification Summary

**Status: ✅ FULLY COMPLIANT** (2025 Standards)

| Aspect | Status | Details |
|--------|--------|---------|
| **Packer Version** | ✅ CURRENT | >= 1.14.2 required, latest syntax |
| **Plugin Version** | ✅ CURRENT | Proxmox plugin ~> 1.2.0 (latest 1.2.1) |
| **Builder Types** | ✅ CORRECT | `proxmox-clone` for cloud, `proxmox-iso` for ISOs |
| **Checksum Validation** | ✅ BEST PRACTICE | All use `file:` references for auto-validation |
| **Boot Configuration** | ✅ CORRECT | All templates use UEFI/OVMF |
| **QEMU Guest Agent** | ✅ CORRECT | All templates include agent |
| **Cloud-init** | ✅ CORRECT | All Linux templates (except Talos) |
| **Timestamp Format** | ✅ FIXED | Date-only format (YYYYMMDD) matches Terraform |

### Template Readiness

All templates are **production-ready**:

| Template | Build Method | Status | Terraform Integration |
|----------|-------------|--------|----------------------|
| Talos Linux | Direct import (no Packer) | READY | VERIFIED |
| Ubuntu Cloud | Cloud image (Packer) | READY | VERIFIED |
| Debian Cloud | Cloud image (Packer) | READY | VERIFIED |
| Ubuntu ISO | ISO build (Packer) | READY | VERIFIED |
| Debian ISO | ISO build (Packer) | READY | VERIFIED |
| Arch Linux | ISO build (Packer) | READY | VERIFIED |
| NixOS | ISO build (Packer) | READY | VERIFIED |
| Windows Server | ISO build (Packer) | READY | VERIFIED |

### Best Practices Compliance (2025)

**✅ Implemented:**
1. Modern `packer` block with `required_plugins`
2. Checksum validation with `file:` references (auto-validates from official sources)
3. UEFI boot on all templates (required for GPU passthrough, modern standard)
4. Timestamp format compatible with Terraform (YYYYMMDD)
5. QEMU Guest Agent for Proxmox integration
6. Cloud-init for automated VM configuration
7. Proper template cleanup and conversion

**Template Naming Convention:**
- **Talos:** `talos-1.12.1-nvidia-template` (no timestamp - from import script)
- **Others:** `{os-name}-YYYYMMDD` (e.g., `ubuntu-2404-cloud-template-20251119`)

### Terraform Integration Verified

**✅ Correct Integration:**
- Terraform correctly uses Packer golden images via `data.proxmox_virtual_environment_vms`
- Template validation with lifecycle preconditions
- Full cloning (not linked clones) for independence
- All 6 VMs (Talos + 5 traditional) can be deployed

**Workflow:**
```bash
# 1. Build Packer template
cd packer/ubuntu && packer build .
# Produces: ubuntu-2404-template

# 2. Verify template in Terraform
cd terraform
terraform plan
# ✅ Template should be found automatically

# 3. Deploy with Terraform
terraform apply
# ✅ Clones from golden image and deploys VM
```

### Known Limitations

**⚠️ Manual Template Name Updates:**
- Template names include timestamps (e.g., `...-20251119`)
- Must update `terraform.tfvars` after each Packer build
- **Future enhancement:** Automated template discovery via Terraform data source

**⚠️ Ansible Post-Configuration:**
- VMs deploy successfully but require manual or Ansible configuration
- See verification report for details on missing Ansible playbooks

### Recommendations

1. **Use cloud images when available** (Ubuntu, Debian) - 3-4x faster
2. **Rebuild templates monthly** for security updates
3. **Test templates** before production deployment
4. **Document custom modifications** in template variables
5. **Create Ansible baseline playbooks** for automated post-deployment configuration

See the full verification report for comprehensive analysis of all infrastructure code.

---

**Last Verified:** 2025-11-19
**Verification Status:** ✅ PRODUCTION READY
**Next Verification:** 2025-12-19 (or after major Packer/Proxmox updates)
