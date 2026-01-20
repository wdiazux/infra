# Longhorn Storage

Distributed block storage with snapshots, backups, and web UI.

**Related:** [NFS Storage](nfs-storage.md) for shared media files

---

## Overview

Longhorn is installed **automatically** via Terraform Helm release. Manual installation is not required.

**What's Automatic:**
- Longhorn deployment
- Storage classes creation
- NFS backup target configuration (if enabled)
- Longhorn UI LoadBalancer

**Configuration Files:**
- Helm values: `kubernetes/infrastructure/values/longhorn-values.yaml`
- Storage classes: `kubernetes/infrastructure/configs/longhorn-storage-classes.yaml`
- Terraform: `terraform/talos/addons.tf`

---

## Key Features

| Feature | Description |
|---------|-------------|
| Distributed Storage | Block storage with replication |
| Snapshots | Point-in-time volume snapshots |
| Backups | NFS backup to external NAS (10.10.2.5) |
| Web UI | Visual storage management |
| Expansion | Resize volumes online |

---

## Service URLs

| Service | URL |
|---------|-----|
| Longhorn UI | http://10.10.2.12 |

---

## Storage Classes

| Class | Use Case | Reclaim | Filesystem |
|-------|----------|---------|------------|
| `longhorn` | Default, general purpose | Delete | ext4 |
| `longhorn-retain` | Critical data | Retain | ext4 |
| `longhorn-fast` | High IOPS, databases | Delete | ext4 |
| `longhorn-xfs` | Large files, media | Delete | xfs |
| `longhorn-backup` | Auto-backup enabled | Retain | ext4 |

---

## Application Config Storage

Longhorn is used for **application configuration volumes** (databases, metadata, settings) because SQLite and other databases do NOT work on NFS.

### arr-stack Namespace

| Application | PVC Name | Size | Purpose |
|-------------|----------|------|---------|
| SABnzbd | `sabnzbd-config` | 256Mi | Usenet downloader settings |
| qBittorrent | `qbittorrent-config` | 256Mi | Torrent client settings |
| Prowlarr | `prowlarr-config` | 256Mi | Indexer manager database |
| Radarr | `radarr-config` | 512Mi | Movie manager database |
| Sonarr | `sonarr-config` | 512Mi | TV series manager database |
| Bazarr | `bazarr-config` | 256Mi | Subtitle manager database |

**Config:** `kubernetes/apps/base/arr-stack/storage.yaml`

### media Namespace

| Application | PVC Name | Size | Purpose |
|-------------|----------|------|---------|
| Emby | `emby-config` | 10Gi | Media server database, thumbnails |
| Navidrome | `navidrome-config` | 1Gi | Music streaming database |

**Config:** `kubernetes/apps/base/media/storage.yaml`

### Why Block Storage for Configs?

SQLite (used by all arr-stack and media apps) requires:
- File locking support (NFS has poor locking)
- POSIX-compliant filesystem
- Low-latency access

Longhorn provides block-level storage that meets these requirements.

---

## Volume Operations

### Create Volume

**Option 1: Via PVC (Recommended)**

Create a PersistentVolumeClaim and Longhorn automatically provisions the volume:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
  namespace: my-namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn          # Or longhorn-retain, longhorn-fast, etc.
  resources:
    requests:
      storage: 10Gi
```

Apply it:
```bash
kubectl apply -f my-pvc.yaml

# Verify
kubectl get pvc -n my-namespace
kubectl get volumes.longhorn.io -n longhorn-system
```

**Option 2: Via Longhorn UI**

1. Go to http://10.10.2.12
2. Volume → Create Volume
3. Set name, size, replicas (1 for single-node)
4. Create PV/PVC from the volume

**Option 3: Via kubectl (Direct Volume)**

```bash
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: my-volume
spec:
  size: "10737418240"        # Size in bytes (10Gi)
  numberOfReplicas: 1
  dataLocality: best-effort
  accessMode: rwo
EOF
```

### Mount in Pod

```yaml
spec:
  containers:
    - name: app
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-data
```

---

### Resize Volume (Expand)

Longhorn supports **online volume expansion** - no need to stop the pod.

**Prerequisites:**
- StorageClass must have `allowVolumeExpansion: true` (all Longhorn classes do)
- Can only **increase** size, not shrink

**Option 1: Edit PVC (Recommended)**

```bash
# Check current size
kubectl get pvc my-data -n my-namespace

# Edit and change spec.resources.requests.storage
kubectl edit pvc my-data -n my-namespace
```

Or patch directly:
```bash
kubectl patch pvc my-data -n my-namespace -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

**Option 2: Via Longhorn UI**

1. Go to http://10.10.2.12
2. Volume → Select volume
3. Click "Expand Volume"
4. Enter new size → Expand

**Option 3: Via kubectl**

```bash
# Get volume name from PVC
VOLUME=$(kubectl get pvc my-data -n my-namespace -o jsonpath='{.spec.volumeName}')

# Expand the Longhorn volume
kubectl -n longhorn-system patch volume $VOLUME --type merge -p '{"spec":{"size":"21474836480"}}'  # 20Gi in bytes
```

**Verify expansion:**
```bash
# Check PVC status (should show new size)
kubectl get pvc my-data -n my-namespace

# Check volume in Longhorn
kubectl get volumes.longhorn.io -n longhorn-system

# Verify filesystem inside pod
kubectl exec -n my-namespace deploy/my-app -- df -h /data
```

