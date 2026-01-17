# CPU Resource Optimization for Single-Node Homelab

**Date:** 2026-01-17
**Status:** Approved

## Problem

CPU requests are at 99% capacity (7918m), preventing new services from scheduling despite low actual CPU utilization. This is a common homelab issue where chart defaults designed for multi-node clusters over-reserve resources.

## Research Summary

Industry consensus for homelabs:
- **CPU Limits:** Generally avoid - they cause throttling even when CPU is idle
- **CPU Requests:** Keep for critical services, remove or minimize for user apps
- Requests serve as scheduling hints and proportional sharing under pressure

Sources:
- [PerfectScale: CPU Limits Best Practices](https://www.perfectscale.io/blog/kubernetes-cpu-limit-best-practises)
- [Kubernetes: Remove CPU Limits](https://erickhun.com/posts/kubernetes-faster-services-no-cpu-limits/)
- [Homelab QoS Guide](https://www.technowizardry.net/2025/09/guaranteed-qos-in-my-home-lab/)

## Design

### Workload Classification

| Tier | Purpose | Strategy | Workloads |
|------|---------|----------|-----------|
| **Tier 1: Critical** | Cluster won't function | Keep requests, remove limits | Cilium, CoreDNS, kube-apiserver |
| **Tier 2: Storage** | Data integrity | Moderate requests, remove limits | Longhorn |
| **Tier 3: Important** | User-facing infrastructure | Minimal requests, remove limits | Forgejo, FluxCD |
| **Tier 4: User Apps** | Everything else | Remove requests and limits | AI, arr-stack, media, tools, misc |

### Resource Values

#### Tier 1: Critical (kube-system)
Managed by Talos - no changes needed.

#### Tier 2: Storage (Longhorn)
- Instance Manager: 100m request, no limit

#### Tier 3: Important
- Forgejo: 50m request, no limit
- PostgreSQL: 50m request, no limit
- FluxCD controllers: 25m each, no limit

#### Tier 4: User Apps
Remove `resources:` blocks entirely from:
- ai/: Ollama, Open WebUI, Faster-Whisper, Stable Diffusion
- arr-stack/: SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr
- media/: Emby, Navidrome
- tools/: IT-Tools, Speedtest
- misc/: Twitch-miner
- management/: Wallos

### Expected Impact

| Metric | Before | After |
|--------|--------|-------|
| CPU Requests | 7918m (99%) | ~800m (~10%) |
| Scheduling headroom | ~80m | ~7200m |

## Files Modified

### Tier 4: User Apps (16 files)
- `kubernetes/apps/base/ai/ollama/statefulset.yaml`
- `kubernetes/apps/base/ai/open-webui/deployment.yaml`
- `kubernetes/apps/base/ai/faster-whisper/deployment.yaml`
- `kubernetes/apps/base/ai/stable-diffusion/deployment.yaml`
- `kubernetes/apps/base/arr-stack/sabnzbd/deployment.yaml`
- `kubernetes/apps/base/arr-stack/qbittorrent/deployment.yaml`
- `kubernetes/apps/base/arr-stack/prowlarr/deployment.yaml`
- `kubernetes/apps/base/arr-stack/radarr/deployment.yaml`
- `kubernetes/apps/base/arr-stack/sonarr/deployment.yaml`
- `kubernetes/apps/base/arr-stack/bazarr/deployment.yaml`
- `kubernetes/apps/base/media/emby/deployment.yaml`
- `kubernetes/apps/base/media/navidrome/deployment.yaml`
- `kubernetes/apps/base/tools/it-tools/deployment.yaml`
- `kubernetes/apps/base/tools/speedtest/deployment.yaml`
- `kubernetes/apps/base/misc/twitch-miner/deployment.yaml`
- `kubernetes/apps/base/management/wallos/deployment.yaml`

### Tier 3: Helm Values (2 files)
- `kubernetes/infrastructure/values/forgejo-values.yaml`
- FluxCD (if customizable)

### Tier 2: Helm Values (1 file)
- `kubernetes/infrastructure/values/longhorn-values.yaml`

## Rollback

If issues occur, revert the git commit. FluxCD will reconcile back to previous state.
