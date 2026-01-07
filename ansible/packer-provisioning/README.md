# Ansible Packer Provisioning

This directory contains Ansible playbooks and tasks used during Packer image builds to install baseline packages into golden images.

## Architecture

```
ansible/packer-provisioning/
├── install_baseline_packages.yml    # Main orchestration playbook
├── tasks/                            # Modular task files
│   ├── debian_packages.yml           # Debian/Ubuntu package installation
│   ├── archlinux_packages.yml        # Arch Linux package installation
│   ├── ssh_keys.yml                  # SSH authorized_keys configuration
│   └── cleanup.yml                   # Template cleanup (machine-id, cloud-init, temp files)
└── README.md                         # This file

# Note: Windows uses PowerShell provisioners in Packer, not Ansible
# See packer/windows/scripts/ for Windows provisioning
```

## Design Principles

### Modular Architecture

Following **Ansible Best Practices** ([official docs](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)), this structure uses:

- **include_tasks** pattern for OS-specific task separation
- **Single Responsibility Principle** - each task file handles one OS family
- **DRY (Don't Repeat Yourself)** - common variables defined once in main playbook
- **Maintainability** - easy to update packages per OS without affecting others

### 3-Layer Architecture

This provisioning fits into the overall infrastructure architecture:

```
Layer 1: PACKER + ANSIBLE PROVISIONER (this directory)
├─ Install baseline packages in golden images
├─ Install security packages (ufw, CrowdSec, etc.)
├─ Configure SSH authorized_keys (from SOPS-encrypted secrets)
├─ Clean up template (machine-id, cloud-init, temp files)
└─ Create consistent, reproducible templates

Layer 2: TERRAFORM
├─ Deploy VMs from golden images
└─ Configure VM resources (CPU, RAM, disk)

Layer 3: ANSIBLE DAY 1 (../playbooks/day1_*.yml)
├─ Instance-specific configuration ONLY
├─ Hostname, static IPs, secrets management
└─ No package installation (already in golden image)
```

## Usage in Packer Templates

All Packer templates use a unified Ansible provisioner configuration:

```hcl
# Debian/Ubuntu example
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "debian"  # or "ubuntu"
  use_proxy     = false
  use_sftp      = true      # Recommended by Packer, replaces deprecated SCP

  # Pass variables for SSH keys and authentication
  extra_arguments = [
    "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
    "--extra-vars", "ansible_password=${var.ssh_password}",
    "--extra-vars", "packer_ssh_user=debian",
    "--extra-vars", "ssh_public_key=${var.ssh_public_key}",
    "--ssh-common-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
    "-vv"  # Verbose output for debugging
  ]

  # Use password authentication via sshpass (avoids SSH key libcrypto error)
  ansible_env_vars = [
    "ANSIBLE_HOST_KEY_CHECKING=False",
    "ANSIBLE_SSH_ARGS=-o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no"
  ]
}

# Arch Linux example
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "root"
  use_proxy     = false
  use_sftp      = true

  extra_arguments = [
    "--extra-vars", "ansible_python_interpreter=/usr/bin/python",  # Note: Python 2 in Arch ISO
    "--extra-vars", "ansible_password=${var.ssh_password}",
    "--extra-vars", "packer_ssh_user=root",
    "--extra-vars", "ssh_public_key=${var.ssh_public_key}",
    "--ssh-common-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
    "-vv"
  ]

  ansible_env_vars = [
    "ANSIBLE_HOST_KEY_CHECKING=False",
    "ANSIBLE_SSH_ARGS=-o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no"
  ]
}

# Windows example (future)
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "Administrator"
  use_proxy     = false
  extra_arguments = [
    "--connection", "winrm",
    "--extra-vars", "ansible_connection=winrm ansible_winrm_server_cert_validation=ignore ansible_shell_type=powershell"
  ]
}
```

## Baseline Packages Installed

### Common Packages (all OS)
- vim, git, htop
- curl, wget
- tmux, tree
- rsync, zip, unzip
- python3, python3-pip

### Debian/Ubuntu Specific
- net-tools, dnsutils
- ufw, CrowdSec, unattended-upgrades

### Arch Linux Specific
- net-tools, bind (dnsutils equivalent)
- ufw, CrowdSec

### Windows Specific
- Chocolatey (package manager)
- 7zip, sysinternals, putty, winscp

## SSH Key Configuration

**File:** `tasks/ssh_keys.yml`

**Purpose:** Configure SSH authorized_keys idempotently for passwordless authentication on cloned VMs.

**How it works:**
1. Checks if `ssh_public_key` variable is defined and not empty
2. Uses `ansible.posix.authorized_key` module for idempotent configuration
3. Creates `.ssh` directory with correct permissions (700)
4. Adds public key to authorized_keys
5. Skips if no key provided (graceful degradation)

**Key features:**
- **Idempotent**: Safe to run multiple times
- **SOPS integration**: Reads key from encrypted `secrets/proxmox-creds.enc.yaml`
- **Exclusive: no**: Preserves existing SSH keys in authorized_keys
- **Manages directory**: Creates `.ssh` with correct ownership and permissions

**SOPS Configuration:**
```bash
# Edit encrypted secrets file
sops secrets/proxmox-creds.enc.yaml

# Add your SSH public key
ssh_public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... your-email@example.com"
```

**Packer automatically:**
- Reads `ssh_public_key` from SOPS during build
- Passes it to Ansible via `--extra-vars ssh_public_key=${var.ssh_public_key}`
- Ansible configures authorized_keys using the `ansible.posix.authorized_key` module

**Benefits:**
- ✅ Secure storage with SOPS + Age encryption
- ✅ Idempotent configuration via Ansible
- ✅ Works across all cloud-image templates
- ✅ No manual SSH key copying required
- ✅ Cloned VMs automatically have passwordless SSH

## Template Cleanup

**File:** `tasks/cleanup.yml`

**Purpose:** Clean and prepare template for cloning, ensuring cloned VMs have unique identities.

**What it cleans:**
1. **Package caches**: APT cache (Debian/Ubuntu), Pacman cache (Arch)
2. **Temporary files**: `/tmp/*`, `/var/tmp/*`
3. **Cloud-init data**: Logs and seed files (allows cloud-init to run on clones)
4. **Machine ID**: Reset to empty (regenerated on first boot of cloned VM)
5. **DBus machine ID**: Removed and symlinked to `/etc/machine-id`

**Why cleanup is critical:**
- **Machine ID**: Ensures cloned VMs get unique systemd machine IDs
- **Cloud-init**: Allows cloud-init to run properly on cloned VMs
- **Temp files**: Reduces template size
- **Package caches**: Reduces template size

**Tasks performed:**
```yaml
# Reset machine-id for proper cloning
- name: Reset machine-id for proper cloning
  ansible.builtin.command: truncate -s 0 /etc/machine-id
  changed_when: true

# Clean cloud-init data
- name: Clean cloud-init data
  ansible.builtin.command: cloud-init clean --logs --seed
  changed_when: true
  failed_when: false  # Don't fail if cloud-init not present

# Remove temporary files
- name: Remove temporary files
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop:
    - /tmp/*
    - /var/tmp/*
```

**Benefits:**
- ✅ Cloned VMs have unique identities
- ✅ Cloud-init runs correctly on clones
- ✅ Reduced template size
- ✅ Production-ready templates

## Adding New Packages

### Option 1: Add to Common Packages (All OS)

Edit `install_baseline_packages.yml`:

```yaml
common_packages:
  - vim
  - git
  # ... existing packages ...
  - your-new-package  # Add here
```

**Note:** Ensure package name is the same across all OS or use OS-specific names below.

### Option 2: Add to OS-Specific Packages

Edit the appropriate task file:

**Debian/Ubuntu:** `tasks/debian_packages.yml`
```yaml
- name: Install baseline packages (Debian/Ubuntu)
  ansible.builtin.apt:
    name: "{{ common_packages + ['net-tools', 'dnsutils', 'your-new-package'] }}"
    state: present
```

**Arch Linux:** `tasks/archlinux_packages.yml`
```yaml
- name: Install baseline packages (Arch Linux)
  community.general.pacman:
    name: "{{ common_packages + ['net-tools', 'bind', 'your-new-package'] }}"
    state: present
```

> **Note:** Windows uses PowerShell provisioners in Packer (`packer/windows/scripts/`), not Ansible.

## Testing

### Syntax Check
```bash
ansible-playbook --syntax-check install_baseline_packages.yml
```

### Lint
```bash
ansible-lint install_baseline_packages.yml
ansible-lint tasks/*.yml
```

### Test with Packer
```bash
cd ../../packer/ubuntu
packer validate .
packer build .
```

## Troubleshooting

### Package Not Found

**Symptom:** `Package 'xyz' has no installation candidate`

**Solution:** Check package name for your OS version:
- Debian/Ubuntu: `apt search package-name`
- Arch Linux: `pacman -Ss package-name`
- Windows: Search on https://community.chocolatey.org/

### Python Interpreter Not Found

**Symptom:** `/usr/bin/python3: not found` or similar

**Solution:** Ensure correct Python path in Packer template:
- Ubuntu/Debian: `/usr/bin/python3`
- Arch Linux: `/usr/bin/python` (not python3)
- Windows: Uses PowerShell, not Python

### WinRM Connection Failed (Windows)

**Symptom:** `[Errno 111] Connection refused`

**Solution:** Ensure WinRM is configured in Packer template:
```hcl
communicator   = "winrm"
winrm_username = var.winrm_username
winrm_password = var.winrm_password
winrm_use_ssl  = false
winrm_insecure = true
```

## Benefits of This Architecture

1. **Maintainability** - Easy to update packages per OS
2. **Readability** - Clear separation of concerns
3. **Reusability** - Task files can be included in other playbooks if needed
4. **Testability** - Can test individual task files independently
5. **Scalability** - Easy to add new OS support (just add new task file)

## Best Practices Followed

- ✅ **Ansible Collections** - Uses FQCN (ansible.builtin.apt, community.general.pacman)
- ✅ **Idempotency** - All tasks can be run multiple times safely
- ✅ **Tags** - Allows selective execution (`--tags debian`)
- ✅ **Modularity** - Separate task files per OS
- ✅ **Documentation** - Clear comments and READMEs
- ✅ **Error Handling** - Conditional includes prevent errors on unsupported OS

## Related Documentation

- **Packer Templates:** `../../packer/*/README.md`
- **Day 1 Playbooks:** `../playbooks/day1_*.yml`
- **Ansible Documentation:** `../README.md`
- **Ansible Best Practices:** https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html
- **Packer Ansible Provisioner:** https://developer.hashicorp.com/packer/integrations/hashicorp/ansible/latest/components/provisioner/ansible

## Version History

- **2026-01-05:** Added SSH key management (`tasks/ssh_keys.yml`) and template cleanup (`tasks/cleanup.yml`) - consolidated all provisioning into single Ansible provisioner with SOPS integration
- **2025-11-19:** Refactored to modular architecture with separate task files per OS
- **2025-11-18:** Initial creation with single-file playbook

**Last Updated:** 2026-01-05
