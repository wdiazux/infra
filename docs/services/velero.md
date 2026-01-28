# Velero

Kubernetes backup and disaster recovery solution.

---

## Overview

Velero provides backup and restore capabilities for Kubernetes resources and persistent volumes. It uses MinIO as an S3-compatible backend and Longhorn CSI snapshots for volume data.

| Property | Value |
|----------|-------|
| Namespace | `backup` |
| Chart | `vmware-tanzu/velero` |
| Version | `8.7.2` |

**Key Features:**

| Feature | Description |
|---------|-------------|
| Resource Backup | Kubernetes manifests backed up to S3 |
| Volume Snapshots | Longhorn CSI provider for PV snapshots |
| Snapshot Movement | Data moved to object storage for DR |
| Scheduled Backups | Automated daily and weekly backups |

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│  Velero Server  │────▶│  MinIO (S3)     │
│  (backup ns)    │     │  (backup ns)    │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│  Node Agent     │────▶ CSI Snapshots
│  (DaemonSet)    │      (Longhorn)
└─────────────────┘
```

---

## Backup Schedules

### Daily Application Backup

| Property | Value |
|----------|-------|
| Schedule | `0 3 * * *` (3 AM daily) |
| Retention | 7 days |
| Namespaces | ai, arr-stack, automation, forgejo, management, media, printing, tools |

### Weekly Full Backup

| Property | Value |
|----------|-------|
| Schedule | `0 2 * * 0` (2 AM Sunday) |
| Retention | 4 weeks |
| Namespaces | All application namespaces + backup, monitoring |

---

## Configuration

### Storage Backend

```yaml
backupStorageLocation:
  - name: default
    provider: aws
    bucket: velero
    config:
      region: minio
      s3ForcePathStyle: "true"
      s3Url: http://minio.backup.svc.cluster.local:9000
```

### Volume Snapshots

```yaml
volumeSnapshotLocation:
  - name: longhorn
    provider: csi

# Enable CSI snapshots
features: EnableCSI

# Move snapshot data to object storage (required for DR)
defaultSnapshotMoveData: true
```

---

## Plugins

| Plugin | Version | Purpose |
|--------|---------|---------|
| velero-plugin-for-aws | v1.13.0 | S3/MinIO backend support |
| CSI plugin | built-in (v1.14+) | Longhorn volume snapshots |

---

## Common Operations

### View Backups

```bash
# List all backups
velero backup get

# Describe a specific backup
velero backup describe daily-apps-20260128030000

# View backup logs
velero backup logs daily-apps-20260128030000
```

### Manual Backup

```bash
# Backup specific namespace
velero backup create manual-ai-backup \
  --include-namespaces ai \
  --snapshot-move-data

# Backup with resource labels
velero backup create manual-backup \
  --selector app=immich
```

### Restore Operations

```bash
# List available restores
velero restore get

# Restore entire backup
velero restore create --from-backup daily-apps-20260128030000

# Restore specific namespace
velero restore create --from-backup daily-apps-20260128030000 \
  --include-namespaces media

# Restore specific resources
velero restore create --from-backup daily-apps-20260128030000 \
  --include-resources persistentvolumeclaims,persistentvolumes
```

### Schedule Management

```bash
# List schedules
velero schedule get

# Pause a schedule
velero schedule pause daily-apps

# Resume a schedule
velero schedule unpause daily-apps

# Trigger immediate backup from schedule
velero backup create --from-schedule daily-apps
```

---

## Disaster Recovery

### Full Cluster Restore

1. **Install Velero** on new cluster with same configuration
2. **Verify backup access**: `velero backup get`
3. **Restore infrastructure first**:
   ```bash
   velero restore create --from-backup weekly-full-YYYYMMDD \
     --include-namespaces backup,monitoring
   ```
4. **Restore applications**:
   ```bash
   velero restore create --from-backup weekly-full-YYYYMMDD \
     --exclude-namespaces backup,monitoring
   ```

### Single Namespace Recovery

```bash
# Delete corrupted namespace (if needed)
kubectl delete namespace media

# Restore from backup
velero restore create media-restore \
  --from-backup daily-apps-20260128030000 \
  --include-namespaces media
```

---

## Verification

```bash
# Check Velero pods
kubectl get pods -n backup -l app.kubernetes.io/name=velero

# Check node agent (for CSI snapshots)
kubectl get pods -n backup -l app.kubernetes.io/name=velero -l app.kubernetes.io/component=node-agent

# Verify backup storage location
velero backup-location get

# Verify snapshot location
velero snapshot-location get

# Test backup integrity
velero backup describe <backup-name> --details
```

---

## Troubleshooting

### Backup Stuck in Progress

```bash
# Check Velero logs
kubectl logs -n backup deployment/velero --tail=100

# Check node agent logs (for volume operations)
kubectl logs -n backup daemonset/node-agent --tail=100
```

### Volume Snapshot Failures

```bash
# Verify Longhorn CSI is healthy
kubectl get volumesnapshots -A
kubectl get volumesnapshotcontents

# Check CSI snapshot class
kubectl get volumesnapshotclass
```

### MinIO Connection Issues

```bash
# Verify MinIO is running
kubectl get pods -n backup -l app=minio

# Test S3 connectivity
kubectl run -n backup --rm -it --image=amazon/aws-cli test -- \
  --endpoint-url http://minio:9000 s3 ls s3://velero/
```

---

## Resources

| Resource | Requests | Limits |
|----------|----------|--------|
| CPU | 100m | 500m |
| Memory | 256Mi | 512Mi |

---

## Documentation

- [Velero Documentation](https://velero.io/docs/)
- [CSI Snapshot Support](https://velero.io/docs/main/csi/)
- [Disaster Recovery](https://velero.io/docs/main/disaster-case/)
- [Backup Verification](../operations/backups.md)

---

**Last Updated:** 2026-01-28
