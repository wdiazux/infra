# Affine Deployment Design

**Date**: 2026-01-21
**Status**: Approved

## Overview

Deploy Affine, a knowledge base and note-taking application (Notion alternative), to the Kubernetes cluster.

## Requirements

- Namespace: `tools`
- IP: 10.10.2.33
- Storage: NFS at `/mnt/tank/documents/Affine` (already created)
- Domains: `affine.home-infra.net`, `affine.home.arpa`
- FluxCD image automation for auto-updates
- Homepage dashboard widget

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    tools namespace                       │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  PostgreSQL │  │    Redis    │  │  Affine Server  │ │
│  │  (pgvector) │  │             │  │                 │ │
│  │  StatefulSet│  │  Deployment │  │   Deployment    │ │
│  │    5Gi      │  │    1Gi      │  │  + init wait    │ │
│  │  Longhorn   │  │  Longhorn   │  │                 │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │   LoadBalancer Svc      │
              │    10.10.2.33:80        │
              └─────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │   NFS: /mnt/tank/       │
              │   documents/Affine      │
              │   (250Gi uploads)       │
              └─────────────────────────┘
```

## Components

### PostgreSQL (pgvector/pgvector:pg17)
- StatefulSet with 5Gi Longhorn volumeClaimTemplate
- Database: `affine`, User: `affine`
- Probes: `pg_isready` liveness/readiness
- Security: fsGroup 999

### Redis (redis:8)
- Deployment with 1Gi Longhorn PVC
- Probes: `redis-cli ping`
- Security: runAsNonRoot, drop ALL capabilities

### Affine Server (ghcr.io/toeverything/affine-graphql:stable)
- Deployment with init containers (wait-for-db, wait-for-redis)
- Port: 3010 (mapped to 80 on LoadBalancer)
- Environment variables:
  - `AFFINE_SERVER_EXTERNAL_URL`: `http://affine.${DOMAIN_PRIMARY}`
  - `DATABASE_URL`: `postgresql://affine:${password}@affine-postgres:5432/affine`
  - `REDIS_SERVER_HOST`: `affine-redis`
- Volume mounts:
  - `/root/.affine/storage` → NFS (uploads)
- Probes: HTTP GET on `/` with startup probe (30 retries)

### Services
| Name | Type | Port | Target |
|------|------|------|--------|
| affine-postgres | ClusterIP | 5432 | postgres |
| affine-redis | ClusterIP | 6379 | redis |
| affine | LoadBalancer | 80 | 3010 |

## File Structure

```
kubernetes/
├── apps/base/tools/affine/
│   ├── kustomization.yaml
│   ├── postgres-statefulset.yaml
│   ├── redis-deployment.yaml
│   ├── server-deployment.yaml
│   ├── services.yaml
│   ├── pvc.yaml
│   └── secret.enc.yaml
│
├── infrastructure/storage/
│   ├── nfs-documents-affine-pv.yaml
│   └── nfs-documents-affine-pvc.yaml
│
└── infrastructure/cluster-vars/
    └── cluster-vars.yaml              # Add IP_AFFINE

flux-system/
└── image-automation/
    ├── affine-imagepolicy.yaml
    └── affine-imagerepository.yaml

scripts/
└── generate-dns-config.py             # Add to MULTI_SUFFIX_SERVICES

kubernetes/apps/base/tools/homepage/
└── configmap.yaml                     # Add Affine widget
```

## NFS Storage

**PersistentVolume**:
- Name: `nfs-documents-affine`
- Path: `/mnt/tank/documents/Affine`
- Capacity: 250Gi
- Mount options: nfsvers=4.1, hard, noatime, rsize/wsize=1048576

**PersistentVolumeClaim**:
- Name: `affine-storage`
- Namespace: `tools`
- Binds to: `nfs-documents-affine`

## FluxCD Image Automation

**ImageRepository**:
- Image: `ghcr.io/toeverything/affine-graphql`
- Interval: 1h

**ImagePolicy**:
- Pattern: `^stable-(?P<ts>[0-9]+)$`
- Policy: numerical ascending (latest timestamp)

## Configuration Updates

### cluster-vars.yaml
```yaml
IP_AFFINE: "10.10.2.33"
```

### generate-dns-config.py
```python
MULTI_SUFFIX_SERVICES = {
    # ... existing
    "affine": ["home.arpa", "home-infra.net"],
}
```

### Homepage configmap.yaml
```yaml
- Tools:
    - Affine:
        icon: affine.png
        href: http://affine.${DOMAIN_INTERNAL}
        description: Knowledge Base & Notes
```

## Post-Deployment

```bash
# Generate DNS configs
./scripts/generate-dns-config.py

# Sync DNS (dry-run first)
./scripts/controld/controld-dns.py sync --dry-run
```

## Storage Sizing

| Component | Storage | Class |
|-----------|---------|-------|
| PostgreSQL | 5Gi | Longhorn |
| Redis | 1Gi | Longhorn |
| Uploads (NFS) | 250Gi | NFS |
