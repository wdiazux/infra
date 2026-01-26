# Network Reference

Network configuration and IP allocations for the homelab infrastructure.

---

## Overview

| Setting | Value |
|---------|-------|
| Network | `10.10.2.0/24` |
| Gateway | `10.10.2.1` |
| DNS | `10.10.2.1`, `8.8.8.8` |
| Domain | `home-infra.net` |

---

## IP Allocation Scheme

| Range | Purpose | Count |
|-------|---------|-------|
| 10.10.2.1-10 | Core Infrastructure | 10 |
| 10.10.2.11-150 | Kubernetes Services & Apps (LoadBalancer) | 140 |
| 10.10.2.151-254 | Traditional VMs | 104 |

---

## Core Infrastructure (10.10.2.1-10)

| IP | Hostname | Description | Status |
|----|----------|-------------|--------|
| 10.10.2.1 | gateway | Router/Gateway | Required |
| 10.10.2.2 | proxmox | Proxmox VE Host | Required |
| 10.10.2.5 | nas | NAS (Longhorn backup) | Optional |
| 10.10.2.10 | talos-node | Talos Kubernetes Node | Required |

---

## LoadBalancer Services

Only services requiring direct network access use LoadBalancer IPs.
All web UIs use ClusterIP and are accessed via Cilium Gateway API at 10.10.2.20.

| IP | Service | Port | Namespace | Purpose |
|----|---------|------|-----------|---------|
| 10.10.2.14 | Forgejo SSH | 22 | forgejo | Git SSH access |
| 10.10.2.15 | FluxCD Webhook | 80 | flux-system | External webhook receiver |
| 10.10.2.20 | Gateway API | 443 | kube-system | HTTPS termination (all web UIs) |
| 10.10.2.41 | qBittorrent | 6881 | arr-stack | BitTorrent protocol |
| 10.10.2.50 | Ollama | 11434 | ai | LLM API access |

---

## Traditional VMs (10.10.2.151-254)

| IP | Hostname | OS | Status |
|----|----------|----|--------|
| 10.10.2.151 | ubuntu-vm | Ubuntu 24.04 | Planned |
| 10.10.2.152 | debian-vm | Debian 13 | Planned |
| 10.10.2.153 | arch-vm | Arch Linux | Planned |
| 10.10.2.154 | nixos-vm | NixOS 25.11 | Planned |
| 10.10.2.155 | windows-vm | Windows | Planned |

---

## Cilium LoadBalancer Pool

Services and applications use IPs from the 10.10.2.11-150 range.

```yaml
# Cilium L2 Announcement configuration
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
spec:
  blocks:
    - start: "10.10.2.11"
      stop: "10.10.2.150"
```

---

## Service Access Points

### Infrastructure (Direct IP)

| Service | URL | Auth |
|---------|-----|------|
| Proxmox | https://10.10.2.2:8006 | API Token |
| Kubernetes API | https://10.10.2.10:6443 | kubeconfig |
| Talos API | https://10.10.2.10:50000 | talosconfig |
| Forgejo SSH | ssh://git@10.10.2.14 | SSH Key |
| Ollama | http://10.10.2.50:11434 | None |

### Web Services (via Gateway API at 10.10.2.20)

| Service | URL | Auth |
|---------|-----|------|
| Homepage | https://home-infra.net | None |
| Zitadel | https://auth.home-infra.net | SSO |
| Grafana | https://grafana.home-infra.net | SSO (Zitadel) |
| Forgejo | https://git.home-infra.net | SSO (Zitadel) |
| Immich | https://photos.reynoza.org | SSO (Zitadel) |
| Open WebUI | https://chat.home-infra.net | SSO (Zitadel) |
| Paperless-ngx | https://paperless.home-infra.net | SSO (Zitadel) |
| Home Assistant | https://hass.home-infra.net | Username/Password |
| Hubble UI | https://hubble.home-infra.net | Forward Auth |
| Longhorn UI | https://longhorn.home-infra.net | Forward Auth |
| VictoriaMetrics | https://metrics.home-infra.net | Forward Auth |
| Navidrome | https://music.home-infra.net | Username/Password |
| Emby | https://emby.home-infra.net | Username/Password |
| ComfyUI | https://comfy.home-infra.net | None |
| Weave GitOps | https://gitops.home-infra.net | Username/Password |
| n8n | https://n8n.home-infra.net | Username/Password |
| Radarr | https://radarr.home-infra.net | Forward Auth |
| Sonarr | https://sonarr.home-infra.net | Forward Auth |
| Prowlarr | https://prowlarr.home-infra.net | Forward Auth |
| Bazarr | https://bazarr.home-infra.net | Forward Auth |
| SABnzbd | https://sabnzbd.home-infra.net | Forward Auth |
| qBittorrent | https://qbittorrent.home-infra.net | Forward Auth |

