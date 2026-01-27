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

---

## Manual Backup Operations (kubectl)

If the `velero` CLI is not installed, use `kubectl` to create and manage backups directly.

### Quick Reference

| Namespace | Services | Has Volumes | Recommended TTL |
|-----------|----------|-------------|-----------------|
| ai | Ollama, Open WebUI, ComfyUI | Yes | 7d |
| arr-stack | Radarr, Sonarr, Prowlarr, Bazarr, qBittorrent, SABnzbd | Yes | 7d |
| automation | Home Assistant, n8n, PostgreSQL | Yes | 7d |
| forgejo | Forgejo, PostgreSQL | Yes | 14d |
| management | Paperless-ngx, Wallos | Yes | 7d |
| media | Emby, Navidrome, Immich | Yes | 7d |
| monitoring | Grafana, VictoriaMetrics, vmagent | Yes | 3d |
| printing | Obico | Yes | 7d |
| tools | Homepage, ntfy, IT-Tools, Attic | Yes | 7d |

### Check Backup Infrastructure Status

```bash
# Verify backup storage location is available
kubectl get backupstoragelocations -n backup
# Should show: PHASE=Available

# Check volume snapshot location
kubectl get volumesnapshotlocations -n backup

# Verify node-agent is running (required for volume backups)
kubectl get pods -n backup -l name=node-agent
```

### Create Manual Backup - Single Namespace

```bash
# Basic backup of a single namespace
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-forgejo-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  includedNamespaces:
    - forgejo
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 168h  # 7 days
EOF
```

### Create Manual Backup - Multiple Namespaces

```bash
# Backup multiple namespaces at once
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-apps-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  includedNamespaces:
    - ai
    - arr-stack
    - automation
    - forgejo
    - management
    - media
    - printing
    - tools
  excludedResources:
    - events
    - pods
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 168h  # 7 days
EOF
```

### Create Manual Backup - All Application Namespaces

```bash
# Full backup of all application namespaces (mirrors weekly-full schedule)
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-full-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  includedNamespaces:
    - ai
    - arr-stack
    - automation
    - backup
    - forgejo
    - management
    - media
    - monitoring
    - printing
    - tools
  excludedResources:
    - events
    - pods
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 672h  # 28 days
EOF
```

### Namespace-Specific Backup Examples

**AI Namespace** (Ollama models, Open WebUI configs):
```bash
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: backup-ai-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  includedNamespaces:
    - ai
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 168h
EOF
```

**Media Namespace** (Immich photos, Emby/Navidrome metadata):
```bash
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: backup-media-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  includedNamespaces:
    - media
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 168h
EOF
```

**Automation Namespace** (Home Assistant, n8n workflows):
```bash
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: backup-automation-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  includedNamespaces:
    - automation
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 168h
EOF
```

### Monitor Backup Progress

```bash
# List all Velero backups (use full API group to avoid Longhorn conflict)
kubectl get backup.velero.io -n backup

# Watch backup status in real-time
kubectl get backup.velero.io -n backup -w

# Get detailed backup status
kubectl get backup.velero.io -n backup <backup-name> -o yaml | grep -A20 "status:"

# Check backup phase (New, InProgress, Completed, PartiallyFailed, Failed)
kubectl get backup.velero.io -n backup <backup-name> -o jsonpath='{.status.phase}'

# View items backed up
kubectl get backup.velero.io -n backup <backup-name> \
  -o jsonpath='{.status.progress.itemsBackedUp}/{.status.progress.totalItems}'
```

### Check Backup Errors and Warnings

```bash
# Describe backup for errors/warnings
kubectl describe backup.velero.io -n backup <backup-name>

# Check Velero controller logs
kubectl logs -n backup deploy/velero --tail=100 | grep -i "error\|warning"

# Check specific backup in logs
kubectl logs -n backup deploy/velero --tail=200 | grep "<backup-name>"
```

### Verify Backup Data in MinIO

```bash
# List backups stored in MinIO
kubectl exec -n backup deploy/minio -- ls -la /data/velero/backups/

# Check specific backup contents
kubectl exec -n backup deploy/minio -- ls -la /data/velero/backups/<backup-name>/

# Check backup size
kubectl exec -n backup deploy/minio -- du -sh /data/velero/backups/<backup-name>/
```

### Delete Old Backups

```bash
# Delete a specific backup
kubectl delete backup.velero.io -n backup <backup-name>

# Delete all backups older than 7 days (be careful!)
kubectl get backup.velero.io -n backup -o name | while read backup; do
  age=$(kubectl get $backup -n backup -o jsonpath='{.metadata.creationTimestamp}')
  echo "Backup: $backup, Created: $age"
done
```

