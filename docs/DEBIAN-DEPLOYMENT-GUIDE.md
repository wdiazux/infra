# Debian Golden Image: Complete Deployment Guide

**Date**: 2025-11-23
**Purpose**: Step-by-step guide for creating Debian 12 golden images with Packer and deploying VMs with Terraform

---

## Overview

This guide walks through the complete workflow:
1. **Day 0**: Import official Debian 12 cloud image to Proxmox (one-time setup)
2. **Day 1**: Build golden image template with Packer
3. **Day 2**: Deploy production VMs from template with Terraform

**Total Time**: ~15-20 minutes (after one-time setup)

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
- Storage pool (e.g., `local-zfs`)
- Network bridge (e.g., `vmbr0`)

### Network Requirements

- Proxmox host has internet access (for downloading cloud images)
- DHCP enabled on network bridge OR static IP configuration
- DNS configured on Proxmox host

---

## Part 1: Day 0 Setup (One-Time)

### Option A: Automated Cloud Image Import (Recommended)

Use the Ansible playbook to automate the entire cloud image import:

```bash
cd ansible

# Import both Debian and Ubuntu cloud images
ansible-playbook -i inventory/proxmox.ini playbooks/day0_import_cloud_images.yml
```

**What this does**:
- Downloads official Debian 12 and Ubuntu 24.04 cloud images
- Verifies checksums (SHA512 for Debian, SHA256 for Ubuntu)
- Imports to Proxmox storage
- Creates base VMs (ID 9110 for Debian, 9100 for Ubuntu)
- Configures cloud-init and QEMU guest agent

**Time**: ~5 minutes

**Verify**:
```bash
# SSH to Proxmox host
ssh root@proxmox

# Check base VM exists
qm list | grep 9110
# Should show: debian-12-cloud-base

# Check VM configuration
qm config 9110
```

### Option B: Manual Cloud Image Import

If you prefer manual control or the Ansible playbook fails:

```bash
# SSH to Proxmox host
ssh root@proxmox

# Copy import script from repo
scp packer/debian/import-cloud-image.sh root@proxmox:/root/

# Run import script
chmod +x /root/import-cloud-image.sh
/root/import-cloud-image.sh 9110
```

**Verification**:
```bash
# Verify base VM exists
qm list | grep 9110

# Verify cloud-init is configured
qm config 9110 | grep cloudinit

# Verify QEMU agent is enabled
qm config 9110 | grep agent
```

---

## Part 2: Build Golden Image with Packer

### Step 1: Configure Packer Variables

```bash
cd packer/debian

# Copy example configuration
cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl

# Edit configuration (use your editor of choice)
vim debian.auto.pkrvars.hcl
```

**Required settings**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx"
proxmox_node     = "pve"
proxmox_skip_tls_verify = true

# Debian Version
debian_version = "12"

# Cloud Image Base VM (created by import script)
cloud_image_vm_id = 9110  # MUST match base VM created in Part 1

# Template Configuration
template_name        = "debian-12-cloud-template"
template_description = "Debian 12 (Bookworm) from official cloud image with customizations"
vm_id                = 9112  # Template VM ID (must be different from 9110)

# VM Hardware
vm_cores    = 2
vm_memory   = 2048
vm_disk_storage = "local-zfs"  # Your Proxmox storage pool

# Network
vm_network_bridge = "vmbr0"  # Your Proxmox network bridge

# SSH (default from cloud image)
ssh_password = "debian"
```

### Step 2: Install Ansible Collections (if not already installed)

```bash
cd ../../ansible

# Install required Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### Step 3: Build the Template

```bash
cd ../packer/debian

# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build Process**:
1. Packer clones base VM (9110) → creates new VM (9112)
2. Starts VM and waits for cloud-init
3. Runs Ansible playbook to install baseline packages
4. Cleans up (removes temp files, resets machine-id)
5. Converts VM to template

**Build Time**: ~5-10 minutes

**Watch Progress**:
- Open Proxmox UI → VM 9112 → Console
- You'll see cloud-init, package installation, cleanup

### Step 4: Verify Template

```bash
# SSH to Proxmox host
ssh root@proxmox

