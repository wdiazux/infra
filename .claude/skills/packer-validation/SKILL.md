# Packer Validation Skill

Validates Packer HCL templates for this infrastructure project against official best practices and homelab requirements.

## Purpose

This skill ensures Packer templates are:
- Syntactically valid
- Using current (non-deprecated) options
- Following HashiCorp style guide
- Optimized for Proxmox VE 9.0
- Consistent across all OS templates

## When to Use

Invoke this skill when:
- Creating new Packer templates
- Updating existing templates
- Before running `packer build`
- After upgrading Packer version
- Reviewing pull requests with Packer changes

## What This Skill Does

1. **Syntax Validation**
   - Run `packer fmt -check` on all .pkr.hcl files
   - Run `packer validate` on templates
   - Check for deprecated options

2. **Best Practices Check**
   - Verify Ansible provisioner uses `use_sftp = true`
   - Ensure `use_proxy = false` for Ansible 2.8+
   - Check disk optimization (discard = true for ZFS)
   - Validate boot_iso block usage (not deprecated iso_url/iso_checksum)
   - Verify cloud-init configuration for cloud images
   - Check QEMU guest agent is enabled

3. **Proxmox-Specific Validation**
   - Ensure storage pool uses ZFS (tank)
   - Verify network bridge (vmbr0)
   - Check CPU type (host for Talos, kvm64 for others)
   - Validate EFI configuration for UEFI boot

4. **Template Consistency**
   - Compare templates for common patterns
   - Ensure variable naming consistency
   - Check template naming convention

5. **Security Checks**
   - Verify secrets aren't hardcoded
   - Check SSH key management via SOPS
   - Ensure credentials use variables

## Example Usage

```
User: "Can you validate my Packer templates?"