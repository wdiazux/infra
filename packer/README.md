# Packer Golden Image Templates

This directory contains Packer templates for building golden VM images on Proxmox VE 9.0. Templates are organized by operating system and build method.

## 📖 Overview

Golden images provide consistent, pre-configured VM templates that can be rapidly cloned for new deployments. This project uses **two approaches** based on OS support:

1. **Cloud Images** (Preferred) - Official pre-built images from OS vendors
2. **ISO Builds** (Fallback) - Custom installation from ISO when cloud images unavailable

## 🎯 Which Method to Use?

### ✅ Use Cloud Images (PREFERRED)

For operating systems with official cloud image support:

| OS | Directory | VM IDs | Build Time | Status |
|----|-----------|--------|------------|--------|
| **Ubuntu 24.04** | `ubuntu-cloud/` | 9100→9102 | 5-10 min | ✅ **Recommended** |
| **Debian 12** | `debian-cloud/` | 9110→9112 | 5-10 min | ✅ **Recommended** |

**Why cloud images?**
- ⚡ **3-4x faster** build times
- ✅ **More reliable** - official pre-built images
- 🎯 **Simpler** - no installation complexity
- 📦 **Pre-configured** - cloud-init and qemu-guest-agent included
- 🔄 **Industry standard** - production best practice

### ⚠️ Use ISO Builds (When Required)

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

### 🚀 Special Case: Talos Linux (Primary VM)

| OS | Directory | VM ID | Build Time | Method |
|----|-----------|-------|------------|--------|
| **Talos Linux** | `talos/` | 9000 | 10-15 min | Talos Factory images |

Talos uses **Factory-generated images** (similar concept to cloud images) with custom extensions.

## 📁 Repository Structure

```
packer/
├── README.md                    # This file - overview
│
├── talos/                       # Talos Linux (PRIMARY VM)
│   ├── talos.pkr.hcl           # Factory image with NVIDIA extensions
│   ├── variables.pkr.hcl
│   └── README.md
│
├── debian-cloud/                # ✨ Debian 12 (PREFERRED)
│   ├── debian-cloud.pkr.hcl    # Uses official cloud image
│   ├── import-cloud-image.sh   # One-time setup script
│   ├── variables.pkr.hcl
│   └── README.md
│
├── debian/                      # Debian 12 (ISO fallback)
│   ├── debian.pkr.hcl          # Uses ISO with preseed
│   ├── http/preseed.cfg
│   └── README.md
│
├── ubuntu-cloud/                # ✨ Ubuntu 24.04 (PREFERRED)
│   ├── ubuntu-cloud.pkr.hcl    # Uses official cloud image
│   ├── import-cloud-image.sh   # One-time setup script
│   ├── variables.pkr.hcl
│   └── README.md
│
├── ubuntu/                      # Ubuntu 24.04 (ISO fallback)
│   ├── ubuntu.pkr.hcl          # Uses ISO with autoinstall
│   ├── http/user-data
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

## 🚀 Quick Start

### For Cloud Images (Ubuntu/Debian)

**Step 1:** Import cloud image (one-time setup on Proxmox host)
```bash
cd packer/ubuntu-cloud
./import-cloud-image.sh
```

**Step 2:** Build customized template
```bash
packer init .
packer validate .
packer build .
```

**Build time:** 5-10 minutes ⚡

### For ISO Builds (Arch/NixOS/Windows)

**Step 1:** Configure variables
```bash
cd packer/arch
cp arch.auto.pkrvars.hcl.example arch.auto.pkrvars.hcl
vim arch.auto.pkrvars.hcl
```

**Step 2:** Build template
```bash
packer init .
packer validate .
packer build .
```

**Build time:** 15-90 minutes depending on OS ⏱️

## 📊 Build Time Comparison

| OS | Cloud Image | ISO Build | Speedup |
|----|-------------|-----------|---------|
| Ubuntu | 5-10 min | 20-30 min | **3-4x faster** |
| Debian | 5-10 min | 20-30 min | **3-4x faster** |
| Arch | N/A | 15-25 min | - |
| NixOS | N/A | 20-30 min | - |
| Windows | N/A | 30-90 min | - |
| Talos | 10-15 min | N/A | Factory images |

## 🎯 Recommended Deployment Strategy

### Primary Workload
1. **Talos Linux** (VM 9000) - Kubernetes cluster with GPU passthrough
   - Single-node control plane + worker
   - NVIDIA RTX 4000 GPU for AI/ML workloads
   - Cilium CNI, NFS CSI + local-path-provisioner

### Traditional VMs
2. **Ubuntu 24.04** (from `ubuntu-cloud/`) - General purpose Linux
3. **Debian 12** (from `debian-cloud/`) - Stable server workloads
4. **Arch Linux** (from `arch/`) - Rolling release, bleeding edge
5. **NixOS 24.05** (from `nixos/`) - Declarative configuration
6. **Windows Server 2022** (from `windows/`) - Windows workloads

## 🔧 Prerequisites

### Required Tools

```bash
# Packer 1.14.2+
packer --version

