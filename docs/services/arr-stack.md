# Arr-Stack (Hotio Images)

Media automation suite: Radarr, Sonarr, Bazarr, Prowlarr, qBittorrent, SABnzbd.

**Namespace**: `arr-stack`

## Images

| Service | Image | IP |
|---------|-------|-----|
| Radarr | `ghcr.io/hotio/radarr:release-6.0.4.10291` | `10.10.2.43` |
| Sonarr | `ghcr.io/hotio/sonarr:release-4.0.16.2944` | `10.10.2.44` |
| Bazarr | `ghcr.io/hotio/bazarr:release-1.5.4` | `10.10.2.45` |
| Prowlarr | `ghcr.io/hotio/prowlarr:release-2.3.0.5236` | `10.10.2.42` |
| qBittorrent | `ghcr.io/hotio/qbittorrent:release-5.1.4` | `10.10.2.41` |
| SABnzbd | `ghcr.io/hotio/sabnzbd:release-4.5.5` | `10.10.2.40` |

---

## Common Hotio Environment Variables

All hotio images share these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `UMASK` | File permission mask | `002` |
| `TZ` | Timezone (or mount `/etc/localtime`) | - |

### UMASK Values

| UMASK | Folder Permissions | File Permissions |
|-------|-------------------|------------------|
| `002` | 775 (drwxrwxr-x) | 664 (-rw-rw-r--) |
| `022` | 755 (drwxr-xr-x) | 644 (-rw-r--r--) |

---

## qBittorrent

### VPN Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `VPN_ENABLED` | Enable WireGuard VPN | `false` |
| `VPN_PROVIDER` | VPN provider (`generic`, `proton`, `pia`) | `generic` |
| `VPN_LAN_NETWORK` | LAN network(s) allowed through VPN | - |
| `VPN_EXPOSE_PORTS_ON_LAN` | Ports to expose on LAN (e.g., `7878/tcp`) | - |
| `WEBUI_PORTS` | WebUI port(s) | `8080/tcp,8080/udp` |

### PIA VPN Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `VPN_PIA_USER` | PIA username | - |
| `VPN_PIA_PASS` | PIA password | - |
| `VPN_PIA_PREFERRED_REGION` | PIA preferred region | - |
| `PORT_FORWARD` | Enable port forwarding (PIA/Proton) | `false` |

### Privoxy

| Variable | Description | Default |
|----------|-------------|---------|
| `PRIVOXY_ENABLED` | Enable Privoxy | `false` |

### WireGuard Setup

1. Set `VPN_ENABLED=true`
2. Place `wg0.conf` in `/config/wireguard/`
3. For PIA/Proton, set `VPN_PROVIDER` and credentials

### Required Capabilities for VPN

```yaml
cap_add:
  - NET_ADMIN
devices:
  - /dev/net/tun:/dev/net/tun
sysctls:
  - net.ipv4.conf.all.src_valid_mark=1
  - net.ipv6.conf.all.disable_ipv6=1
```

---

## SABnzbd

### VPN Configuration

Same VPN variables as qBittorrent:

| Variable | Description | Default |
|----------|-------------|---------|
| `VPN_ENABLED` | Enable WireGuard VPN | `false` |
| `VPN_PROVIDER` | VPN provider | `generic` |
| `VPN_LAN_NETWORK` | LAN network(s) allowed | - |
| `VPN_EXPOSE_PORTS_ON_LAN` | Ports to expose on LAN | - |
| `WEBUI_PORTS` | WebUI port(s) | `8080/tcp` |

---

## Recommended Directory Structure

Following the Servarr Wiki best practices:

```
/data
├── torrents
│   ├── movies
│   └── tv
├── usenet
│   ├── movies
│   └── tv
└── media
    ├── movies
    └── tv
```

Mount `/data` to all arr services for hardlinks to work.

## Documentation

- [Hotio Containers](https://hotio.dev/containers/)
- [Servarr Wiki Docker Guide](https://wiki.servarr.com/docker-guide)
- [TRaSH Guides](https://trash-guides.info/)
