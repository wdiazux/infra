# Homepage

Highly customizable application dashboard with Docker and service integrations.

**Image**: `ghcr.io/gethomepage/homepage:v1.9.0`
**Namespace**: `tools`
**IP**: `10.10.2.21`

## Environment Variables

### Required (v1.0+)

| Variable | Description | Default |
|----------|-------------|---------|
| `HOMEPAGE_ALLOWED_HOSTS` | Allowed hosts for API access (required for non-localhost) | - |

### User/Group

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID | - |
| `PGID` | Group ID | - |

### Custom Variables

| Variable Pattern | Description |
|-----------------|-------------|
| `HOMEPAGE_VAR_*` | Custom variables for config files |
| `HOMEPAGE_FILE_*` | File-based secrets for config files |

### Docker Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `HOMEPAGE_DOCKER_INTEGRATE` | Docker integration control | - |

### Logging

| Variable | Description | Default |
|----------|-------------|---------|
| `LOG_LEVEL` | Log level | `info` |
| `LOG_TARGETS` | Log targets | `stdout` |

## Config File Variable Substitution

Use `{{HOMEPAGE_VAR_XXX}}` in config files:

```yaml
# settings.yaml
providers:
  openweathermap: "{{HOMEPAGE_VAR_OPENWEATHERMAP_API_KEY}}"
```

Environment setup:
```yaml
environment:
  HOMEPAGE_VAR_OPENWEATHERMAP_API_KEY: "your-api-key"
```

## File-Based Secrets

Use `HOMEPAGE_FILE_*` for file-based secrets:

```yaml
environment:
  HOMEPAGE_FILE_APIKEY: /run/secrets/api_key
```

Then in config:
```yaml
api_key: "{{HOMEPAGE_FILE_APIKEY}}"
```

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/app/config` | Configuration files |
| `/var/run/docker.sock` | Docker socket (optional) |

## Configuration Files

Place these in the config volume:

| File | Purpose |
|------|---------|
| `settings.yaml` | General settings |
| `services.yaml` | Service definitions |
| `widgets.yaml` | Widget configurations |
| `bookmarks.yaml` | Bookmark definitions |
| `docker.yaml` | Docker integration config |

## Docker Integration

To enable Docker service discovery:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

Then configure in `docker.yaml`:
```yaml
my-docker:
  socket: /var/run/docker.sock
```

## Verification

Check environment variables are set:
```bash
docker exec -it homepage env | grep HOMEPAGE_VAR
```

## Documentation

- [Homepage Docker Installation](https://gethomepage.dev/installation/docker/)
- [Configuration](https://gethomepage.dev/configs/)
- [GitHub](https://github.com/gethomepage/homepage)