### Restore from Manual Backup

```bash
# Create restore from backup
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  backupName: <backup-name>
  includedNamespaces:
    - forgejo  # Or '*' for all namespaces in backup
  restorePVs: true
EOF

# Monitor restore progress
kubectl get restore.velero.io -n backup -w

# Check restore status
kubectl describe restore.velero.io -n backup <restore-name>
```

### Pre-Upgrade Backup Script

Before major upgrades, create a full backup:

```bash
#!/bin/bash
# pre-upgrade-backup.sh
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="pre-upgrade-${TIMESTAMP}"

echo "Creating pre-upgrade backup: ${BACKUP_NAME}"

kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ${BACKUP_NAME}
  namespace: backup
  labels:
    backup-type: pre-upgrade
spec:
  includedNamespaces:
    - ai
    - arr-stack
    - automation
    - backup
    - forgejo
    - management
    - media
    - monitoring
    - printing
    - tools
  excludedResources:
    - events
    - pods
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 720h  # 30 days
EOF

echo "Waiting for backup to complete..."
while true; do
  PHASE=$(kubectl get backup.velero.io -n backup ${BACKUP_NAME} -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "Current phase: ${PHASE}"
  if [[ "$PHASE" == "Completed" ]] || [[ "$PHASE" == "PartiallyFailed" ]]; then
    break
  fi
  if [[ "$PHASE" == "Failed" ]]; then
    echo "Backup failed!"
    exit 1
  fi
  sleep 10
done

echo "Backup completed: ${BACKUP_NAME}"
kubectl get backup.velero.io -n backup ${BACKUP_NAME}
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

## Backup Verification & Testing

**Critical Principle**: "Backups without verification are Schrödinger's backups - simultaneously working and broken until tested."

### Monthly Backup Verification Procedure

Run this procedure on the **first Sunday of each month** to verify backup integrity.

```bash
#!/bin/bash
# monthly-backup-test.sh
# Verifies latest backup can be restored successfully

set -e

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_NAMESPACE="backup-test"

echo "============================================"
echo "Monthly Backup Verification - ${TIMESTAMP}"
echo "============================================"

# 1. Find latest successful backup
echo "Step 1: Finding latest backup..."
LATEST_BACKUP=$(kubectl get backup.velero.io -n backup \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1].metadata.name}')

if [ -z "$LATEST_BACKUP" ]; then
  echo "ERROR: No backups found!"
  exit 1
fi

echo "Latest backup: $LATEST_BACKUP"

# 2. Check backup status
BACKUP_PHASE=$(kubectl get backup.velero.io -n backup "$LATEST_BACKUP" \
  -o jsonpath='{.status.phase}')

if [ "$BACKUP_PHASE" != "Completed" ]; then
  echo "ERROR: Latest backup is not completed (phase: $BACKUP_PHASE)"
  exit 1
fi

echo "Backup status: $BACKUP_PHASE ✓"

# 3. Create test namespace
echo "Step 2: Creating test namespace..."
kubectl create namespace "$TEST_NAMESPACE" 2>/dev/null || true

# 4. Perform test restore (media namespace as example)
echo "Step 3: Performing test restore..."
cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: test-restore-${TIMESTAMP}
  namespace: backup
spec:
  backupName: ${LATEST_BACKUP}
  includedNamespaces:
    - media
  namespaceMapping:
    media: ${TEST_NAMESPACE}
  restorePVs: true
EOF

