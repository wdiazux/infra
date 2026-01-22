# Kubernetes Resource Strategy

This document defines the resource allocation policy for the homelab Kubernetes cluster.

## Philosophy

This is a **single-node homelab**, not a multi-tenant production cluster. Our resource strategy balances two concerns:

1. **Prevent OOM kills** - Memory limits protect against runaway processes crashing the node
2. **Allow burst capacity** - No CPU limits/requests so pods can use spare CPU when needed

**Principles**:
- **Memory**: Low requests + researched limits (prevents OOM, allows scheduling)
- **CPU**: No requests, no limits (avoids scheduling issues, allows burst)
- Single-node means no scheduler competition - CPU requests just block deployments

## Policy by Service Category

| Category | Memory Request | Memory Limit | CPU | Rationale |
|----------|----------------|--------------|-----|-----------|
| **Core Infrastructure** | Keep | Keep | Keep | Must survive memory pressure (Cilium, Longhorn, CoreDNS, Flux) |
| **AI/GPU Workloads** | Small (100-512Mi) | Large (20-32Gi) | None | GPU workloads need RAM spillover; no CPU limits for burst |
| **Databases** | Small (256Mi) | Medium (512Mi-1Gi) | None | Protect from OOM during queries |
| **Heavy Apps** | Medium (256-512Mi) | Large (2-4Gi) | None | Apps with known high memory usage (HA, n8n, paperless) |
| **Medium Apps** | Small (64-256Mi) | Medium (512Mi-2Gi) | None | Arr-stack, media apps with moderate memory needs |
| **Light Apps** | Minimal (32-64Mi) | Small (128-512Mi) | None | Simple web UIs, utilities |
| **Redis/Cache** | Small (64Mi) | Small (256Mi) | None | Standard cache instances |

## QoS Class Implications

| QoS Class | Definition | Usage |
|-----------|------------|-------|
| **Guaranteed** | requests = limits (both CPU and memory) | Core infrastructure only |
| **Burstable** | requests < limits | All user apps (memory only) |
| **BestEffort** | no requests/limits | Avoid - no OOM protection |

**Our approach**: All apps are **Burstable** with memory-only resources:
- Small memory request (for scheduling)
- Researched memory limit (for OOM protection)
- No CPU resources (allows burst, avoids scheduling issues)

**Important**: If you specify only a `limit` without a `request`, Kubernetes auto-assigns `request = limit` (Guaranteed QoS). Always set an explicit small request.

## Decision Flowchart for New Services

```
Is it core infrastructure (CNI, storage, GitOps)?
  YES → Keep both CPU and memory requests/limits
  NO ↓

Is it an AI/GPU workload?
  YES → Small memory request (100-512Mi), large limit (16-32Gi), GPU resource
  NO ↓

Is it a database?
  YES → Small request (256Mi), medium limit (512Mi-1Gi)
  NO ↓

Research the service's memory requirements, then:
  - Heavy app (HA, n8n, paperless)? → 256-512Mi request, 2-4Gi limit
  - Medium app (arr-stack, media)? → 64-256Mi request, 512Mi-2Gi limit
  - Light app (utilities, dashboards)? → 32-64Mi request, 128-512Mi limit
  - Redis/cache? → 64Mi request, 256Mi limit

NEVER set CPU requests/limits (except core infrastructure)
```

## Current Service Configuration

### Core Infrastructure (Keep Full Resources)

| Namespace | Service | Notes |
|-----------|---------|-------|
| cilium | Cilium agents | CNI - critical |
| longhorn-system | Longhorn components | Storage - critical |
| flux-system | FluxCD controllers | GitOps - critical |
| kube-system | CoreDNS, metrics | System services |

### AI Namespace

| Service | Request | Limit | Notes |
|---------|---------|-------|-------|
| Ollama | 100Mi + GPU | 32Gi + GPU | Supports 24GB+ models, KEEP_ALIVE=5m |
| ComfyUI | 512Mi + GPU | 20Gi + GPU | SDXL/Flux headroom |
| Open WebUI | 256Mi | 2Gi | LLM frontend, embedding models |

### Heavy Apps (4Gi limit)

