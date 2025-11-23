# Packer Template Strategy - Cloud Images + Automation

**Date**: 2025-11-23
**Strategy**: Use official cloud images when available, fully automated workflow

---

## 📋 Template Organization

| OS | Build Method | Build Time | Directory |
|----|--------------|------------|-----------|
| **Debian 12** | Official Cloud Image | 5-10 min | `packer/debian/` |
| **Ubuntu 24.04** | Official Cloud Image | 5-10 min | `packer/ubuntu/` |
| **Arch Linux** | ISO | 20-30 min | `packer/arch/` |
| **NixOS** | ISO | 20-30 min | `packer/nixos/` |
| **Windows Server** | ISO | 30-40 min | `packer/windows/` |
| **Talos Linux** | Factory ISO | 10-15 min | `packer/talos/` |

**No duplicate templates** - each OS has ONE preferred method

---

## 🚀 Fully Automated Workflow

### Step 1: One-Time Cloud Image Setup (Debian + Ubuntu)

**Automated via Ansible**:
```bash
cd ansible

# Import official cloud images to Proxmox (one-time setup)
ansible-playbook -i inventory/proxmox.ini playbooks/day0_import_cloud_images.yml
```

**What this does**:
- ✅ Downloads official Debian 12 and Ubuntu 24.04 cloud images
- ✅ Verifies checksums (SHA512 for Debian, SHA256 for Ubuntu)
- ✅ Imports to Proxmox storage
- ✅ Creates base VMs (ID 9110 for Debian, 9100 for Ubuntu)
- ✅ Configures cloud-init and QEMU guest agent

**Time**: ~5 minutes (downloads + import)
**Run**: Once per Proxmox host

---

### Step 2: Build Golden Image Templates

**Fast builds** (Debian, Ubuntu - use cloud images):
```bash
# Debian (5-10 min)
cd packer/debian
packer init .
packer build .

# Ubuntu (5-10 min)
cd packer/ubuntu
packer init .
packer build .
```

**Standard builds** (ISO-based):
```bash
# Arch Linux (20-30 min)
cd packer/arch
packer init .
packer build .

# NixOS (20-30 min)
cd packer/nixos
packer init .
packer build .

# Windows (30-40 min)
cd packer/windows
packer init .
packer build .

# Talos (10-15 min)
cd packer/talos
packer init .
packer build .
```

---

## 📊 Why Cloud Images?

### ✅ Advantages
- **⚡ 3-4x faster**: 5-10 min vs 20-30 min
- **🔒 More secure**: Official pre-hardened images
- **✅ More reliable**: No installation failures
- **📦 Pre-configured**: cloud-init, qemu-agent already installed
- **🔄 Industry standard**: Production best practice
- **🤖 Fully automated**: Ansible handles import, Packer handles customization

---

## 🔧 Template Names (for Terraform)

After building, use these template names in `terraform.tfvars`:

```hcl
# Cloud templates (5-10 min builds)
debian_template_name  = "debian-12-cloud-template"
ubuntu_template_name  = "ubuntu-2404-cloud-template"

# ISO templates (20-40 min builds)
arch_template_name    = "arch-linux-golden-template"
nixos_template_name   = "nixos-golden-template"
windows_template_name = "windows-server-2022-golden-template"

# Talos (Factory image)
talos_template_name   = "talos-1.11.4-nvidia-template"
```

---

## 📈 Performance Comparison

### Build Time Savings

| OS | Build Time | Method |
|----|-----------|---------|
| Debian | 7 min | Cloud Image ✅ |
| Ubuntu | 8 min | Cloud Image ✅ |
| Arch | 25 min | ISO (no cloud image) |
| NixOS | 25 min | ISO (no cloud image) |
| Windows | 35 min | ISO (no cloud image) |
| Talos | 12 min | Factory ISO |

### Full Template Set Build Time

**Total**: ~112 min (all 6 OS templates)

---

## 🛠️ Troubleshooting

### Cloud Image Import Fails

**Issue**: Ansible playbook can't import cloud images

**Solutions**:
1. Check Proxmox host internet access
2. Verify storage pool exists: `pvesm status`
3. Check available space: `df -h`
4. Manually run import script: `packer/{debian,ubuntu}/import-cloud-image.sh`

### Packer Clone Fails

**Issue**: Packer can't clone base VM

**Solutions**:
1. Verify base VM exists: `qm list | grep 9100`
2. Check VM ID in variables matches base VM ID
3. Ensure base VM is NOT a template (Packer needs a VM, not template)
4. Re-run import: `ansible-playbook playbooks/day0_import_cloud_images.yml`

---

## ✅ Summary

**Strategy**: ONE template per OS, use official cloud images when available

**Workflow**:
1. Run Ansible playbook once (5 min) → Creates base VMs for Debian/Ubuntu
2. Build cloud templates for Debian/Ubuntu (5-10 min each)
3. Build ISO templates for Arch/NixOS/Windows/Talos (10-40 min each)
4. Total time: ~112 min for all 6 OS templates

**Result**:
✅ Fully automated
✅ Fast builds for Debian/Ubuntu
✅ Production best practices (official cloud images)
✅ No confusion (one template per OS)
✅ Works on first run
