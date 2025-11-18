# Tool Versions - Infrastructure Automation Project

**Last Updated**: 2025-11-18
**Research Date**: 2025-11-18

This document tracks the latest stable versions of all tools used in this infrastructure automation project. All versions have been verified as compatible with Proxmox VE 9.0 and each other as of the research date.

## Core Infrastructure Tools

### Terraform
- **Version**: 1.13.5
- **Release Date**: Latest stable as of Nov 2025
- **Compatibility**: Proxmox VE 9.0 compatible
- **Installation**: https://www.terraform.io/downloads
- **Release Notes**: https://github.com/hashicorp/terraform/releases
- **Notes**: Version 1.14.0 is in RC/beta, use 1.13.5 for stability

### Packer
- **Version**: 1.14.2
- **Release Date**: Latest stable as of 2025
- **Compatibility**: Proxmox VE 9.0 compatible
- **Installation**: https://www.packer.io/downloads
- **Release Notes**: https://github.com/hashicorp/packer/releases
- **Notes**: Includes Proxmox ISO and clone builders

### Ansible
- **ansible-core Version**: 2.20.0
- **ansible Package**: Latest (community package, Nov 5, 2025)
- **Release Date**: ansible-core 2.20.0 released Nov 4, 2025
- **Compatibility**: All modern Linux distributions
- **Installation**: `pip install ansible`
- **Documentation**: https://docs.ansible.com/
- **Notes**: Use ansible-core 2.20.x for latest features, community package for collections

## Talos Linux

### Talos Linux
- **Version**: v1.11.4
- **Release Date**: November 6, 2025
- **Kubernetes Version**: Supports v1.31+
- **Compatibility**: Proxmox VE 9.0 with qemu-guest-agent
- **Official Site**: https://www.talos.dev/
- **Release Notes**: https://github.com/siderolabs/talos/releases
- **Notes**:
  - Built with Go 1.24.9, runc 1.3.3, Linux kernel 6.12.57
  - Supports Wake-on-LAN (WOL)
  - Machine config embedding in boot image
  - Use Talos Factory for custom images with extensions

### Talosctl
- **Version**: Match Talos version (v1.11.4)
- **Compatibility**: Client-server version must match
- **Installation**: https://www.talos.dev/v1.11/introduction/quickstart/
- **Notes**: Download client matching your Talos cluster version

## Terraform Providers

### bpg/proxmox Provider
- **Version**: 0.86.0
- **Release Date**: ~16 days ago (late Oct/early Nov 2025)
- **Registry**: https://registry.terraform.io/providers/bpg/proxmox/latest
- **GitHub**: https://github.com/bpg/terraform-provider-proxmox
- **Usage**:
  ```hcl
  terraform {
    required_providers {
      proxmox = {
        source  = "bpg/proxmox"
        version = "~> 0.86.0"
      }
    }
  }
  ```
- **Notes**:
  - Version 0.x not guaranteed backward compatible
  - Work in progress for v1.0 with Terraform Plugin Framework
  - Most feature-complete Proxmox provider available

### siderolabs/talos Provider
- **Version**: 0.9.0
- **Release Date**: ~September 2025
- **Registry**: https://registry.terraform.io/providers/siderolabs/talos/latest
- **GitHub**: https://github.com/siderolabs/terraform-provider-talos
- **Usage**:
  ```hcl
  terraform {
    required_providers {
      talos = {
        source  = "siderolabs/talos"
        version = "~> 0.9.0"
      }
    }
  }
  ```
- **Notes**:
  - Official HashiCorp-verified provider
  - Manages Talos machine configs, bootstrapping, cluster health
  - Retrieves kubeconfig and talosconfig

## Complementary Tools

### TFLint (Terraform Linter)
- **Version**: v0.59.1
- **Release Date**: September 1, 2025
- **Compatibility**: Terraform v1.13 supported
- **Installation**: https://github.com/terraform-linters/tflint
- **Notes**:
  - Go 1.25 based
  - Requires SDK v0.16+ for plugins
  - Run `tflint --init` before first use

### Trivy (Security Scanner)
- **Version**: v0.67.2
- **Release Date**: October 10, 2025
- **Capabilities**: CVE scanning, IaC misconfig detection, SBOM generation, secrets scanning
- **Installation**: https://aquasecurity.github.io/trivy/
- **GitHub**: https://github.com/aquasecurity/trivy
- **Usage**: `trivy config .` for IaC scanning
- **Notes**:
  - Comprehensive scanner (successor to tfsec)
  - Single binary, no dependencies
  - Actively maintained by Aqua Security

