# Immich

Self-hosted photo and video backup solution with AI-powered features.

## Images

| Component | Registry | Image | Version |
|-----------|----------|-------|---------|
| Server | GitHub Container Registry | `ghcr.io/immich-app/immich-server` | `v2.4.1` |
| Machine Learning | GitHub Container Registry | `ghcr.io/immich-app/immich-machine-learning` | `v2.4.1-cuda` |
| PostgreSQL | GitHub Container Registry | `ghcr.io/immich-app/postgres` | `14-vectorchord0.4.3-pgvectors0.2.0` |
| Redis | Docker Hub | `valkey/valkey` | `9` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `media` |
| IP | `10.10.2.22` |
| Port | `2283` |
| URL | `https://photos.reynoza.org` |

## Environment Variables

### General Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone (TZ identifier) | - |
| `IMMICH_ENV` | Environment mode | `production` |
| `IMMICH_LOG_LEVEL` | Log verbosity (`verbose`, `debug`, `log`, `warn`, `error`) | `log` |
| `IMMICH_MEDIA_LOCATION` | Internal media path | `/data` |
| `IMMICH_CONFIG_FILE` | Path to config file | - |
| `NO_COLOR` | Disable color logging | `false` |

### Server Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `IMMICH_HOST` | Listening host address | `0.0.0.0` |
| `IMMICH_PORT` | Listening port | `2283` |
| `IMMICH_TRUSTED_PROXIES` | Comma-separated trusted proxy IPs | - |
| `IMMICH_API_METRICS_PORT` | OTEL metrics port | `8081` |

### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_URL` | Full database connection string | - |
| `DB_HOSTNAME` | Database host | `database` |
| `DB_PORT` | Database port | `5432` |
| `DB_USERNAME` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `DB_DATABASE_NAME` | Database name | `immich` |
| `DB_SSL_MODE` | SSL connection mode | - |
| `DB_VECTOR_EXTENSION` | Vector extension type | auto-detected |
| `DB_SKIP_MIGRATIONS` | Skip startup migrations | `false` |
| `DB_STORAGE_TYPE` | IO optimization mode (`SSD`, `HDD`) | `SSD` |

### Redis Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Full Redis connection string (overrides individual settings) | - |
| `REDIS_SOCKET` | Redis socket path | - |
| `REDIS_HOSTNAME` | Redis host | `redis` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_USERNAME` | Redis username | - |
| `REDIS_PASSWORD` | Redis password | - |
| `REDIS_DBINDEX` | Database index | `0` |

### Machine Learning Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `MACHINE_LEARNING_HOST` | ML service host | `0.0.0.0` |
| `MACHINE_LEARNING_PORT` | ML service port | `3003` |
| `MACHINE_LEARNING_WORKERS` | Worker processes | `1` |
| `MACHINE_LEARNING_MODEL_TTL` | Model inactivity timeout (seconds) | `300` |
| `MACHINE_LEARNING_CACHE_FOLDER` | Model cache directory | `/cache` |
| `MACHINE_LEARNING_REQUEST_THREADS` | Request thread pool size | CPU cores |
| `MACHINE_LEARNING_WORKER_TIMEOUT` | Worker timeout | `120` |
| `MACHINE_LEARNING_DEVICE_IDS` | GPU device IDs | `0` |

### Model Preloading

| Variable | Description | Default |
|----------|-------------|---------|
| `MACHINE_LEARNING_PRELOAD__CLIP__TEXTUAL` | Preload CLIP text models | - |
| `MACHINE_LEARNING_PRELOAD__CLIP__VISUAL` | Preload CLIP visual models | - |
| `MACHINE_LEARNING_PRELOAD__FACIAL_RECOGNITION__RECOGNITION` | Preload face recognition | - |
| `MACHINE_LEARNING_PRELOAD__FACIAL_RECOGNITION__DETECTION` | Preload face detection | - |

## Docker Secrets Support

Variables support the `_FILE` suffix pattern for secrets:
- `DB_PASSWORD_FILE`
- `REDIS_PASSWORD_FILE`

Set `CREDENTIALS_DIRECTORY=/run/secrets` to use all Docker secrets automatically.

## Important Notes

- Database location must not be on a network share
- Changing env vars requires container recreation (`docker compose up -d --force-recreate`)
- Use `IMMICH_TRUSTED_PROXIES` when behind a reverse proxy
- Preloading models prevents slow first searches

## GPU Support (Machine Learning)

For CUDA-enabled ML service:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

## Documentation

- [Environment Variables](https://docs.immich.app/install/environment-variables/)
- [Docker Compose Installation](https://docs.immich.app/install/docker-compose/)
- [Config File](https://docs.immich.app/install/config-file/)
- [GitHub](https://github.com/immich-app/immich)
