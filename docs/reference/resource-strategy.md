# Kubernetes Resource Strategy

This document defines the resource allocation policy for the homelab Kubernetes cluster.

## Philosophy

This is a **single-node homelab**, not a multi-tenant production cluster. Standard production practices (requests = limits) waste capacity because:

- No scheduler competition (everything runs on one node)
- Requests reserve memory that sits unused
- Single user knows what's running

**Principle**: Remove requests, keep limits only where they matter.

## Policy by Service Category

| Category | Requests | Limits | Rationale |
|----------|----------|--------|-----------|
| **Core Infrastructure** | Keep | Keep | Must survive memory pressure (Cilium, Longhorn, CoreDNS, Flux) |
| **AI/GPU Workloads** | Small (100Mi) | Keep (sized for models) | GPU workloads self-limit by VRAM; small request prevents auto-assignment |
| **Databases** | Keep small | Keep | Protect from OOM during queries |
| **User Apps** | Remove | Remove | Trusted apps, single user, let them use what they need |

## QoS Class Implications

| QoS Class | Definition | Usage |
|-----------|------------|-------|
| **Guaranteed** | requests = limits | Core infrastructure only |
| **Burstable** | requests < limits | Databases, AI workloads |
| **BestEffort** | no requests/limits | User apps (evicted first under pressure) |

BestEffort is acceptable for homelab user apps - you'd rather have services running than "guaranteed" but unable to deploy new services.

**Important**: If you specify only a `limit` without a `request`, Kubernetes auto-assigns `request = limit` (Guaranteed QoS). To avoid this, either:
- Remove both request and limit (BestEffort), or
- Set a small explicit request like `100Mi` (Burstable)

## Decision Flowchart for New Services

```
Is it core infrastructure (CNI, storage, GitOps)?
  YES → Keep requests and limits
  NO ↓

Is it a database or stateful service with crash risk?
  YES → Small request (256Mi), reasonable limit
  NO ↓

Is it an AI/GPU workload?
  YES → No request, limit sized for model requirements
  NO ↓

It's a user app → No requests, no limits
```

## Current Service Configuration

### Core Infrastructure (Keep Resources)

| Namespace | Service | Notes |
|-----------|---------|-------|
| cilium | Cilium agents | CNI - critical |
| longhorn-system | Longhorn components | Storage - critical |
| flux-system | FluxCD controllers | GitOps - critical |
| kube-system | CoreDNS, metrics | System services |

### AI Namespace (Limits Only)

| Service | Request | Limit | Notes |
|---------|---------|-------|-------|
| Ollama | 100Mi + GPU | 32Gi | Supports 24GB+ models |
| Stable Diffusion | 100Mi + GPU | 16Gi | SDXL headroom |
| Faster-Whisper | 100Mi + GPU | 8Gi | large-v3 model |
| Open WebUI | None | None | BestEffort - lightweight UI |

### Databases (Small Requests + Limits)

| Namespace | Service | Request | Limit |
|-----------|---------|---------|-------|
| forgejo | PostgreSQL | 256Mi | 512Mi |

### User Apps (No Resources)

| Namespace | Services |
|-----------|----------|
| arr-stack | SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr |
| media | Emby, Navidrome |
| tools | IT-Tools, Speedtest |
| misc | Twitch-Miner |
| management | Wallos |
| forgejo | Forgejo (app, not DB) |

## Adding New Services

When adding a new service, consult the decision flowchart above and add it to the appropriate section in this document.

**Example**: Adding a new media app (e.g., Jellyfin)
1. Is it core infrastructure? No
2. Is it a database? No
3. Is it an AI/GPU workload? No
4. → It's a user app → No requests, no limits

## Monitoring Actual Usage

Without metrics-server, check actual usage via:

```bash
# Node-level memory pressure
kubectl describe node | grep -A5 "Conditions:"

# Pod resource consumption (if metrics available)
kubectl top pods -A

# Allocated vs capacity
kubectl describe node | grep -A10 "Allocated resources"
```

## History

- **2026-01-17**: Initial strategy - removed requests from user apps, optimized AI limits
