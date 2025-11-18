# CLAUDE.md - AI Assistant Guide for Infrastructure Project

## Project Overview

This repository contains Infrastructure-as-Code (IaC) automation for building golden VM images on Proxmox VE 9.0. The project uses Terraform, Packer, cloud-init, and Ansible to create standardized, reproducible virtual machine images for multiple operating systems.

### Project Goals

- Automate golden image creation for enterprise-grade VM templates
- Support multiple operating systems with consistent baseline configurations
- Maintain simple, optimized, and maintainable code
- Prioritize functionality and reliability over complexity
- Use industry best practices from official documentation

## Repository Structure

### Current State

```
infra/
├── TODO.md          # Project roadmap and requirements
└── CLAUDE.md        # This file - AI assistant guide
```

### Planned Structure

```
infra/
├── packer/          # Packer templates for image building
│   ├── debian/
│   ├── ubuntu/
│   ├── arch/
│   ├── nixos/
│   ├── talos/
│   └── windows/
├── terraform/       # Terraform configurations
│   ├── modules/
│   └── environments/
├── ansible/         # Ansible playbooks for post-provisioning
│   ├── playbooks/
│   ├── roles/
│   └── inventory/
├── cloud-init/      # Cloud-init configuration files
├── scripts/         # Helper scripts
├── docs/            # Additional documentation
├── .gitignore       # Git ignore patterns
├── README.md        # User-facing documentation
├── TODO.md          # Project roadmap
└── CLAUDE.md        # This file
```

## Technology Stack

### Core Tools

1. **Packer** (latest version)
   - Purpose: Building VM images/templates
   - Official docs: https://www.packer.io/docs

2. **Terraform** (latest version)
   - Purpose: Infrastructure orchestration
   - Provider: Proxmox
   - Official docs: https://www.terraform.io/docs

3. **Ansible** (latest version)
   - Purpose: Post-provisioning configuration management
   - Official docs: https://docs.ansible.com/

4. **cloud-init**
   - Purpose: Initial VM configuration
   - Official docs: https://cloud-init.io/

### Target Platform

- **Proxmox VE 9.0**
- Official docs: https://pve.proxmox.com/pve-docs/

## Supported Operating Systems

The project targets the following operating systems:

1. **Debian** (latest stable)
2. **Ubuntu** (latest LTS)
3. **Arch Linux**
4. **NixOS**
5. **Talos**
6. **Windows** (version TBD)

Each OS should have:
- Dedicated Packer template
- OS-specific cloud-init configuration
- Ansible playbook for baseline configuration

## Development Workflows

### Research-First Approach

Before implementing ANY feature:

