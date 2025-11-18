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
├── secrets/         # Encrypted secrets (SOPS + Age)
│   └── *.enc.yaml   # Encrypted files
├── scripts/         # Helper scripts
├── docs/            # Additional documentation
├── .sops.yaml       # SOPS configuration
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

5. **SOPS** (latest version)
   - Purpose: Secrets management and encryption
   - Official docs: https://github.com/getsops/sops

6. **Age** (latest version)
   - Purpose: Encryption tool for SOPS
   - Official docs: https://github.com/FiloSottile/age

### Complementary Tools

These tools enhance the core workflow and follow industry best practices:

#### Terraform Ecosystem

1. **TFLint** (latest version)
   - Purpose: Terraform linter for catching errors and enforcing best practices
   - Official docs: https://github.com/terraform-linters/tflint
   - Use: Detect invalid instance types, deprecated syntax, naming issues

2. **terraform-docs** (latest version)
   - Purpose: Auto-generate documentation from Terraform modules
   - Official docs: https://terraform-docs.io/
   - Use: Maintain up-to-date module documentation

3. **Trivy** (latest version, successor to tfsec)
   - Purpose: Security scanner for IaC misconfigurations and vulnerabilities
   - Official docs: https://aquasecurity.github.io/trivy/
   - Use: Scan Terraform code for security issues and compliance violations

4. **Checkov** (latest version)
   - Purpose: Static code analysis for IaC with 750+ pre-defined checks
   - Official docs: https://www.checkov.io/
   - Use: Security scanning across multiple cloud providers and compliance frameworks

5. **Terrascan** (latest version)
   - Purpose: IaC security scanner with OPA policy support
   - Official docs: https://runterrascan.io/
   - Use: Custom policy enforcement with 500+ built-in policies

6. **Infracost** (latest version)
   - Purpose: Cloud cost estimation from Terraform code
   - Official docs: https://www.infracost.io/
   - Use: Show cost impact in pull requests before deployment

7. **tfenv** (latest version)
   - Purpose: Terraform version manager
   - Official docs: https://github.com/tfutils/tfenv
   - Use: Switch between multiple Terraform versions per project

8. **Terragrunt** (optional)
   - Purpose: Terraform wrapper for DRY configurations and remote state management
   - Official docs: https://terragrunt.gruntwork.io/
   - Use: Keep Terraform code DRY, manage dependencies

9. **Atlantis** (optional)
   - Purpose: Terraform automation for pull requests (GitOps)
   - Official docs: https://www.runatlantis.io/
   - Use: Automate terraform plan/apply in PR workflows

#### Ansible Ecosystem

1. **ansible-lint** (latest version)
   - Purpose: Linter for Ansible playbooks, roles, and collections
   - Official docs: https://ansible-lint.readthedocs.io/
   - Use: Enforce best practices, catch syntax errors, security misconfigurations

2. **Molecule** (latest version)
   - Purpose: Testing framework for Ansible roles
   - Official docs: https://molecule.readthedocs.io/
   - Use: Test roles in isolated environments before production deployment

3. **yamllint** (latest version)
   - Purpose: YAML linter
   - Official docs: https://yamllint.readthedocs.io/
   - Use: Ensure YAML files follow consistent style

4. **Ansible Semaphore** (optional)
   - Purpose: Modern lightweight UI for Ansible
   - Official docs: https://semaphoreui.com/
   - Use: Web UI for running playbooks, managing inventories, scheduling jobs
   - Note: Also supports Terraform, OpenTofu, Terragrunt, PowerShell

5. **AWX** (optional, enterprise)
   - Purpose: Upstream open-source version of Ansible Tower
   - Official docs: https://github.com/ansible/awx
   - Use: Enterprise-grade automation platform with RBAC and workflows
   - Note: More complex than Semaphore, suitable for large teams

#### Cross-cutting Tools

1. **pre-commit** (latest version)
   - Purpose: Git hook framework for automated code checks
   - Official docs: https://pre-commit.com/
   - Use: Run formatting, linting, security scanning before commits
   - Integration: Works with terraform fmt, ansible-lint, tflint, checkov, trivy

