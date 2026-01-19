# Contributing Guide

## Documentation Sync Map

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
| **K8s Resources** | `kubernetes/apps/**/deployment.yaml` | `docs/reference/resource-strategy.md` |
| **Service IPs** | `kubernetes/apps/**/service.yaml` | `CLAUDE.md` (Network table), `kubernetes/apps/base/tools/homepage/configmap.yaml` |

## Quick Version Search

```bash
grep -r "v1\.12\." --include="*.md" --include="*.hcl" --include="*.tf" --include="*.sh" | grep -v research
```

## Git Workflow

- Development branch: `claude/claude-md-*` (session-specific)
- Atomic, descriptive commits
- Format: `<type>: <description>`
- Types: feat, fix, docs, refactor, test, chore

**Before committing**:
- Follow naming conventions
- Update documentation
- Remove debug code/secrets
- Verify SOPS encryption
- Remove old/obsolete code
- Run linters

## Code Quality

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

## Reference Materials

### Official Documentation

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

### Reference Repositories (Inspiration Only)

- rgl/terraform-proxmox-talos
- pascalinthecloud/terraform-proxmox-talos-cluster
- mgrzybek/talos-ansible-playbooks
- chriswayg/packer-proxmox-templates
