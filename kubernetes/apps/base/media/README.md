# Media Namespace

Media playback and streaming services.

## Services

| Service | IP | Port | Description |
|---------|-----|------|-------------|
| Emby | 10.10.2.28 | 80 | Video/audio streaming server |
| Navidrome | 10.10.2.29 | 80 | Music streaming server |

## Storage

### Config Volumes (Longhorn)

- `emby-config` - 10Gi - Metadata, thumbnails, cache
- `navidrome-config` - 1Gi - Database, cache

### Media Storage (NFS)

Both services mount `/mnt/tank/media` from NAS (10.10.2.5) via a dedicated PV/PVC:
- PV: `nfs-media-media` (duplicate of arr-stack's PV)
- PVC: `nfs-media` (in media namespace)

**Directory structure:**
```
/mnt/tank/media/
├── movies/     → Emby /data/movies
├── tvseries/   → Emby /data/tvseries
├── music/      → Emby /data/music, Navidrome /music
└── videos/     → Emby /data/videos
```

## Secrets

Navidrome uses SOPS-encrypted secrets for Last.fm and Spotify integration:

```bash
# Edit secrets (requires SOPS key)
sops kubernetes/apps/base/media/navidrome/secret.yaml
```

Required keys:
- `ND_LASTFM_APIKEY` - Last.fm API key
- `ND_LASTFM_SECRET` - Last.fm API secret
- `ND_SPOTIFY_ID` - Spotify client ID
- `ND_SPOTIFY_SECRET` - Spotify client secret

## Access

| Service | URL |
|---------|-----|
| Emby | http://10.10.2.28 |
| Navidrome | http://10.10.2.29 |

## Deployment

Deployed via FluxCD from `kubernetes/apps/production/kustomization.yaml`.

```bash
# Force reconciliation
flux reconcile kustomization apps --with-source

# Check status
kubectl get pods -n media
kubectl get svc -n media
```
