# Implementation Guides

**Step-by-step guides for deploying and operating your Talos infrastructure**

---

## Guide Categories

### [Getting Started](getting-started/)
Complete beginner's guides for Talos operations

- **TALOS-GETTING-STARTED.md** - Complete beginner's guide
  - Initial setup verification
  - Essential commands (talosctl, kubectl)
  - NGINX deployment example
  - Troubleshooting
  - Quick reference

- **TALOS-FACTORY-GUIDE.md** - Generate custom Talos images
  - Select Talos version
  - Add required extensions (iscsi-tools, util-linux-tools)
  - Generate schematic ID for Terraform

### [Deployment Guides](deployment/)
OS-specific deployment guides for all supported operating systems

- **TALOS-DEPLOYMENT-GUIDE.md** - Talos Linux (primary platform)
- **DEBIAN-DEPLOYMENT-GUIDE.md** - Debian 13
- **DEBIAN-DEPLOYMENT-EXAMPLE.md** - Debian Terraform deployment example
- **ARCH-DEPLOYMENT-GUIDE.md** - Arch Linux
- **NIXOS-DEPLOYMENT-GUIDE.md** - NixOS
- **WINDOWS-DEPLOYMENT-GUIDE.md** - Windows Server
- **LONGHORN-INTEGRATION.md** - Longhorn storage integration with Terraform

### [Services](services/)
Production service deployment guides

- **RECOMMENDED-SERVICES-GUIDE.md** - Complete service stack
  - FluxCD + SOPS (GitOps)
  - Forgejo (self-hosted Git)
  - Monitoring (Prometheus/Grafana)
  - GPU workloads
  - CI/CD options
  - Complete YAML examples

---

## Recommended Reading Path

1. **Start Here:** [Getting Started](getting-started/TALOS-GETTING-STARTED.md)
2. **Generate Image:** [Talos Factory Guide](getting-started/TALOS-FACTORY-GUIDE.md)
3. **Deploy OS:** [Deployment Guides](deployment/)
4. **Add Services:** [Services Guide](services/RECOMMENDED-SERVICES-GUIDE.md)
5. **Secure Secrets:** [../secrets/](../secrets/)

---

[Back to Documentation](../README.md)
