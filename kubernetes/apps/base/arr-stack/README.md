# Arr-Stack - Media Automation Services

Media automation stack for managing movies, TV series, and downloads.

## Services

| Service | IP | Port | Purpose |
|---------|-----|------|---------|
| SABnzbd | 10.10.2.40 | 80 | Usenet download client |
| qBittorrent | 10.10.2.41 | 80 | Torrent download client |
| Prowlarr | 10.10.2.42 | 80 | Indexer manager |
| Radarr | 10.10.2.43 | 80 | Movie collection manager |
| Sonarr | 10.10.2.44 | 80 | TV series collection manager |
| Bazarr | 10.10.2.45 | 80 | Subtitle manager |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        arr-stack namespace                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐  ┌─────────────┐  ┌──────────┐                   │
│  │ SABnzbd  │  │ qBittorrent │  │ Prowlarr │                   │
│  │ :8080    │  │ :8080       │  │ :9696    │                   │
│  └────┬─────┘  └──────┬──────┘  └────┬─────┘                   │
│       │               │              │                          │
│       └───────────────┼──────────────┘                          │
│                       │                                          │
│                       ▼                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
│  │  Radarr  │  │  Sonarr  │  │  Bazarr  │                      │
│  │  :7878   │  │  :8989   │  │  :6767   │                      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                      │
│       │             │             │                             │
└───────┼─────────────┼─────────────┼─────────────────────────────┘
        │             │             │
        ▼             ▼             ▼
┌───────────────────────────────────────────────────────────────┐
│                         Storage                                │
├───────────────────────────────────────────────────────────────┤
│  Longhorn (RWO)           │  NFS (RWX)                        │
│  ─────────────────        │  ─────────────────────────────    │
│  • sabnzbd-config         │  • nfs-media (/mnt/tank/media)    │
│  • qbittorrent-config     │    └── movies/, tvseries/         │
│  • prowlarr-config        │                                    │
│  • radarr-config          │  • nfs-downloads (/mnt/downloads) │
│  • sonarr-config          │    └── usenet/, torrents/         │
│  • bazarr-config          │                                    │
└───────────────────────────────────────────────────────────────┘
```

## Storage Strategy

### Why Two Storage Types?

**Longhorn (Block Storage)** for `/config` directories:
- Arr services use SQLite databases
- SQLite does NOT work reliably on NFS (file locking issues, corruption)
- Block storage (Longhorn RWO) provides proper file locking

**NFS (Shared Storage)** for media and downloads:
- Large files that need shared access
- Hardlink support for instant moves (same filesystem)
- External NAS provides durable storage

### NFS Mounts

| PV Name | NAS Path | Used By | Purpose |
|---------|----------|---------|---------|
| nfs-media | /mnt/tank/media | Radarr, Sonarr, Bazarr | Final media storage |
| nfs-downloads | /mnt/downloads | SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr | Download staging |

### Directory Structure

```
NAS (10.10.2.5)
├── /mnt/tank/media/          # Media library
│   ├── movies/               # Radarr target
│   ├── tvseries/             # Sonarr target
│   ├── music/                # Lidarr target (future)
│   └── videos/               # General videos
│
└── /mnt/downloads/           # Download staging
    ├── usenet/
    │   ├── complete/
    │   │   ├── movies/
    │   │   ├── tvseries/
    │   │   ├── music/
    │   │   └── videos/
    │   └── incomplete/
    └── torrents/
