# Immich Helm Chart Migration Design

**Date**: 2026-01-27
**Status**: Approved

## Summary

Migrate Immich from raw Kubernetes manifests to the official Helm chart (`oci://ghcr.io/immich-app/immich-charts/immich`) with CloudNative-PG for PostgreSQL.

## Current State

9 raw manifest files in `kubernetes/apps/base/media/immich/`:
- PostgreSQL StatefulSet (VectorChord image)
- Valkey (Redis) Deployment
- Server Deployment (init container for OIDC config)
- Machine Learning Deployment (NVIDIA GPU)
- 4 ClusterIP Services
- ML cache PVC
- HTTPRoute (photos.reynoza.org)
- SOPS-encrypted secrets

FluxCD ImagePolicies auto-update server and ML image tags.

## Target State

### New Components

1. **CloudNative-PG operator** — infrastructure-level HelmRelease
2. **CNPG Cluster** — PostgreSQL with VectorChord for Immich
3. **Immich HelmRelease** — official chart managing server, ML, and Valkey

### File Structure

```
kubernetes/
├── infrastructure/
│   └── controllers/
│       ├── helm-repositories.yaml   # ADD: immich + cnpg repos
│       └── cnpg-operator.yaml       # NEW: CNPG operator HelmRelease
│
└── apps/base/media/immich/
    ├── kustomization.yaml           # REWRITE
    ├── secret.enc.yaml              # KEEP
    ├── cnpg-cluster.yaml            # NEW
    ├── helmrelease.yaml             # NEW
    ├── httproute.yaml               # KEEP (update service name if needed)
    └── pvc.yaml                     # KEEP
```

### Removed Files

- `postgres-statefulset.yaml` — replaced by CNPG Cluster
- `redis-deployment.yaml` — replaced by chart's bundled Valkey
- `server-deployment.yaml` — replaced by HelmRelease
- `ml-deployment.yaml` — replaced by HelmRelease
- `services.yaml` — replaced by chart + CNPG auto-generated services
- FluxCD ImagePolicy/ImageRepository for immich (no longer needed)

## Design Details

### CloudNative-PG Operator

- Chart: `cloudnative-pg` from `https://cloudnative-pg.github.io/charts`
- Namespace: `cnpg-system`
- Deployed as infrastructure controller (same tier as Cilium, Longhorn)

### CNPG Cluster

- Image: `ghcr.io/tensorchord/cloudnative-vectorchord:16-v0.4.1`
- Extensions: `vchord.so`, `vectors.so` (shared_preload_libraries)
- Storage: 10Gi Longhorn
- Single instance (homelab)
- Database: `immich`, owner: `immich`
- Auto-creates service: `immich-postgres-rw`

### Immich HelmRelease

- Chart: `immich` from OCI registry (ghcr.io/immich-app/immich-charts)
- Versioning: follow chart releases (no pinned image tag)
- Server: connects to CNPG via `immich-postgres-rw:5432`
- Machine Learning: `runtimeClassName: nvidia`, 1x GPU
- Valkey: chart-managed (enabled)
- OIDC: chart's `immich.configuration` mechanism
- Storage: existing NFS PVC for photos, existing Longhorn PVC for ML cache
- Timezone: America/El_Salvador

### Database Migration

Fresh start — no data migration. Immich will re-scan the NFS photo library.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| DB management | CloudNative-PG | Operator-managed, recommended by chart |
| Cache management | Chart's bundled Valkey | Simplest, Valkey is stateless |
| DB migration | Fresh start | User preference, photos preserved on NFS |
| Versioning | Follow chart releases | Simplest, removes need for image automation |
| OIDC config | Chart's config mechanism | Cleaner than init container approach |