---

## Local HTTPS Access (Gateway API Architecture)

Services are accessible via HTTPS using wildcard certificates from Let's Encrypt.
Cilium Gateway API provides TLS termination with HTTPRoute/GRPCRoute routing.

### DNS Resolution

| Domain Suffix | Resolves To | Protocol | Purpose |
|---------------|-------------|----------|---------|
| `*.home-infra.net` | 10.10.2.20 (Gateway) | HTTPS | Local HTTPS access |
| `*.reynoza.org` | 10.10.2.20 (Gateway) | HTTPS | External domain (Immich) |

### How It Works

```
Local Client (browser)
         │
         ▼
    ControlD DNS
         │ resolves *.home-infra.net → 10.10.2.20
         ▼
  Cilium Gateway API (10.10.2.20)
         │ TLS termination (Let's Encrypt wildcard cert)
         │ Routes by hostname (HTTPRoute/GRPCRoute)
         ▼
  Backend Service (e.g., Navidrome)
```

### HTTPS URLs

| Service | HTTPS URL |
|---------|-----------|
| Homepage | https://home-infra.net |
| Navidrome | https://music.home-infra.net |
| Grafana | https://grafana.home-infra.net |
| Open WebUI | https://chat.home-infra.net |
| Immich | https://photos.reynoza.org |

### Certificate Management

- **Provider:** Let's Encrypt (production)
- **Type:** Wildcard certificates (*.home-infra.net, *.reynoza.org)
- **Challenge:** DNS-01 via Cloudflare API
- **Distribution:** Reflector syncs certs to all app namespaces
- **Documentation:** See [cert-manager docs](../services/cert-manager.md)

---

## DNS Records (ControlD)

ControlD handles local DNS for homelab access. All services use HTTPS via Gateway API.

### Domain Resolution

All `*.home-infra.net` and `*.reynoza.org` domains resolve to Gateway API for HTTPS:

```
10.10.2.20   home-infra.net      # Homepage (root domain)
10.10.2.20   *.home-infra.net    # All services via Gateway API
10.10.2.20   *.reynoza.org       # Immich (photos.reynoza.org)
```

### Static Infrastructure

```
10.10.2.20   proxmox.home-infra.net pve.home-infra.net
10.10.2.20   nas.home-infra.net
```

---

## Quick Check Commands

```bash
# Check LoadBalancer services
kubectl get svc -A | grep LoadBalancer

# Check Cilium IP pool
kubectl get ciliumloadbalancerippool -A

# Test Gateway API (all web services)
curl -sk https://10.10.2.20 -H "Host: home-infra.net"

# Test LoadBalancer services
curl -s http://10.10.2.50:11434/api/version  # Ollama

# Test HTTPS services (requires DNS resolution)
curl -s https://grafana.home-infra.net/api/health
curl -s https://git.home-infra.net
curl -s https://auth.home-infra.net/.well-known/openid-configuration
```

---

## Kubernetes Internal DNS

Internal service DNS names for cluster-internal access and Pangolin resource configuration.

Format: `<service>.<namespace>.svc.cluster.local`

> **Note: Service-to-Service Communication**
>
> When configuring communication between Kubernetes services:
>
> | Scenario | Use | Example |
> |----------|-----|---------|
> | Same namespace | Service name only | `http://redis:6379` |
> | Different namespace | Full internal DNS | `http://ollama.ai.svc.cluster.local:11434` |
> | External access (users) | Domain name | `http://grafana.home-infra.net` |
>
> **Best practices:**
> - Services in the **same namespace** should use short names (e.g., `postgres`, `redis`)
> - Services in **different namespaces** must use full DNS names
> - **Never use external domains** for internal service communication (adds latency, breaks if DNS fails)
> - **Never use LoadBalancer IPs** for internal communication (unnecessary network hops)

### Core Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Hubble UI | `hubble-ui.kube-system.svc.cluster.local` | 80 | 8081 |
| Longhorn UI | `longhorn-frontend.longhorn-system.svc.cluster.local` | 80 | 80 |
| Forgejo HTTP | `forgejo-http.forgejo.svc.cluster.local` | 80 | 3000 |
| Forgejo SSH | `forgejo-ssh.forgejo.svc.cluster.local` | 22 | 22 |
| FluxCD Webhook | `webhook-receiver-lb.flux-system.svc.cluster.local` | 80 | 9292 |
| Weave GitOps | `weave-gitops-lb.flux-system.svc.cluster.local` | 80 | 9001 |
| MinIO Console | `minio-console.backup.svc.cluster.local` | 80 | 9001 |

### AI Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Open WebUI | `open-webui.ai.svc.cluster.local` | 80 | 8080 |
| Ollama | `ollama-lb.ai.svc.cluster.local` | 11434 | 11434 |
| ComfyUI | `comfyui.ai.svc.cluster.local` | 80 | 8188 |

