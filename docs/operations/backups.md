# Backups

Backup strategies and procedures for the homelab infrastructure.

---

## Overview

| Component | Backup Target | Method | Schedule |
|-----------|---------------|--------|----------|
| Kubernetes Resources | MinIO → NAS | Velero | Daily 3 AM / Weekly 2 AM |
| Longhorn Volumes | MinIO → NAS | Velero CSI Snapshots | Daily 3 AM / Weekly 2 AM |
| Longhorn Volumes | NAS (NFS) | Longhorn Backup | Manual / On-demand |
| Terraform State | Git/Local | Manual | Before changes |
| Talos Config | Local files | Terraform output | Auto |
| Git Repositories | Forgejo | Longhorn volume | Daily |
| Secrets | Git (encrypted) | SOPS | On change |

---

## Velero Disaster Recovery

Velero provides Kubernetes-native backup and restore with CSI snapshot integration for persistent volumes.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Backup Flow                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Velero ──▶ CSI Snapshotter ──▶ Longhorn (snapshot)         │
│     │                              │                         │
│     ▼                              ▼                         │
│  MinIO (S3 API) ◀────── Snapshot Data Movement              │
│     │                                                        │
│     ▼                                                        │
│  NAS (10.10.2.5:/mnt/tank/backups/velero)                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### How Velero + Longhorn CSI Integration Works

1. **Velero triggers backup** at scheduled time
2. **CSI Snapshotter** creates point-in-time Longhorn volume snapshots
3. **Node Agent** (runs on each node) moves snapshot data to MinIO
4. **MinIO** stores backup data in S3-compatible format
5. **MinIO backend** persists to NAS via NFS mount

**Key settings enabling this:**
- `features: EnableCSI` - Enables CSI snapshot integration
- `defaultSnapshotMoveData: true` - Copies snapshot data to object storage
- `volumeSnapshotLocations: [longhorn]` - Uses Longhorn as snapshot provider

**Configuration file:** `kubernetes/infrastructure/controllers/velero.yaml`

### Components

| Component | Purpose | Access |
|-----------|---------|--------|
| Velero | Kubernetes backup/restore | CLI: `velero` command |
| MinIO | S3-compatible storage backend | Console: http://10.10.2.17 |
| CSI Snapshotter | Volume snapshot controller | Internal |
| Node Agent | Moves snapshot data to object storage | Internal (DaemonSet) |

### Backup Schedules

| Schedule | Time | Retention | Namespaces |
|----------|------|-----------|------------|
| `velero-daily-apps` | 3 AM daily | 7 days | ai, arr-stack, automation, forgejo, management, media, printing, tools |
| `velero-weekly-full` | 2 AM Sunday | 4 weeks | All above + backup, monitoring |

### What Gets Backed Up

**Daily Backup (`velero-daily-apps`):**

| Namespace | Services | Data Included |
|-----------|----------|---------------|
| ai | Open WebUI, Ollama, ComfyUI | LLM configs, generated images |
| arr-stack | Radarr, Sonarr, Prowlarr, Bazarr, SABnzbd, qBittorrent | App configs (SQLite DBs) |
| automation | Home Assistant, n8n | Automations, workflows, PostgreSQL |
| forgejo | Forgejo, PostgreSQL | Git repos, user data, database |
| management | Homepage, Paperless-ngx, Wallos | Documents, configs |
| media | Emby, Navidrome, Immich | Media metadata, PostgreSQL |
| printing | Obico | 3D print monitoring data |
| tools | IT-Tools, ntfy, Attic | Configs, notifications |

**Weekly Full (`velero-weekly-full`):**
- All daily namespaces PLUS:
- `backup` - MinIO, Velero configs
- `monitoring` - Grafana dashboards, VictoriaMetrics data

**Not backed up (intentionally):**
- `kube-system` - Recreated by Kubernetes/Talos
- `flux-system` - Recreated from Git
- `longhorn-system` - Storage infrastructure
- NFS media files - Backed up separately on NAS

### Velero Commands

```bash
# Check Velero status
velero status

# List backups
velero backup get

# Create manual backup
velero backup create manual-backup --include-namespaces=forgejo

# Create backup of specific namespace with volumes
velero backup create my-backup \
  --include-namespaces=media \
  --snapshot-move-data

# Restore from backup
velero restore create --from-backup daily-apps-20260120030000

# Check restore status
velero restore get

# Describe backup details
velero backup describe daily-apps-20260120030000 --details

# View backup logs
velero backup logs daily-apps-20260120030000
```

### MinIO Console

Access the MinIO web console at **http://10.10.2.17** to:
- Browse backup data in the `velero` bucket
- Monitor storage usage
- Manage bucket policies

Credentials are in `secrets/minio-creds.enc.yaml`.

### Configuration Files

