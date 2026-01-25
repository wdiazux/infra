# Wallos

Personal subscription tracker for managing recurring expenses.

## Image

| Registry | Image | Version |
|----------|-------|---------|
| Docker Hub | `bellamy/wallos` | `4.6.0` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `management` |
| IP | `10.10.2.34` |
| Port | `80` |
| URL | `https://wallos.home-infra.net` |

## Environment Variables

Wallos uses minimal environment variables. Most configuration is done via the web interface.

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/var/www/html/db` | SQLite database |
| `/var/www/html/images/uploads/logos` | Custom logos |

## Port

| Port | Purpose |
|------|---------|
| 80 | Web interface (internal) |

## Configuration

Most configuration is done through the web UI:
- Currency settings
- Categories
- Payment methods
- Notification settings

## Example Deployment

```yaml
services:
  wallos:
    image: bellamy/wallos:4.6.0
    environment:
      TZ: America/El_Salvador
    volumes:
      - wallos-db:/var/www/html/db
      - wallos-logos:/var/www/html/images/uploads/logos
    ports:
      - "8282:80"
```

## Documentation

- [GitHub](https://github.com/ellite/Wallos)
- [Official Website](https://wallosapp.com/)
- [Docker Hub](https://hub.docker.com/r/bellamy/wallos)
