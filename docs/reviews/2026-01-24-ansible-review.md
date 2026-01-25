# Ansible Review - 2026-01-24

## Summary

Comprehensive review of Ansible playbooks and provisioning code across the infrastructure repository.

- **Total Files**: 15 Ansible files (9 playbooks, 4 task files, 1 inventory, 1 group_vars)
- **Ansible Version**: ansible-core 2.20.0
- **Lint Tool**: ansible-lint 25.8.2
- **Critical Issues**: 0
- **Warnings**: 0 (2 found, 2 fixed)
- **Info**: 3
- **Overall Status**: ✅ Excellent - production-ready

## Collection Versions

### Required Collections (from requirements.yml)

| Collection | Required Version | Purpose | Status |
|------------|-----------------|---------|--------|
| community.sops | >=2.2.7 | SOPS encrypted secrets | ✅ Current |
| community.general | >=12.0.1 | General utilities (ufw, timezone, pacman) | ✅ Current |
| ansible.posix | >=2.1.0 | POSIX utilities (mount, sysctl, authorized_key) | ✅ Current |
| ansible.windows | >=3.2.0 | Windows management | ✅ Current |
| community.windows | >=3.0.1 | Windows community modules | ✅ Current |
| kubernetes.core | >=6.2.0 | Kubernetes management | ✅ Current |
| chocolatey.chocolatey | >=1.5.0 | Windows package management | ✅ Current |

### Compatibility Notes

- Minimum ansible-core: 2.17.0+ (required by community.general v12+)
- Python: 3.9+ (required by kubernetes.core v6)

---

## Warnings (Fixed)

### [ANS-W001] Directory Naming Convention ✅ FIXED

**File**: `packer-provisioning/` → `packer_provisioning/`
**Severity**: Low
**ansible-lint Rule**: `role-name`
**Status**: ✅ Fixed on 2026-01-24

**Finding**:
```
Role name packer-provisioning does not match ^[a-z][a-z0-9_]*$ pattern.
```

**Resolution**: Renamed directory to `packer_provisioning` and updated all references in:
- Packer templates (debian, ubuntu, arch .pkr.hcl files)
- README files
- .ansible-lint configuration

---

### [ANS-W002] Missing pipefail in Shell Task ✅ FIXED

**File**: `playbooks/day0_proxmox_prep.yml:577`
**Severity**: Low
**ansible-lint Rule**: `risky-shell-pipe`
**Status**: ✅ Fixed on 2026-01-24

**Finding**:
```yaml
- name: Get GPU IOMMU group
  ansible.builtin.shell: |
    GPU_ADDR=$(lspci | grep -i nvidia | grep -i vga | awk '{print $1}' | cut -d: -f1-2)
    readlink -f /sys/bus/pci/devices/0000:${GPU_ADDR}.0/iommu_group 2>/dev/null | xargs basename || echo "unknown"
```

**Resolution**: Added `set -o pipefail` to the shell task:
```yaml
- name: Get GPU IOMMU group
  ansible.builtin.shell: |
    set -o pipefail
    GPU_ADDR=$(lspci | grep -i nvidia | grep -i vga | awk '{print $1}' | cut -d: -f1-2)
    readlink -f /sys/bus/pci/devices/0000:${GPU_ADDR}.0/iommu_group 2>/dev/null | xargs basename || echo "unknown"
  args:
    executable: /bin/bash
```

**Action Required**: Low priority - defensive improvement

---

## Info

### [ANS-I001] Excellent FQCN Usage

**Status**: ✅ All modules use Fully Qualified Collection Names

All playbooks correctly use FQCN format:
- `ansible.builtin.apt` (not `apt`)
- `ansible.builtin.command` (not `command`)
- `ansible.builtin.copy` (not `copy`)
- `community.general.ufw` (not `ufw`)
- `community.general.pacman` (not `pacman`)
- `ansible.posix.mount` (not `mount`)
- `ansible.posix.sysctl` (not `sysctl`)
- `ansible.windows.*` for Windows tasks
- `chocolatey.chocolatey.win_chocolatey` for Chocolatey

