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

LoadBalancer IPs assigned to Kubernetes services.

| IP | Service | Port | Namespace |
|----|---------|------|-----------|
| 10.10.2.11 | Hubble UI | 80 | kube-system |
| 10.10.2.12 | Longhorn UI | 80 | longhorn-system |
| 10.10.2.13 | Forgejo HTTP | 80 | forgejo |
| 10.10.2.14 | Forgejo SSH | 22 | forgejo |
| 10.10.2.15 | FluxCD Webhook | 80 | flux-system |
| 10.10.2.16 | Weave GitOps | 80 | flux-system |
| 10.10.2.17 | Grafana | 80 | monitoring |
| 10.10.2.18 | VictoriaMetrics | 80 | monitoring |
| 10.10.2.19 | Attic | 80 | tools |
| 10.10.2.23 | Home Assistant | 80 | automation |
| 10.10.2.24 | n8n | 80 | automation |

---

## Applications (10.10.2.21-150)

| IP | Service | Port | Namespace |
|----|---------|------|-----------|
| 10.10.2.22 | Immich | 80 | media |
| 10.10.2.25 | Open WebUI | 80 | ai |
| 10.10.2.26 | ComfyUI | 80 | ai |
| 10.10.2.30 | Emby | 80 | media |
| 10.10.2.31 | Navidrome | 80 | media |
| 10.10.2.32 | IT-Tools | 80 | tools |
| 10.10.2.35 | ntfy | 80 | tools |
| 10.10.2.34 | Wallos | 80 | management |
| 10.10.2.40 | SABnzbd | 80 | arr-stack |
| 10.10.2.41 | qBittorrent | 80 | arr-stack |
| 10.10.2.42 | Prowlarr | 80 | arr-stack |
| 10.10.2.43 | Radarr | 80 | arr-stack |
| 10.10.2.44 | Sonarr | 80 | arr-stack |
| 10.10.2.45 | Bazarr | 80 | arr-stack |
| 10.10.2.27 | Obico | 80 | printing |

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
| Grafana | http://10.10.2.17 | Username/Password |
| VictoriaMetrics | http://10.10.2.18 | None |
| Attic | http://10.10.2.19 | Token |
| Immich | http://10.10.2.22 | Username/Password |
| Home Assistant | http://10.10.2.23 | Username/Password |
| n8n | http://10.10.2.24 | Username/Password |
| Open WebUI | http://10.10.2.25 | Username/Password |
| ComfyUI | http://10.10.2.26 | None (API auth optional) |
| Emby | http://10.10.2.30 | Username/Password |
| Navidrome | http://10.10.2.31 | Username/Password |
| IT-Tools | http://10.10.2.32 | None |
| Wallos | http://10.10.2.34 | Username/Password |
| ntfy | http://10.10.2.35 | Username/Password |
| SABnzbd | http://10.10.2.40 | Username/Password |
| qBittorrent | http://10.10.2.41 | Username/Password |
| Prowlarr | http://10.10.2.42 | Username/Password |
| Radarr | http://10.10.2.43 | Username/Password |
| Sonarr | http://10.10.2.44 | Username/Password |
| Bazarr | http://10.10.2.45 | Username/Password |
| Obico | http://10.10.2.27 | Username/Password |

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
10.10.2.17   grafana.home-infra.net
10.10.2.18   metrics.home-infra.net
10.10.2.19   attic.home-infra.net
10.10.2.22   photos.home-infra.net photos.reynoza.org
10.10.2.23   hass.home-infra.net
10.10.2.24   n8n.home-infra.net
10.10.2.25   chat.home-infra.net
10.10.2.26   sd.home-infra.net diffusion.home-infra.net
10.10.2.30   emby.home-infra.net
10.10.2.31   music.home-infra.net
10.10.2.32   tools.home-infra.net
10.10.2.34   wallos.home-infra.net
10.10.2.35   ntfy.home-infra.net
10.10.2.40   sabnzbd.home-infra.net
10.10.2.41   qbittorrent.home-infra.net
10.10.2.42   prowlarr.home-infra.net
10.10.2.43   radarr.home-infra.net
10.10.2.44   sonarr.home-infra.net
10.10.2.45   bazarr.home-infra.net
10.10.2.27   obico.home-infra.net
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
curl -s http://10.10.2.32  # IT-Tools
curl -s http://10.10.2.34  # Wallos

# AI services
curl -s http://10.10.2.25  # Open WebUI
curl -s http://10.10.2.26  # ComfyUI

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

## External Access via Pangolin

Services can be exposed externally via Pangolin tunneling (no port forwarding required).

| External Domain | Internal Service | IP | Type |
|----------------|------------------|-----|------|
| photos.reynoza.org | Immich | 10.10.2.22 | Private |
| photos.home-infra.net | Immich | 10.10.2.22 | Internal |

**Architecture:**
- Pangolin VPS at 207.246.115.3 (NixOS)
- WireGuard tunnel via Newt extension in Talos
- Handles domains: reynoza.org, unix.red

**Configuration:** See [Pangolin documentation](../services/pangolin.md)

---

**Last Updated:** 2026-01-19
