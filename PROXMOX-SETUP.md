# Proxmox VE 9.0 Setup Instructions

This document provides critical setup instructions for Proxmox VE 9.0 before deploying infrastructure with Terraform.

---

## 🔴 CRITICAL: Update Terraform API User Role

**Proxmox VE 9.0 broke compatibility** with the `VM.Monitor` privilege. You **MUST** update your Terraform API user role or Terraform will fail with **403 Forbidden** errors.

### Issue

Proxmox VE 9.0 deprecated the `VM.Monitor` privilege and replaced it with `Sys.Audit`.

**Reference**: [Proxmox 8 to 9 Upgrade Guide](https://fredrickb.com/2025/11/11/upgrade-proxmox-from-8-to-9/)

### Solution

Run the following commands on your Proxmox host:

```bash
# SSH into Proxmox host
ssh root@pve.home-infra.net

# Update the Terraform role with new privileges
pveum rolemod TerraformProv -privs "Datastore.AllocateSpace,Datastore.Audit,Pool.Allocate,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,Sys.PowerMgmt,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt"

# Key change: VM.Monitor → Sys.Audit
```

### If TerraformProv Doesn't Exist

If you haven't created a Terraform user yet, follow these steps:

**Note**: Using `@pve` realm instead of `@pam` is more secure because:
- API-only access (cannot SSH into host)
- Isolated from Linux system
- Follows principle of least privilege

```bash
# 1. Create Terraform user (PVE realm - more secure, API-only access)
pveum useradd terraform@pve --comment "Terraform automation user"

# 2. Set password (or use API token)
pveum passwd terraform@pve

# 3. Create Terraform role with correct privileges
pveum roleadd TerraformProv -privs "Datastore.AllocateSpace,Datastore.Audit,Pool.Allocate,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,Sys.PowerMgmt,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt"

# 4. Assign role to user
pveum aclmod / -user terraform@pve -role TerraformProv

# 5. Create API token (recommended over password)
pveum user token add terraform@pve terraform-token --privsep 0

# Copy the token ID and secret - you'll need these for Terraform
# Format: PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Verify Role

```bash
# Check all roles (look for TerraformProv in the output)
pveum role list

# Or filter for TerraformProv specifically
pveum role list | grep -A 1 TerraformProv

# Expected output should include:
# - Sys.Audit (NOT VM.Monitor)
# - SDN.Use and Sys.PowerMgmt
# - All VM and Datastore privileges
```

---

## Create Personal Admin User

For your personal administrative access to Proxmox, create a dedicated user account.

**Note**: Personal admin users should use `@pam` realm (NOT `@pve`) because:
- Requires SSH access to the Proxmox host
- Needs full administrative capabilities
- Human user, not automation

```bash
# SSH into Proxmox host as root
ssh root@pve.home-infra.net

# 1. Create personal admin user (PAM realm for full access)
pveum useradd wdiaz@pam --comment "William Diaz - Primary Administrator"

# 2. Set password
pveum passwd wdiaz@pam

# 3. Assign Administrator role
pveum aclmod / -user wdiaz@pam -role Administrator

# 4. Verify user was created
pveum user list | grep wdiaz

# Expected output:
# wdiaz@pam      William Diaz - Primary Administrator
```

### User Differences

| User | Realm | Purpose | SSH Access | Web UI | API Access |
|------|-------|---------|------------|--------|------------|
| **wdiaz@pam** | PAM | Personal admin | ✅ Yes | ✅ Yes | ✅ Yes |
| **terraform@pve** | PVE | Automation | ❌ No | ✅ Yes | ✅ Yes |
| **root@pam** | PAM | System admin | ✅ Yes | ✅ Yes | ✅ Yes |

**Security Best Practice:**
- Use `wdiaz@pam` for daily administration (full access)
- Use `terraform@pve` for automation (API-only, limited privileges)
- Avoid using `root@pam` for routine tasks

---

## Optional: IOMMU for GPU Passthrough

If you're using GPU passthrough, ensure IOMMU is enabled:

### AMD CPUs

```bash
# Edit GRUB configuration
nano /etc/default/grub

# Update this line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"

# Save and update GRUB
update-grub

# Reboot
reboot
```

### Intel CPUs

```bash
# Edit GRUB configuration
nano /etc/default/grub

# Update this line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# Save and update GRUB
update-grub

# Reboot
reboot
```

### Verify IOMMU

```bash
# After reboot, check IOMMU is enabled
dmesg | grep -i "amd-vi"

# Expected output should include:
# AMD-Vi: IOMMU performance counters supported
# perf/amd_iommu: Detected AMD IOMMU

# Alternative: Check for passthrough mode
dmesg | grep -i iommu | grep -i passthrough

# Expected output:
# iommu: Default domain type: Passthrough

# Count IOMMU groups (should be multiple groups)
find /sys/kernel/iommu_groups/ -type l | wc -l

# Expected: Should show 20+ groups
```

---

## Optional: Run Ansible Day 0 Playbook

For automated Proxmox host preparation (IOMMU, VFIO, ZFS, GPU detection), run:

```bash
# From your workstation (not Proxmox host)
cd ansible

# Update inventory with your Proxmox host
cat > inventory/hosts.yml <<EOF
all:
  children:
    proxmox:
      hosts:
        pve:
          ansible_host: your-proxmox-ip
          ansible_user: root
          has_gpu: true  # Set to false if no GPU
          zfs_arc_max_gb: 16  # Adjust for your system
EOF

# Run the playbook
ansible-playbook playbooks/day0-proxmox-prep.yml -i inventory/hosts.yml

# Follow the post-configuration summary instructions
```

The playbook will:
- ✅ Validate Proxmox VE 9.0+ installation
- ✅ Configure IOMMU for GPU passthrough
- ✅ Load VFIO kernel modules
- ✅ Blacklist GPU drivers on host
- ✅ Configure ZFS ARC memory limit
- ✅ Detect GPU PCI ID for Terraform
- ✅ Verify network bridge configuration

---

## Checklist Before Running Terraform

Before running `terraform apply`, ensure:

- [ ] **CRITICAL**: Terraform API user role updated (Sys.Audit privilege)
- [ ] Proxmox API token or password configured
- [ ] Network bridge `vmbr0` exists
- [ ] IOMMU enabled (if using GPU passthrough)
- [ ] **ZFS pool "tank" created and configured** (all VMs use ZFS storage)
- [ ] Talos Factory schematic ID generated
- [ ] `terraform.tfvars` configured with your environment

**Note:** This infrastructure uses **ZFS for all VM storage** via the `tank` pool.

---

## Quick Reference

### Terraform API Token Format

```hcl
# In terraform.tfvars
proxmox_api_token = "PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Get GPU PCI ID

```bash
# On Proxmox host
lspci | grep -i nvidia

# Example output:
# 01:00.0 VGA compatible controller: NVIDIA Corporation ...

# Use "01:00" in terraform.tfvars:
# gpu_pci_id = "01:00"
```

### Check Proxmox Version

```bash
pveversion

# Expected: pve-manager/9.x.x (running kernel: 6.x.x)
```

---

## Troubleshooting

### Terraform fails with "403 Forbidden"

**Cause**: Terraform API user doesn't have `Sys.Audit` privilege (VM.Monitor is deprecated).

**Solution**: Run the role update command above.

### GPU passthrough not working

**Cause**: IOMMU not enabled or GPU not in separate IOMMU group.

**Solution**:
1. Verify IOMMU: `dmesg | grep -i iommu | grep -i enabled`
2. Check IOMMU groups: `find /sys/kernel/iommu_groups/ -type l`
3. Verify GPU drivers blacklisted: `lsmod | grep -i nvidia` (should be empty)

### ZFS pool not found

**Cause**: ZFS storage pool doesn't exist or is named differently.

**Solution**:
1. List pools: `zpool list`
2. Update `terraform.tfvars`: `node_disk_storage = "tank"`  # Replace "tank" with your pool name

---

## Next Steps

After completing Proxmox setup:

1. **Build Packer templates**: `cd packer/talos && packer build .`
2. **Deploy with Terraform**: `cd terraform && terraform apply`
3. **Install Cilium CNI**: See `kubernetes/cilium/INSTALLATION.md`
4. **Install Longhorn storage**: See `kubernetes/longhorn/INSTALLATION.md`

---

**Last Updated**: 2025-12-31
**Proxmox Version**: 9.1.4 (tested and verified)
**Applies To**: Proxmox VE 9.0+
**Terraform Version**: >= 1.14.2
**Proxmox Provider**: bpg/proxmox >= 0.89.1
