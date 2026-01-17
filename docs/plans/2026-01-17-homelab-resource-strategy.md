# Homelab Resource Strategy Design

**Date**: 2026-01-17
**Status**: Approved
**Problem**: 46% memory allocated but only ~30% actually used, blocking new deployments

## Context

Single-node Talos homelab with 96GB RAM. Production-style resource reservations waste capacity because:
- No scheduler competition (single node)
- Requests reserve memory that sits unused
- Single user knows what's running

## Decision: Remove Requests, Keep Strategic Limits

### Policy by Service Category

| Category | Requests | Limits | Rationale |
|----------|----------|--------|-----------|
| **Core Infrastructure** | Keep | Keep | Must survive memory pressure (Cilium, Longhorn, CoreDNS, Flux) |
| **AI/GPU Workloads** | Remove | Keep (sized for models) | GPU workloads self-limit by VRAM; need headroom for large models |
| **Databases** | Keep small | Keep | Protect from OOM during queries |
| **User Apps** | Remove | Remove | Trusted apps, single user, let them use what they need |

### QoS Class Implications

- **Guaranteed** (requests=limits): Core infrastructure only
- **Burstable** (requests < limits): Databases, AI workloads
- **BestEffort** (no requests/limits): User apps - evicted first under pressure, but this is acceptable for homelab

## Changes to Implement

### AI Namespace

| Service | Current Req | Current Lim | New Req | New Lim | Notes |
|---------|-------------|-------------|---------|---------|-------|
| Ollama | 8Gi | 16Gi | Remove | 32Gi | Supports 24GB+ models |
| Stable Diffusion | 8Gi | 12Gi | Remove | 16Gi | SDXL headroom |
| Faster-Whisper | 4Gi | 8Gi | Remove | 8Gi | large-v3 model |
| Open WebUI | 512Mi | 1Gi | Remove | 2Gi | UI can cache |

### User Apps (Remove All Requests and Limits)

| Namespace | Services |
|-----------|----------|
| arr-stack | SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr |
| media | Emby, Navidrome |
| tools | IT-Tools, Speedtest |
| misc | Twitch-Miner |
| management | Wallos |

### Keep Unchanged

| Namespace | Services | Reason |
|-----------|----------|--------|
| forgejo | Forgejo, PostgreSQL | Database protection |
| longhorn-system | All | Core infrastructure |
| cilium | All | Core infrastructure |
| flux-system | All | Core infrastructure |
| kube-system | All | Core infrastructure |

## Adding New Services

Use this flowchart:

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

## Expected Outcome

- Memory allocated: 46% → ~15%
- Can deploy more services
- Ollama supports 24GB+ models (fixes 6Gi error)
- Clear policy for future services

## Files to Modify

### AI Namespace
- `kubernetes/apps/base/ai/ollama/statefulset.yaml`
- `kubernetes/apps/base/ai/stable-diffusion/deployment.yaml`
- `kubernetes/apps/base/ai/faster-whisper/deployment.yaml`
- `kubernetes/apps/base/ai/open-webui/deployment.yaml`

### Arr-Stack
- `kubernetes/apps/base/arr-stack/sabnzbd/deployment.yaml`
- `kubernetes/apps/base/arr-stack/qbittorrent/deployment.yaml`
- `kubernetes/apps/base/arr-stack/prowlarr/deployment.yaml`
- `kubernetes/apps/base/arr-stack/radarr/deployment.yaml`
- `kubernetes/apps/base/arr-stack/sonarr/deployment.yaml`
- `kubernetes/apps/base/arr-stack/bazarr/deployment.yaml`

### Media
- `kubernetes/apps/base/media/emby/deployment.yaml`
- `kubernetes/apps/base/media/navidrome/deployment.yaml`

### Tools/Misc/Management
- `kubernetes/apps/base/tools/it-tools/deployment.yaml`
- `kubernetes/apps/base/tools/speedtest/deployment.yaml`
- `kubernetes/apps/base/misc/twitch-miner/deployment.yaml`
- `kubernetes/apps/base/management/wallos/deployment.yaml`

### Documentation
- `docs/reference/resource-strategy.md` (new - permanent reference)
- `CLAUDE.md` (add reference to resource strategy)
