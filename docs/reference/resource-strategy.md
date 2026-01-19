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
| Ollama | 100Mi + GPU | 32Gi | Supports 24GB+ models, KEEP_ALIVE=5m |
| Stable Diffusion | 100Mi + GPU | 16Gi | SDXL headroom |
| Open WebUI | None | None | BestEffort - lightweight UI |

### Databases (Small Requests + Limits)

| Namespace | Service | Request | Limit |
|-----------|---------|---------|-------|
| forgejo | PostgreSQL | 256Mi | 512Mi |

### Media Namespace (GPU for Transcoding)

| Service | Request | Limit | Notes |
|---------|---------|-------|-------|
| Emby | GPU | GPU | Hardware transcoding via NVENC |
| Navidrome | None | None | BestEffort - no GPU needed |

### User Apps (No Resources)

| Namespace | Services |
|-----------|----------|
| arr-stack | SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr |
| tools | IT-Tools |
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

## GPU Time-Slicing & VRAM Sharing

The RTX 4000 SFF has **20GB VRAM** shared across all GPU services via time-slicing (4 virtual slots).

**Current GPU allocation** (3/4 slots):
| Service | Purpose |
|---------|---------|
| Ollama | LLM inference |
| Stable Diffusion | Image generation |
| Emby | Video transcoding |

**VRAM management**:
- Large Ollama models (e.g., nemotron 24GB) consume most VRAM
- `OLLAMA_KEEP_ALIVE=5m` unloads models after 5 min idle
- Sequential heavy GPU usage recommended (not simultaneous)

## Image Versioning Policy

**Principle**: Use `latest` for most services, pin versions only for critical or complex services.

### Use `:latest` (Default)

Most services can safely use `:latest`:

| Category | Services | Rationale |
|----------|----------|-----------|
| **User Apps** | IT-Tools, Wallos, ntfy | Simple apps, breaking changes rare |
| **Media** | Navidrome, Emby | Mature projects, stable releases |
| **Arr-Stack** | Radarr, Sonarr, Prowlarr, Bazarr, SABnzbd, qBittorrent | Hotio images auto-update |
| **Automation** | n8n, Home Assistant | Rolling releases preferred |
| **AI** | Ollama, Open WebUI | Rapid development, want latest features |
| **Monitoring** | Grafana, VictoriaMetrics | Stable APIs, backward compatible |

### Pin Specific Versions

Pin versions for services where:
- Breaking changes are common
- Multiple components must stay in sync
- Data migrations are involved

| Service | Pin Strategy | Example |
|---------|--------------|---------|
| **Immich** | Pin all components to same version | `v1.124.2`, `v1.124.2-cuda` |
| **Databases** | Pin major version | `postgres:16-alpine`, `valkey:9` |

### Immich Special Case

Immich releases frequently with database migrations. All components must use the same version:

```yaml
# Server
image: ghcr.io/immich-app/immich-server:v1.124.2

# Machine Learning
image: ghcr.io/immich-app/immich-machine-learning:v1.124.2-cuda

# PostgreSQL (separate versioning)
image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
```

**Upgrade process**: Update all Immich images together, verify compatibility with Postgres extensions.

## History

- **2026-01-17**: Image versioning policy added - latest for most, pin Immich
- **2026-01-17**: Emby GPU enabled, OLLAMA_KEEP_ALIVE=5m
- **2026-01-17**: Initial strategy - removed requests from user apps, optimized AI limits
