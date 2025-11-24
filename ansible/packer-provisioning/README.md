# Ansible Packer Provisioning

This directory contains Ansible playbooks and tasks used during Packer image builds to install baseline packages into golden images.

## Architecture

```
ansible/packer-provisioning/
├── install_baseline_packages.yml    # Main orchestration playbook
├── tasks/                            # Modular OS-specific tasks
│   ├── debian_packages.yml           # Debian/Ubuntu package installation
│   ├── archlinux_packages.yml        # Arch Linux package installation
│   └── windows_packages.yml          # Windows package installation (Chocolatey)
└── README.md                         # This file
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
├─ Install security packages (ufw, fail2ban, etc.)
└─ Create consistent, reproducible templates

Layer 2: TERRAFORM
├─ Deploy VMs from golden images
└─ Configure VM resources (CPU, RAM, disk)

Layer 3: ANSIBLE DAY 1 (../playbooks/day1_*.yml)
├─ Instance-specific configuration ONLY
└─ No package installation (already in golden image)
```

## Usage in Packer Templates

All Packer templates reference the main playbook:

```hcl
# Debian/Ubuntu example
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "ubuntu"
  use_proxy     = false
  extra_arguments = [
    "--extra-vars", "ansible_python_interpreter=/usr/bin/python3"
  ]
}

# Arch Linux example
provisioner "ansible" {
  playbook_file = "../../ansible/packer-provisioning/install_baseline_packages.yml"
  user          = "root"
  use_proxy     = false
  extra_arguments = [
    "--extra-vars", "ansible_python_interpreter=/usr/bin/python"
  ]
}

# Windows example
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
- ufw, fail2ban, unattended-upgrades

### Arch Linux Specific
- net-tools, bind (dnsutils equivalent)
- ufw, fail2ban

### Windows Specific
- Chocolatey (package manager)
- 7zip, sysinternals, putty, winscp

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

**Windows:** `tasks/windows_packages.yml`
```yaml
- name: Install baseline packages (Windows)
  ansible.windows.win_chocolatey:
    name:
      - vim
      # ... existing packages ...
      - your-new-package  # Add here
    state: present
```

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
- **Ansible Baseline Role:** `../roles/baseline/README.md`
- **Day 1 Playbooks:** `../playbooks/day1_*.yml`
- **Duplication Audit:** `../../docs/DUPLICATION-AUDIT-2025.md`
- **Ansible Best Practices:** https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html
- **Packer Ansible Provisioner:** https://developer.hashicorp.com/packer/integrations/hashicorp/ansible/latest/components/provisioner/ansible

## Version History

- **2025-11-19:** Refactored to modular architecture with separate task files per OS
- **2025-11-18:** Initial creation with single-file playbook

**Last Updated:** 2025-11-19
