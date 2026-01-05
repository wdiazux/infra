# Ansible Configuration Management

This directory contains Ansible playbooks for configuring and managing infrastructure deployed via Terraform and Packer.

## Overview

Ansible is used for:
- **Day 0**: Proxmox host preparation (IOMMU, GPU passthrough, ZFS configuration)
- **Day 1**: VM baseline configuration (packages, security, networking)
- **Day 2**: Ongoing operations and maintenance

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Available Playbooks](#available-playbooks)
- [Inventory Configuration](#inventory-configuration)
- [Usage Examples](#usage-examples)
- [Windows VMs](#windows-vms)
- [NixOS Special Considerations](#nixos-special-considerations)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### 1. Ansible Installation

```bash
# Ubuntu/Debian
sudo apt install ansible

# macOS
brew install ansible

# Or via pip
pip install ansible
```

**Minimum version:** Ansible 2.16+

### 2. Ansible Collections

Install required collections:

```bash
cd ansible/
ansible-galaxy collection install -r requirements.yml
```

**Collections installed:**
- `community.sops` - SOPS encrypted secrets
- `community.general` - Essential utilities
- `ansible.posix` - POSIX utilities (mount, sysctl)
- `ansible.windows` - Core Windows modules
- `community.windows` - Additional Windows modules
- `kubernetes.core` - Kubernetes management

### 3. Python Dependencies

**For Windows VMs:**
```bash
pip install pywinrm
```

**For Kubernetes operations:**
```bash
pip install kubernetes
```

### 4. Inventory Configuration

Copy and customize the inventory:

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
vim inventory/hosts.yml
```

Update with your actual:
- IP addresses
- SSH keys
- Proxmox node names
- VM configurations

## Quick Start

### Step 1: Install Dependencies

```bash
# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# For Windows VMs
pip install pywinrm
```

### Step 2: Configure Inventory

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
vim inventory/hosts.yml
# Add your VM IPs and credentials
```

### Step 3: Verify Connectivity

**Linux VMs:**
```bash
ansible ubuntu_vms -m ping
ansible debian_vms -m ping
ansible arch_vms -m ping
```

**Windows VMs:**
```bash
ansible windows_vms -m win_ping
```

### Step 4: Run Playbooks

**Configure all VMs:**
```bash
ansible-playbook playbooks/day1-all-vms.yml
```

**Or configure specific OS:**
```bash
ansible-playbook playbooks/day1-ubuntu-baseline.yml
ansible-playbook playbooks/day1-debian-baseline.yml
```

## Available Playbooks

### Day 0: Infrastructure Preparation

| Playbook | Purpose | Target Hosts |
|----------|---------|--------------|
| `day0-proxmox-prep.yml` | Prepare Proxmox host (IOMMU, GPU, ZFS) | `proxmox` |

**Run before deploying VMs:**
```bash
ansible-playbook playbooks/day0-proxmox-prep.yml
```

**Features:**
- IOMMU configuration (AMD/Intel)
- VFIO kernel modules
- GPU driver blacklisting
- ZFS ARC memory limits
- GPU PCI ID detection

### Day 1: VM Baseline Configuration

| Playbook | Purpose | Target Hosts | Package Manager |
|----------|---------|--------------|-----------------|
| `day1-ubuntu-baseline.yml` | Configure Ubuntu 24.04 VMs | `ubuntu_vms` | apt |
| `day1-debian-baseline.yml` | Configure Debian 12 VMs | `debian_vms` | apt |
| `day1-arch-baseline.yml` | Configure Arch Linux VMs | `arch_vms` | pacman |
| `day1-nixos-baseline.yml` | Configure NixOS VMs | `nixos_vms` | nix |
| `day1-windows-baseline.yml` | Configure Windows Server VMs | `windows_vms` | chocolatey |
| `day1-all-vms.yml` | **Orchestrate all VM configurations** | `all` | N/A |

**All Day 1 playbooks provide:**
- System updates
- Baseline package installation
- Timezone and locale configuration
- SSH hardening (Linux)
- Firewall configuration (UFW/Windows Firewall)
- CrowdSec (Linux)
- Automatic security updates
- Optional Docker/Podman installation
- Optional NFS mounts
- System performance tuning

**Run after Terraform deployment:**
```bash
# Configure all VMs at once
ansible-playbook playbooks/day1-all-vms.yml

# Or configure specific OS types
ansible-playbook playbooks/day1-ubuntu-baseline.yml
ansible-playbook playbooks/day1-debian-baseline.yml
ansible-playbook playbooks/day1-arch-baseline.yml
ansible-playbook playbooks/day1-nixos-baseline.yml
ansible-playbook playbooks/day1-windows-baseline.yml
```

## Inventory Configuration

### Inventory Structure

```
inventory/
├── hosts.yml           # Main inventory (not committed - add to .gitignore)
└── hosts.yml.example   # Example template
```

### Example Inventory

```yaml
# inventory/hosts.yml
---
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3

# Proxmox hosts (for Day 0)
proxmox:
  hosts:
    pve:
      ansible_host: 192.168.1.10
      ansible_user: root
      cpu_vendor: "amd"  # or "intel"
      has_gpu: true

# Ubuntu VMs
ubuntu_vms:
  hosts:
    ubuntu-vm:
      ansible_host: 192.168.1.110
      ansible_user: admin

# Debian VMs
debian_vms:
  hosts:
    debian-vm:
      ansible_host: 192.168.1.111
      ansible_user: admin

# Arch Linux VMs
arch_vms:
  hosts:
    arch-vm:
      ansible_host: 192.168.1.112
      ansible_user: admin

# NixOS VMs
nixos_vms:
  hosts:
    nixos-vm:
      ansible_host: 192.168.1.113
      ansible_user: admin

# Windows VMs
windows_vms:
  hosts:
    windows-vm:
      ansible_host: 192.168.1.114
      ansible_user: Administrator
      ansible_password: YourPassword  # Or use ansible-vault
      ansible_connection: winrm
      ansible_winrm_transport: ntlm
      ansible_port: 5985

  vars:
    ansible_connection: winrm
    ansible_winrm_server_cert_validation: ignore
```

## Usage Examples

### Basic Operations

**Check connectivity (Linux):**
```bash
ansible all -m ping
```

**Check connectivity (Windows):**
```bash
ansible windows_vms -m win_ping
```

**Run ad-hoc commands:**
```bash
# Linux
ansible ubuntu_vms -m command -a "uname -a"

# Windows
ansible windows_vms -m win_shell -a "Get-ComputerInfo"
```

### Customizing Playbooks

**Override variables:**
```bash
ansible-playbook playbooks/day1-ubuntu-baseline.yml \
  -e "install_docker=true" \
  -e "timezone=America/Los_Angeles"
```

**Limit to specific hosts:**
```bash
ansible-playbook playbooks/day1-ubuntu-baseline.yml --limit ubuntu-vm
```

**Dry run (check mode):**
```bash
ansible-playbook playbooks/day1-ubuntu-baseline.yml --check
```

**Verbose output:**
```bash
ansible-playbook playbooks/day1-ubuntu-baseline.yml -vvv
```

### Workflow: Complete Deployment

```bash
# 1. Prepare Proxmox host (one-time)
ansible-playbook playbooks/day0-proxmox-prep.yml

# 2. Build Packer templates (run from packer directory)
cd ../packer/ubuntu && packer build .

# 3. Deploy VMs with Terraform (run from terraform directory)
cd ../../terraform && terraform apply

# 4. Wait for VMs to boot (cloud-init takes 1-2 minutes)
sleep 120

# 5. Configure all VMs with Ansible
cd ../ansible
ansible-playbook playbooks/day1-all-vms.yml

# 6. Verify configuration
ansible all -m ping
```

## Windows VMs

### Windows-Specific Requirements

**1. Install pywinrm on control node:**
```bash
pip install pywinrm
```

**2. WinRM must be configured on Windows VMs**
- Cloudbase-Init configures WinRM automatically (if using Packer template)
- Or manually configure: `winrm quickconfig`

**3. Inventory configuration:**
```yaml
windows_vms:
  hosts:
    windows-vm:
      ansible_host: 192.168.1.114
      ansible_user: Administrator
      ansible_password: !vault |
        $ANSIBLE_VAULT;1.1;AES256...
      ansible_connection: winrm
      ansible_winrm_transport: ntlm
      ansible_port: 5985  # HTTP (5986 for HTTPS)

  vars:
    ansible_connection: winrm
    ansible_winrm_server_cert_validation: ignore
```

**4. Use ansible-vault for passwords:**
```bash
ansible-vault encrypt_string 'YourPassword' --name 'ansible_password'
```

### Windows Playbook Features

- Windows Features installation
- Chocolatey package manager
- Windows Firewall configuration
- Security hardening (password policy, audit policy)
- Remote Desktop configuration
- Windows Updates
- Optional Docker Desktop installation

## NixOS Special Considerations

### NixOS is Declarative

Unlike other Linux distributions, NixOS uses a declarative configuration approach:

**Configuration file:** `/etc/nixos/configuration.nix`

**Applying changes:**
```bash
# Test configuration
sudo nixos-rebuild test

# Apply permanently
sudo nixos-rebuild switch

# Rollback if needed
sudo nixos-rebuild --rollback switch
```

### NixOS Playbook Workflow

1. Ansible generates a baseline `/etc/nixos/configuration.nix`
2. Runs `nixos-rebuild switch` to apply
3. Creates backup of previous configuration
4. For future changes, edit `/etc/nixos/configuration.nix` directly or re-run playbook

### NixOS Template

The playbook uses a Jinja2 template: `templates/nixos-configuration.nix.j2`

**Customize by editing the template or:**
```bash
ansible-playbook playbooks/day1-nixos-baseline.yml \
  -e "enable_docker=true" \
  -e "baseline_packages=['vim','git','htop','curl']"
```

## Best Practices

### Security

1. **Use SSH keys instead of passwords:**
   ```yaml
   ansible_ssh_private_key_file: ~/.ssh/id_rsa
   ```

2. **Store sensitive variables in ansible-vault or SOPS:**
   ```bash
   ansible-vault create secrets.yml
   ansible-playbook playbook.yml -e @secrets.yml --ask-vault-pass
   ```

3. **Test in development first:**
   ```bash
   ansible-playbook playbook.yml --check --diff
   ```

4. **Review SSH configuration changes:**
   - Playbooks disable password authentication
   - Ensure SSH keys are configured before running

### Performance

1. **Use pipelining (already configured in ansible.cfg):**
   ```ini
   [ssh_connection]
   pipelining = True
   ```

2. **Run playbooks in parallel:**
   ```bash
   ansible-playbook playbook.yml --forks=10
   ```

3. **Use fact caching (already configured):**
   ```ini
   [defaults]
   fact_caching = jsonfile
   fact_caching_timeout = 3600
   ```

### Maintenance

1. **Playbooks are idempotent** - safe to run multiple times
2. **Keep playbooks in version control**
3. **Document custom configurations**
4. **Test after OS updates**
5. **Regular security audits**

## Troubleshooting

### SSH Connection Issues

**Problem:** `Permission denied (publickey)`

**Solution:**
```bash
# Verify SSH key
ssh -i ~/.ssh/id_rsa admin@192.168.1.110

# Check inventory
ansible ubuntu_vms -m ping -vvv
```

### Windows Connection Issues

**Problem:** `winrm or requests is not installed`

**Solution:**
```bash
pip install pywinrm
```

**Problem:** `ssl: certificate verify failed`

**Solution:**
```yaml
ansible_winrm_server_cert_validation: ignore
```

### Firewall Blocking

**Problem:** Ansible hangs or times out

**Solution:**
- Ensure firewall allows port 22 (SSH) or 5985/5986 (WinRM)
- Check cloud-init finished: `cloud-init status`

### Fact Gathering Fails

**Problem:** `Failed to gather facts`

**Solution:**
```bash
# Disable fact gathering temporarily
ansible-playbook playbook.yml --skip-tags facts

# Or in playbook
gather_facts: no
```

### Playbook Syntax Errors

**Check syntax:**
```bash
ansible-playbook playbook.yml --syntax-check
```

**Lint playbooks:**
```bash
ansible-lint playbook.yml
```

## Variables

### Common Variables

All playbooks support these variables (override with `-e` or in inventory):

**Ubuntu/Debian:**
```yaml
timezone: "America/New_York"
locale: "en_US.UTF-8"
install_docker: false
install_podman: false
enable_auto_security_updates: true
firewall_allowed_ports: [22]
```

**Arch Linux:**
```yaml
timezone: "America/New_York"
locale: "en_US.UTF-8"
install_docker: false
install_podman: false
install_yay: false  # AUR helper
firewall_allowed_ports: [22]
```

**NixOS:**
```yaml
timezone: "America/New_York"
locale: "en_US.UTF-8"
enable_docker: false
enable_podman: false
baseline_packages: ['vim', 'git', 'htop']
firewall_allowed_ports: [22]
```

**Windows:**
```yaml
timezone: "Eastern Standard Time"
install_docker: false
enable_windows_update: true
windows_update_categories: ['SecurityUpdates', 'CriticalUpdates']
firewall_allowed_ports: [3389, 5985, 5986]
```

### NFS Mounts

```yaml
nfs_mounts:
  - src: "192.168.1.200:/mnt/tank/shared"
    path: "/mnt/nfs/shared"
    opts: "rw,sync,hard,intr"
```

## Next Steps

After configuring VMs:

1. **Verify configuration:**
   ```bash
   ansible all -m command -a "hostname"
   ansible all -m command -a "date"
   ```

2. **Deploy applications** (create custom playbooks/roles)
3. **Set up monitoring** (Prometheus, Grafana)
4. **Configure backups** (Proxmox backup, Restic, etc.)
5. **Implement GitOps** (Ansible Tower, AWX, Semaphore UI)

## Additional Resources

- **Ansible Documentation:** https://docs.ansible.com/
- **Best Practices:** https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html
- **Ansible Galaxy:** https://galaxy.ansible.com/
- **Windows Modules:** https://docs.ansible.com/ansible/latest/collections/ansible/windows/
- **Ansible Vault:** https://docs.ansible.com/ansible/latest/user_guide/vault.html

---

**Last Updated:** 2025-11-19
**Ansible Version:** 2.16+
**Status:** ✅ Production Ready