2. **pre-commit-terraform** (latest version)
   - Purpose: Pre-configured hooks for Terraform
   - Official docs: https://github.com/antonbabenko/pre-commit-terraform
   - Use: Format, validate, lint, document, and secure Terraform code automatically

### Tool Selection Guidelines

**Mandatory Tools:**
- TFLint, terraform-docs, Trivy/Checkov (one security scanner minimum)
- ansible-lint, Molecule, yamllint
- pre-commit (with appropriate hooks)

**Optional But Recommended:**
- Infracost (for cost awareness)
- tfenv (for version management)
- Ansible Semaphore (for UI-based management)

**Enterprise/Advanced:**
- Terragrunt (for large multi-environment setups)
- Atlantis (for GitOps workflows)
- AWX (for enterprise automation needs)

**Selection Criteria:**
- Start with mandatory tools
- Add optional tools as team size and complexity grow
- Prioritize tools that integrate into CI/CD pipelines
- Always use official/maintained tools over deprecated alternatives

### Target Platform

**Software Platform:**
- **Proxmox VE 9.0**
- Official docs: https://pve.proxmox.com/pve-docs/

**Hardware Platform:**
- **Minisforum MS-A2**
- CPU: AMD Ryzen AI 9 HX 370 (formerly 9955HX)
- RAM: 96GB
- GPU: NVIDIA Ada Lovelace RTX 4000
- Use case: Enterprise-grade mini PC for homelab/production virtualization with GPU acceleration

## Supported Operating Systems

### Primary Focus: Talos Linux

**Talos Linux** is the primary and most-used VM in this infrastructure:

- **Purpose**: Kubernetes-native, immutable, minimal Linux distribution
- **Primary Use Cases**:
  - Kubernetes cluster hosting
  - Multimedia services (Plex, Jellyfin, etc.)
  - AI/ML workloads (leveraging NVIDIA RTX 4000 GPU)
  - Container orchestration for production workloads
- **Key Features**:
  - API-driven configuration (no SSH, no shell)
  - Immutable infrastructure
  - Minimal attack surface
  - GPU passthrough support for AI/ML workloads
- **Official Docs**: https://www.talos.dev/

### Additional Operating Systems

Supporting golden images for:

1. **Debian** (latest stable)
2. **Ubuntu** (latest LTS)
3. **Arch Linux**
4. **NixOS**
5. **Windows** (version TBD)

### OS-Specific Requirements

**For Talos Linux:**
- Custom Packer template with qemu-guest-agent
- Talos Factory images with NVIDIA extensions (for GPU passthrough)
- Terraform-based cluster deployment
- Ansible for Day 0/1/2 operations
- No cloud-init (uses machine configuration API)

**For traditional OSes:**
- Dedicated Packer template
- OS-specific cloud-init configuration
- Ansible playbook for baseline configuration

## Talos Linux Implementation Guide

### Overview

Talos Linux is a modern, immutable Linux distribution designed specifically for Kubernetes. It provides a secure, minimal, and API-driven platform for running containerized workloads.

### Key Characteristics

- **Immutable**: No package manager, no shell access
- **API-Driven**: All configuration via declarative API
- **Kubernetes-Native**: Built specifically for running Kubernetes
- **Minimal**: Small attack surface with only essential components
- **Production-Ready**: Used in enterprise environments

### Implementation Strategy

**Packer Image Building:**
- Use Talos Factory (factory.talos.dev) to build custom images
- Include qemu-guest-agent support for Terraform integration
- Add NVIDIA extensions for GPU passthrough:
  - nvidia-open-gpu-kernel-modules
  - nvidia-container-toolkit
- Image type considerations:
  - Talos 1.7.x: "nocloud" images (cloud-init compatible)
  - Talos 1.8.0+: "metal" images (recommended for current versions)

**Terraform Deployment:**
- Use official Proxmox provider (bpg/proxmox)
- Use Talos provider (siderolabs/talos)
- Structure:
  - Template module for reusable VM templates
  - Cluster module for multi-node deployments
  - Network module for Cilium integration