# List templates
qm list | grep -i template
# Should show: debian-12-cloud-template

# Check template configuration
qm config 9112

# Verify it's marked as template
qm config 9112 | grep template
# Should show: template: 1
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

**Key settings for Debian VM**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx"
proxmox_node     = "pve"

# Debian VM Configuration
deploy_debian_vm    = true  # Enable Debian VM deployment
debian_template_name = "debian-12-cloud-template"  # Must match Packer template name
debian_vm_name      = "debian-prod-01"
debian_vm_id        = 200  # VM ID for deployed VM

# Resources
debian_cores  = 4
debian_memory = 8192  # 8GB RAM

# Networking
debian_ip      = "192.168.1.110"
debian_netmask = "24"
debian_gateway = "192.168.1.1"
dns_servers    = ["8.8.8.8", "1.1.1.1"]

# Cloud-init User
debian_user     = "wdiaz"  # Will be created by cloud-init
debian_password = "your-secure-password"  # Change this!
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
1. Look up template "debian-12-cloud-template" on Proxmox
2. Clone template → create new VM (ID 200)
3. Configure resources (4 cores, 8GB RAM)
4. Apply cloud-init configuration (hostname, IP, user)
5. Start VM

**Deploy Time**: ~2-3 minutes

### Step 3: Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Should show:
# debian_vm_id = "200"
# debian_vm_ip = "192.168.1.110"
# debian_vm_name = "debian-prod-01"
```

**In Proxmox UI**:
1. Navigate to VM 200
2. Check console - should show boot process
3. Verify cloud-init ran: `Console → cloud-init status`

**Test SSH Access**:
```bash
# Wait ~60 seconds for cloud-init to complete
sleep 60

# SSH to new VM
ssh wdiaz@192.168.1.110

# Verify baseline packages installed
htop
vim --version
git --version
python3 --version
```

---

## Part 4: Post-Deployment Configuration (Optional)

### Option: Run Ansible Baseline Role

For instance-specific configuration (install additional packages, configure services, etc.):

```bash
cd ../ansible

# Update inventory with new VM
vim inventory/production.ini

# Add:
# [debian_vms]
# debian-prod-01 ansible_host=192.168.1.110 ansible_user=wdiaz

# Run baseline playbook
ansible-playbook -i inventory/production.ini playbooks/baseline.yml
```

---

## Troubleshooting

### Issue: Ansible playbook fails to import cloud image

**Symptoms**:
```
fatal: [proxmox]: FAILED! => {"msg": "Failed to download cloud image"}
```

**Solutions**:
1. Check Proxmox host internet access: `curl https://cloud.debian.org/`
2. Verify storage pool exists: `ssh root@proxmox 'pvesm status | grep local-zfs'`
3. Check available space: `ssh root@proxmox 'df -h | grep zfs'`
4. Try manual script: `scp packer/debian/import-cloud-image.sh root@proxmox:/root/`

### Issue: Packer build fails - "VM with ID 9110 not found"

**Symptoms**:
```
Error: VM with ID 9110 not found on Proxmox node 'pve'
```

**Solutions**:
1. Verify base VM exists: `ssh root@proxmox 'qm list | grep 9110'`
2. Check `cloud_image_vm_id` matches in `debian.auto.pkrvars.hcl`
3. Re-run import: `ansible-playbook playbooks/day0_import_cloud_images.yml`

### Issue: Packer SSH timeout

**Symptoms**:
```
Timeout waiting for SSH to become available
```

**Solutions**:
1. Check base VM can start: `ssh root@proxmox 'qm start 9110'`
2. Verify VM gets IP: `ssh root@proxmox 'qm guest cmd 9110 network-get-interfaces'`
3. Test SSH manually: `ssh debian@<vm-ip>` (password: debian)
4. Check firewall allows port 22
5. Increase `ssh_timeout` in `debian.pkr.hcl` from "10m" to "15m"

### Issue: Terraform can't find template

**Symptoms**:
```
Error: Template 'debian-12-cloud-template' not found on Proxmox node 'pve'
```

