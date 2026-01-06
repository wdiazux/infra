# Terraform Review Skill

Reviews Terraform configurations for this infrastructure project against official best practices, security standards, and homelab requirements.

## Purpose

This skill ensures Terraform code is:
- Syntactically valid and properly formatted
- Following HashiCorp best practices
- Secure and following least privilege
- Compatible with Proxmox provider (bpg/proxmox ~> 0.89.1)
- Compatible with Talos provider (siderolabs/talos ~> 0.9.0)
- Optimized for homelab single-operator workflow

## When to Use

Invoke this skill when:
- Creating new Terraform modules or configurations
- Updating existing Terraform code
- Before running `terraform apply`
- After upgrading Terraform or provider versions
- Reviewing pull requests with Terraform changes
- Planning infrastructure changes

## What This Skill Does

1. **Syntax and Formatting**
   - Run `terraform fmt -check -recursive`
   - Run `terraform validate`
   - Check for proper HCL syntax

2. **Best Practices Check**
   - Verify provider version constraints are pinned
   - Check resource naming conventions (kebab-case)
   - Ensure variables have descriptions and types
   - Validate outputs are documented
   - Check for proper use of locals vs variables
   - Verify lifecycle rules where appropriate

3. **Security Review**
   - Run `tflint` for common issues
   - Run `trivy config .` for security scanning
   - Check for hardcoded credentials
   - Verify sensitive variables marked as sensitive
   - Ensure SOPS integration for secrets
   - Check API token usage (not passwords)

4. **Proxmox-Specific Validation**
   - Verify VM configuration best practices
   - Check storage pool references (tank for ZFS)
   - Validate network configuration (vmbr0)
   - Ensure cloud-init configuration for templates
   - Check CPU/memory allocations are reasonable
   - Verify tags and descriptions are set

5. **Talos-Specific Validation**
   - Check machine config generation
   - Verify Talos version compatibility
   - Validate schematic ID configuration
   - Ensure proper node types (controlplane/worker)
   - Check GPU passthrough configuration if used

6. **Module Structure**
   - Verify module inputs/outputs
   - Check for proper README.md
   - Ensure examples are provided
   - Validate module versioning

## Example Usage

```
User: "Can you review my Terraform configurations?"
Assistant: I'll use the terraform-review skill to check your configurations.

[Skill runs checks and reports findings]