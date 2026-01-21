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

## Kubernetes Services (10.10.2.11-20)

LoadBalancer IPs assigned to core Kubernetes services.

| IP | Service | Port | Namespace |
|----|---------|------|-----------|
| 10.10.2.11 | Hubble UI | 80 | kube-system |
| 10.10.2.12 | Longhorn UI | 80 | longhorn-system |
| 10.10.2.13 | Forgejo HTTP | 80 | forgejo |
| 10.10.2.14 | Forgejo SSH | 22 | forgejo |
| 10.10.2.15 | FluxCD Webhook | 80 | flux-system |
| 10.10.2.16 | Weave GitOps | 80 | flux-system |
| 10.10.2.17 | MinIO Console | 80 | backup |
| 10.10.2.19 | Open WebUI | 80 | ai |
| 10.10.2.20 | Ollama | 11434 | ai |

---

## Applications (10.10.2.21-150)

| IP | Service | Port | Namespace |
|----|---------|------|-----------|
| 10.10.2.21 | Homepage | 80 | tools |
| 10.10.2.22 | Immich | 80 | media |
| 10.10.2.23 | Grafana | 80 | monitoring |
| 10.10.2.24 | VictoriaMetrics | 80 | monitoring |
| 10.10.2.25 | Home Assistant | 80 | automation |
| 10.10.2.26 | n8n | 80 | automation |
| 10.10.2.27 | Obico | 80 | printing |
| 10.10.2.28 | ComfyUI | 80 | ai |
| 10.10.2.29 | Attic | 80 | tools |
| 10.10.2.30 | Emby | 80 | media |
| 10.10.2.31 | Navidrome | 80 | media |
| 10.10.2.32 | IT-Tools | 80 | tools |
| 10.10.2.34 | Wallos | 80 | management |
| 10.10.2.35 | ntfy | 80 | tools |
| 10.10.2.36 | Paperless-ngx | 80 | management |
| 10.10.2.40 | SABnzbd | 80 | arr-stack |
| 10.10.2.41 | qBittorrent | 80 | arr-stack |
| 10.10.2.42 | Prowlarr | 80 | arr-stack |
| 10.10.2.43 | Radarr | 80 | arr-stack |
| 10.10.2.44 | Sonarr | 80 | arr-stack |
| 10.10.2.45 | Bazarr | 80 | arr-stack |

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

| Service | URL | Auth |
|---------|-----|------|
| Proxmox | https://10.10.2.2:8006 | API Token |
| Kubernetes API | https://10.10.2.10:6443 | kubeconfig |
| Talos API | https://10.10.2.10:50000 | talosconfig |
| Hubble UI | http://10.10.2.11 | None |
| Longhorn UI | http://10.10.2.12 | None |
| Forgejo | http://10.10.2.13 | Username/Password |
| Forgejo SSH | ssh://git@10.10.2.14 | SSH Key |
| Weave GitOps | http://10.10.2.16 | Username/Password |
| MinIO Console | http://10.10.2.17 | Username/Password |
| Open WebUI | http://10.10.2.19 | Username/Password |
| Ollama | http://10.10.2.20:11434 | None |
| Homepage | http://10.10.2.21 | None |
| Immich | http://10.10.2.22 | Username/Password |
| Grafana | http://10.10.2.23 | Username/Password |
| VictoriaMetrics | http://10.10.2.24 | None |
| Home Assistant | http://10.10.2.25 | Username/Password |
| n8n | http://10.10.2.26 | Username/Password |
| Obico | http://10.10.2.27 | Username/Password |
| ComfyUI | http://10.10.2.28 | None (API auth optional) |
| Attic | http://10.10.2.29 | Token |
| Emby | http://10.10.2.30 | Username/Password |
| Navidrome | http://10.10.2.31 | Username/Password |
| IT-Tools | http://10.10.2.32 | None |
| Wallos | http://10.10.2.34 | Username/Password |
| ntfy | http://10.10.2.35 | Username/Password |
| Paperless-ngx | http://10.10.2.36 | Username/Password |
| SABnzbd | http://10.10.2.40 | Username/Password |
| qBittorrent | http://10.10.2.41 | Username/Password |
| Prowlarr | http://10.10.2.42 | Username/Password |
| Radarr | http://10.10.2.43 | Username/Password |
| Sonarr | http://10.10.2.44 | Username/Password |
| Bazarr | http://10.10.2.45 | Username/Password |

