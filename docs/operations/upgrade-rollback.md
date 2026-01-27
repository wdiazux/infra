# Upgrade Rollback

How to recover when a service upgrade breaks things — especially when a database migration has already run.

---

## When to Use This Guide

Use this when **all three** conditions are true:

1. A service was upgraded to a new version (manually or via FluxCD image automation)
2. The new version modified the database schema (migration ran on startup)
3. The service is broken and you need to go back to the previous working version

**Key insight:** You cannot simply downgrade the container image — the database schema has already changed. You must restore the volume data to a pre-upgrade state.

---

## Quick Reference

| Service Type | Database | Recovery Method | Downtime |
|-------------|----------|-----------------|----------|
| Immich, Forgejo, n8n, Paperless, Attic, Affine | PostgreSQL | Velero restore or Longhorn snapshot revert | Minutes |
| Zitadel | PostgreSQL (CockroachDB-compatible) | Velero restore or Longhorn snapshot revert | Minutes |
| Radarr, Sonarr, Prowlarr, Bazarr | SQLite | Velero restore or Longhorn snapshot revert | Seconds |
| SABnzbd, qBittorrent | SQLite (config) | Velero restore or Longhorn snapshot revert | Seconds |
| Home Assistant | SQLite | Velero restore or Longhorn snapshot revert | Seconds |
| Open WebUI | SQLite | Velero restore or Longhorn snapshot revert | Seconds |
| Emby, Navidrome | SQLite (metadata) | Velero restore or Longhorn snapshot revert | Seconds |

### Decision: Longhorn Snapshot vs. Velero Restore

| Method | Use When | Pros | Cons |
|--------|----------|------|------|
| **Longhorn snapshot revert** | Upgrade just happened, snapshot exists | Instant, no data movement | Only if a recent snapshot exists; UI-based |
| **Velero restore** | Need to go back to a scheduled backup | Restores both K8s resources and volumes | Slower (data copied from MinIO) |
| **Manual pg_dump restore** | Have a SQL dump, need surgical recovery | Can restore to any PG instance | Manual, requires dump to exist |

---

## Pre-Upgrade Checklist

Run **before** upgrading any stateful service. This ensures you have a clean restore point.

```bash
# 1. Note the current image tag (you'll need this to pin the old version)
kubectl get deploy,statefulset -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# 2. Create a manual Velero backup of the namespace
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: pre-upgrade-<service>-$(date +%Y%m%d-%H%M%S)
  namespace: backup
  labels:
    backup-type: pre-upgrade
spec:
  includedNamespaces:
    - <namespace>
  storageLocation: default
  volumeSnapshotLocations:
    - longhorn
  snapshotMoveData: true
  ttl: 720h  # 30 days
EOF

# 3. Wait for backup to complete
kubectl get backup.velero.io -n backup -w

# 4. For PostgreSQL services — also take a logical dump
kubectl exec -n <namespace> <postgres-pod> -- \
  pg_dump -U <user> <database> | gzip > <service>-pre-upgrade-$(date +%Y%m%d).sql.gz
```

### PostgreSQL Services Reference

| Namespace | Pod | User | Database |
|-----------|-----|------|----------|
| forgejo | `deploy/forgejo-postgresql` | forgejo | forgejo |
| automation | `sts/n8n-postgres` | n8n | n8n |
| media | `sts/immich-postgres` | postgres | immich |
| management | `sts/paperless-postgres` | paperless | paperless |
| tools | `sts/attic-db` | attic | attic |
| tools | `sts/affine-postgres` | affine | affine |
| auth | `sts/zitadel-postgres` | zitadel | zitadel |

---

## Rollback Procedure: PostgreSQL Services

Use this for: Immich, Forgejo, n8n, Paperless, Attic, Affine, Zitadel.

### Step 1: Suspend FluxCD Image Automation

Prevent FluxCD from re-upgrading the service while you work.

