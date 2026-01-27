# CLAUDE.md - Infrastructure Project Guide

## Quick Start

```bash
# Enter development environment (all tools auto-available)
nix-shell   # or: direnv allow

# Set kubeconfig
export KUBECONFIG=terraform/talos/kubeconfig

# Custom commands available
/k8s-status      # Cluster health check
/tf-plan         # Terraform plan workflow
/tf-apply        # Terraform apply workflow
/deploy-service  # New service deployment
/update-service  # Update existing service
/debug           # Systematic troubleshooting
```

**Claude Code customizations**: See `.claude/` for hooks, commands, and sub-agents.

## Project Overview

Infrastructure-as-Code for a single-node Proxmox homelab running Talos Linux (Kubernetes).

**Stack**: Terraform + Packer + Ansible + Talos + FluxCD + SOPS

**Homelab Philosophy** - Keep it simple:
- ✅ Linting, security scanning, version control, IaC, secrets encryption
- ⚠️ Skip: remote state, multiple environments, PR reviews, resource limits

## Repository Structure

```
infra/
├── .claude/         # Claude Code customizations (hooks, commands, agents)
├── packer/          # Golden image templates (talos/, ubuntu/, debian/, arch/, nixos/)
├── terraform/       # Terraform configs (talos/, traditional-vms/, modules/)
├── ansible/         # Ansible playbooks and roles
├── kubernetes/      # K8s manifests (apps/, clusters/, infrastructure/)
├── secrets/         # SOPS-encrypted secrets
├── docs/            # Documentation
├── shell.nix        # Nix development environment
└── CLAUDE.md        # This file
```

## Technology Stack

| Component | Version/Tool |
|-----------|-------------|
| Hypervisor | Proxmox VE 9.0 |
| Terraform | >= 1.14.2 |
| Talos Linux | v1.12.1 |
| Kubernetes | v1.35.0 |
| CNI | Cilium (eBPF, L2 LB) |
| Storage | Longhorn + NFS CSI |
| GitOps | FluxCD |
| Secrets | SOPS + Age |
| SSO | Zitadel + oauth2-proxy |
| Monitoring | VictoriaMetrics + Grafana |

**Providers**: siderolabs/talos ~> 0.10.0, bpg/proxmox ~> 0.93.0

## Hardware

- **System**: Minisforum MS-A2
- **CPU**: AMD Ryzen AI 9 HX 370 (12 cores)
- **RAM**: 96GB
- **GPU**: NVIDIA RTX 4000 SFF (PCI 07:00.0) - single VM only
- **Storage**: ZFS (16GB ARC max)

## Network Configuration

**Infrastructure Network**: 10.10.2.0/24

| Range | Purpose |
|-------|---------|
| 10.10.2.1-10 | Core infrastructure |
| 10.10.2.11-50 | Kubernetes LoadBalancers (Cilium L2 pool) |
| 10.10.2.151-254 | Traditional VMs |

### Network Architecture

All web UIs use ClusterIP services and are accessed via Cilium Gateway API:
- **Gateway IP**: 10.10.2.20 (HTTPS termination via HTTPRoute/GRPCRoute)
- **Domain**: *.home-infra.net, *.reynoza.org → 10.10.2.20

**Internal Service Communication Preference** (in priority order):
1. **Direct hostname** (e.g., `http://zitadel.auth.svc.cluster.local:8080`) - preferred, avoids DNS/Gateway/L7 proxy issues
2. **Internal DNS** (e.g., CoreDNS rewrite resolves `auth.home-infra.net` → Gateway ClusterIP) - works for services with CoreDNS rewrites
3. **External DNS** (e.g., `https://auth.home-infra.net` → Gateway LoadBalancer IP 10.10.2.20) - last resort, requires port 443 egress + CiliumNetworkPolicy for Zitadel OIDC

Only services requiring direct network access use LoadBalancer IPs:

| Component | IP | Purpose |
|-----------|-----|---------|
| Gateway | 10.10.2.1 | Network router |
| Proxmox | 10.10.2.2 | Hypervisor |
| NAS | 10.10.2.5 | TrueNAS backup target |
| Talos Node | 10.10.2.10 | Kubernetes node |
| Forgejo SSH | 10.10.2.14 | Git SSH (LoadBalancer) |
| FluxCD Webhook | 10.10.2.15 | External webhooks (LoadBalancer) |
| Gateway API | 10.10.2.20 | HTTPS termination (LoadBalancer) |
| qBittorrent | 10.10.2.41 | BitTorrent protocol (LoadBalancer) |
| Ollama | 10.10.2.50 | LLM API (LoadBalancer) |

### Web Services (via Gateway API)

All accessed via HTTPS at `https://<service>.home-infra.net`:

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | home-infra.net | Dashboard |
| Grafana | grafana.home-infra.net | Monitoring |
| Longhorn | longhorn.home-infra.net | Storage UI |
| Hubble | hubble.home-infra.net | Network UI |
| Forgejo | git.home-infra.net | Git server |
| Zitadel | auth.home-infra.net | SSO |
| Immich | photos.reynoza.org | Photo backup |
| Open WebUI | chat.home-infra.net | LLM interface |
| ComfyUI | comfy.home-infra.net | Image generation |
| Home Assistant | hass.home-infra.net | Smart home |

**Domains**: home-infra.net, reynoza.org (ControlD for local DNS)

## Talos Implementation

**Template Creation**: Direct import from Talos Factory (not Packer)
```bash
# On Proxmox host
packer/talos/import-talos-image.sh
```

