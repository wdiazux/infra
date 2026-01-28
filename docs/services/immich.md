# Immich

Self-hosted photo and video backup solution with AI-powered features.

---

## Overview

Immich provides Google Photos-like functionality for self-hosted photo management. It includes AI-powered search using GPU-accelerated machine learning and supports OIDC authentication via Zitadel.

| Property | Value |
|----------|-------|
| Namespace | `media` |
| Chart | `immich/immich` (OCI) |
| Chart Version | `0.10.3` |
| URL | `https://photos.reynoza.org` |

---

## Deployment

| Property | Value |
|----------|-------|
| Service Type | ClusterIP |
| Access | Gateway API HTTPRoute |
| Server Image | `v2.5.0` |
| ML Image | `v2.5.0-cuda` |

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Gateway API    │────▶│  Immich Server  │────▶│  Machine        │
│  (HTTPS)        │     │  (media ns)     │     │  Learning (GPU) │
└─────────────────┘     └────────┬────────┘     └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  PostgreSQL     │     │  Valkey         │     │  Photo Library  │
│  (CNPG + Vector)│     │  (Redis)        │     │  (NFS PVC)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Components

### Server

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/immich-app/immich-server:v2.5.0` |
| Memory | 512Mi - 4Gi |
| User/Group | 1000/3001 |

### Machine Learning (GPU)

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/immich-app/immich-machine-learning:v2.5.0-cuda` |
| Memory | 100Mi - 8Gi |
| GPU | `nvidia.com/gpu: 1` |
| Runtime | `nvidia` |
| Workers | `1` |

### PostgreSQL (CloudNative-PG)

| Setting | Value |
|---------|-------|
| Operator | CloudNative-PG |
| Image | `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` |
| Extension | VectorChord (semantic search) |
| Connection | `immich-postgres-rw:5432` |

### Valkey (Redis)

| Setting | Value |
|---------|-------|
| Enabled | `true` |
| Storage | 1Gi (Longhorn) |

---

## Authentication (Zitadel OIDC)

Immich uses a config file for OIDC, generated dynamically by an init container:

| Setting | Value |
|---------|-------|
| Issuer | `https://auth.home-infra.net` |
| Scopes | `openid email profile` |
| Auto Register | Enabled |
| Button Text | "Login with Zitadel" |
| Signing Algorithm | RS256 |
| Token Auth Method | `client_secret_post` |

The init container reads credentials from `immich-oidc-secrets` and generates `/config/immich.json`.

---

## Storage

### Photo Library

| Setting | Value |
|---------|-------|
| PVC | `immich-photos` |
| Type | NFS |
| Mount | `/usr/src/app/upload` |

### ML Cache

| Setting | Value |
|---------|-------|
| PVC | `immich-ml-cache` |
| Type | Longhorn |
| Mount | `/cache` |

---

## Environment Variables

### General Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone (TZ identifier) | - |
| `IMMICH_ENV` | Environment mode | `production` |
| `IMMICH_LOG_LEVEL` | Log verbosity (`verbose`, `debug`, `log`, `warn`, `error`) | `log` |
| `IMMICH_MEDIA_LOCATION` | Internal media path | `/data` |
| `IMMICH_CONFIG_FILE` | Path to config file | - |

### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOSTNAME` | Database host | `database` |
| `DB_PORT` | Database port | `5432` |
| `DB_USERNAME` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `DB_DATABASE_NAME` | Database name | `immich` |

### Machine Learning Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `MACHINE_LEARNING_WORKERS` | Worker processes | `1` |
| `MACHINE_LEARNING_CACHE_FOLDER` | Model cache directory | `/cache` |
| `NVIDIA_VISIBLE_DEVICES` | GPU visibility | `all` |

---

## Common Operations

### Access Web UI

```bash
# Via Gateway API
open https://photos.reynoza.org

# Via port-forward (troubleshooting)
kubectl port-forward -n media svc/immich-server 2283:2283
open http://localhost:2283
```

### View Logs

```bash
# Server logs
kubectl logs -n media deployment/immich-server --tail=100

# Machine learning logs
kubectl logs -n media deployment/immich-machine-learning --tail=100
```

### Manage Jobs

```bash
# Access admin panel via web UI
# Administration > Jobs

# Or via API
curl -X GET https://photos.reynoza.org/api/jobs \
  -H "Authorization: Bearer <api-key>"
```

### Database Operations

```bash
# Connect to PostgreSQL
kubectl exec -n media -it immich-postgres-1 -- psql -U immich

# Check vector extension
\dx
```

---

## Verification

```bash
# Check all Immich pods
kubectl get pods -n media -l app.kubernetes.io/instance=immich

# Check PostgreSQL cluster
kubectl get cluster -n media immich-postgres

# Check services
kubectl get svc -n media | grep immich

# Check GPU allocation on ML pod
kubectl describe pod -n media -l app.kubernetes.io/component=machine-learning | grep -A5 nvidia

# Test OIDC config
kubectl exec -n media deployment/immich-server -- cat /config/immich.json
```

---

## Troubleshooting

### OIDC Login Fails

```bash
# Check OIDC secrets exist
kubectl get secret -n media immich-oidc-secrets

# Verify config file was generated
kubectl exec -n media deployment/immich-server -- cat /config/immich.json

# Check init container logs
kubectl logs -n media deployment/immich-server -c generate-config

# Verify Zitadel is reachable
kubectl exec -n media deployment/immich-server -- \
  curl -s https://auth.home-infra.net/.well-known/openid-configuration
```

### ML Processing Slow

```bash
# Check GPU is allocated
kubectl describe pod -n media -l app.kubernetes.io/component=machine-learning | grep nvidia

# Check ML logs for errors
kubectl logs -n media deployment/immich-machine-learning --tail=100

# Verify CUDA is working
kubectl exec -n media deployment/immich-machine-learning -- nvidia-smi
```

### Database Connection Issues

```bash
# Check PostgreSQL cluster status
kubectl get cluster -n media immich-postgres

# Check connection from server
kubectl exec -n media deployment/immich-server -- \
  pg_isready -h immich-postgres-rw -p 5432 -U immich

# Check secrets
kubectl get secret -n media immich-postgres-app -o yaml
```

### Photos Not Uploading

```bash
# Check NFS mount
kubectl exec -n media deployment/immich-server -- df -h /usr/src/app/upload

# Check file permissions
kubectl exec -n media deployment/immich-server -- ls -la /usr/src/app/upload

# Check server logs for upload errors
kubectl logs -n media deployment/immich-server | grep -i upload
```

---

## Secrets

| Secret | Source | Purpose |
|--------|--------|---------|
| `immich-postgres-app` | CloudNative-PG | Database credentials (auto-generated) |
| `immich-oidc-secrets` | CronJob | OIDC credentials (auto-managed) |

---

## Important Notes

- **VectorChord Extension**: Required for semantic search; uses special PostgreSQL image
- **GPU Scheduling**: ML pod requires exclusive GPU access; conflicts with other GPU workloads
- **NFS Performance**: Photo library on NFS may impact upload/thumbnail performance
- **Config File**: OIDC settings are in `/config/immich.json`, not environment variables

---

## Documentation

- [Immich Documentation](https://immich.app/docs/)
- [Environment Variables](https://immich.app/docs/install/environment-variables/)
- [Hardware Transcoding](https://immich.app/docs/features/hardware-transcoding/)
- [OAuth/OIDC Setup](https://immich.app/docs/administration/oauth/)
- [GitHub](https://github.com/immich-app/immich)

---

**Last Updated:** 2026-01-28