This ensures compatibility with ansible-core 2.17+ and future versions.

---

### [ANS-I002] Proper Privilege Escalation

**Status**: ✅ Consistent `become: true` usage

| Playbook | become | Notes |
|----------|--------|-------|
| day0_proxmox_prep.yml | Play-level | ✅ Correct - root access required |
| day0_import_cloud_images.yml | Play-level | ✅ Correct - qm commands need root |
| day1_ubuntu_baseline.yml | Play-level | ✅ Correct - system configuration |
| day1_debian_baseline.yml | Play-level | ✅ Correct - system configuration |
| day1_arch_baseline.yml | Play-level | ✅ Correct - system configuration |
| day1_windows_baseline.yml | None | ✅ Correct - Windows uses different auth |
| day1_all_vms.yml | None | ✅ Correct - orchestration only |
| install_baseline_packages.yml | Play-level | ✅ Correct - Packer provisioning |

**Best Practice Observed**: `become` is set at play level rather than per-task, reducing repetition and ensuring consistency.

---

### [ANS-I003] Security Practices

**Status**: ✅ Good security posture

| Check | Status | Notes |
|-------|--------|-------|
| No hardcoded passwords | ✅ Pass | Credentials from SOPS/variables |
| SSH key handling | ✅ Pass | Uses `ansible.posix.authorized_key` |
| Firewall configuration | ✅ Pass | UFW with deny-by-default |
| CrowdSec integration | ✅ Pass | Intrusion detection enabled |
| SSH hardening | ✅ Pass | Root login disabled, key-only auth |
| Auto security updates | ✅ Pass | unattended-upgrades configured |

**Security Configurations**:

1. **SSH Hardening** (all Linux playbooks):
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `PubkeyAuthentication yes`
   - `MaxAuthTries 3`

2. **Firewall** (UFW):
   - Default deny incoming
   - Only required ports open (SSH)
   - Consistent across all Linux distros

3. **CrowdSec**:
   - Installed in golden images
   - First-boot registration script
   - Collections: linux, sshd

4. **Windows Security**:
   - SMBv1 disabled
   - Password complexity enforced
   - Account lockout configured
   - Audit policy enabled

---

## Code Quality Analysis

### Validation Results

| Check | Result |
|-------|--------|
| ansible-lint (offline) | ⚠️ 2 warnings |
| FQCN compliance | ✅ 100% |
| Privilege escalation | ✅ Consistent |
| Handler usage | ✅ Proper |
| Block/rescue patterns | ✅ Good error handling |

### Best Practices Observed

1. **Modular Structure**
   - Task files separated by OS family
   - Reusable task includes
   - Clear playbook organization

2. **Documentation**
   - Comprehensive header comments in all playbooks
   - Prerequisites documented
   - Architecture explained (3-layer model)

3. **Idempotency**
   - `changed_when` properly used
   - `failed_when` for expected failures
   - State management correct

4. **Error Handling**
   - Block/rescue patterns in Packer tasks
   - Graceful failure handling for optional features
   - Clear error messages

5. **Variable Management**
   - Defaults in playbook vars
   - Overrides in group_vars
   - External secrets from SOPS

### Code Patterns

**Conditional Execution**:
```yaml
- name: Install NFS client (if NFS mounts configured)
  ansible.builtin.apt:
    name: nfs-common
    state: present
  when: nfs_mounts | length > 0
```

**Block/Rescue for Error Handling**:
```yaml
- name: Debian/Ubuntu package installation
  block:
    - name: Install packages
      ansible.builtin.apt: ...
  rescue:
    - name: Handle failure
      ansible.builtin.debug: ...
    - name: Retry
      ansible.builtin.apt: ...
```

**Notify Handlers**:
```yaml
- name: Configure SSH daemon
  ansible.builtin.lineinfile: ...
  notify: Restart SSH

handlers:
  - name: Restart SSH
    ansible.builtin.systemd:
      name: sshd
      state: restarted
```

---

## Playbook Summary