---

## DNS Records

Configure in your DNS server or `/etc/hosts`:

```
10.10.2.1    gateway.home-infra.net
10.10.2.2    proxmox.home-infra.net pve
10.10.2.5    nas.home-infra.net
10.10.2.10   talos.home-infra.net
10.10.2.11   hubble.home-infra.net
10.10.2.12   longhorn.home-infra.net
10.10.2.13   git.home-infra.net
10.10.2.16   gitops.home-infra.net
10.10.2.17   minio.home-infra.net
10.10.2.19   chat.home-infra.net
10.10.2.20   ollama.home-infra.net
10.10.2.21   home.home-infra.net
10.10.2.22   photos.home-infra.net photos.reynoza.org
10.10.2.23   grafana.home-infra.net
10.10.2.24   metrics.home-infra.net
10.10.2.25   hass.home-infra.net
10.10.2.26   n8n.home-infra.net
10.10.2.27   obico.home-infra.net
10.10.2.28   sd.home-infra.net diffusion.home-infra.net
10.10.2.29   attic.home-infra.net
10.10.2.30   emby.home-infra.net
10.10.2.31   music.home-infra.net
10.10.2.32   tools.home-infra.net
10.10.2.34   wallos.home-infra.net
10.10.2.35   ntfy.home-infra.net
10.10.2.36   paperless.home-infra.net
10.10.2.40   sabnzbd.home-infra.net
10.10.2.41   qbittorrent.home-infra.net
10.10.2.42   prowlarr.home-infra.net
10.10.2.43   radarr.home-infra.net
10.10.2.44   sonarr.home-infra.net
10.10.2.45   bazarr.home-infra.net
```

---

## Quick Check Commands

```bash
# Check service IPs
kubectl get svc -A | grep LoadBalancer

# Check Cilium IP pool
kubectl get ciliumloadbalancerippool -A

# Test service connectivity
curl -s http://10.10.2.11  # Hubble
curl -s http://10.10.2.12  # Longhorn
curl -s http://10.10.2.13  # Forgejo
curl -s http://10.10.2.16  # Weave GitOps
curl -s http://10.10.2.23  # Grafana
curl -s http://10.10.2.24  # VictoriaMetrics
curl -s http://10.10.2.32  # IT-Tools
curl -s http://10.10.2.34  # Wallos

# AI services
curl -s http://10.10.2.19  # Open WebUI
curl -s http://10.10.2.28  # ComfyUI

# Media services
curl -s http://10.10.2.30  # Emby
curl -s http://10.10.2.31  # Navidrome

# Arr-stack services
curl -s http://10.10.2.40  # SABnzbd
curl -s http://10.10.2.41  # qBittorrent
curl -s http://10.10.2.42  # Prowlarr
curl -s http://10.10.2.43  # Radarr
curl -s http://10.10.2.44  # Sonarr
curl -s http://10.10.2.45  # Bazarr
```

---

## Kubernetes Internal DNS

Internal service DNS names for cluster-internal access and Pangolin resource configuration.

Format: `<service>.<namespace>.svc.cluster.local`

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

## External Access via Pangolin

Services can be exposed externally via Pangolin tunneling (no port forwarding required).

### Domain Strategy

| Domain | Purpose | Resolution |
|--------|---------|------------|
| `.home.arpa` | Internal only | ControlD (home) / Pangolin VPN (remote) |
| `home-infra.net` | Exposed services | ControlD (home) / Pangolin (remote) |
| `reynoza.org` | Public domains | Pangolin only |

### Exposed Services

| External Domain | Internal DNS | LoadBalancer IP | Access |
|-----------------|--------------|-----------------|--------|
| home.home-infra.net | `homepage.tools.svc.cluster.local` | 10.10.2.21 | Private |
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

**Last Updated:** 2026-01-21
