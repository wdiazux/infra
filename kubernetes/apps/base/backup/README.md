# Backup Namespace

Disaster recovery and backup infrastructure for the Kubernetes cluster.

## Components

| Service | Purpose | Access |
|---------|---------|--------|
| MinIO | S3-compatible storage backend | Console: 10.10.2.28:9001 |
| Velero | Kubernetes backup/restore | CLI: `velero` command |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Backup Flow                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Velero ──▶ CSI Snapshotter ──▶ Longhorn (snapshot)    │
│     │                              │                    │
│     ▼                              ▼                    │
│  MinIO (S3 API) ◀────── Snapshot Data Movement         │
│     │                                                   │
│     ▼                                                   │
│  NAS (10.10.2.5:/mnt/tank/backups/velero)              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Storage

- **MinIO Data**: NFS mount to NAS at `/mnt/tank/backups/velero`
- **Capacity**: 500Gi allocated
- **Retention**: Managed by Velero backup policies

## Credentials

MinIO credentials are stored in `minio-credentials` secret:
- `root-user`: MinIO admin username
- `root-password`: MinIO admin password

Velero credentials are stored in `velero-credentials` secret.

## Backup Schedules

Configured in Velero HelmRelease values:
- Daily backups at 3 AM (7-day retention)
- Weekly backups on Sunday (4-week retention)

## Commands

```bash
# Check backup status
velero backup get

# Create manual backup
velero backup create manual-backup --include-namespaces=<namespace>

# Restore from backup
velero restore create --from-backup <backup-name>

# Check Velero status
velero status
```

## Related Files

- Namespace: `kubernetes/infrastructure/namespaces/backup.yaml`
- NFS Storage: `kubernetes/infrastructure/storage/nfs-backups-*.yaml`
- Velero HelmRelease: `kubernetes/infrastructure/controllers/velero.yaml`
- Velero Values: `kubernetes/infrastructure/values/velero-values.yaml`
