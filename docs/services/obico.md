# Obico

3D printer monitoring and failure detection using AI.

**Images**:
- Web: `ghcr.io/gabe565/obico/web:release`
- ML API: `ghcr.io/wdiazux/obico-ml-api:cuda12.3`
- Redis: `redis:7-alpine`

**Namespace**: `printing`
**IP**: `10.10.2.27`

## Web Service Environment Variables

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `DEBUG` | Enable debug mode | `False` |
| `DJANGO_SECRET_KEY` | Django secret key (required) | - |
| `SITE_USES_HTTPS` | Site uses HTTPS | `False` |
| `SITE_IS_PUBLIC` | Public site | `False` |

### Security

| Variable | Description | Default |
|----------|-------------|---------|
| `CSRF_TRUSTED_ORIGINS` | Trusted CSRF origins (JSON array) | - |
| `ALLOWED_HOSTS` | Allowed hosts | `*` |

### Database

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Database connection URL | - |

### Redis

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis connection URL | - |

### Email

| Variable | Description | Default |
|----------|-------------|---------|
| `EMAIL_HOST` | SMTP host | - |
| `EMAIL_PORT` | SMTP port | - |
| `EMAIL_HOST_USER` | SMTP username | - |
| `EMAIL_HOST_PASSWORD` | SMTP password | - |
| `DEFAULT_FROM_EMAIL` | Default from address | - |

### Social Login (Optional)

| Variable | Description | Default |
|----------|-------------|---------|
| `SOCIAL_LOGIN` | Enable social login | `False` |

## ML API Service Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEBUG` | Enable debug mode | `False` |
| `FLASK_APP` | Flask application | `server.py` |
| `ML_API_TOKEN` | API authentication token | - |

## Configuration File (`.env`)

Create `.env` from `.env.example`:

```bash
# Django
DJANGO_SECRET_KEY=your-very-long-secret-key
DEBUG=False

# Site settings
SITE_USES_HTTPS=true
SITE_IS_PUBLIC=false

# CSRF
CSRF_TRUSTED_ORIGINS=["https://obico.example.com"]

# Database
DATABASE_URL=postgres://user:pass@postgres:5432/obico

# Redis
REDIS_URL=redis://redis:6379

# Email (optional)
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
EMAIL_HOST_USER=user
EMAIL_HOST_PASSWORD=pass
```

## GPU Configuration for ML API

```yaml
services:
  ml_api:
    image: ghcr.io/wdiazux/obico-ml-api:cuda12.3
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

## Service Dependencies

```yaml
services:
  web:
    depends_on:
      ml_api:
        condition: service_started
      redis:
        condition: service_healthy
```

## Important Notes

- `DJANGO_SECRET_KEY` should be randomly generated and rotated periodically
- For public-facing servers, always set `CSRF_TRUSTED_ORIGINS`
- The ML API can run on CPU but GPU (CUDA) is recommended for performance

## Documentation

- [Obico Server Configuration](https://www.obico.io/docs/server-guides/configure/)
- [Self-Hosted Server Guides](https://www.obico.io/docs/server-guides/)
- [gabe565/docker-obico GitHub](https://github.com/gabe565/docker-obico)
