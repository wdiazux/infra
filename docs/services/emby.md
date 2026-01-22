# Emby

Media server for organizing and streaming media.

**Image**: `lscr.io/linuxserver/emby:4.9.3`
**Namespace**: `media`
**IP**: `10.10.2.30`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `TZ` | Timezone | `Etc/UTC` |
| `UMASK` | File permission mask | `022` |

## LinuxServer.io Common Variables

This image follows LinuxServer.io conventions:

| Variable | Description |
|----------|-------------|
| `FILE__*` | Load value from file (e.g., `FILE__PASSWORD=/run/secrets/pw`) |

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/config` | Configuration files |
| `/data/tvshows` | TV shows library |
| `/data/movies` | Movies library |
| `/transcode` | Transcoding temp directory (optional) |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8096 | HTTP | Web interface |
| 8920 | HTTPS | Secure web interface (optional) |

## GPU Transcoding

For hardware transcoding with Intel QuickSync:
```yaml
devices:
  - /dev/dri:/dev/dri
```

For NVIDIA:
```yaml
runtime: nvidia
environment:
  - NVIDIA_VISIBLE_DEVICES=all
```

## Documentation

- [LinuxServer Emby](https://docs.linuxserver.io/images/docker-emby/)
- [Docker Hub](https://hub.docker.com/r/linuxserver/emby)