### ansible-lint
- **Version**: 25.11.0
- **Release Date**: November 10, 2025
- **Compatibility**: Last 2 major Ansible versions
- **Installation**: `pip install ansible-lint`
- **Documentation**: https://ansible-lint.readthedocs.io/
- **Notes**: Checks playbooks for best practices and potential improvements

### yamllint
- **Version**: Latest from PyPI
- **Installation**: `pip install yamllint`
- **Documentation**: https://yamllint.readthedocs.io/
- **Notes**: YAML syntax and style checker

## Secrets Management

### SOPS
- **Version**: 3.11.0
- **Release Date**: September 28, 2025
- **Supported Backends**: AWS KMS, GCP KMS, Azure Key Vault, Age, PGP
- **Installation**: https://github.com/getsops/sops/releases
- **GitHub**: https://github.com/getsops/sops
- **Usage**: `sops -e file.yaml > file.enc.yaml`
- **Notes**:
  - Supports YAML, JSON, ENV, INI, BINARY formats
  - Recommend Age over PGP for simplicity

### Age
- **Version**: v1.1.1
- **Release Date**: Latest stable
- **Official Site**: https://github.com/FiloSottile/age
- **Installation**: https://github.com/FiloSottile/age#installation
- **Usage**: `age-keygen -o ~/.config/sops/age/keys.txt`
- **Notes**:
  - Simple, modern alternative to OpenPGP
  - No config options, UNIX-style composability
  - Supports hardware tokens (YubiKey) via plugins
  - Pre-built binaries for all major platforms

## Kubernetes Stack (for Talos)

### Cilium (CNI)
- **Version**: v1.18.0
- **Release Date**: Referenced in 2025 documentation
- **Official Site**: https://cilium.io/
- **Documentation**: https://docs.cilium.io/
- **GitHub**: https://github.com/cilium/cilium
- **Installation**: Via Helm or Talos bootstrapping
- **Notes**:
  - eBPF-based networking, observability, and security
  - Can replace kube-proxy
  - L2/L4/L7 load balancing
  - Talos integration: https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/

### FluxCD (GitOps)
- **Version**: v2.7.3
- **Release Date**: October 28, 2025
- **Major Release**: v2.7.0 GA (September 30, 2025)
- **Official Site**: https://fluxcd.io/
- **Documentation**: https://fluxcd.io/flux/
- **GitHub**: https://github.com/fluxcd/flux2
- **Installation**: `flux bootstrap`
- **Notes**:
  - CNCF Graduated project
  - v2.7.0 GA for Image Automation APIs
  - v2.6.0 GA for OCI Artifacts support
  - Supports latest 3 Kubernetes minor versions

### kubectl
- **Version**: Match Kubernetes version (v1.31+)
- **Compatibility**: Within 1 minor version of cluster
- **Installation**: https://kubernetes.io/docs/tasks/tools/
- **Notes**: Install version matching your Kubernetes cluster

## Optional Enhancement Tools

### terraform-docs
- **Version**: Latest stable
- **Purpose**: Auto-generate module documentation
- **Installation**: https://terraform-docs.io/
- **Usage**: `terraform-docs markdown . > README.md`

### pre-commit
- **Version**: Latest stable
- **Purpose**: Git hooks framework
- **Installation**: `pip install pre-commit`
- **Documentation**: https://pre-commit.com/
- **Notes**: Optional for homelab, useful for automation

### pre-commit-terraform
- **Version**: Latest stable
- **Purpose**: Pre-configured Terraform hooks
- **GitHub**: https://github.com/antonbabenko/pre-commit-terraform
- **Notes**: Integrates terraform fmt, tflint, trivy, terraform-docs

### tfenv
- **Version**: Latest stable
- **Purpose**: Terraform version manager
- **GitHub**: https://github.com/tfutils/tfenv
- **Notes**: Switch between multiple Terraform versions

### Molecule (Ansible Testing)
- **Version**: Latest stable
- **Purpose**: Ansible role testing framework
- **Documentation**: https://molecule.readthedocs.io/
- **Notes**: Optional, only for complex reusable roles

