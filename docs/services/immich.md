# Immich

Self-hosted photo and video backup solution.

**Images**:
- Server: `ghcr.io/immich-app/immich-server:v2.4.1`
- ML: `ghcr.io/immich-app/immich-machine-learning:v2.4.1-cuda`
- PostgreSQL: `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0`
- Valkey: `valkey/valkey:9`

**Namespace**: `media`
**IP**: `10.10.2.22`

## Environment Variables

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `UPLOAD_LOCATION` | Upload storage location | `./library` |
| `DB_DATA_LOCATION` | Database storage location (no network shares) | `./postgres` |
| `TZ` | Timezone | `Etc/UTC` |
| `IMMICH_VERSION` | Version to deploy | `release` |

### Database Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_PASSWORD` | PostgreSQL password | - |
| `DB_USERNAME` | PostgreSQL username | `postgres` |
| `DB_DATABASE_NAME` | Database name | `immich` |
| `DB_HOSTNAME` | Database host | `database` |

### Redis/Valkey Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_HOSTNAME` | Redis/Valkey host | `redis` |
| `REDIS_PORT` | Redis/Valkey port | `6379` |
| `REDIS_PASSWORD` | Redis/Valkey password | - |
| `REDIS_URL` | Full Redis URL (overrides above) | - |
| `REDIS_SOCKET` | Redis socket path | - |

### Advanced Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `IMMICH_CONFIG_FILE` | Path to config file | - |
| `IMMICH_MEDIA_LOCATION` | Media storage path | - |
| `LOG_LEVEL` | Logging level | `log` |

## Docker Secrets Support

Variables support the `_FILE` suffix pattern:
- `DB_PASSWORD_FILE`
- `REDIS_PASSWORD_FILE`

Set `CREDENTIALS_DIRECTORY=/run/secrets` to use all Docker secrets automatically.

## Important Notes

- Database location (`DB_DATA_LOCATION`) must not be on a network share
- Changing env vars requires `docker compose up -d` to recreate containers
- Use `docker compose up -d --force-recreate` if changes aren't detected

## ML Service (GPU)

For CUDA-enabled ML service:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

## Documentation

- [Immich Environment Variables](https://docs.immich.app/install/environment-variables/)
- [Docker Compose Installation](https://docs.immich.app/install/docker-compose/)