```bash
# Suspend the image automation (stops all automatic image updates)
flux suspend image update image-updates

# Verify it's suspended
flux get image update
# Should show: SUSPENDED=True
```

### Step 2: Pin the Old Image Version

Edit the deployment manifest to use the previous working version.

```bash
# Find the previous image tag from git history
git log --oneline --all -- kubernetes/apps/base/<namespace>/<service>/ | head -5

# Check the diff to find the old tag
git diff <commit>^ <commit> -- kubernetes/apps/base/<namespace>/<service>/
```

Edit the manifest file and change the image tag back to the old version. The `$imagepolicy` comment can stay — it's inert while automation is suspended.

```bash
# Example: revert Immich from v2.5.0 to v2.4.1
vim kubernetes/apps/base/media/immich/server-deployment.yaml
# Change: image: ghcr.io/immich-app/immich-server:v2.5.0
# To:     image: ghcr.io/immich-app/immich-server:v2.4.1
```

### Step 3: Scale Down the Service

Stop the application and its database so volumes are not in use.

```bash
NAMESPACE=<namespace>

# Scale down the application first, then the database
kubectl scale deployment -n $NAMESPACE <app-deployment> --replicas=0
kubectl scale statefulset -n $NAMESPACE <postgres-statefulset> --replicas=0

# Wait for pods to terminate
kubectl wait --for=delete pod -n $NAMESPACE -l app.kubernetes.io/part-of=<service> --timeout=120s

# Verify no pods are running
kubectl get pods -n $NAMESPACE
```

### Step 4: Restore the Volume

**Option A: Longhorn Snapshot Revert (fastest)**

1. Open Longhorn UI: https://longhorn.home-infra.net
2. Go to **Volume** tab
3. Find the PostgreSQL volume (match by PVC name from `kubectl get pvc -n <namespace>`)
4. Click the volume → find the snapshot taken **before** the upgrade in the timeline
5. Click **Revert** on that snapshot
6. Confirm — this overwrites the current volume data

**Option B: Velero Restore (from scheduled or manual backup)**

```bash
# List available backups for the namespace
kubectl get backup.velero.io -n backup --sort-by=.metadata.creationTimestamp | grep <namespace-or-service>

# Delete the current PVCs (Velero cannot restore into existing PVCs)
kubectl delete pvc -n $NAMESPACE <postgres-pvc-name>

# Wait for Longhorn to release the volume
sleep 15

# Create the restore
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: rollback-<service>-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  backupName: <backup-name>
  includedNamespaces:
    - $NAMESPACE
  includedResources:
    - persistentvolumeclaims
    - persistentvolumes
  restorePVs: true
EOF

# Monitor restore progress
kubectl get restore.velero.io -n backup -w
```

**Option C: Manual pg_dump Restore (if you have a SQL dump)**

```bash
# Scale up only the database
kubectl scale statefulset -n $NAMESPACE <postgres-statefulset> --replicas=1
kubectl wait --for=condition=ready pod -n $NAMESPACE -l app.kubernetes.io/name=<postgres> --timeout=120s

# Drop and recreate the database
kubectl exec -n $NAMESPACE <postgres-pod> -- psql -U <user> -c "DROP DATABASE <database>;"
kubectl exec -n $NAMESPACE <postgres-pod> -- psql -U <user> -c "CREATE DATABASE <database>;"

# Restore from dump
gunzip -c <service>-pre-upgrade-YYYYMMDD.sql.gz | \
  kubectl exec -i -n $NAMESPACE <postgres-pod> -- psql -U <user> <database>
```

### Step 5: Start the Service with the Old Version

```bash
# Apply the manifest with the old image tag
kubectl apply -k kubernetes/apps/base/<namespace>/<service>/

# Or if you didn't use kustomize, scale back up manually
kubectl scale statefulset -n $NAMESPACE <postgres-statefulset> --replicas=1
kubectl wait --for=condition=ready pod -n $NAMESPACE -l app.kubernetes.io/name=<postgres> --timeout=120s

kubectl scale deployment -n $NAMESPACE <app-deployment> --replicas=1
```

