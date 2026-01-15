# Backups

Backup strategies and procedures for the homelab infrastructure.

---

## Overview

| Component | Backup Target | Method | Schedule |
|-----------|---------------|--------|----------|
| Longhorn Volumes | NAS (NFS) | Longhorn Backup | Daily 2 AM |
| Terraform State | Git/Local | Manual | Before changes |
| Talos Config | Local files | Terraform output | Auto |
| Git Repositories | Forgejo | Longhorn volume | Daily |
| Secrets | Git (encrypted) | SOPS | On change |

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

### Full Cluster Recovery

1. **Ensure NAS is accessible** with backup data
2. **Deploy new cluster:**
   ```bash
   terraform destroy  # If needed
   terraform apply
   ```
3. **Restore critical volumes** from Longhorn backups
4. **Restore Git repositories** if Forgejo data lost
5. **Verify FluxCD syncs** applications

### Single Volume Recovery

1. Go to Longhorn UI → Backup
2. Find the backup for your volume
3. Click "Create PV/PVC"
4. Update your deployment to use restored PVC

---

## Best Practices

1. **Test restores regularly** (monthly)
2. **Keep multiple backup generations** (7 daily, 4 weekly)
3. **Store Age key securely** outside the cluster
4. **Monitor backup status** in Longhorn UI
5. **Offsite backup** copy critical data externally

---

**Last Updated:** 2026-01-15
