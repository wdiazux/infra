# Copyparty File Browser Design

**Date**: 2026-01-22
**Status**: Approved

## Overview

Deploy Copyparty as a web-based file browser to navigate all NFS datasets used by other services in the cluster.

## Requirements

- Browse all major NFS storage paths from a single interface
- Read-write access to all mounted paths
- No authentication (homelab local network)
- Accessible via LoadBalancer IP

## Configuration

| Setting | Value |
|---------|-------|
| Namespace | tools |
| LoadBalancer IP | 10.10.2.37 |
| Port | 80 → 3923 |
| Image | copyparty/ac:latest |
| Access Mode | Read-write, no auth |
| User/Group | 1000:3001 |

## NFS Volumes

| Mount Point | NFS Path | Capacity | Content |
|-------------|----------|----------|---------|
| /data/media | /mnt/tank/media | 1Ti | Movies, TV, Music, Videos |
| /data/downloads | /mnt/downloads | 500Gi | Usenet & Torrent downloads |
| /data/ai | /mnt/tank/ai | 500Gi | Ollama & ComfyUI models |
| /data/photos | /mnt/tank/photos | 1Ti | Photos (Immich) |
| /data/documents | /mnt/tank/documents | 500Gi | Paperless & Affine docs |
| /data/backups | /mnt/tank/backups | 500Gi | Velero/MinIO backups |

## Storage Architecture

Each NFS path requires a dedicated PV/PVC pair for Copyparty (PVs can only bind to one PVC).

**PersistentVolumes** (in `kubernetes/infrastructure/storage/nfs-copyparty-pv.yaml`):
- nfs-media-copyparty
- nfs-downloads-copyparty
- nfs-ai-copyparty
- nfs-photos-copyparty
- nfs-documents-copyparty
- nfs-backups-copyparty

**PersistentVolumeClaims** (in `kubernetes/infrastructure/storage/nfs-copyparty-pvc.yaml`):
- All PVCs in `tools` namespace
- Each binds to corresponding PV via `volumeName`

## Deployment

**Security Context**:
```yaml
securityContext:
  fsGroup: 3001
  fsGroupChangePolicy: "OnRootMismatch"
```

**Environment**:
```yaml
env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "3001"
  - name: TZ
    value: America/El_Salvador
```

**Resources**:
```yaml
resources:
  requests:
    memory: 64Mi
  limits:
    memory: 256Mi
```

## File Structure

```
kubernetes/infrastructure/storage/
├── nfs-copyparty-pv.yaml      # 6 PersistentVolumes
├── nfs-copyparty-pvc.yaml     # 6 PersistentVolumeClaims
└── kustomization.yaml         # Updated to include new files

kubernetes/apps/base/tools/copyparty/
├── deployment.yaml
├── service.yaml
└── kustomization.yaml

kubernetes/apps/base/tools/kustomization.yaml  # Updated to include copyparty
```

## Access

- URL: http://10.10.2.37
- No authentication required
- Full read-write access to all mounted paths