### Day 0 Playbooks (Infrastructure Setup)

| Playbook | Purpose | Lines | Status |
|----------|---------|-------|--------|
| day0_proxmox_prep.yml | Proxmox host preparation | 748 | ✅ Excellent |
| day0_import_cloud_images.yml | Cloud image import | 254 | ✅ Good |

### Day 1 Playbooks (VM Configuration)

| Playbook | Purpose | Lines | Status |
|----------|---------|-------|--------|
| day1_all_vms.yml | Orchestration | 100 | ✅ Good |
| day1_ubuntu_baseline.yml | Ubuntu config | 397 | ✅ Excellent |
| day1_debian_baseline.yml | Debian config | 368 | ✅ Excellent |
| day1_arch_baseline.yml | Arch config | 337 | ✅ Excellent |
| day1_windows_baseline.yml | Windows config | 297 | ✅ Good |

### Packer Provisioning

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| install_baseline_packages.yml | Main provisioner | 81 | ✅ Good |
| tasks/debian_packages.yml | Debian/Ubuntu pkgs | 207 | ✅ Excellent |
| tasks/archlinux_packages.yml | Arch pkgs | 110 | ✅ Good |
| tasks/ssh_keys.yml | SSH key config | 58 | ✅ Good |
| tasks/cleanup.yml | Template cleanup | 108 | ✅ Good |

---

## Metrics

| Metric | Value |
|--------|-------|
| Total Lines | ~3,000 |
| Playbooks | 9 |
| Task Files | 4 |
| Collections Used | 7 |
| OS Supported | 4 (Ubuntu, Debian, Arch, Windows) |

---

## Recommendations

### Priority: Low - ✅ All Completed

1. ~~**Rename packer-provisioning directory**~~ [ANS-W001] ✅ DONE
   - Renamed to `ansible/packer_provisioning/`
   - Updated all references in Packer templates and documentation

2. ~~**Add pipefail to shell task**~~ [ANS-W002] ✅ DONE
   - Added `set -o pipefail` to `playbooks/day0_proxmox_prep.yml:577`

### Priority: None (Maintenance)

1. **Continue using ansible-lint**
   - Run before commits: `ansible-lint ansible/`
   - Consider adding to CI/CD

2. **Monitor collection updates**
   - Check for security updates quarterly
   - Review breaking changes before upgrading

---

## Comparison with Previous Review

This is the first formal Ansible review for this repository.

| Item | Status |
|------|--------|
| FQCN Compliance | ✅ 100% |
| Security Practices | ✅ Excellent |
| Code Quality | ✅ High |
| Documentation | ✅ Comprehensive |
| Error Handling | ✅ Good |

---

## Conclusion

Your Ansible code is **production-ready** with excellent practices:

✅ 100% FQCN compliance (future-proof)
✅ No deprecated modules
✅ Consistent privilege escalation
✅ Strong security configurations
✅ Good error handling with block/rescue
✅ Comprehensive documentation
✅ Modular, maintainable structure

The two warnings are minor cosmetic issues that don't affect functionality or security.

### Quick Actions

```bash
# Verify fixes (all warnings resolved)
cd ansible && ansible-lint playbooks/ packer_provisioning/
# Expected: Passed: 0 failure(s), 0 warning(s)

# Install/upgrade collections
ansible-galaxy collection install -r requirements.yml --upgrade
```

**Fixes Applied**: 2026-01-24
- ✅ Renamed `packer-provisioning` → `packer_provisioning`
- ✅ Added `pipefail` to shell task in `day0_proxmox_prep.yml`

---

**Sources**:
- [Ansible Lint Documentation](https://ansible.readthedocs.io/projects/lint/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [FQCN Migration Guide](https://docs.ansible.com/ansible/latest/porting_guides/porting_guide_2.10.html#using-fqcn)

---

**Review Date**: 2026-01-24
**Reviewer**: Claude Code (Ansible Review Skill)
**ansible-lint Version**: 25.8.2
**ansible-core Version**: 2.20.0
**Next Review**: 2026-04-24 (quarterly)