**Solutions**:
1. Verify template exists: `ssh root@proxmox 'qm list | grep 9112'`
2. Check template name matches: `ssh root@proxmox 'qm config 9112 | grep name'`
3. Ensure `debian_template_name` in `terraform.tfvars` matches template name from Packer
4. Rebuild template: `cd packer/debian && packer build .`

### Issue: Cloud-init not running on deployed VM

**Symptoms**:
- VM starts but user not created
- Network not configured
- Hostname not set

**Solutions**:
1. Check cloud-init drive exists: `ssh root@proxmox 'qm config 200 | grep ide2'`
2. View cloud-init logs on VM: `ssh root@<vm-ip> 'cloud-init status --long'`
3. Verify cloud-init configuration in Terraform
4. Ensure template has cloud-init enabled: `qm config 9112 | grep cloudinit`

---

## Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    Day 0: One-Time Setup                    │
├─────────────────────────────────────────────────────────────┤
│ ansible-playbook playbooks/day0_import_cloud_images.yml    │
│ → Downloads Debian 12 cloud image                           │
│ → Imports to Proxmox as base VM (ID 9110)                   │
│ → Configures cloud-init + QEMU agent                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│             Day 1: Build Golden Image (5-10 min)            │
├─────────────────────────────────────────────────────────────┤
│ cd packer/debian                                             │
│ cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl │
│ vim debian.auto.pkrvars.hcl  # Configure Proxmox settings   │
│ packer init .                                                │
│ packer build .                                               │
│ → Clones base VM 9110 → creates template VM 9112            │
│ → Runs Ansible to install baseline packages                 │
│ → Creates template "debian-12-cloud-template"               │
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
│ → Clones template → creates VM (ID 200)                     │
│ → Configures resources (cores, RAM, disk)                   │
│ → Applies cloud-init (network, user, packages)              │
│ → Starts VM                                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│            Optional: Post-Deployment Config                  │
├─────────────────────────────────────────────────────────────┤
│ ansible-playbook -i inventory/production.ini \              │
│   playbooks/baseline.yml                                    │
│ → Instance-specific configuration                           │
│ → Additional packages and services                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Update Golden Images Monthly

Keep templates up-to-date with latest security patches:

```bash
# Rebuild template monthly
cd packer/debian
packer build .

# Deploy new VMs from updated template
cd ../terraform
terraform apply
```

### 2. Version Your Templates

Tag templates with build date:

```hcl
# In debian.auto.pkrvars.hcl
template_name = "debian-12-cloud-template-20251123"
```

### 3. Separate Concerns

- **Packer**: Installs baseline packages (vim, git, python, etc.)
- **Cloud-init**: Configures instance-specific settings (hostname, IP, users)
- **Ansible**: Post-deployment customization (app-specific packages, services)

### 4. Use SOPS for Secrets

Never commit plain-text passwords:

```bash
# Encrypt sensitive variables
sops -e terraform.tfvars > terraform.tfvars.enc

# Decrypt before use
sops -d terraform.tfvars.enc > terraform.tfvars
```

### 5. Test Before Production

Always test templates before deploying to production:

```bash
# Deploy test VM
terraform apply -var="debian_vm_name=debian-test-01" -var="debian_vm_id=299"

# Test functionality
ssh wdiaz@<test-vm-ip>

# Destroy test VM
terraform destroy -target=proxmox_virtual_environment_vm.debian
```

---

## Next Steps

1. ✅ Complete Debian deployment
2. Build Ubuntu template (same process, different directory)
3. Build Talos Kubernetes cluster (see `TALOS-DEPLOYMENT-GUIDE.md`)
4. Set up automated template rebuilds (monthly cron job)
5. Implement GitOps workflow with Terraform Cloud or Atlantis

---

## Related Documentation

- **Packer Debian Template**: `packer/debian/README.md`
- **Terraform Configuration**: `terraform/README.md`
- **Ansible Baseline Role**: `ansible/roles/baseline/README.md`
- **Cloud Image Import Playbook**: `ansible/playbooks/day0_import_cloud_images.yml`
- **Talos Deployment Guide**: `docs/TALOS-DEPLOYMENT-GUIDE.md`

---

**Last Updated**: 2025-11-23
**Maintained By**: wdiazux
