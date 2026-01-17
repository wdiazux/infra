# Attic Nix Binary Cache Design

**Date:** 2026-01-17
**Status:** Approved

---

## Overview

Deploy Attic, a multi-tenant Nix binary cache server, to the Kubernetes cluster for caching Nix build artifacts.

## Architecture

**Components:**
- **attic-server** - Main cache server (`heywoodlh/attic:latest`)
- **attic-db** - PostgreSQL 16-alpine for metadata storage
- **NFS storage** - Binary cache artifacts at `/mnt/tank/linux/attic`

**Network:**
- **Namespace:** `attic`
- **IP:** `10.10.2.19`
- **Port:** 80 → 8080
- **URL:** `http://10.10.2.19` or `http://attic.home-infra.net`

## Storage

| Volume | Type | Path/Size | Purpose |
|--------|------|-----------|---------|
| nfs-linux-attic | NFS PV/PVC | `/mnt/tank/linux/attic` (1Ti) | Binary cache storage |
| attic-db-data | Longhorn PVC | 5Gi | PostgreSQL data |

**NFS Server:** 10.10.2.5

## Configuration

**server.toml** (via ConfigMap):

```toml
listen = "[::]:8080"

allowed-hosts = []

api-endpoint = "http://10.10.2.19/"

[database]
url = "postgresql://attic:${POSTGRES_PASSWORD}@attic-db:5432/attic"

[storage]
type = "local"
path = "/var/lib/attic/storage"

[chunking]
nar-size-threshold = 65536  # 64 KiB
min-size = 16384            # 16 KiB
avg-size = 65536            # 64 KiB
max-size = 262144           # 256 KiB

[compression]
type = "zstd"

[garbage-collection]
interval = "12 hours"
```

Based on official template from https://github.com/zhaofengli/attic

## Secrets

SOPS-encrypted secrets in `secrets/attic.enc.yaml`:

| Secret | Purpose |
|--------|---------|
| `POSTGRES_PASSWORD` | Database password |
| `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` | JWT HS256 signing key (base64) |

## File Structure

```
kubernetes/
├── apps/base/attic/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── postgres-statefulset.yaml
│   ├── postgres-service.yaml
│   └── storage.yaml
├── apps/production/
│   └── kustomization.yaml          # Updated
└── infrastructure/storage/
    ├── nfs-linux-attic-pv.yaml     # New
    └── kustomization.yaml          # Updated

secrets/
└── attic.enc.yaml                  # New
```

## Deployment Order

1. NFS PV created in `infrastructure/storage/`
2. Namespace + secrets deployed
3. PostgreSQL StatefulSet starts, becomes healthy
4. Attic deployment starts (waits for DB via init container)
5. LoadBalancer service exposes on 10.10.2.19

## Resource Allocation

Following homelab resource strategy - no CPU/memory requests for non-critical services.

| Component | CPU Request | Memory Request |
|-----------|-------------|----------------|
| attic-server | none | none |
| attic-db | none | none |

## Documentation Updates

- `docs/reference/network.md` - Add 10.10.2.19 Attic entry
- `CLAUDE.md` - Add to network configuration table

---

**Last Updated:** 2026-01-17