| Namespace | Service | Request | Limit | Notes |
|-----------|---------|---------|-------|-------|
| automation | Home Assistant | 256Mi | 4Gi | Smart home, many integrations |
| automation | n8n | 256Mi | 4Gi | Workflow automation |
| management | Paperless Server | 512Mi | 4Gi | OCR processing spikes |

### Medium Apps (1-2Gi limit)

| Namespace | Service | Request | Limit | Notes |
|-----------|---------|---------|-------|-------|
| arr-stack | Radarr | 256Mi | 2Gi | Large movie libraries |
| arr-stack | SABnzbd | 256Mi | 2Gi | Download processing |
| arr-stack | qBittorrent | 256Mi | 2Gi | Cache-dependent |
| arr-stack | Sonarr | 128Mi | 1Gi | TV series management |
| arr-stack | Bazarr | 64Mi | 1Gi | Memory leak protection |
| tools | Affine Server | 256Mi | 2Gi | Doc merge spikes |
| media | Immich Server | 256Mi | 2Gi | Photo management |
| management | Paperless Tika | 256Mi | 2Gi | Java heap for text extraction |
| ai | Open WebUI | 256Mi | 2Gi | Embedding models |

### Light Apps (512Mi or less)

| Namespace | Service | Request | Limit | Notes |
|-----------|---------|---------|-------|-------|
| arr-stack | Prowlarr | 64Mi | 512Mi | Indexer manager |
| media | Navidrome | 64Mi | 512Mi | Music streaming |
| tools | Attic | 128Mi | 1Gi | Nix binary cache |
| management | Paperless Gotenberg | 128Mi | 1Gi | PDF conversion |
| tools | Homepage | 64Mi | 256Mi | Dashboard |
| tools | IT-Tools | 32Mi | 128Mi | Static utilities |

### Redis/Cache Instances (256Mi limit)

| Namespace | Service | Request | Limit |
|-----------|---------|---------|-------|
| tools | Affine Redis | 64Mi | 256Mi |
| media | Immich Redis | 64Mi | 256Mi |
| management | Paperless Redis | 64Mi | 256Mi |
| printing | Obico Redis | 64Mi | 256Mi |

### Databases

| Namespace | Service | Request | Limit | Notes |
|-----------|---------|---------|-------|-------|
| automation | n8n Postgres | 256Mi | 512Mi | Workflow data |
| tools | Affine Postgres | 256Mi | 512Mi | Knowledge base |
| media | Immich Postgres | 256Mi | 1Gi | Photo metadata |
| management | Paperless Postgres | 256Mi | 512Mi | Document metadata |

### GPU Workloads

| Namespace | Service | Request | Limit | Notes |
|-----------|---------|---------|-------|-------|
| ai | Ollama | 100Mi + GPU | 32Gi + GPU | LLM inference |
| ai | ComfyUI | 512Mi + GPU | 20Gi + GPU | Image generation |
| media | Emby | GPU | GPU | Hardware transcoding |
| printing | Obico ML API | 512Mi + GPU | 4Gi + GPU | 3D print failure detection |
| media | Immich ML | 256Mi + GPU | 2Gi + GPU | Photo face/object detection |

## Adding New Services

When adding a new service:

1. **Research memory requirements** - Check official docs, GitHub issues, community reports
2. **Consult the decision flowchart** above
3. **Add to appropriate section** in this document
4. **Never set CPU** requests/limits (except core infrastructure)

**Example**: Adding a new media app (e.g., Jellyfin)
1. Research: Jellyfin typically uses 500MB-2GB depending on transcoding
2. Is it core infrastructure? No
3. Is it an AI/GPU workload? Maybe (if hardware transcoding)
4. → Medium app → 128Mi request, 2Gi limit, optional GPU

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
| ComfyUI | Image generation |
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

- **2026-01-22**: Memory limits added to all apps based on research (no CPU to allow burst)
- **2026-01-17**: Image versioning policy added - latest for most, pin Immich
- **2026-01-17**: Emby GPU enabled, OLLAMA_KEEP_ALIVE=5m
- **2026-01-17**: Initial strategy - removed requests from user apps, optimized AI limits
---

**Last Updated:** 2026-01-22
