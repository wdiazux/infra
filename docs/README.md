# Infrastructure Documentation

Comprehensive documentation for Talos Kubernetes homelab on Proxmox VE.

**Last Updated:** 2026-01-21

---

## Quick Navigation

| Section | Description |
|---------|-------------|
| [Getting Started](getting-started/) | Prerequisites, quickstart, architecture overview |
| [Deployment](deployment/) | Talos cluster and traditional VM deployment |
| [Services](services/) | Cilium, Longhorn, Forgejo, FluxCD, GPU |
| [Operations](operations/) | Secrets, backups, upgrades, troubleshooting |
| [Reference](reference/) | Network IPs, Terraform inputs/outputs, infrastructure |
| [Research](research/) | Research reports (historical) |

---

## Getting Started

New to this infrastructure? Start here:

1. **[Prerequisites](getting-started/prerequisites.md)** - Proxmox setup, tools, network configuration
2. **[Quickstart](getting-started/quickstart.md)** - Deploy your first Talos cluster in 10 minutes

---

## Deployment Guides

### Primary: Talos Kubernetes

| Guide | Description |
|-------|-------------|
| [Talos Deployment](deployment/talos.md) | Single-node Talos cluster with GPU passthrough |
| [Deployment Checklist](deployment/checklist.md) | Phase-by-phase validation checklist |

### Traditional VMs

See component READMEs in `packer/` for Ubuntu, Debian, Arch, NixOS, and Windows templates.

---

## Services

### Infrastructure Services

| Service | Description |
|---------|-------------|
| [Cilium](services/cilium.md) | CNI with eBPF, L2 LoadBalancer announcements |
| [Longhorn](services/longhorn.md) | Distributed block storage with snapshots |
| [NFS Storage](services/nfs-storage.md) | NFS media storage and NAS permissions |
| [Forgejo](services/forgejo.md) | In-cluster Git server for GitOps |
| [FluxCD](services/fluxcd.md) | GitOps continuous delivery |
| [GPU](services/gpu.md) | NVIDIA GPU passthrough and container toolkit |
| [Monitoring](services/monitoring.md) | VictoriaMetrics + Grafana observability stack |

---

## Operations

| Topic | Description |
|-------|-------------|
| [Secrets Management](operations/secrets.md) | SOPS + Age encryption with FluxCD |
| [Backups](operations/backups.md) | Longhorn NFS backup configuration |
| [Upgrades](operations/upgrades.md) | Talos, Kubernetes, and Helm upgrades |
| [Destroy](operations/destroy.md) | Safe cluster teardown procedures |
| [Troubleshooting](operations/troubleshooting.md) | Common issues and solutions |

---

## Reference

| Document | Description |
|----------|-------------|
| [Network](reference/network.md) | IP allocations, service endpoints, LoadBalancer pool |
| [Terraform](reference/terraform.md) | All Terraform inputs and outputs |
| [Infrastructure](reference/infrastructure.md) | Hardware specs, assumptions, PCI IDs |

---

## Research Reports

Historical research with 90+ official sources:

| Report | Topic |
|--------|-------|
| [Talos Research](research/talos-research-report.md) | Talos Linux deployment patterns |
| [Packer + Proxmox](research/packer-proxmox-research-report.md) | Golden image best practices |
| [Ansible](research/ansible-research-report.md) | Configuration management patterns |

---

## Quick Reference

### Common Tasks

| Task | Command/Location |
|------|------------------|
| Deploy Talos cluster | `cd terraform/talos && terraform apply` |
| Destroy cluster | `./destroy.sh --force` |
| View cluster status | `talosctl dashboard` |
| Check services | `kubectl get pods -A` |
| Encrypt a secret | `sops -e secret.yaml > secret.enc.yaml` |

### Service URLs (Default IPs)

| Service | URL |
|---------|-----|
| Hubble UI | http://10.10.2.11 |
| Longhorn UI | http://10.10.2.12 |
| Forgejo | http://10.10.2.13 |
| FluxCD Webhook | http://10.10.2.15 |
| Weave GitOps | http://10.10.2.16 |
| MinIO Console | http://10.10.2.17 |
| Open WebUI | http://10.10.2.19 |
| Homepage | http://10.10.2.21 |
| Immich | http://10.10.2.22 |
| Grafana | http://10.10.2.23 |
| VictoriaMetrics | http://10.10.2.24 |
| Home Assistant | http://10.10.2.25 |
| n8n | http://10.10.2.26 |

---

## Related Documentation

- [Project README](../README.md) - Project overview
- [CLAUDE.md](../CLAUDE.md) - AI assistant context and conventions
- [terraform/](../terraform/) - Terraform configurations
- [packer/](../packer/) - Golden image templates
- [kubernetes/](../kubernetes/) - Kubernetes manifests

---

**Navigation:** [Getting Started](getting-started/) | [Deployment](deployment/) | [Services](services/) | [Operations](operations/) | [Reference](reference/)