**Troubleshooting expansion:**
```bash
# If PVC shows "FileSystemResizePending"
kubectl describe pvc my-data -n my-namespace

# Pod may need restart to pick up filesystem resize
kubectl rollout restart deployment/my-app -n my-namespace
```

---

### Delete Volume

**Warning:** Deleting volumes is permanent. Always backup first!

**Option 1: Delete PVC (Recommended)**

```bash
# Check reclaim policy first
kubectl get pvc my-data -n my-namespace -o jsonpath='{.spec.storageClassName}'
kubectl get storageclass longhorn -o jsonpath='{.reclaimPolicy}'
# "Delete" = volume deleted with PVC
# "Retain" = volume kept after PVC deletion

# Scale down workloads using the PVC first
kubectl scale deployment my-app --replicas=0 -n my-namespace

# Delete the PVC
kubectl delete pvc my-data -n my-namespace

# Verify volume is gone (if reclaimPolicy=Delete)
kubectl get volumes.longhorn.io -n longhorn-system | grep my-data
```

**Option 2: Via Longhorn UI**

1. Go to http://10.10.2.12
2. Volume → Select volume
3. Detach volume (if attached)
4. Delete volume

**Option 3: Delete orphaned/retained volumes**

For volumes with `Retain` policy that still exist after PVC deletion:

```bash
# List all Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Find orphaned volumes (no associated PVC)
kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.kubernetesStatus.pvcName}{"\n"}{end}'

# Delete specific volume
kubectl delete volume.longhorn.io <volume-name> -n longhorn-system
```

**Force delete stuck volume:**
```bash
# Remove finalizers if volume is stuck
kubectl patch volume.longhorn.io <volume-name> -n longhorn-system \
  --type=merge -p '{"metadata":{"finalizers":null}}'

# Then delete
kubectl delete volume.longhorn.io <volume-name> -n longhorn-system
```

---

### List and Inspect Volumes

```bash
# List all PVCs across cluster
kubectl get pvc -A

# List all Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Detailed volume info
kubectl describe volume.longhorn.io <volume-name> -n longhorn-system

# Volume status summary
kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
STATE:.status.state,\
SIZE:.spec.size,\
NODE:.status.currentNodeID,\
ROBUSTNESS:.status.robustness

# Check volume health via Longhorn UI
# http://10.10.2.12 → Volume → Select volume
```

---

### Snapshot Operations

**Create snapshot:**
```bash
# Via kubectl
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Snapshot
metadata:
  name: my-snap-$(date +%Y%m%d-%H%M)
spec:
  volume: <volume-name>
EOF

# Via Longhorn UI: Volume → Take Snapshot
```

**List snapshots:**
```bash
kubectl get snapshots.longhorn.io -n longhorn-system
```

**Delete snapshot:**
```bash
kubectl delete snapshot.longhorn.io <snapshot-name> -n longhorn-system
```

**Restore from snapshot:**
1. Longhorn UI → Volume → Select volume
2. Find snapshot in timeline
3. Click "Revert" to restore volume to that point
   - **Warning:** This overwrites current data!

---

## NFS Backup

### Verify Backup Target

```bash
kubectl get backuptarget -n longhorn-system -o yaml
# Should show: available: true
```

### Manual Backup

Via Longhorn UI:
1. Go to Volume
2. Select volume → Take Snapshot
3. Click "Backup" on snapshot

Via kubectl:
```bash
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: backup-$(date +%Y%m%d)
spec:
  snapshotName: snap-manual
EOF
```

### Recurring Backup

Configure in Longhorn UI:
1. Go to Recurring Job
2. Create new job:
   - Name: `daily-backup`
   - Task: Backup
   - Schedule: `0 2 * * *` (2 AM daily)
   - Retain: 7

---

## Verification

```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system

# Check node status
kubectl get nodes.longhorn.io -n longhorn-system

# Check volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check storage classes
kubectl get storageclass
```

---

## Single-Node Mode

With a single Talos node, Longhorn runs with:
- **Replicas:** 1 (no redundancy)
- **Data Locality:** Best-effort

When expanding to 3 nodes:
1. Change default replica count to 3
2. Existing volumes can be expanded to 3 replicas
3. Use `longhorn-ha` storage class for new volumes

---

## Troubleshooting

For detailed troubleshooting, see [Troubleshooting Guide](../operations/troubleshooting.md#storage-issues).

### Quick Reference

```bash
# Check PVC status
kubectl get pvc

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Check instance manager
kubectl get pods -n longhorn-system -l app=longhorn-instance-manager

# Check backup target status
kubectl get backuptarget -n longhorn-system -o yaml
```

---

## Best Practices

1. **Keep 25-30% disk space free** for operations
2. **Regular backups** to external NAS
3. **Monitor volume health** via UI
4. **Use `longhorn-retain`** for important data
5. **Plan for 3-node expansion** for production

---

## Resources

- [Longhorn Documentation](https://longhorn.io/)
- [Talos Longhorn Guide](https://www.talos.dev/v1.12/kubernetes-guides/configuration/deploy-longhorn/)
- [Longhorn Troubleshooting](https://longhorn.io/docs/1.10.1/troubleshoot/)

---

**Last Updated:** 2026-01-20
