# Infrastructure Documentation

**Comprehensive documentation for Talos Kubernetes homelab on Proxmox**

Last Updated: 2025-11-23

---

## 📁 Documentation Structure

```
docs/
├── guides/              # User-facing implementation guides
│   ├── getting-started/ # Getting started with Talos
│   ├── deployment/      # OS deployment guides (6 OS)
│   └── services/        # Production services guide
├── research/            # Research reports and analysis
├── secrets/             # Secrets management guides (SOPS + FluxCD)
├── comparisons/         # Infrastructure comparisons and analysis
└── archive/             # Historical reports (preserved for reference)
```

---

## 🚀 Quick Start

**New to this infrastructure?**

1. **[Getting Started](guides/getting-started/)** - Start here
2. **[Deployment Guides](guides/deployment/)** - Deploy your OS
3. **[Services Guide](guides/services/)** - Deploy production services
4. **[Secrets Management](secrets/)** - Secure your secrets with SOPS

---

## 📚 Documentation Categories

### Getting Started Guides

| Guide | Description | Audience |
|-------|-------------|----------|
| [TALOS-GETTING-STARTED.md](guides/getting-started/TALOS-GETTING-STARTED.md) | Complete beginner's guide to Talos operations | New users |

### Deployment Guides

| Guide | OS | Type |
|-------|----|----|
| [TALOS-DEPLOYMENT-GUIDE.md](guides/deployment/TALOS-DEPLOYMENT-GUIDE.md) | Talos Linux | Primary |
| [DEBIAN-DEPLOYMENT-GUIDE.md](guides/deployment/DEBIAN-DEPLOYMENT-GUIDE.md) | Debian 13 | Traditional VM |
| [ARCH-DEPLOYMENT-GUIDE.md](guides/deployment/ARCH-DEPLOYMENT-GUIDE.md) | Arch Linux | Traditional VM |
| [NIXOS-DEPLOYMENT-GUIDE.md](guides/deployment/NIXOS-DEPLOYMENT-GUIDE.md) | NixOS | Traditional VM |
| [WINDOWS-DEPLOYMENT-GUIDE.md](guides/deployment/WINDOWS-DEPLOYMENT-GUIDE.md) | Windows Server | Traditional VM |

### Production Services

| Guide | Description | Coverage |
|-------|-------------|----------|
| [RECOMMENDED-SERVICES-GUIDE.md](guides/services/RECOMMENDED-SERVICES-GUIDE.md) | Complete production service stack | FluxCD, Forgejo, Monitoring, GPU, CI/CD |

### Secrets Management

| Guide | Description | Type |
|-------|-------------|------|
| [SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md](secrets/SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md) | Production secrets management (18KB) | Implementation |
| [KUBERNETES_SECRETS_MANAGEMENT_GUIDE.md](secrets/KUBERNETES_SECRETS_MANAGEMENT_GUIDE.md) | Complete comparison (40+ pages) | Deep-dive |
| [SECRETS_MANAGEMENT_QUICK_START.md](secrets/SECRETS_MANAGEMENT_QUICK_START.md) | 5-minute setup guide | Quick reference |
| [SOPS-ACTION-CHECKLIST.md](secrets/SOPS-ACTION-CHECKLIST.md) | Implementation checklist | Checklist |

### Research & Analysis

| Report | Topic | Sources |
|--------|-------|---------|
| [packer-proxmox-research-report.md](research/packer-proxmox-research-report.md) | Packer best practices | 33 sources |
| [ANSIBLE_RESEARCH_REPORT.md](research/ANSIBLE_RESEARCH_REPORT.md) | Ansible best practices | 31 sources |
| [talos-research-report.md](research/talos-research-report.md) | Talos Linux research | 30+ sources |

### Infrastructure Comparisons

| Report | Description | Scope |
|--------|-------------|-------|
| [COMPARISON-EXECUTIVE-SUMMARY.md](comparisons/COMPARISON-EXECUTIVE-SUMMARY.md) | Executive summary | Top 20% rating |
| [INFRASTRUCTURE-COMPARISON-REPORT.md](comparisons/INFRASTRUCTURE-COMPARISON-REPORT.md) | Detailed comparison | 10 GitHub projects |
| [ACTION-PLAN-FROM-COMPARISON.md](comparisons/ACTION-PLAN-FROM-COMPARISON.md) | Improvement roadmap | Path to Top 10% |

---

## 📖 Documentation by Use Case

### "I'm new to Talos"
1. [Getting Started](guides/getting-started/TALOS-GETTING-STARTED.md)
2. [Deployment Guide](guides/deployment/TALOS-DEPLOYMENT-GUIDE.md)
3. [Services Guide](guides/services/RECOMMENDED-SERVICES-GUIDE.md)

### "I need to deploy a service"
1. [Services Guide](guides/services/RECOMMENDED-SERVICES-GUIDE.md) - Complete examples
2. [SOPS Implementation](secrets/SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md) - For secrets

### "I want to understand secrets management"
1. [Quick Start](secrets/SECRETS_MANAGEMENT_QUICK_START.md) - 5 minutes
2. [Implementation Guide](secrets/SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md) - Step-by-step
3. [Complete Guide](secrets/KUBERNETES_SECRETS_MANAGEMENT_GUIDE.md) - All options

### "I want to learn best practices"
1. [Research Reports](research/) - 90+ sources
2. [Comparison Reports](comparisons/) - Community validation
3. Project root: `CLAUDE.md` - Complete conventions guide

---

## 📊 Documentation Metrics

- **Total Documentation**: 60+ files
- **Lines of Documentation**: 15,000+
- **Words**: 150,000+
- **Research Sources**: 90+ official sources
- **Coverage**: 100% of major components

---

## 🔗 Related Documentation

**In Project Root:**
- [README.md](../README.md) - Project overview
- [CLAUDE.md](../CLAUDE.md) - Complete project guide (2,600+ lines)
- [TODO.md](../TODO.md) - Project roadmap
- [DEPLOYMENT-CHECKLIST.md](../DEPLOYMENT-CHECKLIST.md) - Deployment validation
- [INFRASTRUCTURE-ASSUMPTIONS.md](../INFRASTRUCTURE-ASSUMPTIONS.md) - Hard-coded values

**Component-Specific:**
- [terraform/README.md](../terraform/README.md) - Terraform documentation
- [ansible/README.md](../ansible/README.md) - Ansible documentation
- [kubernetes/longhorn/INSTALLATION.md](../kubernetes/longhorn/INSTALLATION.md) - Longhorn setup
- [kubernetes/cilium/INSTALLATION.md](../kubernetes/cilium/INSTALLATION.md) - Cilium setup

---

## 🎯 Quick Links

| I want to... | Go here |
|-------------|---------|
| Get started with Talos | [guides/getting-started/](guides/getting-started/) |
| Deploy an operating system | [guides/deployment/](guides/deployment/) |
| Deploy production services | [guides/services/](guides/services/) |
| Set up secrets management | [secrets/](secrets/) |
| Learn from research | [research/](research/) |
| Compare with other projects | [comparisons/](comparisons/) |
| Find historical reports | [archive/](archive/) |

---

**Navigate:** [📁 Getting Started](guides/getting-started/) | [🚀 Deployment](guides/deployment/) | [⚙️ Services](guides/services/) | [🔐 Secrets](secrets/)
