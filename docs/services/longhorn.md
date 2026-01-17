# Longhorn Storage

Distributed block storage with snapshots, backups, and web UI.

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

## Using Storage

### Create PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-default
  resources:
    requests:
      storage: 10Gi
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

### Pods Stuck in Pending

```bash
# Check PVC status
kubectl get pvc

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Verify kernel modules
talosctl -n 10.10.2.10 read /proc/modules | grep -E 'iscsi|nbd'
```

### Volumes Stuck in Attaching

```bash
# Check instance manager
kubectl get pods -n longhorn-system -l app=longhorn-instance-manager

# Restart instance manager
kubectl delete pod -n longhorn-system -l app=longhorn-instance-manager

# Check kubelet mounts
talosctl -n 10.10.2.10 get machineconfig -o yaml | grep -A 5 extraMounts
```

### Backup Target Unavailable

```bash
# Check backup target status
kubectl get backuptarget -n longhorn-system -o yaml

# Verify NAS is reachable
talosctl -n 10.10.2.10 ping 10.10.2.5

# Check backup secret
kubectl get secret longhorn-backup-secret -n longhorn-system
```

### No Space Left

```bash
# Check node disk usage
kubectl get nodes.longhorn.io -n longhorn-system -o yaml

# Access UI to manage volumes
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Delete unused volumes/snapshots
kubectl get volumes.longhorn.io -n longhorn-system
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

# NFS Media Storage

External NAS storage for large media files shared across namespaces.

---

## Overview

NFS storage from the external NAS (10.10.2.5) provides shared storage for media files and downloads. Unlike Longhorn (block storage for databases), NFS is ideal for large files that need to be accessed by multiple applications.

**Configuration:** `kubernetes/infrastructure/storage/`

---

## NFS Shares

| Share | NAS Path | Size | Purpose |
|-------|----------|------|---------|
| Media | `/mnt/tank/media` | 1Ti | Movies, TV series, music, videos |
| Downloads | `/mnt/downloads` | 500Gi | Usenet/torrent download staging |

### Media Directory Structure

```
/mnt/tank/media/
├── movies/       # Radarr target, Emby movies library
├── tvseries/     # Sonarr target, Emby TV library
├── music/        # Future Lidarr target, Navidrome library
└── videos/       # General videos, Emby videos library
```

### Downloads Directory Structure

```
/mnt/downloads/
├── usenet/
│   ├── complete/{tv,movies,music,prowlarr,anime,software,audio}
│   └── incomplete/
└── torrents/
```

---

## Cross-Namespace Access Pattern

**Problem:** Kubernetes PersistentVolumes can only bind to ONE PersistentVolumeClaim. Both `arr-stack` and `media` namespaces need access to the same NFS media share.

**Solution:** Create duplicate PVs pointing to the same NFS path, one for each namespace.

### PV/PVC Architecture

```
NAS (10.10.2.5:/mnt/tank/media)
         │
         ├──► PV: nfs-media ──────► PVC: nfs-media (arr-stack namespace)
         │                                  │
         │                                  └──► radarr, sonarr, bazarr
         │
         └──► PV: nfs-media-media ──► PVC: nfs-media (media namespace)
                                            │
                                            └──► emby, navidrome
```

### Configuration Files

| File | Purpose |
|------|---------|
| `nfs-media-pv.yaml` | PV for arr-stack namespace |
| `nfs-media-pvc.yaml` | PVC in arr-stack namespace |
| `nfs-media-pv-media.yaml` | Duplicate PV for media namespace |
| `nfs-media-pvc-media.yaml` | PVC in media namespace |
| `nfs-downloads-pv.yaml` | Downloads PV (arr-stack only) |
| `nfs-downloads-pvc.yaml` | Downloads PVC in arr-stack |

---

## How Applications Mount Storage

### arr-stack (Radarr example)

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: radarr-config    # Longhorn - SQLite database
  - name: media
    persistentVolumeClaim:
      claimName: nfs-media        # NFS - final media location
  - name: downloads
    persistentVolumeClaim:
      claimName: nfs-downloads    # NFS - download staging

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /movies
    subPath: movies               # Only mount movies subdirectory
  - name: downloads
    mountPath: /data/usenet
    subPath: usenet
```

### media (Emby example)

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: emby-config      # Longhorn - metadata database
  - name: media
    persistentVolumeClaim:
      claimName: nfs-media        # NFS - media libraries

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /data/movies
    subPath: movies
  - name: media
    mountPath: /data/tvseries
    subPath: tvseries
  - name: media
    mountPath: /data/music
    subPath: music
```

---

## Storage Summary by Namespace

### arr-stack Namespace

| Volume Type | PVC Name | Storage | Mount Points |
|-------------|----------|---------|--------------|
| Longhorn | `*-config` | Block | `/config` (each app) |
| NFS | `nfs-media` | 1Ti | `/movies`, `/tv`, etc. |
| NFS | `nfs-downloads` | 500Gi | `/data/usenet`, `/data/torrents` |

### media Namespace

| Volume Type | PVC Name | Storage | Mount Points |
|-------------|----------|---------|--------------|
| Longhorn | `*-config` | Block | `/config` (each app) |
| NFS | `nfs-media` | 1Ti | `/data/movies`, `/data/tvseries`, etc. |

---

## NFS Mount Options

All NFS volumes use these mount options:

```yaml
mountOptions:
  - nfsvers=4.1    # NFSv4.1 for better performance
  - hard           # Retry indefinitely on failure
  - noatime        # Don't update access times (performance)
```

---

## Verification

```bash
# Check PVs
kubectl get pv | grep nfs

# Check PVCs in both namespaces
kubectl get pvc -n arr-stack
kubectl get pvc -n media

# Verify NFS mounts in a pod
kubectl exec -n arr-stack deploy/radarr -- df -h /movies
kubectl exec -n media deploy/emby -- df -h /data/movies

# Check NFS connectivity from Talos
talosctl -n 10.10.2.10 ping 10.10.2.5
```

---

## Troubleshooting

### PVC Stuck in Pending

```bash
# Check PV availability
kubectl get pv

# Verify PV-PVC binding
kubectl describe pvc nfs-media -n arr-stack

# Check events
kubectl get events -n arr-stack --field-selector reason=FailedBinding
```

### NFS Mount Errors

```bash
# Check pod events
kubectl describe pod -n arr-stack -l app.kubernetes.io/name=radarr

# Verify NAS is accessible
talosctl -n 10.10.2.10 ping 10.10.2.5

# Check NFS exports on NAS
showmount -e 10.10.2.5
```

### Permission Issues

All apps use:
- **PUID:** 1000
- **PGID:** 3001
- **fsGroup:** 3001

Ensure NAS exports allow this GID:
```bash
# On NAS, verify permissions
ls -la /mnt/tank/media
# Should show group ownership matching GID 3001
```

---

**Last Updated:** 2026-01-16
