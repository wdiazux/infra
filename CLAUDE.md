# CLAUDE.md - AI Assistant Guide for Infrastructure Project

## Project Overview

This repository contains Infrastructure-as-Code (IaC) automation for building golden VM images on Proxmox VE 9.0. The project uses Terraform, Packer, cloud-init, and Ansible to create standardized, reproducible virtual machine images.

### Goals

- Automate golden image creation for reliable, reproducible VM templates
- Support Talos Linux (primary) and traditional operating systems
- Maintain simple, optimized, and maintainable code
- Use industry best practices from official documentation

### Homelab Philosophy

This is a **HOMELAB setup** - some enterprise practices are optional:

**Essential:**
- ✅ Linting and security scanning (TFLint, Trivy, ansible-lint)
- ✅ Version control, documentation, IaC
- ✅ Secrets encryption (SOPS + Age)

**Optional (adds complexity):**
- ⚠️ Remote Terraform state (local state OK for solo homelab)
- ⚠️ Multiple environments (single environment is fine)
- ⚠️ PR reviews (you're one person)

## Repository Structure

```
infra/
├── packer/          # Golden image templates
│   ├── talos/       # Talos (direct import - no Packer)
│   ├── ubuntu/      # Ubuntu (Packer + cloud image)
│   ├── debian/      # Debian (Packer + cloud image)
│   ├── arch/        # Arch (Packer + ISO)
│   ├── nixos/       # NixOS (Packer + ISO)
│   └── windows/     # Windows (Packer + ISO)
├── terraform/       # Terraform configurations
│   ├── talos/       # Talos Kubernetes cluster
│   ├── traditional-vms/  # Traditional VMs
│   └── modules/     # Shared modules
├── ansible/         # Ansible playbooks for post-provisioning
│   ├── playbooks/
│   └── roles/
├── talos/           # Talos machine configs and patches
├── kubernetes/      # Kubernetes manifests and Helm values
│   ├── longhorn/
│   └── storage-classes/
├── secrets/         # Encrypted secrets (SOPS + Age)
├── docs/            # Documentation
├── npins/           # Nix dependency pinning
├── shell.nix        # Nix development environment
├── .envrc           # direnv configuration
├── .sops.yaml       # SOPS configuration
└── CLAUDE.md        # This file
```

## Technology Stack

### Dependency Management

**Nix + npins** is used for reproducible development environments:

- **Nix**: Declarative package manager ensuring consistent tooling across environments
- **npins**: Version pinning for Nix dependencies (replaces niv/flakes for simplicity)
- **direnv**: Automatic environment activation when entering the project directory

All project dependencies are defined in `shell.nix` and automatically available when entering the project directory. No manual installation of tools required.

### Core Tools (Versions)

- **Proxmox VE**: 9.0
- **Terraform**: >= 1.14.2
- **Packer**: ~> 1.14.3
- **Ansible**: ansible-core >= 2.17.0, Python >= 3.9
- **Talos Linux**: v1.10+ (primary platform)
- **Kubernetes**: v1.31+
- **SOPS**: latest (secrets management)
- **Age**: latest (encryption for SOPS)

**Note**: All tools are managed via Nix (see `shell.nix`). Versions are controlled through npins.

### Terraform Providers

- **siderolabs/talos**: ~> 0.10.0 (Talos configuration)
- **bpg/proxmox**: ~> 0.92.0 (VM provisioning)
- **hashicorp/local**: ~> 2.5.3
- **hashicorp/null**: ~> 3.2.4

### Kubernetes Stack (Talos)

- **Networking**: Cilium (eBPF-based CNI with L2 load balancing)
- **Storage**: Longhorn (primary) + NFS CSI (backup target on external NAS)
- **GitOps**: FluxCD
- **Secrets**: SOPS with FluxCD + Age encryption
- **Monitoring**: kube-prometheus-stack, Loki

### Required Linters/Scanners

- **TFLint**, **terraform-docs**, **Trivy** (Terraform)
- **ansible-lint**, **yamllint** (Ansible)
- **pre-commit** (optional, adds automation)

### Hardware Platform

- **System**: Minisforum MS-A2
- **CPU**: AMD Ryzen AI 9 HX 370 (12 cores, Raphael/Granite Ridge)
- **RAM**: 96GB
- **GPU**: NVIDIA RTX 4000 SFF Ada Generation (AD104GL)
- **Storage**: ZFS on Proxmox (16GB ARC max, mirror vdevs recommended)
- **NVMe**: 2x Samsung S4LV008 (Pascal controller)

**Key PCI IDs for Passthrough:**
| Device | PCI ID | Notes |
|--------|--------|-------|
| NVIDIA RTX 4000 SFF | `07:00.0` | GPU for passthrough |
| NVIDIA Audio | `07:00.1` | Pass through with GPU |
| AMD iGPU (Radeon) | `01:00.0` | Proxmox display |
| Intel X710 10GbE | `05:00.0`, `05:00.1` | Dual SFP+ ports |
| Intel I226-V 2.5GbE | `04:00.0` | Management NIC |
| Realtek RTL8125 | `03:00.0` | 2.5GbE |

**IOMMU**: AMD IOMMU at `00:00.2` (enabled)

## Network Configuration

**Network**: 10.10.2.0/24
**Domain**: home-infra.net, .local

**IP Allocation Scheme**:
- 10.10.2.1-10: Physical computers & core infrastructure
- 10.10.2.11-20: Important services (management, monitoring)
- 10.10.2.21-50: Applications & services
- 10.10.2.51-70: Virtual machines
- 10.10.2.240-254: Kubernetes LoadBalancer pool

| Component | IP Address | Purpose | Status |
|-----------|------------|---------|--------|
| Gateway | 10.10.2.1 | Router/gateway | REQUIRED |
| Proxmox Host | 10.10.2.2 | Hypervisor | REQUIRED |
| NAS | 10.10.2.5 | Longhorn backup target | OPTIONAL |
| Talos Node | 10.10.2.10 | Kubernetes node | REQUIRED |
| Cilium Hubble UI | 10.10.2.11 | Network observability | OPTIONAL |
| Longhorn UI | 10.10.2.12 | Storage management | OPTIONAL |
| Forgejo | 10.10.2.13 | Git server (HTTP:3000, SSH:22) | OPTIONAL |
| FluxCD Webhook | 10.10.2.14 | GitOps webhook receiver | OPTIONAL |
| Ubuntu VM | 10.10.2.51 | Traditional VM | OPTIONAL |
| Debian VM | 10.10.2.52 | Traditional VM | OPTIONAL |
| Arch VM | 10.10.2.53 | Traditional VM | OPTIONAL |
| NixOS VM | 10.10.2.54 | Traditional VM | OPTIONAL |
| Windows VM | 10.10.2.55 | Traditional VM | OPTIONAL |
| Cilium LB Pool | 10.10.2.240-254 | K8s LoadBalancer (15 IPs) | REQUIRED |

See `docs/SERVICES.md` for complete network documentation.

## Supported Operating Systems

### Primary: Talos Linux

**Talos Linux** is the primary and most-used VM:
- Kubernetes-native, immutable, minimal Linux distribution
- No SSH, no shell - API-driven only
- GPU passthrough for AI/ML workloads
- Single-node cluster (expandable to 3-node HA later)

### Traditional OS

Supporting golden images for:
- **Debian** (latest stable) - Cloud image approach
- **Ubuntu** (latest LTS) - Cloud image approach
- **Arch Linux** (rolling) - Cloud image approach
- **NixOS** (25.11) - Cloud image approach (Hydra VMA, no Ansible - declarative config)
- **Windows** - TBD

#### Packer Implementation Strategy

All traditional Linux distributions use the **official cloud image approach**:

**Workflow:**
1. **One-time setup** (on Proxmox host): Run `import-cloud-image.sh` to download and import official cloud image
2. **Packer build** (from workstation): `proxmox-clone` builder clones the base VM and customizes with Ansible (except NixOS - declarative)
3. **Result**: Golden template ready for deployment via Terraform

**Note**: NixOS uses its own declarative configuration system (`/etc/nixos/configuration.nix`). No Ansible provisioning is used - configure NixOS via `nixos-rebuild switch`.

**Benefits:**
- ✅ Much faster than ISO installation (5-10 min vs 20-30 min)
- ✅ Official, tested base images
- ✅ No boot/installation issues
- ✅ Consistent workflow across all distributions
- ✅ Cloud-init pre-configured

**Template Details:**

| OS | Cloud Image Source | Base VM ID | Template ID | Default User |
|----|-------------------|------------|-------------|--------------|
| Ubuntu 24.04 | cloud-images.ubuntu.com | 9100 | 9102 | ubuntu |
| Debian 13 | cloud.debian.org | 9110 | 9112 | debian |
| Arch Linux | mirror.pkgbuild.com/images | 9300 | 9302 | arch |
| NixOS 25.11 | hydra.nixos.org (VMA) | 9200 | 9202 | nixos |

## Talos Implementation

### Template Creation (Direct Import - No Packer)

Talos templates are created using **direct disk image import** from Talos Factory - **not Packer**. This is the recommended approach because:
- Talos has no SSH - Packer's communicator model doesn't work
- Talos requires no customization - configured via API after deployment
- Talos Factory provides pre-built images with custom extensions
- Direct import is simpler and faster than any Packer workflow

**Workflow:**
1. Generate schematic at https://factory.talos.dev/ with required extensions
2. Run `packer/talos/import-talos-image.sh` on Proxmox host
3. Template created in ~2-5 minutes

See `packer/talos/README.md` for full documentation.

### Single-Node Configuration

**CRITICAL Requirements:**

1. **Proxmox CPU Type**: Must be "host" (not kvm64) - required for Talos v1.0+
2. **Allow Pod Scheduling**: Remove control-plane taint
   ```bash
   kubectl taint nodes --all node-role.kubernetes.io/control-plane-
   ```
3. **System Extensions** (via Talos Factory):
   - `siderolabs/qemu-guest-agent` (Proxmox integration)
   - `siderolabs/iscsi-tools` (Longhorn storage - REQUIRED)
   - `siderolabs/util-linux-tools` (Longhorn volumes - REQUIRED)
   - `nonfree-kmod-nvidia-production` (GPU drivers - optional)
   - `nvidia-container-toolkit-production` (GPU containers - optional)

4. **Machine Config**:
   - Disable Flannel and kube-proxy (using Cilium)
   - Enable KubePrism on port 7445
   - CNI set to "none"
   - Drop SYS_MODULE from Cilium (Talos restriction)

### GPU Passthrough

**⚠️ CRITICAL LIMITATION**: The NVIDIA RTX 4000 can only be assigned to **ONE VM at a time**. Consumer GPUs don't support vGPU or SR-IOV.

**Recommendation**: Assign GPU to Talos cluster for maximum flexibility.

### Storage Strategy

- **Talos OS disk**: 150-200GB
- **Longhorn**: Primary storage for almost all services (databases, apps, persistent data)
  - Single-replica mode for single node
  - Expandable to 3-replica HA when adding nodes
  - Snapshots, backups, resize, web UI
- **NFS CSI**: External NAS (10.10.2.5) for Longhorn backup target
- **External NAS**: Durable storage independent of Talos node

## Resource Allocation

**System**: 96GB RAM, 12 cores

**Allocation Example (Balanced):**
- Proxmox overhead: 20GB (16GB ZFS ARC + 4GB services)
- Talos single node: 24-32GB RAM, 6-8 cores, GPU passthrough
- Traditional VMs: Remaining resources (2-4 VMs possible)
- Free buffer: 10-15GB RAM

## Development Workflows

### Environment Setup

**Prerequisites**: Install Nix package manager (https://nixos.org/download.html)

**Quick Start**:
```bash
# Clone repository
git clone <repo-url> && cd infra

# Option 1: Use direnv (recommended - auto-activates on cd)
echo "use nix" > .envrc
direnv allow

# Option 2: Manual activation
nix-shell

# Verify tools are available
terraform version
packer version
ansible --version
```

**Updating Dependencies**:
```bash
# Update pinned dependencies
npins update

# Update specific package
npins update nixpkgs
```

All tools (Terraform, Packer, Ansible, kubectl, etc.) are automatically available in the Nix shell - no manual installation needed.

### Research-First Approach

Before implementing:
1. Research official documentation
2. Verify compatibility with latest versions
3. Check Proxmox 9.0 compatibility
4. Review reference examples (don't copy directly)
5. Follow industry-standard best practices

### Implementation Order

1. **Packer Templates** - Build golden images
2. **Cloud-init** (traditional OS only) - Initial provisioning
3. **Ansible Playbooks** - Post-provisioning configuration
4. **Terraform Integration** - Orchestrate deployment
5. **Testing & Validation**
6. **Documentation**

### Best Practices (MANDATORY)

**Sources**: Official documentation (Terraform, Ansible, Packer, HashiCorp Style Guide, CIS Benchmarks)

**Requirements**:
- Use consistent naming conventions
- Implement security scanning in pipelines
- Follow principle of least privilege
- Document all non-obvious decisions
- Use version pinning for reproducibility
- Never commit secrets (use SOPS + Age)
- Tag and label resources appropriately
- Run linters before committing

## Secrets Management

**Chosen Solution**: SOPS with FluxCD + Age encryption

**Why**:
- Zero additional infrastructure (FluxCD native)
- Perfect for homelab scale
- GitOps-native with audit trail
- Simple Age key management

**Baseline Security**:
- Talos disk encryption (TPM-anchored)
- Kubernetes secrets encryption at rest (secretbox)
- SOPS for GitOps layer

**Setup**:
```bash
# Generate Age key
age-keygen -o ~/.config/sops/age/keys.txt

# Extract public key
age-keygen -y ~/.config/sops/age/keys.txt

# Encrypt file
sops -e secrets/plaintext.yaml > secrets/encrypted.enc.yaml

# Decrypt file
sops -d secrets/encrypted.enc.yaml
```

**Documentation**: See `docs/KUBERNETES_SECRETS_MANAGEMENT_GUIDE.md`

## Code Quality Standards

### Simplicity & Maintainability

- Write simple, readable code
- Avoid over-engineering
- Use clear names
- Prefer explicit configuration

### Code Cleanup (CRITICAL)

When updating features:
- Remove ALL old implementation code completely
- Delete unused variables, functions, configurations
- Remove commented-out code (unless critical documentation)
- Update documentation to reflect current implementation only
- No duplicate or dead code

### File Organization

- One template per OS
- Separate variables files
- Modular Ansible roles
- Logical directory structure

## Key Conventions

### Naming

- Files: `{os-name}.pkr.hcl`, `day1_{os-name}_baseline.yml`
- Resources: Descriptive kebab-case, include OS/version
- Variables: snake_case, prefix with scope

### User Configuration (Traditional VMs)

- **Timezone**: America/El_Salvador
- **Username**: wdiaz
- **UID/GID**: Default OS (typically 1000:1000)
- **Shell**: /bin/bash

### Environment Variables

Set these in your `.envrc` file or export them in your shell:

```bash
# Proxmox
export PROXMOX_URL="https://proxmox.example.com:8006/api2/json"
export PROXMOX_USER="user@pam"
export PROXMOX_TOKEN="your-token-here"

# SOPS
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

**Note**: When using direnv, add these exports to `.envrc` after the `use nix` line. They'll be automatically loaded when entering the project directory.

## AI Assistant Guidelines

### When Asked to Implement

1. **Always research first** - Check official docs, verify compatibility
2. **Propose before implementing** - Explain approach, mention trade-offs
3. **Write production-ready code** - Error handling, validation, best practices
4. **Clean up old code** - Remove ALL obsolete implementations
5. **Run quality tools** - Linters, security scanners, documentation generators
6. **Test and validate** - Provide testing instructions
7. **Sync documentation with code** - When updating code (versions, configs, features), ALWAYS update associated documentation:
   - Version changes → Update ALL files referencing that version (use grep to find them)
   - Config changes → Update README.md, example files, and guides
   - Feature changes → Update relevant docs in `docs/`, `README.md`, and inline comments
   - **Skip archive/research docs** - These are historical snapshots, don't modify them

### When Asked Questions

1. **Prioritize official documentation** - Quote/link official sources
2. **Provide context** - Explain WHY, not just HOW
3. **Be honest** - If unsure, say so and suggest verification steps

### Common Pitfalls to Avoid

1. Version mismatches - verify compatibility
2. Copying outdated examples - validate against current docs
3. Over-complicating - keep simple
4. Skipping documentation
5. Committing unencrypted secrets
6. Leaving old code when updating - remove completely
7. Skipping linters/security scanners
8. Not using quality tools

### Documentation Sync Map

When updating a component, check these associated files:

| Component | Code Files | Documentation to Update |
|-----------|------------|------------------------|
| **Talos Version** | `packer/talos/import-talos-image.sh`, `terraform/talos/variables.tf` | `docs/deployment/talos.md`, `docs/reference/terraform.md`, `packer/talos/README.md` |
| **GPU Config** | `terraform/talos/variables.tf`, `terraform/talos/vm.tf`, `terraform/talos/addons.tf` | `docs/services/gpu.md`, `docs/reference/infrastructure.md`, `CLAUDE.md` (Hardware section) |
| **Traditional VMs** | `packer/{os}/*.pkr.hcl`, `terraform/traditional-vms/main.tf` | `packer/{os}/README.md`, `CLAUDE.md` (Template Details table) |
| **Network Config** | `terraform/talos/variables.tf`, `terraform/talos/variables-services.tf` | `docs/reference/network.md`, `CLAUDE.md` (Network Configuration table) |
| **Kubernetes Stack** | `kubernetes/**`, `terraform/talos/addons.tf` | `docs/services/` (cilium, longhorn, forgejo, fluxcd) |
| **Secrets** | `secrets/*.enc.yaml`, `.sops.yaml` | `docs/operations/secrets.md` |
| **Tool Versions** | `shell.nix`, `npins/` | `CLAUDE.md` (Core Tools section) |

**Documentation Structure:**
```
docs/
├── getting-started/   # Prerequisites, quickstart
├── deployment/        # Talos deployment, checklist
├── services/          # Cilium, Longhorn, Forgejo, FluxCD, GPU
├── operations/        # Secrets, backups, upgrades, destroy, troubleshooting
├── reference/         # Network, terraform, infrastructure
└── research/          # Historical research reports
```

**Quick version search**: `grep -r "v1\.12\." --include="*.md" --include="*.hcl" --include="*.tf" --include="*.sh" | grep -v research`

## Git Workflow

- Development branch: `claude/claude-md-*` (session-specific)
- Atomic, descriptive commits
- Format: `<type>: <description>`
- Types: feat, fix, docs, refactor, test, chore

**Before committing**:
- Follow conventions
- Update documentation
- Remove debug code/secrets
- Verify SOPS encryption
- Remove old/obsolete code
- Run linters

## Quick Reference

### Development Environment

```bash
# Nix Shell
nix-shell                     # Enter development environment
direnv allow                  # Enable automatic environment activation

# Dependency Management
npins update                  # Update all pinned dependencies
npins update nixpkgs          # Update specific dependency
npins show                    # Show current pins
```

### Core Commands

```bash
# Packer
packer validate template.pkr.hcl
packer build template.pkr.hcl

# Terraform
terraform init
terraform plan
terraform apply
terraform fmt -recursive
terraform validate
tflint                        # Lint
trivy config .                # Security scan

# Ansible
ansible-playbook playbook.yml
ansible-lint playbook.yml
yamllint playbook.yml

# SOPS + Age
age-keygen -o ~/.config/sops/age/keys.txt
sops -e file.yaml > file.enc.yaml
sops -d file.enc.yaml
sops file.enc.yaml            # Edit encrypted

# Talos
talosctl gen config           # Generate config
talosctl apply-config         # Apply config
talosctl bootstrap            # Bootstrap K8s
talosctl kubeconfig           # Get kubeconfig
talosctl upgrade              # Upgrade Talos
talosctl upgrade-k8s          # Upgrade K8s

# Kubernetes
kubectl get nodes
kubectl get pods -A
k9s                           # Terminal UI
helm list -A
flux reconcile source git flux-system

# ZFS
zpool status                  # Check health
zfs list                      # List datasets
arc_summary                   # ARC statistics
zpool scrub poolname          # Data integrity check
```

## Reference Materials

### Official Documentation (Use These First)

**Development Environment**:
- Nix: https://nixos.org/manual/nix/stable/
- npins: https://github.com/andir/npins
- direnv: https://direnv.net/

**Core Tools**:
- Terraform: https://www.terraform.io/docs
- Packer: https://www.packer.io/docs
- Ansible: https://docs.ansible.com/
- Proxmox: https://pve.proxmox.com/pve-docs/
- SOPS: https://github.com/getsops/sops

**Talos**:
- Talos Docs: https://www.talos.dev/
- Talos Factory: https://factory.talos.dev/
- Talos Proxmox Guide: https://www.talos.dev/v1.10/talos-guides/install/virtualized-platforms/proxmox/
- talosctl CLI: https://www.talos.dev/v1.10/learn-more/talosctl/

**Terraform Providers**:
- siderolabs/talos: https://registry.terraform.io/providers/siderolabs/talos/latest
- bpg/proxmox: https://registry.terraform.io/providers/bpg/proxmox/latest

**Kubernetes**:
- Cilium: https://docs.cilium.io/
- Longhorn: https://longhorn.io/
- FluxCD: https://fluxcd.io/
- NVIDIA GPU Operator: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/

**Best Practices**:
- Terraform Best Practices: https://www.terraform-best-practices.com/
- HashiCorp Style Guide: https://developer.hashicorp.com/terraform/language/style
- Ansible Best Practices: https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html

### Reference Repositories (Inspiration Only)

- rgl/terraform-proxmox-talos
- pascalinthecloud/terraform-proxmox-talos-cluster
- mgrzybek/talos-ansible-playbooks
- chriswayg/packer-proxmox-templates

## Version History

- **2026-01-15**: Documentation consolidation - reorganized 54 files into structured `docs/` hierarchy (getting-started, deployment, services, operations, reference)
- **2026-01-14**: Service LoadBalancer IPs assigned (Hubble UI, Longhorn, Forgejo, FluxCD webhook), documentation cleanup (removed archive docs)
- **2026-01-11**: Talos switched from Packer to direct disk image import (recommended approach by Sidero Labs)
- **2026-01-10**: Talos v1.12.1 upgrade, GPU passthrough config (PCI 07:00), hardware documentation, documentation sync guidelines added
- **2026-01-06**: Talos configuration review (timezone, Cilium L2 interface fix), documentation cleanup (removed orphaned roles/baseline, NixOS Ansible playbook, windows_packages.yml)
- **2026-01-05**: NixOS cloud image implementation (using Hydra VMA, declarative config - no Ansible)
- **2026-01-05**: Arch Linux cloud image implementation (converted from ISO to official cloud image approach, consistent with Ubuntu/Debian)
- **2026-01-04**: Nix + npins dependency management implementation (shell.nix, direnv, reproducible environments)
- **2025-12-15**: Infrastructure dependencies audit and update (Terraform 1.14.2, Packer 1.14.3, Ansible major updates)
- **2025-11-23**: Session recovery and comprehensive infrastructure review (fixed template naming, added validation, Ansible integration)
- **2025-11-23**: Network configuration update (NAS IP 10.10.2.5, IP allocation table)
- **2025-11-23**: Kubernetes secrets management research (SOPS + FluxCD chosen)
- **2025-11-22**: Longhorn storage manager implementation (single-replica mode)
- **2025-11-18**: Talos as primary platform, ZFS storage, CI/CD implementation
- **2025-11-18**: Initial CLAUDE.md creation

---

**Last Updated**: 2026-01-14
**Project Status**: Production-Ready
**Primary Contact**: wdiazux