### Step 6: Verify

```bash
# Check pods are running
kubectl get pods -n $NAMESPACE

# Check logs for migration errors
kubectl logs -n $NAMESPACE deploy/<app-deployment> --tail=50

# Test the service (web UI, API, etc.)
curl -s https://<service>.home-infra.net | head -5
```

---

## Rollback Procedure: SQLite Services

Use this for: arr-stack (Radarr, Sonarr, Prowlarr, Bazarr, SABnzbd, qBittorrent), Home Assistant, Open WebUI, Emby, Navidrome.

SQLite services are simpler because the database file is inside the config volume — one volume restore recovers everything.

### Step 1: Suspend FluxCD Image Automation

```bash
flux suspend image update image-updates
```

### Step 2: Pin the Old Image Version

```bash
# Find the old tag
git log --oneline --all -- kubernetes/apps/base/<namespace>/<service>/ | head -5

# Edit the manifest to use the old tag
vim kubernetes/apps/base/<namespace>/<service>/<deployment>.yaml
```

### Step 3: Scale Down

```bash
kubectl scale deployment -n <namespace> <deployment> --replicas=0
kubectl wait --for=delete pod -n <namespace> -l app.kubernetes.io/name=<service> --timeout=60s
```

### Step 4: Restore the Config Volume

**Option A: Longhorn Snapshot Revert**

1. Open Longhorn UI: https://longhorn.home-infra.net
2. Find the config volume (e.g., `radarr-config`, `sonarr-config`)
3. Revert to the pre-upgrade snapshot

**Option B: Velero Restore**

```bash
# Delete existing PVC
kubectl delete pvc -n <namespace> <config-pvc>
sleep 15

# Restore from backup
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: rollback-<service>-$(date +%Y%m%d-%H%M%S)
  namespace: backup
spec:
  backupName: <backup-name>
  includedNamespaces:
    - <namespace>
  includedResources:
    - persistentvolumeclaims
    - persistentvolumes
  restorePVs: true
EOF

kubectl get restore.velero.io -n backup -w
```

### Step 5: Start with Old Version

```bash
kubectl apply -k kubernetes/apps/base/<namespace>/<service>/
```

### Step 6: Verify

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service>
kubectl logs -n <namespace> deploy/<deployment> --tail=30
```

---

## FluxCD Version Pinning

After a rollback, you need to prevent FluxCD from re-upgrading to the broken version.

### Option 1: Keep Automation Suspended (temporary)

Leave automation suspended until the upstream project releases a fix:

```bash
# Check current state
flux get image update

# Automation stays suspended until you resume it
flux resume image update image-updates
```

### Option 2: Constrain the Image Policy (targeted)

Restrict the semver range to exclude the broken version. This allows automation to resume for all other services.

```bash
# Example: Immich v2.5.0 is broken, pin to <2.5.0
vim kubernetes/infrastructure/image-automation/policies/media.yaml
```

Change the policy range:

```yaml
# Before
spec:
  policy:
    semver:
      range: ">=1.0.0 <3.0.0"

# After — excludes v2.5.0+
spec:
  policy:
    semver:
      range: ">=1.0.0 <2.5.0"
```

Then commit, push, and resume automation:

```bash
git add kubernetes/infrastructure/image-automation/policies/
git commit -m "fix: pin <service> below broken version"
git push

flux resume image update image-updates
flux reconcile kustomization flux-system --with-source
```

### Option 3: Suspend a Single Image Policy (targeted)

Suspend only the policy for the broken service:

```bash
# Suspend just the Immich server policy
flux suspend image policy immich-server

# All other image policies continue working
flux resume image update image-updates
```

### Resuming After Fix

When the upstream project releases a fixed version:

```bash
# If you constrained the range, revert it
git revert <commit-hash>
git push