1. **Research official documentation** for the specific tool/feature
2. **Verify compatibility** with latest versions (Terraform, Packer, Ansible)
3. **Check Proxmox 9.0 compatibility** for all configurations
4. **Review reference examples** for patterns (but don't copy directly)
5. **Validate best practices** for current versions

### Implementation Order

Follow this sequence for development:

1. **Research Phase**
   - Document version requirements
   - Verify syntax compatibility
   - Identify breaking changes from older versions

2. **Packer Templates**
   - Create templates for each OS
   - Test builds individually
   - Optimize for size and build time

3. **Cloud-init Configuration**
   - Set up initial provisioning
   - Configure networking
   - Create initial users

4. **Ansible Playbooks**
   - Define baseline package sets
   - Apply OS-specific configurations
   - Set default credentials (username/password)

5. **Terraform Integration**
   - Orchestrate image building
   - Manage VM deployment
   - Handle provider configuration

6. **Testing & Validation**
   - Test each OS image thoroughly
   - Verify configurations persist
   - Document any quirks or issues

7. **Documentation**
   - Update README.md with usage instructions
   - Document version compatibility
   - Add troubleshooting guides

### Version Management

**CRITICAL**: Always use the latest stable versions of tools.

- Check release notes for breaking changes
- Update syntax to match current version
- Avoid deprecated features
- Document version requirements in code

## Code Quality Standards

### Simplicity & Maintainability

- Write simple, readable code
- Avoid over-engineering
- Use clear variable and resource names
- Prefer explicit over implicit configuration

### Documentation

- Add comments explaining key configurations
- Document non-obvious decisions
- Include usage examples
- Maintain inline documentation for complex logic

### Example Code Quality

**Good:**
```hcl
# Packer template for Debian 12 (Bookworm)
# Built for Proxmox VE 9.0
source "proxmox-iso" "debian12" {
  proxmox_url = var.proxmox_url
  node        = var.proxmox_node

  # ISO configuration for Debian 12.x
  iso_file         = "local:iso/debian-12.0.0-amd64-netinst.iso"
  iso_checksum     = "sha256:xxxxx"

  # VM resources
  cores  = 2
  memory = 2048

  # Descriptive template name
  template_name        = "debian-12-golden-${formatdate("YYYYMMDD", timestamp())}"
  template_description = "Debian 12 golden image with baseline config"
}
```

**Bad:**
```hcl
# Don't do this - unclear, no context, hard to maintain
source "proxmox-iso" "d12" {
  proxmox_url = var.u
  node        = var.n
  iso_file    = var.iso
  cores       = var.c
  memory      = var.m
  template_name = "d12-${var.ts}"
}
```

### File Organization

- One template per OS
- Separate variables files
- Modular Ansible roles
- Logical directory structure

## Key Conventions

### Naming Conventions

**Files:**
- Packer templates: `{os-name}.pkr.hcl`
- Terraform configs: Descriptive names like `main.tf`, `variables.tf`, `outputs.tf`
- Ansible playbooks: `{os-name}-baseline.yml`

**Resources:**
- Use descriptive, kebab-case names
- Include OS/version in resource names
- Be consistent across all tools

**Variables:**
- Use snake_case for variable names
- Prefix with scope (e.g., `proxmox_url`, `debian_iso_path`)
- Document purpose and valid values

### Configuration Management

**Secrets:**
- NEVER commit credentials
- Use variables for sensitive data
- Document required environment variables
- Consider using Vault or similar

**Defaults:**
- Default username/password should be configurable via Ansible
- Baseline packages should be defined in variables
- Keep sensible defaults that can be overridden

### Cloud-init Integration

- Use cloud-init for:
  - Initial network configuration
  - User creation
  - SSH key injection
  - Basic package installation

- Use Ansible for:
  - Advanced configuration
  - Package management
  - Service configuration
  - OS-specific customization

## Reference Materials

### Primary Sources (Use These First)

1. **Terraform Documentation**: https://www.terraform.io/docs
2. **Packer Documentation**: https://www.packer.io/docs
3. **Ansible Documentation**: https://docs.ansible.com/
4. **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
5. **Cloud-init Documentation**: https://cloud-init.io/

### Reference Repositories (Inspiration Only)

These repositories are for pattern reference, NOT for copying:

- [kencx/homelab](https://github.com/kencx/homelab)
- [zimmertr/TJs-Kubernetes-Service](https://github.com/zimmertr/TJs-Kubernetes-Service)
- [sergelogvinov/terraform-talos](https://github.com/sergelogvinov/terraform-talos)
- [dfroberg/cluster](https://github.com/dfroberg/cluster)
- [hcavarsan/homelab](https://github.com/hcavarsan/homelab)
- [chriswayg/packer-proxmox-templates](https://github.com/chriswayg/packer-proxmox-templates)

### Reference Blog Posts

- [Talos Cluster on Proxmox with Terraform](https://olav.ninja/talos-cluster-on-proxmox-with-terraform)
- [Homelab as Code](https://merox.dev/blog/homelab-as-code/)
- [Terraform Proxmox Provider Guide](https://spacelift.io/blog/terraform-proxmox-provider)

**Important**: Cross-reference blog posts with official documentation to ensure accuracy and current best practices.

## AI Assistant Guidelines

### When Asked to Implement Features

1. **Always start with research**
   - Check official docs for latest syntax
   - Verify Proxmox 9.0 compatibility
   - Look for version-specific changes

2. **Propose before implementing**
   - Explain the approach
   - Mention trade-offs
   - Ask for clarification if needed

3. **Write production-ready code**
   - Include error handling
   - Add validation
   - Document assumptions

4. **Test and validate**
   - Provide testing instructions
   - Document expected outcomes
   - Include troubleshooting tips

### When Asked Questions

1. **Prioritize official documentation**
   - Quote or link to official sources
   - Verify information is current
   - Note version-specific details

2. **Provide context**
   - Explain WHY, not just HOW
   - Mention alternatives
   - Discuss trade-offs

3. **Be honest about limitations**
   - If unsure, say so
   - Recommend where to find authoritative answers
   - Suggest verification steps

### Common Pitfalls to Avoid

1. **Version mismatches**: Always verify compatibility
2. **Copying outdated examples**: Validate against current docs
3. **Over-complicating**: Keep it simple and maintainable
4. **Skipping documentation**: Always document your code
5. **Hardcoding secrets**: Use variables and environment configs
6. **Ignoring error handling**: Plan for failures
7. **Not testing**: Verify before committing

## Git Workflow

### Branch Strategy

- Development branch: `claude/claude-md-*` (session-specific)
- Commits should be atomic and descriptive
- Always push to the designated development branch

### Commit Message Format

```
<type>: <brief description>

<detailed explanation if needed>
```

Types: feat, fix, docs, refactor, test, chore

### Before Committing

- Ensure code follows conventions
- Test if possible
- Update documentation
- Remove any debug code or secrets

## Environment Setup

### Required Environment Variables

Document any required environment variables:

```bash
# Proxmox connection
export PROXMOX_URL="https://proxmox.example.com:8006/api2/json"
export PROXMOX_USER="user@pam"
export PROXMOX_TOKEN="your-token-here"

# Ansible defaults
export ANSIBLE_DEFAULT_USER="admin"
export ANSIBLE_DEFAULT_PASSWORD="changeme"
```

### Prerequisites

List any tools that need to be installed:
- Terraform (latest)
- Packer (latest)
- Ansible (latest)
- Git

## Troubleshooting

### Common Issues

1. **Packer build failures**
   - Check ISO availability
   - Verify Proxmox permissions
   - Review build logs

2. **Terraform provider errors**
   - Verify provider version
   - Check API credentials
   - Validate resource names

3. **Ansible playbook failures**
   - Check inventory configuration
   - Verify SSH connectivity
   - Review variable definitions

## Contributing

### Adding a New OS

1. Create Packer template in `packer/{os-name}/`
2. Add cloud-init config in `cloud-init/{os-name}/`
3. Create Ansible playbook in `ansible/playbooks/{os-name}-baseline.yml`
4. Document OS-specific requirements
5. Update this file with any new conventions

### Updating Documentation

- Keep CLAUDE.md in sync with project structure
- Update TODO.md as tasks are completed
- Maintain README.md for end users
- Document breaking changes

## Quick Reference

### File Locations

- Main documentation: `README.md` (user-facing)
- AI guide: `CLAUDE.md` (this file)
- Project roadmap: `TODO.md`
- Packer templates: `packer/`
- Terraform configs: `terraform/`
- Ansible playbooks: `ansible/playbooks/`

### Key Commands

```bash
# Packer
packer init .
packer validate template.pkr.hcl
packer build template.pkr.hcl

# Terraform
terraform init
terraform plan
terraform apply

# Ansible
ansible-playbook -i inventory playbook.yml
ansible-playbook --check playbook.yml  # Dry run
```

## Version History

- **2025-11-18**: Initial CLAUDE.md creation
  - Project in early stages
  - Only TODO.md exists
  - Structure planned but not implemented

---

**Last Updated**: 2025-11-18
**Project Status**: Initial Setup
**Primary Contact**: wdiazux (repository owner)