# 5. Wait for restore to complete
echo "Step 4: Waiting for restore to complete..."
TIMEOUT=300  # 5 minutes
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  RESTORE_PHASE=$(kubectl get restore.velero.io -n backup "test-restore-${TIMESTAMP}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

  echo "Current restore phase: $RESTORE_PHASE"

  if [ "$RESTORE_PHASE" == "Completed" ]; then
    echo "Restore completed successfully! ✓"
    break
  elif [ "$RESTORE_PHASE" == "PartiallyFailed" ]; then
    echo "WARNING: Restore partially failed"
    kubectl describe restore.velero.io -n backup "test-restore-${TIMESTAMP}"
    break
  elif [ "$RESTORE_PHASE" == "Failed" ]; then
    echo "ERROR: Restore failed!"
    kubectl describe restore.velero.io -n backup "test-restore-${TIMESTAMP}"
    exit 1
  fi

  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
  echo "ERROR: Restore timed out after ${TIMEOUT} seconds"
  exit 1
fi

# 6. Verify restored resources
echo "Step 5: Verifying restored resources..."
RESTORED_PODS=$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
RESTORED_PVCS=$(kubectl get pvc -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)

echo "Restored pods: $RESTORED_PODS"
echo "Restored PVCs: $RESTORED_PVCS"

if [ $RESTORED_PODS -eq 0 ] && [ $RESTORED_PVCS -eq 0 ]; then
  echo "WARNING: No resources restored (may indicate empty namespace or backup issue)"
fi

# 7. Check PVC status
echo "Step 6: Checking PVC status..."
kubectl get pvc -n "$TEST_NAMESPACE"

# 8. Cleanup test resources
echo "Step 7: Cleaning up test namespace..."
kubectl delete namespace "$TEST_NAMESPACE" --wait=false

# 9. Summary
echo "============================================"
echo "Backup Verification Summary"
echo "============================================"
echo "Backup Name: $LATEST_BACKUP"
echo "Backup Phase: $BACKUP_PHASE"
echo "Restore Phase: $RESTORE_PHASE"
echo "Restored Pods: $RESTORED_PODS"
echo "Restored PVCs: $RESTORED_PVCS"
echo "Status: SUCCESS ✓"
echo "============================================"
echo ""
echo "Next verification: $(date -d 'next month' +%Y-%m-01)"
echo ""
echo "Cleanup: Test namespace will be deleted in background"
echo "============================================"
```

**Usage**:
```bash
# Run monthly verification
chmod +x monthly-backup-test.sh
./monthly-backup-test.sh

# Or manual verification
./monthly-backup-test.sh 2>&1 | tee backup-verification-$(date +%Y%m).log
```

---

### Quick Verification Commands

For ad-hoc backup verification without full restore:

```bash
# 1. Check recent backups exist
velero backup get | head -10
# Should show daily and weekly backups

# 2. Verify backup completeness
LATEST=$(velero backup get -o json | jq -r '.[0].name')
velero backup describe $LATEST --details
# Check: Phase=Completed, Errors=0, Warnings=0

# 3. Verify backup data in MinIO
kubectl exec -n backup deploy/minio -- ls -lh /data/velero/backups/ | tail -10
# Should show recent backup directories

# 4. Check volume snapshots
kubectl get volumesnapshots -A | grep -v "<none>"
# Should show recent Longhorn snapshots

# 5. Verify backup storage location
kubectl get backupstoragelocations -n backup -o wide
# Should show: PHASE=Available, ACCESS MODE=ReadWrite
```

---

### Automated Backup Verification (CronJob)

Deploy a monthly CronJob to automate verification and send alerts:

```yaml
# Save as: kubernetes/apps/base/backup/backup-verification-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-verification
  namespace: backup
  labels:
    app.kubernetes.io/name: backup-verification
    app.kubernetes.io/part-of: backup
spec:
  schedule: "0 4 1 * *"  # 4 AM on 1st of month
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        metadata:
          labels:
            app.kubernetes.io/name: backup-verification
        spec:
          serviceAccountName: velero
          restartPolicy: OnFailure
          containers:
            - name: verify
              image: bitnami/kubectl:latest
              command:
                - /bin/bash
                - -c
                - |
                  set -e
                  echo "Starting automated backup verification..."

                  # Find latest backup
                  LATEST=$(kubectl get backup.velero.io -n backup \
                    --sort-by=.metadata.creationTimestamp \
                    -o jsonpath='{.items[-1].metadata.name}')

                  echo "Latest backup: $LATEST"

                  # Check backup status
                  PHASE=$(kubectl get backup.velero.io -n backup "$LATEST" \
                    -o jsonpath='{.status.phase}')

                  if [ "$PHASE" != "Completed" ]; then
                    echo "ERROR: Backup $LATEST not completed (phase: $PHASE)"
                    # Send alert via ntfy
                    curl -d "Velero backup verification FAILED: $LATEST is $PHASE" \
                      http://ntfy.tools.svc.cluster.local/homelab-alerts || true
                    exit 1
                  fi

                  # Verify backup has items
                  ITEMS=$(kubectl get backup.velero.io -n backup "$LATEST" \
                    -o jsonpath='{.status.progress.itemsBackedUp}')

                  if [ "$ITEMS" -eq 0 ]; then
                    echo "WARNING: Backup $LATEST has 0 items"
                    curl -d "Velero backup verification WARNING: $LATEST has no items" \
                      http://ntfy.tools.svc.cluster.local/homelab-alerts || true
                  fi

                  echo "Backup $LATEST verified: $ITEMS items backed up ✓"

                  # Success notification
                  curl -d "Velero backup verification SUCCESS: $LATEST ($ITEMS items)" \
                    http://ntfy.tools.svc.cluster.local/homelab-alerts || true
              env:
                - name: KUBECONFIG
                  value: /var/run/secrets/kubernetes.io/serviceaccount/token
```

**Deploy**:
```bash
kubectl apply -f kubernetes/apps/base/backup/backup-verification-cronjob.yaml

# Test immediately
kubectl create job -n backup test-verify --from=cronjob/backup-verification

# Check logs
kubectl logs -n backup job/test-verify
```

---

### Disaster Recovery Drill (Quarterly)

Perform a **full cluster recovery drill** every 3 months:

#### Preparation

```bash
# 1. Document current cluster state
kubectl get nodes -o wide > cluster-state-before.txt
kubectl get pods -A -o wide >> cluster-state-before.txt
kubectl get pvc -A >> cluster-state-before.txt

# 2. Ensure recent full backup exists
velero backup get | grep weekly-full | head -1

# 3. Back up Terraform state
cp terraform/talos/terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)

