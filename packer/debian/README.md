# Debian Cloud Image Packer Template (PREFERRED METHOD)

This directory contains configuration for building Debian 13 (Trixie) golden images from **official Debian cloud images**. This is the **preferred and recommended approach** for creating Debian templates in Proxmox.

## Recent Updates (2026-01-05)

### Ansible Provisioner Enhancement
- ✅ **Enhanced**: Consolidated SSH key management and template cleanup into Ansible
- ✅ **Added**: Modular Ansible task files (`tasks/ssh_keys.yml`, `tasks/cleanup.yml`)
- ✅ **Added**: SSH public key support via SOPS-encrypted secrets
- ✅ **Fixed**: Ansible provisioner SSH key libcrypto error (switched to password authentication via sshpass)
- ✅ **Improved**: Single Ansible provisioner handles packages, SSH keys, and cleanup
- ✅ **Improved**: Idempotent SSH key configuration using `ansible.posix.authorized_key` module

### Earlier Fixes
- ✅ **Fixed**: SSH timeout issues by adding `VM.GuestAgent.Audit` permission requirement
- ✅ **Fixed**: Base image now pre-installs `qemu-guest-agent` via `virt-customize`
- ✅ **Fixed**: SSH password authentication enabled in cloud image
- ✅ **Fixed**: Cloud-init exit code 2 now accepted as valid (degraded/done status)
- ✅ **Updated**: SSH timeout reduced to 5 minutes (was 15 minutes)
- ✅ **Updated**: All tools managed via Nix (`shell.nix`) with `sshpass` added
- ✅ **Verified**: Template builds successfully with all baseline packages installed via Ansible

## Why Cloud Images? (Preferred Method)

### ✅ Advantages over ISO Build
- **⚡ Much faster**: 5-10 minutes vs 20-30 minutes
- **🎯 Simpler**: No preseed complexity
- **✅ More reliable**: Official pre-built images
- **🔄 Industry standard**: How production environments work
- **📦 Pre-configured**: cloud-init and qemu-guest-agent already installed
- **🔒 Security**: Regular official updates, minimal attack surface

### 📊 Comparison

| Method | Build Time | Complexity | Reliability | Use Case |
|--------|------------|------------|-------------|----------|
| **Cloud Image** | 5-10 min | Low | High | **Production (Recommended)** |
| ISO Build | 20-30 min | High | Medium | Custom partitioning, learning |

### Note About ISO Templates

**ISO-based Debian templates have been removed** in favor of this cloud image approach. The cloud image method is faster, simpler, and follows industry best practices.

If you absolutely need custom disk partitioning or non-standard filesystem layouts, you can create a custom ISO template, but for 95% of use cases, **cloud images are the better choice**.

## Prerequisites

### Development Environment (REQUIRED)

**⚠️ IMPORTANT:** This project uses **Nix + direnv** for reproducible development environments. All commands in this guide must be run from the Nix shell.

**One-time setup:**
```bash
# 1. Install Nix (if not already installed)
# See: https://nixos.org/download.html

# 2. Enable direnv in project root (recommended)
cd /path/to/infra
echo "use nix" > .envrc
direnv allow

# 3. Tools are now automatically available when you enter the directory
cd /path/to/infra/packer/debian
packer --version    # >= 1.14.3
ansible --version   # >= 2.17.0
```

**Without direnv (manual activation):**
```bash
# From project root
nix-shell

# Now all tools are available
packer --version
```

**Tools automatically provided by Nix shell:**
- Packer >= 1.14.3
- Terraform >= 1.14.2
- Ansible >= 2.17.0
- sshpass (required for Ansible provisioner)
- SOPS + Age (for secrets management)
- libguestfs-tools (virt-customize)
- All other project dependencies

See `shell.nix` in project root for complete tool list.

### Environment Variables

Create `.envrc` file in project root with Proxmox credentials:

```bash
# Load Nix environment
use nix

# Proxmox API credentials (from SOPS encrypted secrets)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
# ... (credentials loaded from secrets/proxmox-creds.enc.yaml)
```

