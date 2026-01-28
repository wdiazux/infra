# CloudNative-PG

Kubernetes operator for managing PostgreSQL clusters declaratively.

---

## Overview

CloudNative-PG (CNPG) manages PostgreSQL databases as Kubernetes-native resources. It provides automated failover, backup integration, and declarative cluster management.

| Property | Value |
|----------|-------|
| Namespace | `kube-system` (operator) |
| Chart | `cnpg/cloudnative-pg` |
| Version | `0.27.0` |

**Key Features:**

| Feature | Description |
|---------|-------------|
| Declarative Clusters | PostgreSQL clusters defined as CRDs |
| Auto Credentials | Secrets auto-generated for app access |
| Extensions | Support for pgvector, VectorChord, etc. |
| Backup Integration | Native backup to S3/MinIO |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CNPG Operator (kube-system)                      │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ manages
        ┌────────────────────────┼────────────────────────┐
        ▼                        ▼                        ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│ immich-postgres│       │zitadel-postgresql│    │forgejo-postgresql│
│ (media)       │       │ (auth)          │      │ (forgejo)      │
│ + VectorChord │       │ SSO critical    │      │                │
└───────────────┘       └───────────────┘       └───────────────┘
        ▼                        ▼                        ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│paperless-postgresql│  │attic-postgresql│       │affine-postgresql│
│ (management)  │       │ (tools)        │       │ (tools)        │
│               │       │                │       │ + pgvector     │
└───────────────┘       └───────────────┘       └───────────────┘
                                 ▼
                        ┌───────────────┐
                        │n8n-postgresql │
                        │ (automation)  │
                        └───────────────┘
```

---

## Managed Clusters

CNPG manages **7 PostgreSQL clusters** across the homelab:

| Cluster | Namespace | Database | Storage | Extensions | Backup |
|---------|-----------|----------|---------|------------|--------|
| `immich-postgres` | media | immich | 10Gi | VectorChord | s3://cnpg-backups/immich/ |
| `zitadel-postgresql` | auth | zitadel | 10Gi | - | s3://cnpg-backups/zitadel/ |
| `forgejo-postgresql` | forgejo | forgejo | 5Gi | - | s3://cnpg-backups/forgejo/ |
| `paperless-postgresql` | management | paperless | 5Gi | - | s3://cnpg-backups/paperless/ |
| `attic-postgresql` | tools | attic | 5Gi | - | s3://cnpg-backups/attic/ |
| `affine-postgresql` | tools | affine | 5Gi | pgvector | s3://cnpg-backups/affine/ |
| `n8n-postgresql` | automation | n8n | 2Gi | - | s3://cnpg-backups/n8n/ |

**Backup Configuration:**
- All clusters backup to MinIO (`minio.backup.svc.cluster.local:9000`)
- WAL and data compression: gzip
- Retention policy: 14 days
- Scheduled daily backups at 3:00 AM

---

## Cluster Definition

Example PostgreSQL cluster:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: app-postgres
  namespace: app-namespace
spec:
  instances: 1  # Single node for homelab

  storage:
    size: 10Gi
    storageClass: longhorn

  postgresql:
    parameters:
      shared_buffers: "256MB"
      effective_cache_size: "512MB"

  bootstrap:
    initdb:
      database: appdb
      owner: appuser
```

---

## Service Naming Convention

CNPG creates multiple services for each cluster:

| Service Suffix | Purpose | When to Use |
|----------------|---------|-------------|
| `<cluster>-rw` | Read-write primary | Default for applications (writes) |
| `<cluster>-ro` | Read-only replicas | Read scaling (multi-instance only) |
| `<cluster>-r` | Any instance | Round-robin for reads |

**For single-instance clusters**, always use `-rw` suffix:
```yaml
env:
  - name: DATABASE_HOST
    value: "zitadel-postgresql-rw.auth.svc.cluster.local"
```

---

## Auto-Generated Secrets

CNPG automatically creates secrets for database access:

| Secret Name | Keys | Purpose |
|-------------|------|---------|
| `<cluster>-app` | `username`, `password`, `host`, `port`, `dbname`, `uri` | Application access |
| `<cluster>-superuser` | `username`, `password` | Admin access |

### Using in Applications

```yaml
env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: app-postgres-app
        key: host
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-postgres-app
        key: password
```

---

## Extensions

### VectorChord (Immich)

Immich uses VectorChord for AI-powered semantic search:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: immich-postgres
spec:
  imageName: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0

  postgresql:
    shared_preload_libraries:
      - "vectorchord"
```

### pgvector (Affine)

Affine uses pgvector for AI features:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: affine-postgresql
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:17.5

  postgresql:
    shared_preload_libraries:
      - "vector"

  bootstrap:
    initdb:
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS vector;
```

---

## Common Operations

### View Clusters

```bash
# List all clusters
kubectl get clusters.postgresql.cnpg.io -A

# Describe cluster status
kubectl describe cluster immich-postgres -n media
```