# For cloud images (optional, for manual verification)
wget --version
qm --version  # On Proxmox host
```

### Proxmox Requirements

- Proxmox VE 9.0
- API token or password authentication
- Storage pool (e.g., local-zfs)
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

Add ansible provisioner:

```hcl
provisioner "ansible" {
  playbook_file = "../ansible/playbooks/baseline.yml"
}
```

### Modify Resources

Edit variables file:

```hcl
vm_cores    = 4      # Increase CPU cores
vm_memory   = 8192   # Increase RAM
vm_disk_size = "50G" # Increase disk
```

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

### 2. Regular Rebuilds
- **Cloud images**: Monthly (security updates)
- **ISO builds**: Quarterly or as needed
- Track template versions with timestamps

### 3. Test Before Production
```bash
# Clone and test template
qm clone 9102 999 --name test-vm --full
qm start 999
# Validate functionality
qm destroy 999
```

### 4. Version Control
- Keep Packer templates in Git
- Tag template versions
- Document changes in commit messages

### 5. Separation of Concerns
- **Base VM** (cloud image): Official, rarely changes
- **Template** (Packer): Customized, updated regularly
- **Production VMs**: Cloned from template, configured with cloud-init/Ansible

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

**Issue: Installation hangs**
- Check Proxmox console for prompts
- Verify boot_command syntax
- Increase boot_wait time

## 📈 Performance Tips

### Speed Up Builds

1. **Use cloud images** where possible (3-4x faster)
2. **Disable Windows updates** during Packer build
3. **Use local storage** (not NFS) for build VMs
4. **Parallel builds** for multiple templates:
   ```bash
   packer build ubuntu-cloud/ &
   packer build debian-cloud/ &
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

## 📊 VM ID Allocation

| VM ID | Purpose | Type | Status |
|-------|---------|------|--------|
| 9000 | Talos Linux template | Factory image | Primary VM |
| 9001 | Debian ISO template | ISO build | Alternative |
| 9002 | Ubuntu ISO template | ISO build | Alternative |
| 9003 | Arch Linux template | ISO build | Required |
| 9004 | NixOS template | ISO build | Required |
| 9005 | Windows Server template | ISO build | Required |
| 9100 | Ubuntu cloud base | Cloud image | **Preferred** |
| 9102 | Ubuntu cloud template | Cloud image | **Preferred** |
| 9110 | Debian cloud base | Cloud image | **Preferred** |
| 9112 | Debian cloud template | Cloud image | **Preferred** |

**Allocation Strategy:**
- 9000-9099: Templates (ISO and Factory builds)
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

**Last Updated:** 2025-11-18
**Packer Version:** 1.14.2+
**Proxmox Version:** 9.0