# 4. Back up kubeconfig and talosconfig
cp terraform/talos/kubeconfig ~/kubeconfig.backup.$(date +%Y%m%d)
cp terraform/talos/talosconfig ~/talosconfig.backup.$(date +%Y%m%d)
```

#### Recovery Drill (Destructive - Only in Maintenance Window)

```bash
# WARNING: This destroys the cluster!
# Only run during scheduled maintenance

# 1. Destroy cluster
cd terraform/talos
terraform destroy -auto-approve

# 2. Rebuild cluster
terraform apply -auto-approve

# 3. Wait for FluxCD to sync infrastructure
watch kubectl get pods -A

# 4. Install Velero (if not auto-deployed via Flux)
flux reconcile kustomization infrastructure-controllers --with-source

# 5. Restore from latest weekly backup
LATEST_WEEKLY=$(velero backup get | grep weekly-full | head -1 | awk '{print $1}')
velero restore create dr-drill-restore --from-backup $LATEST_WEEKLY

# 6. Wait for restore
watch velero restore get

# 7. Verify cluster state
kubectl get pods -A -o wide > cluster-state-after.txt
diff cluster-state-before.txt cluster-state-after.txt

# 8. Test critical services
curl http://10.10.2.22  # Immich
curl http://10.10.2.13  # Forgejo
kubectl -n ai exec deploy/ollama -- ollama list
```

#### Recovery Time Objective (RTO) Tracking

| Phase | Target Time | Last Drill | Notes |
|-------|-------------|------------|-------|
| 1. Terraform destroy | 5 minutes | - | Fast |
| 2. Terraform apply (VM creation) | 10 minutes | - | Proxmox VM creation |
| 3. Talos bootstrap | 5 minutes | - | Kubernetes API ready |
| 4. FluxCD infrastructure sync | 15 minutes | - | CNI, storage, Velero |
| 5. Velero restore initiation | 2 minutes | - | Create restore CR |
| 6. Volume data restoration | 60 minutes | - | Depends on backup size |
| 7. Application pod startup | 10 minutes | - | All apps running |
| **Total RTO** | **~2 hours** | - | Acceptable for homelab |

---

### Backup Integrity Checks

Verify backup data hasn't been corrupted:

```bash
# 1. Check MinIO data integrity
kubectl exec -n backup deploy/minio -- sh -c '
  mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  mc admin heal local/velero --recursive --verbose
'

# 2. List backup contents
BACKUP_NAME="daily-apps-20260122030000"
kubectl exec -n backup deploy/minio -- \
  ls -R /data/velero/backups/$BACKUP_NAME/

# 3. Check for incomplete backups
kubectl get backup.velero.io -n backup \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' | \
  grep -v Completed

# 4. Verify NAS backup target accessible
kubectl exec -n backup deploy/minio -- df -h /data
# Should show NFS mount with available space
```

---

## Related Guides

- [Upgrade Rollback](upgrade-rollback.md) — Step-by-step procedures for rolling back after a bad service upgrade (database migration failures, broken versions)

---

## Best Practices

1. **Test restores regularly** (monthly) - Use automated verification script
2. **Keep multiple backup generations** (7 daily, 4 weekly)
3. **Store Age key securely** outside the cluster
4. **Monitor backup status** via `velero backup get`
5. **Offsite backup** - MinIO data stored on NAS provides offsite from cluster
6. **Verify Velero status** after cluster changes: `velero status`
7. **Document RTO** - Track recovery time during drills
8. **Alert on failures** - Use ntfy for backup failure notifications

---

**Last Updated:** 2026-01-22 | Added backup verification procedures and disaster recovery drill
