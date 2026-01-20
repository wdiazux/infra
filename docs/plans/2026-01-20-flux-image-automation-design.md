# Flux Image Automation Design

**Date:** 2026-01-20
**Status:** Approved
**Author:** Claude Code

## Overview

Implement Flux Image Automation to automatically detect new container image versions and create weekly update branches for manual review and merge.

## Goals

- Track 32 container images for version updates
- Create weekly branches (`image-updates/2026-w04`) for review
- Support multiple versioning schemes (semver, date-based, release tags)
- Exclude CUDA-specific and custom images from automation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flux Image Automation                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ImageRepository (per image)                                 │
│  └── Scans registry every 1h for new tags                   │
│                                                              │
│  ImagePolicy (per image)                                     │
│  └── Selects latest stable version (excludes alpha/beta/rc) │
│                                                              │
│  ImageUpdateAutomation (single)                              │
│  └── Every 12h: creates branch "image-updates/YYYY-wWW"     │
│  └── Updates manifests with new versions                     │
│  └── Pushes to Forgejo for review                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
kubernetes/infrastructure/image-automation/
├── kustomization.yaml
├── automation.yaml              # ImageUpdateAutomation config
└── policies/
    ├── kustomization.yaml
    ├── arr-stack.yaml           # radarr, sonarr, bazarr, prowlarr, qbittorrent, sabnzbd
    ├── ai.yaml                  # ollama, open-webui
    ├── media.yaml               # emby, navidrome, immich
    ├── tools.yaml               # homepage, ntfy, it-tools
    ├── automation.yaml          # n8n, home-assistant
    ├── monitoring.yaml          # grafana, victoria-metrics
    ├── backup.yaml              # minio
    ├── documents.yaml           # paperless, tika, gotenberg
    └── misc.yaml                # wallos, twitch-miner, busybox, obico
```

## ImageUpdateAutomation Configuration

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata:
  name: image-updates
  namespace: flux-system
spec:
  interval: 12h
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: flux-image-bot
        email: flux@home-infra.net
      messageTemplate: |
        chore(images): update {{range .Changed.Changes}}{{.OldValue}} -> {{.NewValue}} {{end}}
    push:
      branch: image-updates/{{ now "2006-w02" }}
  update:
    path: ./kubernetes/apps
    strategy: Setters
```

## Image Policies

### Semver Policy (21 images)

| Image | Pin Version | Range |
|-------|-------------|-------|
| ollama/ollama | 0.14.2 | `>=0.1.0` |
| ghcr.io/open-webui/open-webui | v0.7.2 | `>=0.1.0` |
| ghcr.io/gethomepage/homepage | v1.9.0 | `>=0.1.0` |
| ghcr.io/home-assistant/home-assistant | 2026.1.2 | `>=2024.0.0` |
| n8nio/n8n | 2.5.0 | `>=1.0.0` |
| grafana/grafana | 12.3.1 | `>=10.0.0` |
| ghcr.io/paperless-ngx/paperless-ngx | v2.20.5 | `>=2.0.0` |
| binwiederhier/ntfy | v2.16.0 | `>=2.0.0` |
| docker.io/deluan/navidrome | v0.59.0 | `>=0.50.0` |
| docker.io/bellamy/wallos | v4.6.0 | `>=4.0.0` |
| lscr.io/linuxserver/emby | 4.9.3 | `>=4.0.0` |
| docker.io/gotenberg/gotenberg | 8.25.1 | `>=8.0.0` |
| docker.io/apache/tika | 3.2.3.0 | `>=3.0.0` |
| rdavidoff/twitch-channel-points-miner-v2 | 2.0.4 | `>=2.0.0` |
| busybox | 1.37 | `>=1.30` |
| victoriametrics/victoria-metrics | v1.134.0 | `>=1.90.0` |
| victoriametrics/vmagent | v1.134.0 | `>=1.90.0` |
| ghcr.io/immich-app/immich-server | v2.4.1 | `>=1.0.0` |
| ghcr.io/immich-app/immich-machine-learning | v2.4.1-cuda | `>=1.0.0` |
| quay.io/prometheus/node-exporter | v1.10.2 | `>=1.0.0` |
| registry.k8s.io/kube-state-metrics/kube-state-metrics | v2.18.0 | `>=2.0.0` |

### Hotio Images - Release Tags (6 images)

| Image | Pin Version | Filter |
|-------|-------------|--------|
| ghcr.io/hotio/radarr | release-6.0.4.10291 | `^release-` |
| ghcr.io/hotio/sonarr | release-4.0.16.2944 | `^release-` |
| ghcr.io/hotio/bazarr | release-1.5.4 | `^release-` |
| ghcr.io/hotio/prowlarr | release-2.3.0.5236 | `^release-` |
| ghcr.io/hotio/qbittorrent | release-5.1.4 | `^release-` |
| ghcr.io/hotio/sabnzbd | release-4.5.5 | `^release-` |

### Date-based Images (2 images)

| Image | Pin Version | Filter |
|-------|-------------|--------|
| minio/minio | RELEASE.2025-09-07T16-13-09Z | `^RELEASE\.` |
| minio/mc | RELEASE.2025-08-13T08-35-41Z | `^RELEASE\.` |

### Special Cases (3 images)

| Image | Pin Version | Policy | Notes |
|-------|-------------|--------|-------|
| corentinth/it-tools | v2024.10.22-7ca5933 | `^v20` alphabetical | Date+commit tags |
| ghcr.io/gabe565/obico/web | release | `^release$` exact | No semver |

## Excluded from Automation

These images require manual updates:

| Image | Reason |
|-------|--------|
| yanwk/comfyui-boot:cu128-slim | CUDA-version specific |
| ghcr.io/zhaofengli/attic:latest | No versioned tags available |
| ghcr.io/wdiazux/obico-ml-api:cuda12.3 | Custom image |
| ghcr.io/immich-app/postgres:14-vectorchord0.4.3 | Extension-version specific |

## Workflow

1. **Every 12 hours:** Flux scans registries for new tags
2. **If updates found:** Commits to weekly branch (e.g., `image-updates/2026-w04`)
3. **User reviews:** Check branch in Forgejo, verify changes
4. **User merges:** Merge to main when ready
5. **FluxCD deploys:** Detects merge, applies updates to cluster

## Implementation Phases

### Phase 1: Create Infrastructure
- Create `kubernetes/infrastructure/image-automation/` directory
- Create ImageUpdateAutomation resource
- Create ImageRepository and ImagePolicy for each image
- Wire into FluxCD kustomization

### Phase 2: Pin Images
- Update all 32 manifests with pinned versions
- Add policy markers: `# {"$imagepolicy": "flux-system:image-name"}`

### Phase 3: Validate
- Run `kubectl apply --dry-run=client` on all manifests
- Verify Flux reconciliation
- Test by manually triggering image scan

## Manifest Marker Format

```yaml
containers:
  - name: app
    image: ollama/ollama:0.14.2 # {"$imagepolicy": "flux-system:ollama"}
```

## Success Criteria

- [ ] All ImageRepository resources scanning successfully
- [ ] All ImagePolicy resources selecting correct versions
- [ ] ImageUpdateAutomation creating branches on schedule
- [ ] Manifests updated correctly with new versions
- [ ] Weekly branches appearing in Forgejo for review
