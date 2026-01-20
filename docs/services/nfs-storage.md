# NFS Media Storage

External NAS storage for large media files shared across namespaces.

**Related:** [Longhorn Storage](longhorn.md) for block storage (databases, configs)

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

For detailed troubleshooting, see [Troubleshooting Guide](../operations/troubleshooting.md).

---

## NFS Permissions with Talos and ZFS NAS

### Understanding the Permission Model

```
┌─────────────────┐     NFS      ┌─────────────────┐
│  Talos Node     │◄────────────►│  TrueNAS (ZFS)  │
│  (Kubernetes)   │              │                 │
│                 │              │  /mnt/tank/     │
│  Pod runs as:   │              │    ├── media/   │
│  UID: 1000      │              │    └── downloads│
│  GID: 3001      │              │                 │
└─────────────────┘              └─────────────────┘
```

**Key concepts:**
- Talos is **immutable** - no SSH, no direct filesystem changes
- NFS permissions are enforced by the **NAS**, not Talos
- Pods access NFS with their configured UID/GID (1000:3001)
- ZFS datasets have their own permission model

### Talos NFS Limitations

Talos cannot:
- Run `chmod`/`chown` on NFS mounts directly
- Install NFS client tools
- SSH into the node

Talos can:
- Mount NFS shares via Kubernetes PVs
- Access files if NAS permissions allow the pod's UID/GID

### Checking NFS Access from Talos

**Test NFS connectivity:**
```bash
# Ping NAS from Talos node
talosctl -n 10.10.2.10 netstat | grep 10.10.2.5

# Check mounted NFS shares in a pod
kubectl exec -n arr-stack deploy/radarr -- df -h | grep nfs

# Test read access
kubectl exec -n arr-stack deploy/radarr -- ls -la /movies

# Test write access
kubectl exec -n arr-stack deploy/radarr -- touch /movies/test-write && \
kubectl exec -n arr-stack deploy/radarr -- rm /movies/test-write
```

**Check pod's effective UID/GID:**
```bash
kubectl exec -n arr-stack deploy/radarr -- id
# Should show: uid=1000 gid=3001
```

### ZFS/TrueNAS Permission Configuration

#### Option 1: Set Dataset Permissions (Recommended)

On TrueNAS SCALE shell or SSH:

```bash
# Set ownership to match pod UID/GID
chown -R 1000:3001 /mnt/tank/media
chown -R 1000:3001 /mnt/downloads

# Set directory permissions (rwxrwxr-x)
find /mnt/tank/media -type d -exec chmod 775 {} \;

# Set file permissions (rw-rw-r--)
find /mnt/tank/media -type f -exec chmod 664 {} \;

# Verify
ls -la /mnt/tank/media
```

#### Option 2: Use ZFS ACLs

For more granular control:

```bash
# On TrueNAS, set ACL for the dataset
# Allow UID 1000 and GID 3001 full access

# Via TrueNAS GUI:
# Storage → Pools → tank → media → Edit Permissions
# - User: 1000 (or create user with that UID)
# - Group: 3001 (or create group with that GID)
# - Apply permissions recursively
```

#### Option 3: NFS Export with Mapall

Force all NFS access to use specific UID/GID:

```bash
# In TrueNAS NFS Share settings:
# - Mapall User: your-media-user (UID 1000)
# - Mapall Group: your-media-group (GID 3001)

# This maps ALL NFS access to these IDs regardless of client
```

**TrueNAS GUI path:**
Shares → NFS → Edit Share → Advanced Options → Mapall User/Group

### Debugging Permission Denied Errors

**Step 1: Identify the error**
```bash
# Check pod logs
kubectl logs -n arr-stack deploy/radarr | grep -i "permission\|denied\|error"

# Check events
kubectl get events -n arr-stack --field-selector reason=FailedMount
```

**Step 2: Verify pod UID/GID**
```bash
# Check what user the container runs as
kubectl get pod -n arr-stack -l app.kubernetes.io/name=radarr -o yaml | grep -A5 securityContext
```

**Step 3: Check NAS permissions**
```bash
# SSH to TrueNAS and check
ls -la /mnt/tank/media
# Owner/group should be 1000:3001 or match mapall settings

# Check NFS export settings
cat /etc/exports
# Or via TrueNAS GUI: Shares → NFS
```

**Step 4: Test from a debug pod**
```bash
# Create debug pod with same UID/GID
kubectl run nfs-debug --rm -it --restart=Never \
  --image=busybox \
  --overrides='{"spec":{"securityContext":{"runAsUser":1000,"runAsGroup":3001,"fsGroup":3001}}}' \
  -- sh

# Inside pod, mount NFS manually (if nfs-utils available) or test existing mount
```

### Common Permission Scenarios

| Symptom | Cause | Solution |
|---------|-------|----------|
| `Permission denied` on read | NAS ownership doesn't allow GID 3001 | `chown -R :3001` on NAS |
| `Permission denied` on write | Directory not writable by group | `chmod -R g+w` on NAS |
| `Read-only filesystem` | NFS export is read-only | Check NFS share settings on NAS |
| New files have wrong owner | Mapall not configured | Set Mapall User/Group in NFS export |
| Can read but not delete | Sticky bit or wrong permissions | Check parent directory permissions |

### Recommended NAS Setup for Homelab

**Create dedicated user/group on TrueNAS:**
```bash
# Create group for media apps
groupadd -g 3001 mediagroup

# Create user for media apps
useradd -u 1000 -g 3001 -M -s /usr/sbin/nologin mediauser
```

**Configure NFS exports:**
```
# /etc/exports or via TrueNAS GUI
/mnt/tank/media     10.10.2.0/24(rw,async,no_subtree_check,all_squash,anonuid=1000,anongid=3001)
/mnt/downloads      10.10.2.0/24(rw,async,no_subtree_check,all_squash,anonuid=1000,anongid=3001)
```

**Key NFS options:**
- `all_squash` - Map all users to anonymous
- `anonuid=1000` - Anonymous UID
- `anongid=3001` - Anonymous GID
- `rw` - Read-write access
- `async` - Async writes (faster, less safe)
- `no_subtree_check` - Disable subtree checking (performance)

### Applying Permission Changes

**After changing NAS permissions:**
```bash
# Restart affected pods to pick up changes
kubectl rollout restart deployment -n arr-stack
kubectl rollout restart deployment -n media

# Or restart specific pod
kubectl delete pod -n arr-stack -l app.kubernetes.io/name=radarr
```

**After changing NFS export settings on NAS:**
```bash
# On TrueNAS, restart NFS service
# GUI: Services → NFS → Restart

# Or via CLI
systemctl restart nfs-server

# Then restart pods that use NFS
kubectl rollout restart deployment -n arr-stack
kubectl rollout restart deployment -n media
```

---

**Last Updated:** 2026-01-20