| File | Purpose |
|------|---------|
| `kubernetes/infrastructure/controllers/velero.yaml` | Velero HelmRelease |
| `kubernetes/apps/base/backup/minio/` | MinIO deployment |
| `kubernetes/infrastructure/storage/nfs-backups-*.yaml` | NFS PV/PVC for MinIO |

---

## Managing Backup Schedules

### View Current Schedules

```bash
# List all schedules
kubectl get schedule -n backup

# Detailed schedule info
kubectl describe schedule velero-daily-apps -n backup

# Check last backup for schedule
kubectl get backup -n backup --sort-by=.metadata.creationTimestamp | tail -10
```

### Modify Existing Schedule

Schedules are managed via Helm values in `kubernetes/infrastructure/controllers/velero.yaml`.

**To change schedule timing or retention:**

1. Edit the Velero HelmRelease:
```yaml
# In velero.yaml, under spec.values.schedules
schedules:
  daily-apps:
    schedule: "0 4 * * *"  # Change to 4 AM
    template:
      ttl: "336h"          # Change to 14 days retention
      includedNamespaces:
        - ai
        - arr-stack
        # ... add/remove namespaces
```

2. Commit and push to trigger FluxCD reconciliation:
```bash
git add kubernetes/infrastructure/controllers/velero.yaml
git commit -m "chore(backup): Update daily backup schedule"
git push
```

3. Force reconciliation (optional):
```bash
flux reconcile helmrelease velero -n backup
```

### Add New Backup Schedule

**Option 1: Via Helm Values (Recommended - GitOps)**

Add to `velero.yaml` under `spec.values.schedules`:

```yaml
schedules:
  # Existing schedules...

  # New schedule example
  databases-hourly:
    disabled: false
    schedule: "0 * * * *"  # Every hour
    useOwnerReferencesInBackup: false
    template:
      ttl: "48h"           # 2 days retention
      includedNamespaces:
        - forgejo
        - automation
      labelSelector:
        matchLabels:
          backup-type: database
      snapshotMoveData: true
      storageLocation: default
      volumeSnapshotLocations:
        - longhorn
```

**Option 2: Via kubectl (Immediate, non-GitOps)**

```bash
kubectl create -n backup -f - <<EOF
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: my-custom-schedule
  namespace: backup
spec:
  schedule: "0 6 * * *"  # 6 AM daily
  template:
    ttl: 168h
    includedNamespaces:
      - my-namespace
    snapshotMoveData: true
    storageLocation: default
    volumeSnapshotLocations:
      - longhorn
EOF
```

### Add Namespace to Existing Backup

1. Edit `velero.yaml` and add namespace to `includedNamespaces` list
2. Commit and push
3. Next scheduled backup will include the new namespace

### Disable/Enable Schedule

```bash
# Disable schedule (pause backups)
kubectl patch schedule velero-daily-apps -n backup \
  --type merge -p '{"spec":{"paused":true}}'

# Enable schedule (resume backups)
kubectl patch schedule velero-daily-apps -n backup \
  --type merge -p '{"spec":{"paused":false}}'
```

### Delete Schedule

```bash
# Delete via kubectl
kubectl delete schedule my-custom-schedule -n backup

# For Helm-managed schedules, remove from velero.yaml and reconcile
```

### Backup Schedule Cron Reference

| Expression | Meaning |
|------------|---------|
| `0 3 * * *` | Daily at 3 AM |
| `0 2 * * 0` | Weekly on Sunday at 2 AM |
| `0 * * * *` | Every hour |
| `*/15 * * * *` | Every 15 minutes |
| `0 0 1 * *` | Monthly on 1st at midnight |

---

## Longhorn NFS Backup

### Configuration

Backup target is configured automatically via Terraform:
- **Target:** `nfs://10.10.2.5:/mnt/tank/backups`
- **Secret:** `longhorn-backup-secret` in `longhorn-system`

### Verify Backup Target

```bash
kubectl get backuptarget -n longhorn-system -o yaml
# Should show: available: true
```

### Create Manual Backup

**Via Longhorn UI:**
1. Access http://10.10.2.12
2. Go to Volume → Select volume
3. Take Snapshot → Backup

**Via kubectl:**
```bash
# Create snapshot first
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Snapshot
metadata:
  name: manual-snap-$(date +%Y%m%d)
spec:
  volume: pvc-xxxx  # Your volume name
EOF

# Then create backup
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: backup-$(date +%Y%m%d)
spec:
  snapshotName: manual-snap-$(date +%Y%m%d)
EOF
```

### Recurring Backups

Configure in Longhorn UI:
1. Recurring Job → Create
2. Settings:
   - **Name:** `daily-backup`
   - **Task:** Backup
   - **Schedule:** `0 2 * * *` (2 AM daily)
   - **Retain:** 7 (keep 7 backups)
   - **Concurrency:** 1

### Restore from Backup

1. Go to Backup in Longhorn UI
2. Find backup → Create PV/PVC
3. Use the restored PVC in your pod

---

## Terraform State

