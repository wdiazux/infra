# Media Namespace Design

**Date:** 2026-01-16
**Status:** Approved
**Author:** Claude (brainstorming session)

---

## Overview

Create a new `media` namespace for media playback/streaming services, separate from `arr-stack` (which handles acquisition/organization).

### Services

| Service | IP | External Port | Internal Port | Purpose |
|---------|-----|---------------|---------------|---------|
| Emby | 10.10.2.28 | 80 | 8096 | Video/audio streaming server |
| Navidrome | 10.10.2.29 | 80 | 4533 | Music streaming server |

### Design Decisions

- **No GPU transcoding** - CPU-only for Emby, keeps setup simple
- **Longhorn for configs** - Block storage for SQLite databases
- **NFS for media** - Shared with arr-stack via duplicate PV
- **ReadWrite access** - Both services can write to media directories
- **SOPS secrets** - Last.fm and Spotify API keys for Navidrome

---

## File Structure

```
kubernetes/
├── apps/base/media/
│   ├── kustomization.yaml
│   ├── storage.yaml              # Longhorn PVCs
│   ├── emby/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── navidrome/
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       └── secret.yaml           # SOPS-encrypted
├── apps/production/media/
│   └── kustomization.yaml
├── infrastructure/namespaces/
│   └── media.yaml
└── infrastructure/storage/
    ├── nfs-media-pv-media.yaml   # Duplicate PV for media namespace
    └── nfs-media-pvc-media.yaml  # PVC in media namespace
```

---

## Storage Configuration

### Longhorn PVCs (Config Volumes)

| Service | PVC Name | Size | Storage Class |
|---------|----------|------|---------------|
| Emby | emby-config | 10Gi | longhorn |
| Navidrome | navidrome-config | 1Gi | longhorn |

### NFS Media Storage

Create a duplicate PV pointing to the same NFS path as arr-stack:

**PersistentVolume:** `nfs-media-media`
- Server: 10.10.2.5
- Path: /mnt/tank/media
- Access Mode: ReadWriteMany
- Capacity: 1Ti

**PersistentVolumeClaim:** `nfs-media` (in `media` namespace)
- Binds to: nfs-media-media
- Access Mode: ReadWriteMany

---

## Emby Configuration

### Container

```yaml
image: lscr.io/linuxserver/emby:latest
containerPort: 8096
```

### Environment Variables

| Variable | Value |
|----------|-------|
| PUID | 1000 |
| PGID | 3001 |
| TZ | America/El_Salvador |

### Volume Mounts

| Mount Path | Source | SubPath |
|------------|--------|---------|
| /config | emby-config (Longhorn) | - |
| /data/movies | nfs-media | movies |
| /data/tvseries | nfs-media | tvseries |
| /data/music | nfs-media | music |
| /data/videos | nfs-media | videos |

### Health Checks

- **Liveness:** HTTP GET `/web/index.html` port 8096, initial delay 30s
- **Readiness:** HTTP GET `/web/index.html` port 8096, initial delay 10s

### Resources

- Requests: 100m CPU, 512Mi memory
- Limits: 2000m CPU, 4Gi memory

---

## Navidrome Configuration

### Container

```yaml
image: docker.io/deluan/navidrome:latest
containerPort: 4533
```

### Environment Variables

| Variable | Value |
|----------|-------|
| PUID | 1000 |
| PGID | 3001 |
| TZ | America/El_Salvador |
| ND_LOGLEVEL | warn |
| ND_SCANSCHEDULE | 12h |
| ND_ENABLEGRAVATAR | true |
| ND_LASTFM_ENABLED | true |
| ND_IMAGECACHESIZE | 200MB |

### Secret Environment Variables (SOPS)

| Variable | Description |
|----------|-------------|
| ND_LASTFM_APIKEY | Last.fm API key |
| ND_LASTFM_SECRET | Last.fm API secret |
| ND_SPOTIFY_ID | Spotify client ID |
| ND_SPOTIFY_SECRET | Spotify client secret |

### Volume Mounts

| Mount Path | Source | SubPath |
|------------|--------|---------|
| /data | navidrome-config (Longhorn) | - |
| /music | nfs-media | music |

### Health Checks

- **Liveness:** HTTP GET `/ping` port 4533, initial delay 30s
- **Readiness:** HTTP GET `/ping` port 4533, initial delay 10s

### Resources

- Requests: 50m CPU, 128Mi memory
- Limits: 500m CPU, 512Mi memory

---

## Services (LoadBalancer)

### Emby Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: emby
  namespace: media
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.28"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8096
      protocol: TCP
```

### Navidrome Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: navidrome
  namespace: media
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.29"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 4533
      protocol: TCP
```

---

## Documentation Updates Required

| File | Changes |
|------|---------|
| `docs/reference/network.md` | Add Emby (10.10.2.28), Navidrome (10.10.2.29) |
| `CLAUDE.md` | Add IPs to Network Configuration table |
| `kubernetes/apps/base/media/README.md` | New documentation file |

---

## Implementation Steps

1. Create namespace (`kubernetes/infrastructure/namespaces/media.yaml`)
2. Create NFS PV/PVC for media namespace
3. Create Longhorn storage PVCs
4. Create Emby deployment and service
5. Create Navidrome deployment, service, and SOPS secret
6. Create kustomization files (base + production)
7. Update FluxCD to deploy the namespace
8. Update network documentation
9. Test deployments and verify connectivity

---

## Access Points (Post-Deployment)

| Service | URL |
|---------|-----|
| Emby | http://10.10.2.28 |
| Navidrome | http://10.10.2.29 |

---

## Secret Setup (Manual Step)

Before deployment, create and encrypt the Navidrome secrets:

```bash
# Create plaintext secret
cat > /tmp/navidrome-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: navidrome-secrets
  namespace: media
type: Opaque
stringData:
  ND_LASTFM_APIKEY: "your-lastfm-api-key"
  ND_LASTFM_SECRET: "your-lastfm-api-secret"
  ND_SPOTIFY_ID: "your-spotify-client-id"
  ND_SPOTIFY_SECRET: "your-spotify-client-secret"
EOF

# Encrypt with SOPS
sops -e /tmp/navidrome-secret.yaml > kubernetes/apps/base/media/navidrome/secret.yaml

# Clean up plaintext
rm /tmp/navidrome-secret.yaml
```

---

**Last Updated:** 2026-01-16