**Required Extensions** (via Talos Factory):
- `siderolabs/qemu-guest-agent`
- `siderolabs/iscsi-tools` (Longhorn)
- `siderolabs/util-linux-tools` (Longhorn)
- `nonfree-kmod-nvidia-production` (GPU, optional)

**Single-Node Requirements**:
- CPU type: "host" (not kvm64)
- Remove control-plane taint: `kubectl taint nodes --all node-role.kubernetes.io/control-plane-`
- Disable Flannel/kube-proxy (using Cilium)

## Traditional VMs

| OS | Base VM ID | Template ID | User |
|----|------------|-------------|------|
| Ubuntu 24.04 | 9100 | 9102 | ubuntu |
| Debian 13 | 9110 | 9112 | debian |
| Arch Linux | 9300 | 9302 | arch |
| NixOS 25.11 | 9200 | 9202 | nixos |

## Secrets Management

```bash
# Generate Age key
age-keygen -o ~/.config/sops/age/keys.txt

# Encrypt/decrypt
sops -e file.yaml > file.enc.yaml
sops -d file.enc.yaml
```

## Security

**Approach**: Practical homelab security with defense-in-depth layers

| Layer | Implementation | Status |
|-------|----------------|--------|
| **Secrets** | SOPS + Age encryption | ✅ Active |
| **Network** | Cilium NetworkPolicies | ✅ Active (2026-01-22) |
| **Container** | SecurityContexts, justified privileged | ✅ Active |
| **Backup** | Velero + verification procedures | ✅ Active |

**Key Decisions**:
- ✅ NetworkPolicies for sensitive namespaces (media, management, backup, forgejo, ai)
- ✅ Privileged containers only when technically required (Forgejo runner, Home Assistant, Velero)
- ⚠️ Terraform state contains decoded secrets (local only, acceptable for homelab)
- ⚠️ Backup data not encrypted (NAS physically secured, simplifies recovery)

**See**: `docs/reference/security-strategy.md` for complete security posture and threat model

**Verification**:
```bash
# Check NetworkPolicies
kubectl get networkpolicies -A

# Test backup verification
docs/operations/backups.md  # See "Monthly Backup Verification Procedure"

# Security monitoring
kubectl -n kube-system exec ds/cilium -- cilium policy get  # NetworkPolicy enforcement
```

## Quick Reference

```bash
# Kubernetes
export KUBECONFIG=terraform/talos/kubeconfig
kubectl get pods -A
flux reconcile kustomization flux-system --with-source
k9s

# Terraform
cd terraform/talos
terraform init && terraform plan -out=tfplan
terraform apply tfplan

# Talos
talosctl --nodes 10.10.2.10 health
talosctl --nodes 10.10.2.10 dashboard

# SOPS
sops -e secrets/file.yaml > secrets/file.enc.yaml
```

## Key Conventions

- **Naming**: kebab-case for resources, snake_case for variables
- **User**: wdiaz, America/El_Salvador timezone
- **Kubeconfig**: `terraform/talos/kubeconfig`
- **Commits**: `<type>: <description>` (feat, fix, docs, refactor)

## AI Assistant Rules

1. **Research first** - Check official docs before implementing
2. **Propose before implementing** - Explain approach and trade-offs
3. **Clean up old code** - Remove ALL obsolete implementations
4. **Sync docs with code** - Update docs when changing versions/configs
5. **Never commit secrets** - Use SOPS encryption
6. **Run linters** - tflint, trivy, ansible-lint before committing
7. **Code reviews** - Use `/code-review` for comprehensive IaC reviews (quarterly recommended)

**Skip**: archive/research docs (historical snapshots)

**Last Terraform Review**: 2026-01-22 (see `docs/reviews/2026-01-22-terraform-review.md`)
- Status: ✅ Production-ready, all providers up-to-date
- Findings: 0 critical, 2 warnings (addressed), 3 info
- Next review: 2026-04-22 (quarterly)

## Documentation

```
docs/
├── getting-started/   # Prerequisites, quickstart
├── deployment/        # Talos deployment
├── services/          # Cilium, Longhorn, FluxCD, GPU
├── operations/        # Secrets, backups, troubleshooting
├── reference/         # Network, terraform, infrastructure
├── plans/             # Design documents
├── CHANGELOG.md       # Version history
└── CONTRIBUTING.md    # Documentation sync map
```

## Recent Changes

- **2026-01-27**: Added upgrade rollback guide (`docs/operations/upgrade-rollback.md`) for recovering from bad service upgrades with database migrations
- **2026-01-26**: Terraform code organization (14 scripts extracted to scripts/), dynamic Talos image factory schematic, talos_cluster_health, Kubernetes inline script extraction to ConfigMaps, removed Zitadel Terraform provider, documentation updates
- **2026-01-25**: Migrated web UIs from LoadBalancer to ClusterIP (all via Gateway API), consolidated domains to home-infra.net, auto-generated Forgejo runner tokens, CiliumNetworkPolicies for K8s API access
- **2026-01-24**: Zitadel SSO implementation (replaces Logto, CoreDNS rewrite for hairpin fix)
- **2026-01-22**: Terraform code review, memory ballooning implementation, NetworkPolicies, security-strategy.md, backup verification procedures
- **2026-01-21**: Documentation audit and cleanup
- **2026-01-20**: Velero backup, PodGC, ComfyUI, Obico, version updates
- **2026-01-19**: Claude Code optimization (hooks, commands, sub-agents)
- **2026-01-17**: Paperless-ngx, Attic, monitoring stack, Home Assistant, n8n
- **2026-01-16**: AI namespace with GPU, media namespace, arr-stack

See `docs/CHANGELOG.md` for full history.

---
**Last Updated**: 2026-01-26 | **Status**: Production-Ready