### Backup Before Changes

```bash
# Copy current state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)

# Or store in Git (careful with secrets)
```

### Critical Files to Backup

| File | Location | Contains |
|------|----------|----------|
| `terraform.tfstate` | `terraform/talos/` | All infrastructure state |
| `kubeconfig` | `terraform/talos/` | Cluster access |
| `talosconfig` | `terraform/talos/` | Talos API access |
| `.terraform.lock.hcl` | `terraform/talos/` | Provider versions |

### State Recovery

If state is lost but infrastructure exists:
```bash
# Import existing resources
terraform import proxmox_virtual_environment_vm.talos_node pve/qemu/1000
```

---

## Secrets Backup

### SOPS Age Key

**Critical:** Back up your Age private key!

```bash
# Location
~/.config/sops/age/keys.txt

# Backup options:
# 1. Password manager (recommended)
# 2. Encrypted backup
gpg -c ~/.config/sops/age/keys.txt

# 3. Physical safe (print it)
cat ~/.config/sops/age/keys.txt
```

### Encrypted Secrets Files

All secrets are stored encrypted in Git:
```
secrets/
├── proxmox-creds.enc.yaml
├── git-creds.enc.yaml
├── nas-backup-creds.enc.yaml
└── pangolin-creds.enc.yaml
```

These are automatically backed up when you push to Forgejo.

---

## Database Backups

### PostgreSQL (Forgejo)

Forgejo's PostgreSQL data is backed up via Longhorn.

**Manual dump:**
```bash
kubectl exec -it -n forgejo deploy/forgejo-postgresql -- \
  pg_dump -U forgejo forgejo | gzip > forgejo-db-$(date +%Y%m%d).sql.gz
```

### Automated CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: forgejo
spec:
  schedule: "0 3 * * *"  # 3 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:16-alpine
              command: ["/bin/sh", "-c"]
              args:
                - pg_dump -h forgejo-postgresql -U $PGUSER $PGDATABASE |
                  gzip > /backup/forgejo-$(date +%Y%m%d).sql.gz
              env:
                - name: PGUSER
                  valueFrom:
                    secretKeyRef:
                      name: forgejo-postgresql
                      key: postgres-user
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: forgejo-postgresql
                      key: postgres-password
                - name: PGDATABASE
                  value: forgejo
              volumeMounts:
                - name: backup
                  mountPath: /backup
          restartPolicy: OnFailure
          volumes:
            - name: backup
              nfs:
                server: 10.10.2.5
                path: /mnt/tank/backups/databases
```

---

## Verification

### Check Longhorn Backups

```bash
# List backups
kubectl get backups.longhorn.io -n longhorn-system

# Check backup status
kubectl get backups.longhorn.io -n longhorn-system -o yaml
```

### Test Restore

Periodically test restores:
1. Create test backup
2. Restore to new PVC
3. Verify data integrity
4. Delete test resources

---

## NAS Requirements

### TrueNAS SCALE Setup

1. **Dataset:** `/mnt/tank/backups`
2. **NFS Share:** Allow `10.10.2.0/24`
3. **Permissions:** Maproot User/Group: `root`

### Directory Structure

```
/mnt/tank/backups/
├── longhorn/      # Longhorn volume backups
├── databases/     # PostgreSQL dumps
└── configs/       # Manual config backups
```

---

## Disaster Recovery

### Full Cluster Recovery (Velero)

1. **Ensure NAS is accessible** with backup data
2. **Deploy new cluster:**
   ```bash
   terraform destroy  # If needed
   terraform apply
   ```
3. **Install Velero** (via FluxCD or manually)
4. **Configure MinIO** backup storage location
5. **Restore from Velero backup:**
   ```bash
   # List available backups
   velero backup get

   # Restore entire backup
   velero restore create full-restore --from-backup weekly-full-20260119020000

   # Or restore specific namespace
   velero restore create forgejo-restore \
     --from-backup weekly-full-20260119020000 \
     --include-namespaces forgejo
   ```
6. **Verify FluxCD syncs** remaining applications

### Single Volume Recovery (Longhorn)

1. Go to Longhorn UI → Backup
2. Find the backup for your volume
3. Click "Create PV/PVC"
4. Update your deployment to use restored PVC

### Single Namespace Recovery (Velero)

```bash
# Restore specific namespace from latest backup
velero restore create media-restore \
  --from-backup daily-apps-20260120030000 \
  --include-namespaces media

# Check restore progress
velero restore describe media-restore
```

---

## Best Practices

1. **Test restores regularly** (monthly)
2. **Keep multiple backup generations** (7 daily, 4 weekly)
3. **Store Age key securely** outside the cluster
4. **Monitor backup status** via `velero backup get`
5. **Offsite backup** - MinIO data stored on NAS provides offsite from cluster
6. **Verify Velero status** after cluster changes: `velero status`

---

**Last Updated:** 2026-01-20