See `CLAUDE.md` for full setup instructions.

### Proxmox Setup

Access to Proxmox VE 9.0 host with:
- API token with **VM.GuestAgent.Audit** permission (critical!)
- Storage pool (e.g., tank)
- Network bridge (e.g., vmbr0)

**Required Proxmox API Permissions:**
```bash
# On Proxmox host, add guest agent permission to role
pveum role modify TerraformProv -privs 'Datastore.AllocateSpace,Datastore.Audit,Pool.Allocate,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,Sys.PowerMgmt,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt,VM.GuestAgent.Audit'
```

## Quick Start

### Step 1: Import Cloud Image (One-Time Setup)

Run the import script **on your Proxmox host**:

```bash
# Copy script to Proxmox host
scp import-cloud-image.sh root@proxmox:/root/

# SSH to Proxmox
ssh root@proxmox

# Run import script (creates base VM with ID 9110)
chmod +x import-cloud-image.sh
./import-cloud-image.sh

# Or specify custom VM ID
./import-cloud-image.sh 9110
```

This creates a base VM (`debian-13-cloud-base`) that Packer will clone and customize.

**What the script does:**
1. Downloads official Debian 13 cloud image
2. Verifies SHA512 checksum
3. **Customizes image** using `virt-customize`:
   - Installs `qemu-guest-agent` (required for Packer IP detection)
   - Enables SSH password authentication
   - Disables root login
4. Imports customized image to Proxmox as VM disk
5. Configures VM with cloud-init and DHCP networking
6. Sets up default user (debian/debian)

**Note**: The script requires `libguestfs-tools` on the Proxmox host, which is installed automatically if missing.

### Step 2: Configure Packer

**⚠️ All following commands must be run from Nix shell** (auto-activated with direnv, or run `nix-shell` manually)

```bash
# Ensure you're in Nix shell environment
cd packer/debian

# Copy example configuration
cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl

# Edit configuration
vim debian.auto.pkrvars.hcl
```

Key settings:
```hcl
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

cloud_image_vm_id = 9110  # Base VM created by import script
vm_id             = 9112  # Template VM ID (must be different)

vm_disk_storage = "tank"
```

### Step 3: Build Template

**⚠️ Reminder:** Ensure you're in the Nix shell environment (direnv auto-activates, or run `nix-shell`)

```bash
# Initialize Packer plugins (from Nix shell)
packer init .

# Validate configuration
packer validate .

# Build template (5-10 minutes)
packer build .
```

### Step 4: Verify Template

Check Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `debian-13-cloud-template-YYYYMMDD-hhmm`

## Using the Template

### Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "debian" {
  name      = "debian-prod-01"
  node_name = "pve"

  clone {
    vm_id = 9112  # Cloud image template
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

### Customize with Cloud-init

The template includes cloud-init pre-configured. Create `user-data`:

```yaml
#cloud-config
hostname: production-server
fqdn: production-server.domain.local

users:
  - name: admin
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... your-key

packages:
  - nginx
  - docker.io
  - postgresql

runcmd:
  - systemctl enable --now docker
  - systemctl enable --now postgresql
```

## Customization

### Add Packages to Template

The template uses a unified Ansible provisioner for all configuration. To add packages, edit the package list in `ansible/packer-provisioning/tasks/debian_packages.yml`:

```yaml
# Add your custom packages to common_packages variable
- name: Install baseline packages (Debian/Ubuntu)
  ansible.builtin.apt:
    name:
      - vim
      - git
      - docker.io    # Add custom packages here
      - nginx
      - postgresql
    state: present
    update_cache: yes
```

### Configure SSH Keys

SSH public keys are automatically configured from SOPS-encrypted secrets:

```bash
# Edit encrypted secrets
sops secrets/proxmox-creds.enc.yaml

# Add your SSH public key
ssh_public_key: "ssh-rsa AAAAB3NzaC1yc2E... your-email@example.com"
```

The Ansible provisioner will:
- Read the key from SOPS during build
- Configure authorized_keys idempotently
- Enable passwordless SSH on cloned VMs

### Unified Ansible Provisioner

The template uses a single Ansible provisioner that handles:

```hcl
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "debian"
  use_proxy     = false
  use_sftp      = true

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

**What it does:**
1. Installs baseline packages (via `tasks/debian_packages.yml`)
2. Configures SSH authorized_keys (via `tasks/ssh_keys.yml`)
3. Cleans up template (via `tasks/cleanup.yml`)

## Troubleshooting

### Issue: Import script fails

```
Error: Cannot download cloud image
```

**Solution**:
- Check internet connectivity on Proxmox host
- Verify URL is correct (Debian URLs change with releases)
- Try manual download: `wget <url>`
- Check https://cloud.debian.org/images/cloud/ for latest

### Issue: Packer can't find base VM

```
Error: VM with ID 9110 not found
```

**Solution**:
- Verify import script completed successfully
- Check VM exists: `qm list | grep 9110`
- Verify `cloud_image_vm_id` matches in variables

### Issue: SSH timeout during Packer build

```
Timeout waiting for SSH
```

**Common causes and solutions**:

1. **Missing guest agent permission** (most common):
   ```
   403 Permission check failed (VM.GuestAgent.Audit|VM.GuestAgent.Unrestricted)
   ```
   **Solution**: Add `VM.GuestAgent.Audit` to Proxmox API token role (see Prerequisites)

2. **Guest agent not installed**:
   - The import script installs it automatically
   - Verify: `qm guest cmd 9110 network-get-interfaces`
   - If missing, re-run import script with updated version

3. **Network/DHCP issues**:
   - Start base VM manually: `qm start 9110`
   - Check IP assignment: `qm guest cmd 9110 network-get-interfaces`
   - Test SSH: `ssh debian@<ip>` (password: debian)

4. **SSH timeout too short**:
   - Current timeout: 5 minutes (configurable in `debian.pkr.hcl`)
   - Cloud-init can take 1-2 minutes to complete

### Issue: Cloud-init status returns exit code 2

```
Script exited with non-zero exit status: 2
```

**This is expected** - Proxmox cloud-init generates deprecation warnings causing "degraded done" status. The template accepts exit codes 0 and 2 as valid.

**Verify**: `cloud-init status --long` on VM shows `extended_status: degraded done`

### Issue: Ansible provisioner fails with libcrypto error (RESOLVED)

```
Load key "/tmp/ansible-key...": error in libcrypto
```

**Status**: ✅ **FIXED** (2026-01-05)

**Solution**: Switched from SSH key authentication to password authentication via `sshpass`:
- Added `use_sftp = true` for file transfer
- Added `ansible_password` variable for password authentication
- Configured Ansible environment variables to disable host key checking
- Added verbose logging (`-vv`) for debugging

**Result**: Ansible provisioner now works perfectly and installs all baseline packages during template build.

## Best Practices

### 1. Keep Base Image Updated

Rebuild monthly to include latest security updates:

```bash
# On Proxmox host, update base image
qm destroy 9110
./import-cloud-image.sh 9110

# Then rebuild template
packer build .
```

### 2. Use Version Tags

Tag templates with date/version:

```hcl
template_name = "debian-13-cloud-template-v${formatdate("YYYYMMDD", timestamp())}"
```

### 3. Separate Base from Customization

- **Base VM** (9110): Official cloud image, rarely changes
- **Template** (9112): Customized with packages, updated frequently
- **Production VMs**: Cloned from template

## Resources

- **Debian Cloud Images**: https://cloud.debian.org/images/cloud/
- **Cloud-init Docs**: https://cloudinit.readthedocs.io/
- **Proxmox Cloud-Init**: https://pve.proxmox.com/wiki/Cloud-Init_Support
- **Packer Proxmox Plugin**: https://www.packer.io/plugins/builders/proxmox/clone

## Next Steps

1. ✅ Import cloud image to Proxmox
2. ✅ Build customized template with Packer
3. Test deployment with cloud-init
4. Create Ansible baseline playbook
5. Set up automated monthly rebuilds

See `../ubuntu/` for Ubuntu cloud image template (same approach).
