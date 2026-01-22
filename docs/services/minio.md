# MinIO

S3-compatible object storage server.

**Image**: `alpine/minio:RELEASE.2025-10-15T17-29-55Z`
**Namespace**: `backup`
**IP**: `10.10.2.17`

## Environment Variables

### Authentication (Required)

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_ROOT_USER` | Root username (min 3 chars) | - |
| `MINIO_ROOT_PASSWORD` | Root password (min 8 chars) | - |

### Server Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_ADDRESS` | API address | `:9000` |
| `MINIO_CONSOLE_ADDRESS` | Console address | `:9001` |
| `MINIO_VOLUMES` | Data volumes | - |
| `MINIO_BROWSER` | Enable browser console | `on` |

### Networking

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_DOMAIN` | Domain for virtual-host-style | - |
| `MINIO_SERVER_URL` | Server URL | - |
| `MINIO_BROWSER_REDIRECT_URL` | Console redirect URL | - |
| `MINIO_SCHEME` | Scheme (http/https) | `http` |

### CORS

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_API_CORS_ALLOW_ORIGIN` | CORS allowed origins | `*` |

### Initialization

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_DEFAULT_BUCKETS` | Buckets to create on startup | - |
| `MINIO_FORCE_NEW_KEYS` | Force key reconfiguration | `no` |

### Prometheus

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_PROMETHEUS_AUTH_TYPE` | Prometheus auth type | `jwt` |
| `MINIO_PROMETHEUS_URL` | Prometheus URL | - |

### Identity (OpenID)

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_IDENTITY_OPENID_CONFIG_URL` | OpenID config URL | - |
| `MINIO_IDENTITY_OPENID_CLIENT_ID` | OpenID client ID | - |
| `MINIO_IDENTITY_OPENID_CLIENT_SECRET` | OpenID client secret | - |

### API Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_API_REQUESTS_MAX` | Max concurrent requests | - |
| `MINIO_API_ROOT_ACCESS` | Root access mode | `on` |

## Docker Secrets Support

Variables support the `_FILE` suffix pattern:
- `MINIO_ROOT_USER_FILE`
- `MINIO_ROOT_PASSWORD_FILE`
- `MINIO_KMS_KES_KEY_FILE`
- `MINIO_KMS_KES_CERT_FILE`

Example:
```yaml
environment:
  MINIO_ROOT_USER_FILE: /run/secrets/minio_user
  MINIO_ROOT_PASSWORD_FILE: /run/secrets/minio_password
```

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/data` | Object storage |
| `/certs` | TLS certificates (for HTTPS) |

## HTTPS Configuration

For TLS, set `MINIO_SCHEME=https` and mount certificates:

```yaml
volumes:
  - ./certs/public.crt:/certs/public.crt:ro
  - ./certs/private.key:/certs/private.key:ro
environment:
  MINIO_SCHEME: https
```

## Example Deployment

```yaml
services:
  minio:
    image: alpine/minio:RELEASE.2025-10-15T17-29-55Z
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio-data:/data
```

## MC (MinIO Client) Commands

```bash
# Configure alias
mc alias set myminio http://localhost:9000 minioadmin minioadmin123

# Create bucket
mc mb myminio/mybucket

# List buckets
mc ls myminio

# Copy files
mc cp file.txt myminio/mybucket/
```

## Documentation

- [MinIO Docker Guide](https://github.com/minio/minio/blob/master/docs/docker/README.md)
- [MinIO Settings](https://min.io/docs/minio/linux/reference/minio-server/settings.html)
- [Docker Hub](https://hub.docker.com/r/minio/minio)
