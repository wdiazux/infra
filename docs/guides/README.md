# Implementation Guides

**Step-by-step guides for deploying and operating your Talos infrastructure**

---

## 📁 Guide Categories

### [Getting Started](getting-started/)
Complete beginner's guides for Talos operations

- **TALOS-GETTING-STARTED.md** - Complete beginner's guide
  - Initial setup verification
  - Essential commands (talosctl, kubectl)
  - NGINX deployment example
  - Troubleshooting
  - Quick reference

### [Deployment Guides](deployment/)
OS-specific deployment guides for all supported operating systems

- **TALOS-DEPLOYMENT-GUIDE.md** - Talos Linux (primary platform)
- **DEBIAN-DEPLOYMENT-GUIDE.md** - Debian 13
- **ARCH-DEPLOYMENT-GUIDE.md** - Arch Linux
- **NIXOS-DEPLOYMENT-GUIDE.md** - NixOS
- **WINDOWS-DEPLOYMENT-GUIDE.md** - Windows Server

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

## 🎯 Recommended Reading Path

1. **Start Here:** [Getting Started](getting-started/TALOS-GETTING-STARTED.md)
2. **Deploy OS:** [Deployment Guides](deployment/)
3. **Add Services:** [Services Guide](services/RECOMMENDED-SERVICES-GUIDE.md)
4. **Secure Secrets:** [../secrets/](../secrets/)

---

[← Back to Documentation](../README.md)