### Connect to Database

```bash
# Get connection string
kubectl get secret immich-postgres-app -n media -o jsonpath='{.data.uri}' | base64 -d

# Port-forward for local access
kubectl port-forward -n media svc/immich-postgres-rw 5432:5432

# Connect with psql
PGPASSWORD=$(kubectl get secret immich-postgres-app -n media -o jsonpath='{.data.password}' | base64 -d) \
  psql -h localhost -U immich -d immich
```

### Backup Operations

All clusters have automated backups configured via `ScheduledBackup` CRDs:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: zitadel-postgresql-daily
  namespace: auth
spec:
  schedule: "0 0 3 * * *"  # Daily at 3:00 AM
  backupOwnerReference: self
  cluster:
    name: zitadel-postgresql
```

#### View All Backups

```bash
# List all scheduled backups
kubectl get scheduledbackups -A

# List all backup objects
kubectl get backups -A

# Check MinIO for backup files
kubectl exec -n backup deploy/minio -- mc ls myminio/cnpg-backups/
```

#### Manual Backup

```bash
# Create on-demand backup for any cluster
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: zitadel-manual-$(date +%Y%m%d)
  namespace: auth
spec:
  cluster:
    name: zitadel-postgresql
EOF

# Check backup status
kubectl get backup -n auth
```

### Restore from Backup

```bash
# Create new cluster from backup
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: zitadel-postgresql-restored
  namespace: auth
spec:
  instances: 1
  storage:
    size: 10Gi
    storageClass: longhorn
  bootstrap:
    recovery:
      backup:
        name: zitadel-manual-20260128
EOF
```

---

## Verification

```bash
# Check operator
kubectl get pods -n kube-system -l app.kubernetes.io/name=cloudnative-pg

# List all CNPG clusters
kubectl get clusters.postgresql.cnpg.io -A

# Expected output:
# NAMESPACE    NAME                   AGE   INSTANCES   READY   STATUS
# auth         zitadel-postgresql     1d    1           1       Cluster in healthy state
# automation   n8n-postgresql         1d    1           1       Cluster in healthy state
# forgejo      forgejo-postgresql     1d    1           1       Cluster in healthy state
# management   paperless-postgresql   1d    1           1       Cluster in healthy state
# media        immich-postgres        7d    1           1       Cluster in healthy state
# tools        affine-postgresql      1d    1           1       Cluster in healthy state
# tools        attic-postgresql       1d    1           1       Cluster in healthy state

# Check all scheduled backups
kubectl get scheduledbackups -A

# Check recent backups
kubectl get backups -A --sort-by=.metadata.creationTimestamp | tail -10

# Verify backup storage
kubectl exec -n backup deploy/minio -- mc ls myminio/cnpg-backups/
```

---

## Troubleshooting

### Cluster Not Ready

```bash
# Check cluster status
kubectl describe cluster <name> -n <namespace>

# Check pod events
kubectl get events -n <namespace> --field-selector involvedObject.name=<cluster-name>

# Check operator logs
kubectl logs -n kube-system deployment/cnpg-cloudnative-pg --tail=100
```

### Connection Refused

```bash
# Verify service exists
kubectl get svc -n <namespace> | grep postgres

# Check pod is running
kubectl get pods -n <namespace> -l cnpg.io/cluster=<cluster-name>

# Test from within cluster
kubectl run -n <namespace> --rm -it --image=postgres:14 test -- \
  psql -h <cluster-name>-rw -U postgres -c "SELECT 1"
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n <namespace> -l cnpg.io/cluster=<cluster-name>

# Check storage class
kubectl get storageclass longhorn
```

---

## Performance Tuning

For homelab single-node deployments:

```yaml
spec:
  postgresql:
    parameters:
      # Memory (adjust based on available RAM)
      shared_buffers: "256MB"
      effective_cache_size: "512MB"
      work_mem: "16MB"
      maintenance_work_mem: "64MB"

      # Connections
      max_connections: "100"

      # WAL
      wal_buffers: "16MB"

      # Query planning
      random_page_cost: "1.1"  # SSD optimized
```

---

## Monitoring

CNPG exposes Prometheus metrics:

```bash
# Check metrics endpoint
kubectl port-forward -n media svc/immich-postgres-rw 9187:9187
curl http://localhost:9187/metrics
```

Metrics are scraped by VictoriaMetrics via ServiceMonitor.

---

## Documentation

- [CloudNative-PG Documentation](https://cloudnative-pg.io/documentation/)
- [Cluster Configuration](https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/)
- [Backup and Recovery](https://cloudnative-pg.io/documentation/current/backup_recovery/)
- [PostgreSQL Extensions](https://cloudnative-pg.io/documentation/current/postgresql_conf/)

---

**Last Updated:** 2026-01-28 (CNPG migration complete - all 7 databases managed)