### Media Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Immich | `immich.media.svc.cluster.local` | 80 | 2283 |
| Emby | `emby.media.svc.cluster.local` | 80 | 8096 |
| Navidrome | `navidrome.media.svc.cluster.local` | 80 | 4533 |

### Automation Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Home Assistant | `home-assistant.automation.svc.cluster.local` | 80 | 8123 |
| n8n | `n8n.automation.svc.cluster.local` | 80 | 5678 |

### Monitoring Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Grafana | `grafana.monitoring.svc.cluster.local` | 80 | 3000 |
| VictoriaMetrics | `victoriametrics-lb.monitoring.svc.cluster.local` | 80 | 8428 |

### Tools & Management

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Homepage | `homepage.tools.svc.cluster.local` | 80 | 3000 |
| IT-Tools | `it-tools.tools.svc.cluster.local` | 80 | 80 |
| Attic | `attic.tools.svc.cluster.local` | 80 | 8080 |
| ntfy | `ntfy.tools.svc.cluster.local` | 80 | 80 |
| Wallos | `wallos.management.svc.cluster.local` | 80 | 80 |
| Paperless-ngx | `paperless.management.svc.cluster.local` | 80 | 8000 |

### Arr-Stack Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| SABnzbd | `sabnzbd.arr-stack.svc.cluster.local` | 80 | 8080 |
| qBittorrent | `qbittorrent.arr-stack.svc.cluster.local` | 80 | 8080 |
| Prowlarr | `prowlarr.arr-stack.svc.cluster.local` | 80 | 9696 |
| Radarr | `radarr.arr-stack.svc.cluster.local` | 80 | 7878 |
| Sonarr | `sonarr.arr-stack.svc.cluster.local` | 80 | 8989 |
| Bazarr | `bazarr.arr-stack.svc.cluster.local` | 80 | 6767 |

### Other Services

| Service | Internal DNS | Port | Target Port |
|---------|--------------|------|-------------|
| Obico | `obico-server.printing.svc.cluster.local` | 80 | 3334 |

---

## Domain Management

### Cloudflare Domains

All external domains are registered and managed in Cloudflare, pointing to the Pangolin VPS.

| Domain | Registrar | DNS Provider | Points To | Purpose |
|--------|-----------|--------------|-----------|---------|
| `home-infra.net` | Cloudflare | Cloudflare | VPS (207.246.115.3) | Primary homelab domain |
| `reynoza.org` | Cloudflare | Cloudflare | VPS (207.246.115.3) | Family/personal services |
| `wdiaz.org` | Cloudflare | Cloudflare | VPS (207.246.115.3) | Personal domain |
| `unix.red` | Cloudflare | Cloudflare | VPS (207.246.115.3) | Tech/projects domain |

### Domain Resolution Strategy

| Domain | Purpose | Resolution Method |
|--------|---------|-------------------|
| `home-infra.net` | Homelab services | ControlD (home) / Cloudflare → Pangolin (external) |
| `reynoza.org` | External services (Immich) | ControlD (home) / Cloudflare → Pangolin (external) |
| `wdiaz.org` | External services | Cloudflare → Pangolin |
| `unix.red` | External services | Cloudflare → Pangolin |
| `.local` | mDNS | Router/mDNS |

### Traffic Flow

```
External Request (e.g., photos.reynoza.org)
         │
         ▼
    Cloudflare DNS
         │ (resolves to VPS IP)
         ▼
  Pangolin VPS (207.246.115.3)
         │ (WireGuard tunnel)
         ▼
    Talos Homelab
         │
         ▼
  Kubernetes Service
```

---

## External Access via Pangolin

Services can be exposed externally via Pangolin tunneling (no port forwarding required).

### Exposed Services

| External Domain | Internal DNS | LoadBalancer IP | Access |
|-----------------|--------------|-----------------|--------|
| home-infra.net | `homepage.tools.svc.cluster.local` | 10.10.2.21 | Private |
| photos.reynoza.org | `immich.media.svc.cluster.local` | 10.10.2.22 | Private |

### Pangolin Resource Configuration

When adding resources in Pangolin, use either:

1. **LoadBalancer IP** (recommended for Talos Newt extension):
   ```
   Target: http://10.10.2.21
   Port: 80
   ```

2. **Internal DNS** (if Newt runs inside cluster as pod):
   ```
   Target: http://homepage.tools.svc.cluster.local
   Port: 80
   ```

**Architecture:**
- Pangolin VPS at 207.246.115.3 (NixOS)
- WireGuard tunnel via Newt extension in Talos
- Handles domains: reynoza.org, unix.red, home-infra.net (external)

**Configuration:** See [Pangolin documentation](../services/pangolin.md)

---

**Last Updated:** 2026-01-26