## Version Compatibility Matrix

| Component | Version | Kubernetes | Talos | Proxmox VE |
|-----------|---------|------------|-------|------------|
| Talos Linux | v1.11.4 | v1.31+ | - | 9.0 ✓ |
| talosctl | v1.11.4 | - | v1.11.4 | - |
| kubectl | v1.31+ | v1.31+ | - | - |
| Terraform | 1.13.5 | - | - | 9.0 ✓ |
| Packer | 1.14.2 | - | - | 9.0 ✓ |
| Ansible | 2.20.0 | - | - | 9.0 ✓ |
| bpg/proxmox | 0.86.0 | - | - | 9.0 ✓ |
| siderolabs/talos | 0.9.0 | - | v1.11+ | - |
| Cilium | v1.18.0 | v1.28+ | v1.7+ | - |
| FluxCD | v2.7.3 | v1.28+ | Any | - |

## Installation Quick Reference

### Install Core Tools (Ubuntu/Debian)
```bash
# Terraform
wget https://releases.hashicorp.com/terraform/1.13.5/terraform_1.13.5_linux_amd64.zip
unzip terraform_1.13.5_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Packer
wget https://releases.hashicorp.com/packer/1.14.2/packer_1.14.2_linux_amd64.zip
unzip packer_1.14.2_linux_amd64.zip
sudo mv packer /usr/local/bin/

# Ansible
pip install ansible

# TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# ansible-lint
pip install ansible-lint yamllint

# SOPS
wget https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64
sudo mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops

# Age
wget https://dl.filippo.io/age/latest?for=linux/amd64 -O age.tar.gz
tar xf age.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/

# talosctl
curl -sL https://talos.dev/install | sh

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# FluxCD CLI
curl -s https://fluxcd.io/install.sh | sudo bash
```

## Update Strategy

### When to Update

**Critical Security Updates**: Apply immediately
- Terraform, Packer, Ansible: Security patches
- Trivy: CVE database updates daily
- SOPS, Age: Cryptographic vulnerabilities

**Stable Release Updates**: Quarterly review
- Major version upgrades: Test in dev first
- Minor version upgrades: Low risk, review changelog
- Patch versions: Generally safe to apply

**Talos Linux Updates**:
- Follow official upgrade guide: https://www.talos.dev/v1.11/talos-guides/upgrading-talos/
- Test on single node before cluster-wide upgrade
- Always backup etcd before major upgrades

**Terraform Provider Updates**:
- bpg/proxmox: Review breaking changes (0.x series)
- siderolabs/talos: Match with Talos version

### Version Pinning Strategy

**In Terraform**:
```hcl
terraform {
  required_version = "~> 1.13.5"  # Allow patch updates only

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86.0"  # Pessimistic constraint
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }
  }
}
```

**In Ansible** (requirements.yml):
```yaml
---
collections:
  - name: community.sops
    version: ">=1.0.0,<2.0.0"
```

**In Packer** (packer.pkr.hcl):
```hcl
packer {
  required_version = "~> 1.14.2"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.2.0"
    }
  }
}
```

## Troubleshooting Version Issues

### Terraform Provider Version Conflicts
```bash
# Clear provider cache
rm -rf .terraform/
rm .terraform.lock.hcl
terraform init
```

### Ansible Collection Updates
```bash
# Update collections
ansible-galaxy collection install --upgrade community.sops
```

### Talos Version Mismatch
```bash
# Check versions
talosctl version
kubectl version

# Upgrade talosctl to match cluster
curl -sL https://talos.dev/install | sh -s -- --version v1.11.4
```

## References

- Terraform Releases: https://releases.hashicorp.com/terraform/
- Packer Releases: https://releases.hashicorp.com/packer/
- Ansible Releases: https://github.com/ansible/ansible/releases
- Talos Releases: https://github.com/siderolabs/talos/releases
- bpg/proxmox Releases: https://github.com/bpg/terraform-provider-proxmox/releases
- siderolabs/talos Provider: https://registry.terraform.io/providers/siderolabs/talos/latest
- Cilium Releases: https://github.com/cilium/cilium/releases
- FluxCD Releases: https://github.com/fluxcd/flux2/releases

---

**Note**: This document should be reviewed and updated quarterly or when major tool updates are released. Always test version updates in a development environment before applying to production systems.