```

### Volume Mounts by Service

| Service | /config | Media Mounts | Download Mounts |
|---------|---------|--------------|-----------------|
| SABnzbd | Longhorn | - | /data/usenet → usenet/ |
| qBittorrent | Longhorn | - | /downloads/torrents → torrents/ |
| Prowlarr | Longhorn | - | /downloads/usenet, /downloads/torrents |
| Radarr | Longhorn | /movies → movies/ | /data/usenet, /data/torrents |
| Sonarr | Longhorn | /tvseries → tvseries/ | /data/usenet, /data/torrents |
| Bazarr | Longhorn | /movies, /tvseries | - |

## Resource Allocation

Based on community research and real-world usage patterns.

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| SABnzbd | 100m | 2000m | 512Mi | 2Gi |
| qBittorrent | 100m | 1000m | 256Mi | 2Gi |
| Prowlarr | 50m | 500m | 128Mi | 512Mi |
| Radarr | 100m | 1000m | 256Mi | 2Gi |
| Sonarr | 100m | 500m | 256Mi | 1Gi |
| Bazarr | 100m | 500m | 128Mi | 512Mi |

**Total Requirements:**
- CPU Requests: 550m
- CPU Limits: 5500m
- Memory Requests: 1.5Gi
- Memory Limits: 8Gi

### Resource Notes

- **SABnzbd**: High CPU limit for par2 repair/unpacking operations
- **Radarr**: Uses ~8x more memory than Sonarr for similar library sizes
- **qBittorrent**: Memory scales with number of loaded torrents
- **Prowlarr/Bazarr**: Lightweight services, minimal resources needed

## Configuration

### User/Group IDs

All services run with:
- **PUID**: 1000
- **PGID**: 3001
- **fsGroup**: 3001

Ensure NFS directories have matching ownership:
```bash
chown -R 1000:3001 /mnt/tank/media /mnt/downloads
chmod -R 775 /mnt/tank/media /mnt/downloads
```

### Timezone

All services configured with: `America/El_Salvador`

### Container Images

All services use [hotio](https://hotio.dev/) images from `ghcr.io/hotio/`:
- Lightweight, security-focused
- Regular updates
- Consistent configuration pattern

## Deployment

### Prerequisites

1. **Longhorn** storage class available
2. **NFS server** (10.10.2.5) with exports:
   - `/mnt/tank/media` - media library
   - `/mnt/downloads` - download staging
3. **Cilium** L2 LoadBalancer with IP pool including 10.10.2.40-45

### Deploy via FluxCD

Already configured in `kubernetes/apps/production/kustomization.yaml`:
```yaml
resources:
  - ../base/arr-stack/
```

FluxCD will automatically deploy on next reconciliation.

### Manual Deployment

```bash
kubectl apply -k kubernetes/apps/base/arr-stack/
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n arr-stack

# Check services
kubectl get svc -n arr-stack

# Check PVCs
kubectl get pvc -n arr-stack
```

## Post-Deployment Configuration

### 1. Prowlarr (First)
1. Access http://10.10.2.42
2. Configure authentication
3. Add indexers (NZB and torrent)

### 2. Download Clients
**SABnzbd** (http://10.10.2.40):
1. Configure usenet servers
2. Set download categories: movies, tvseries, music
3. Set completed download folder: `/data/usenet/complete`

**qBittorrent** (http://10.10.2.41):
1. Default login: admin / (check pod logs for temp password)
2. Set download folder: `/downloads/torrents`
3. Configure categories if needed

### 3. Radarr (http://10.10.2.43)
1. Add Prowlarr as indexer (Settings → Indexers → Add)
2. Add download clients (SABnzbd, qBittorrent)
3. Set root folder: `/movies`
4. Configure quality profiles

### 4. Sonarr (http://10.10.2.44)
1. Add Prowlarr as indexer
2. Add download clients
3. Set root folder: `/tvseries`
4. Configure quality profiles

### 5. Bazarr (http://10.10.2.45)
1. Connect to Radarr and Sonarr (Settings → Radarr/Sonarr)
2. Configure subtitle providers
3. Set languages

## Troubleshooting

### Pods stuck in CreateContainerConfigError

Usually indicates NFS subPath directories don't exist:
```bash
# Check events
kubectl get events -n arr-stack --sort-by='.lastTimestamp'

# Create missing directories on NAS
ssh nas
mkdir -p /mnt/tank/media/{movies,tvseries,music,videos}
mkdir -p /mnt/downloads/{usenet/{complete,incomplete},torrents}
chown -R 1000:3001 /mnt/tank/media /mnt/downloads
```

### SQLite Database Locked Errors

If you see "database is locked" errors, the config volume may be on NFS instead of Longhorn. Verify PVC storage class:
```bash
kubectl get pvc -n arr-stack -o wide
```
Config PVCs should use `longhorn` storage class.

### Permission Denied on NFS

Check ownership matches PUID/PGID:
```bash
# On NAS
ls -la /mnt/tank/media
ls -la /mnt/downloads
# Should show 1000:3001 ownership
```

### Service Not Accessible

1. Check pod is running: `kubectl get pods -n arr-stack`
2. Check service has external IP: `kubectl get svc -n arr-stack`
3. Check Cilium L2 announcements: `cilium bgp peers`

## Files

```
arr-stack/
├── README.md                 # This file
├── kustomization.yaml        # Main kustomization
├── storage.yaml              # Longhorn PVCs for configs
├── bazarr/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── prowlarr/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── qbittorrent/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── radarr/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── sabnzbd/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── sonarr/
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

## References

- [TRaSH Guides](https://trash-guides.info/) - Quality profiles and hardlink setup
- [Servarr Wiki](https://wiki.servarr.com/) - Official documentation
- [hotio.dev](https://hotio.dev/) - Container images
- [Longhorn](https://longhorn.io/) - Block storage for Kubernetes