# If you suspended a policy, resume it
flux resume image policy immich-server

# Verify the new version is picked up
flux get image policy immich-server
```

---

## Concrete Examples

### Example: Immich Upgrade Broke Photo Database

Immich upgraded from v2.4.1 to v2.5.0. The PostgreSQL migration failed and the UI shows errors.

```bash
# 1. Suspend automation
flux suspend image update image-updates

# 2. Note the broken and working versions
# Broken: ghcr.io/immich-app/immich-server:v2.5.0
# Working: ghcr.io/immich-app/immich-server:v2.4.1

# 3. Scale down everything in media namespace related to Immich
kubectl scale deployment -n media immich-server --replicas=0
kubectl scale deployment -n media immich-machine-learning --replicas=0
kubectl scale statefulset -n media immich-postgres --replicas=0
kubectl wait --for=delete pod -n media -l app.kubernetes.io/part-of=immich --timeout=120s

# 4. Revert the PostgreSQL volume via Longhorn UI
# - Open https://longhorn.home-infra.net
# - Find the volume for PVC "immich-postgres-data" in namespace "media"
# - Revert to last snapshot before the upgrade

# 5. Edit manifests to pin old version (BOTH server and ML must match)
# In kubernetes/apps/base/media/immich/server-deployment.yaml:
#   image: ghcr.io/immich-app/immich-server:v2.4.1
# In kubernetes/apps/base/media/immich/machine-learning-deployment.yaml:
#   image: ghcr.io/immich-app/immich-machine-learning:v2.4.1-cuda

# 6. Apply and start
kubectl apply -k kubernetes/apps/base/media/immich/

# 7. Verify
kubectl get pods -n media -l app.kubernetes.io/part-of=immich
kubectl logs -n media deploy/immich-server --tail=20

# 8. Pin the image policy
flux suspend image policy immich-server
flux suspend image policy immich-machine-learning
flux resume image update image-updates
```

### Example: Radarr Upgrade Corrupted SQLite Database

Radarr upgraded and the SQLite database schema is incompatible.

```bash
# 1. Suspend automation
flux suspend image update image-updates

# 2. Scale down
kubectl scale deployment -n arr-stack radarr --replicas=0
kubectl wait --for=delete pod -n arr-stack -l app.kubernetes.io/name=radarr --timeout=60s

# 3. Revert the config volume via Longhorn UI
# - Find volume for PVC "radarr-config"
# - Revert to pre-upgrade snapshot

# 4. Pin old version in manifest
# In kubernetes/apps/base/arr-stack/radarr/deployment.yaml:
#   image: ghcr.io/hotio/radarr:zeus-6.0.3.10234

# 5. Apply
kubectl apply -k kubernetes/apps/base/arr-stack/radarr/

# 6. Verify
kubectl get pods -n arr-stack -l app.kubernetes.io/name=radarr
kubectl logs -n arr-stack deploy/radarr --tail=20

# 7. Suspend just the radarr policy, resume everything else
flux suspend image policy radarr
flux resume image update image-updates
```

---

## Preventive Practices

1. **Check release notes** before upgrading services with databases — look for "breaking changes" or "migration" warnings
2. **Use the pre-upgrade checklist** above for any service with PostgreSQL
3. **Velero daily backups** already provide a safety net — but manual pre-upgrade backups give a cleaner restore point
4. **PostgreSQL major version upgrades** (e.g., 16 → 17) require `pg_dump`/`pg_restore` — volume snapshots alone are not sufficient since the on-disk format changes

---

## Related Documentation

- [Backups](backups.md) — Velero schedules, MinIO, backup verification
- [Upgrades](upgrades.md) — Pre-upgrade checklist, component upgrade procedures
- [Service Management](service-management.md) — Scale, delete, recreate services
- [Longhorn Storage](../services/longhorn.md) — Snapshot operations, volume management

---

**Last Updated:** 2026-01-27