- Enable IOMMU for GPU passthrough in VM configuration
- Configure PCI device passthrough for NVIDIA GPU

**Ansible Automation:**
- Day 0: Prerequisites and network configuration
- Day 1: Cluster deployment and bootstrapping
- Day 2: Ongoing operations and updates
- Use available roles:
  - mgrzybek/talos-ansible-playbooks
  - sergelogvinov/ansible-role-talos-boot

**Kubernetes Integration:**
- Cilium for networking and L2 load balancing
- Longhorn for distributed persistent storage
- NVIDIA GPU Operator for GPU workload scheduling
- System extensions for GPU support

### GPU Passthrough Configuration

**Proxmox Host Setup:**
1. Enable IOMMU in BIOS
2. Edit `/etc/default/grub`:
   - AMD: Add `amd_iommu=on iommu=pt`
   - Intel: Add `intel_iommu=on iommu=pt`
3. Blacklist NVIDIA drivers on host
4. Bind GPU to VFIO driver

**Talos Configuration:**
1. Build custom image with NVIDIA extensions from Talos Factory
2. Configure machine config with GPU device mapping
3. Install NVIDIA GPU Operator in Kubernetes
4. Deploy workloads with GPU resource requests

### Best Practices for Talos

- Use Talos Factory for custom image creation
- Pin Talos version for reproducibility
- Implement GitOps workflow for configuration management
- Use talosctl for cluster operations
- Maintain machine configurations in version control
- Test GPU passthrough before production deployment
- Monitor GPU utilization in Kubernetes

### Reference Implementations

- **GitHub Examples**:
  - rgl/terraform-proxmox-talos
  - pascalinthecloud/terraform-proxmox-talos-cluster
  - mgrzybek/talos-ansible-playbooks
- **Blog Posts**:
  - TechDufus: Building Talos Kubernetes Homelab on Proxmox with Terraform (June 2025)
  - Suraj Remanan: Automating Talos Installation with Packer and Terraform (August 2025)
  - Duck's Blog: NVIDIA GPU Passthrough to TalosOS VM to Kubernetes (March 2025)
- **Official Documentation**:
  - https://www.talos.dev/
  - https://factory.talos.dev/

## Development Workflows

### Research-First Approach

Before implementing ANY feature:

1. **Research official documentation** for the specific tool/feature
2. **Verify compatibility** with latest versions (Terraform, Packer, Ansible)
3. **Check Proxmox 9.0 compatibility** for all configurations
4. **Review reference examples** for patterns (but don't copy directly)
5. **Validate best practices** for current versions
6. **Follow industry-standard best practices** from official sources

### Best Practices Mandate

**CRITICAL**: All implementations MUST follow industry-standard best practices.

**Sources for Best Practices:**
- Official tool documentation (Terraform, Ansible, Packer, etc.)
- HashiCorp's Terraform Style Guide and Best Practices
- Ansible Best Practices documentation
- Cloud provider security frameworks (CIS Benchmarks, etc.)
- Current year (2025) recommendations from tool maintainers

**Best Practices Requirements:**
- Use consistent naming conventions across all tools
- Implement security scanning in all pipelines
- Follow the principle of least privilege
- Document all non-obvious decisions
- Use version pinning for reproducibility
- Implement proper error handling and validation
- Use remote state backends for Terraform (never local)
- Separate environments (dev/staging/prod)
- Use modules/roles for reusability
- Implement idempotency in all automation
- Use pre-commit hooks for code quality
- Never commit secrets (always use SOPS + Age)
- Tag and label all cloud resources appropriately
- Implement cost controls and monitoring
- Use GitOps workflows where applicable

**Verification:**
- Before committing, verify implementation follows best practices
- Run all linters and security scanners
- Review against official style guides
- Ensure code is maintainable and documented

### Implementation Order

Follow this sequence for development:

1. **Research Phase**
   - Document version requirements
   - Verify syntax compatibility
   - Identify breaking changes from older versions

2. **Packer Templates**
   - **Talos**: Build custom image from Talos Factory with NVIDIA extensions
   - **Traditional OS** (Debian, Ubuntu, Arch, NixOS, Windows):
     - Create templates for each OS
     - Configure base OS settings
     - Install required packages
   - Test builds individually
   - Optimize for size and build time

3. **Cloud-init Configuration** (Traditional OS only)
   - Set up initial provisioning
   - Configure networking
   - Create initial users
   - SSH key injection
   - Basic package installation
   - Note: Talos uses machine configuration API instead

4. **Ansible Playbooks**
   - **Talos**: Day 0/1/2 operations (prerequisites, deployment, updates)
   - **Traditional OS** (Debian, Ubuntu, Arch, NixOS, Windows):
     - Define baseline package sets
     - Apply OS-specific configurations
     - Set default credentials (username/password)
     - Configure services
     - Apply security hardening

5. **Terraform Integration**
   - **Talos**: Use Proxmox + Talos providers for cluster deployment
   - **Traditional OS**:
     - Orchestrate image building
     - Manage VM deployment
     - Configure VM resources (CPU, RAM, storage)
   - Configure GPU passthrough (Talos and traditional VMs as needed)
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

### Code Maintenance and Cleanup

**CRITICAL**: When updating features or implementing changes, maintain code hygiene.

**Removing Obsolete Code:**
- When replacing a feature, ALWAYS remove the old implementation completely
- Delete unused functions, variables, and configuration blocks
- Remove commented-out code unless it serves as critical documentation
- Clean up deprecated imports and dependencies

**Code Review for Updates:**
- Before committing changes, review ALL affected files for:
  - Duplicate code or logic
  - Unused variables or resources
  - Orphaned configuration blocks
  - Deprecated syntax or patterns
  - Dead code paths

**Replacement Guidelines:**
- When introducing new implementation:
  1. Identify all locations of old code
  2. Implement new feature completely
  3. Remove old code systematically
  4. Update all references and documentation
  5. Verify no remnants of old implementation remain

**Anti-patterns to Avoid:**
- Leaving both old and new implementations
- Commenting out old code "just in case"
- Accumulating unused helper functions
- Keeping deprecated configuration alongside new config
- Creating duplicate logic in multiple locations

**Verification Checklist:**
- [ ] Old feature code completely removed
- [ ] No unused imports or dependencies
- [ ] No duplicate logic exists
- [ ] All variables are used
- [ ] Configuration is consolidated
- [ ] Documentation reflects current implementation only

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
- NEVER commit unencrypted credentials
- Use SOPS + Age for encrypting sensitive data
- Encrypted files (.sops.yaml, *.enc.yaml) can be safely committed
- Store Age private keys securely (e.g., password manager, hardware token)
- Document required Age keys and SOPS configuration
- All secrets must be encrypted with SOPS before committing

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

**Core Infrastructure Tools:**
1. **Terraform Documentation**: https://www.terraform.io/docs
2. **Packer Documentation**: https://www.packer.io/docs
3. **Ansible Documentation**: https://docs.ansible.com/
4. **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
5. **Cloud-init Documentation**: https://cloud-init.io/
6. **SOPS Documentation**: https://github.com/getsops/sops
7. **Age Documentation**: https://github.com/FiloSottile/age

**Talos Linux:**
8. **Talos Documentation**: https://www.talos.dev/
9. **Talos Factory**: https://factory.talos.dev/
10. **Talos GitHub**: https://github.com/siderolabs/talos
11. **Talos NVIDIA GPU Guide**: https://www.talos.dev/v1.8/talos-guides/configuration/nvidia-gpu/
12. **Talosctl CLI**: https://www.talos.dev/v1.8/reference/cli/

**Terraform Complementary Tools:**
13. **TFLint**: https://github.com/terraform-linters/tflint
14. **terraform-docs**: https://terraform-docs.io/
15. **Trivy**: https://aquasecurity.github.io/trivy/
16. **Checkov**: https://www.checkov.io/
17. **Terrascan**: https://runterrascan.io/
18. **Infracost**: https://www.infracost.io/
19. **tfenv**: https://github.com/tfutils/tfenv
20. **Terragrunt**: https://terragrunt.gruntwork.io/
21. **Atlantis**: https://www.runatlantis.io/

**Ansible Complementary Tools:**
22. **ansible-lint**: https://ansible-lint.readthedocs.io/
23. **Molecule**: https://molecule.readthedocs.io/
24. **yamllint**: https://yamllint.readthedocs.io/
25. **Ansible Semaphore**: https://semaphoreui.com/
26. **AWX**: https://github.com/ansible/awx

**Cross-cutting Tools:**
27. **pre-commit**: https://pre-commit.com/
28. **pre-commit-terraform**: https://github.com/antonbabenko/pre-commit-terraform

**Best Practices Guides:**
29. **Terraform Best Practices**: https://www.terraform-best-practices.com/
30. **HashiCorp Terraform Style Guide**: https://developer.hashicorp.com/terraform/language/style
31. **Ansible Best Practices**: https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html

### Reference Repositories (Inspiration Only)

These repositories are for pattern reference, NOT for copying:

**Talos-Specific:**
- [rgl/terraform-proxmox-talos](https://github.com/rgl/terraform-proxmox-talos) - Talos Kubernetes on Proxmox with Terraform
- [pascalinthecloud/terraform-proxmox-talos-cluster](https://github.com/pascalinthecloud/terraform-proxmox-talos-cluster) - Terraform module for Talos clusters
- [mgrzybek/talos-ansible-playbooks](https://github.com/mgrzybek/talos-ansible-playbooks) - Ansible playbooks for Talos management
- [sergelogvinov/ansible-role-talos-boot](https://github.com/sergelogvinov/ansible-role-talos-boot) - Ansible role for Talos bootstrapping
- [Robert-litts/Talos_Kubernetes](https://github.com/Robert-litts/Talos_Kubernetes) - Automated Talos deployment with Packer and Terraform
- [kubebn/talos-proxmox-kaas](https://github.com/kubebn/talos-proxmox-kaas) - Kubernetes-as-a-Service on Proxmox

**General Homelab:**
- [kencx/homelab](https://github.com/kencx/homelab)
- [zimmertr/TJs-Kubernetes-Service](https://github.com/zimmertr/TJs-Kubernetes-Service)
- [sergelogvinov/terraform-talos](https://github.com/sergelogvinov/terraform-talos)
- [dfroberg/cluster](https://github.com/dfroberg/cluster)
- [hcavarsan/homelab](https://github.com/hcavarsan/homelab)
- [chriswayg/packer-proxmox-templates](https://github.com/chriswayg/packer-proxmox-templates)

### Reference Blog Posts

**Talos on Proxmox:**
- [Building a Talos Kubernetes Homelab with Terraform on Proxmox - TechDufus (June 2025)](https://techdufus.com/tech/2025/06/30/building-a-talos-kubernetes-homelab-on-proxmox-with-terraform.html)
- [Automating Talos Installation on Proxmox with Packer and Terraform - Suraj Remanan (August 2025)](https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/)
- [NVIDIA GPU Passthrough to TalosOS VM to Kubernetes - Duck's Blog (March 2025)](https://blog.duckdefense.cc/kubernetes-gpu-passthrough/)
- [Talos cluster on Proxmox with Terraform - Olav.ninja](https://olav.ninja/talos-cluster-on-proxmox-with-terraform)
- [Kubernetes with Proxmox, Talos, and Terraform - BB Tech Systems](https://bbtechsystems.com/blog/k8s-with-pxe-tf/)

**General Infrastructure:**
- [Homelab as Code](https://merox.dev/blog/homelab-as-code/)
- [Terraform Proxmox Provider Guide](https://spacelift.io/blog/terraform-proxmox-provider)

**Important**: Cross-reference blog posts with official documentation to ensure accuracy and current best practices.

## AI Assistant Guidelines

### When Asked to Implement Features

1. **Always start with research**
   - Check official docs for latest syntax
   - Verify Proxmox 9.0 compatibility
   - Look for version-specific changes
   - Review current best practices from official sources

2. **Propose before implementing**
   - Explain the approach
   - Mention trade-offs
   - Ask for clarification if needed
   - Reference best practices being followed

3. **Write production-ready code**
   - Include error handling
   - Add validation
   - Document assumptions
   - Follow industry-standard best practices
   - Use complementary tools (linters, security scanners)

4. **Clean up old code when replacing features**
   - Identify and remove ALL old implementation code
   - Delete unused variables, functions, and configurations
   - Update documentation to reflect current implementation only
   - Verify no duplicate or dead code remains

5. **Integrate quality tools**
   - Run linters (TFLint, ansible-lint, yamllint)
   - Run security scanners (Trivy, Checkov, or Terrascan)
   - Generate documentation (terraform-docs)
   - Set up pre-commit hooks for automated checks

6. **Test and validate**
   - Provide testing instructions
   - Document expected outcomes
   - Include troubleshooting tips
   - Use Molecule for Ansible role testing where applicable

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
5. **Committing unencrypted secrets**: Always use SOPS + Age for sensitive data
6. **Ignoring error handling**: Plan for failures
7. **Not testing**: Verify before committing
8. **Leaving old code when updating**: Remove obsolete implementations completely
9. **Accumulating duplicate code**: Consolidate and clean up redundant logic
10. **Keeping unused variables/functions**: Delete what isn't being used
11. **Skipping linters and security scanners**: Always run TFLint, ansible-lint, and security tools
12. **Ignoring best practices**: Follow official style guides and recommendations
13. **Not using pre-commit hooks**: Automate quality checks before commits
14. **Skipping cost estimation**: Use Infracost to understand infrastructure costs
15. **Not testing Ansible roles**: Use Molecule to validate roles before deployment

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
- Remove any debug code or unencrypted secrets
- Verify all secrets are encrypted with SOPS
- Remove old/obsolete code completely
- Delete unused variables, functions, and imports
- Check for duplicate or redundant logic
- Ensure no commented-out code remains (unless critical documentation)

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

# SOPS + Age encryption
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

### SOPS + Age Setup

**Initial Setup:**

1. **Generate Age key pair:**
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Extract public key:**
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

3. **Create .sops.yaml configuration:**
   ```yaml
   creation_rules:
     - path_regex: \.enc\.yaml$
       age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     - path_regex: secrets/.*
       age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

4. **Encrypt a file:**
   ```bash
   sops -e secrets/plaintext.yaml > secrets/encrypted.enc.yaml
   ```

5. **Decrypt a file:**
   ```bash
   sops -d secrets/encrypted.enc.yaml
   ```

6. **Edit encrypted file in-place:**
   ```bash
   sops secrets/encrypted.enc.yaml
   ```

**Important:**
- NEVER commit Age private keys to version control
- Store Age private keys in password managers or hardware tokens
- Share Age public keys with team members for encryption
- Encrypted files can be safely committed to Git
- Use consistent naming convention (*.enc.yaml) for encrypted files

### Prerequisites

**Core Tools (Required):**
- Terraform (latest)
- Packer (latest)
- Ansible (latest)
- SOPS (latest)
- Age (latest)
- Git

**Mandatory Complementary Tools:**
- TFLint
- terraform-docs
- Trivy or Checkov (at least one security scanner)
- ansible-lint
- Molecule
- yamllint
- pre-commit
- pre-commit-terraform

**Optional But Recommended:**
- Infracost (cost estimation)
- tfenv (version management)
- Terrascan (additional security scanning)
- Ansible Semaphore (UI management)

**Enterprise/Advanced (as needed):**
- Terragrunt (multi-environment management)
- Atlantis (GitOps automation)
- AWX (enterprise automation platform)

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

4. **SOPS decryption failures**
   - Verify SOPS_AGE_KEY_FILE environment variable is set
   - Check Age private key file exists and has correct permissions
   - Ensure the file was encrypted with a public key that matches your private key
   - Verify .sops.yaml configuration is correct

5. **Age encryption issues**
   - Confirm Age is installed (age --version)
   - Verify public key format starts with "age1"
   - Check file permissions on keys.txt (should be 600)
   - Ensure key file path is correct in SOPS_AGE_KEY_FILE

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
terraform fmt -recursive      # Format code
terraform validate            # Validate syntax

# Terraform Complementary Tools
tflint                        # Lint Terraform code
tflint --init                 # Initialize TFLint plugins
terraform-docs markdown .     # Generate documentation
trivy config .                # Security scan with Trivy
checkov -d .                  # Security scan with Checkov
terrascan scan                # Security scan with Terrascan
infracost breakdown --path .  # Show cost estimate

# Ansible
ansible-playbook -i inventory playbook.yml
ansible-playbook --check playbook.yml      # Dry run
ansible-lint playbook.yml                  # Lint playbook
molecule init role my-role                 # Initialize Molecule
molecule test                              # Test role
yamllint playbook.yml                      # Lint YAML

# SOPS + Age
age-keygen -o ~/.config/sops/age/keys.txt  # Generate key
age-keygen -y ~/.config/sops/age/keys.txt  # Extract public key
sops -e file.yaml > file.enc.yaml          # Encrypt file
sops -d file.enc.yaml                      # Decrypt file
sops file.enc.yaml                         # Edit encrypted file

# Pre-commit
pre-commit install                         # Install hooks
pre-commit run --all-files                 # Run on all files
pre-commit autoupdate                      # Update hook versions

# Version Management
tfenv list                                 # List Terraform versions
tfenv install latest                       # Install latest Terraform
tfenv use 1.x.x                           # Use specific version

# Talos Linux
talosctl version                           # Check Talos version
talosctl cluster create                    # Create local test cluster
talosctl gen config                        # Generate machine configuration
talosctl apply-config                      # Apply configuration to nodes
talosctl bootstrap                         # Bootstrap Kubernetes
talosctl kubeconfig                        # Get kubeconfig
talosctl dashboard                         # Launch Talos dashboard
talosctl get members                       # List cluster members
```

## Version History

- **2025-11-18**: Talos Linux as primary platform with multi-OS support
  - Designated Talos Linux as primary and most-used VM
  - Clarified support for traditional OS (Debian, Ubuntu, Arch, NixOS, Windows)
  - Added comprehensive Talos Linux Implementation Guide
  - Documented Kubernetes use cases (multimedia, AI/ML, production workloads)
  - Added GPU passthrough configuration for Talos and traditional VMs
  - Included Packer, Terraform, and Ansible strategies for both Talos and traditional OS
  - Expanded implementation order with complete workflows for both OS types
  - Added Talos-specific official documentation and reference links
  - Expanded reference repositories with 6 Talos-specific examples
  - Added 5 current blog posts (2025) for Talos on Proxmox
  - Added talosctl command reference

- **2025-11-18**: Hardware platform specification
  - Added hardware platform details (Minisforum MS-A2 with AMD Ryzen AI 9 HX 370, 96GB RAM)
  - Added GPU information (NVIDIA Ada Lovelace RTX 4000)
  - Documented target system for Proxmox VE deployment with GPU acceleration capabilities

- **2025-11-18**: Complementary tools and best practices mandate
  - Added comprehensive complementary tools section for Terraform and Ansible
  - Documented mandatory, optional, and enterprise tools
  - Added tool selection guidelines and integration patterns
  - Added "Best Practices Mandate" section with requirements and verification
  - Updated Prerequisites with categorized tool list
  - Expanded Reference Materials with all complementary tool documentation
  - Added commands for linters, security scanners, and testing tools
  - Updated AI Assistant Guidelines to emphasize best practices and tool usage
  - Added new pitfalls related to skipping quality tools

- **2025-11-18**: SOPS + Age integration and code cleanup guidelines
  - Added SOPS + Age for secrets management
  - Added comprehensive code maintenance and cleanup guidelines
  - Added requirement to remove old/duplicate/unused code during updates
  - Updated environment setup with SOPS + Age configuration
  - Added verification checklist for code cleanliness

- **2025-11-18**: Initial CLAUDE.md creation
  - Project in early stages
  - Only TODO.md exists
  - Structure planned but not implemented

---

**Last Updated**: 2025-11-18
**Project Status**: Initial Setup
**Primary Contact**: wdiazux (repository owner)
