# Home Assistant

Open source home automation platform.

**Image**: `ghcr.io/home-assistant/home-assistant:2026.1.2`
**Namespace**: `automation`
**IP**: `10.10.2.25`

## Environment Variables

Home Assistant uses minimal environment variables. Most configuration is done via `configuration.yaml`.

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | - |
| `PUID` | User ID (LinuxServer image only) | `1000` |
| `PGID` | Group ID (LinuxServer image only) | `1000` |
| `UMASK` | File permission mask | `022` |

## Network Configuration

Home Assistant requires host network mode for device discovery:

```yaml
network_mode: host
```

This enables:
- Zeroconf/mDNS discovery
- UPnP device detection
- Local network device communication

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/config` | Configuration files |

## Device Access

For hardware integrations (Zigbee, Z-Wave, etc.):

```yaml
devices:
  - /dev/ttyUSB0:/dev/ttyUSB0
  - /dev/ttyACM0:/dev/ttyACM0
```

## Privileged Mode

Some integrations require privileged mode:

```yaml
privileged: true
```

## Important Notes

- Environment variables in Home Assistant are limited
- Use `configuration.yaml` for most settings
- For secrets, use `secrets.yaml` file
- Host networking is strongly recommended

## Configuration via File

Most settings go in `/config/configuration.yaml`:

```yaml
homeassistant:
  name: Home
  unit_system: metric
  time_zone: America/El_Salvador

http:
  server_port: 8123
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.10.2.0/24
```

## Documentation

- [Home Assistant Docker Installation](https://www.home-assistant.io/installation/linux#docker-compose)
- [Configuration Guide](https://www.home-assistant.io/docs/configuration/)
