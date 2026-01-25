# n8n

Workflow automation platform with 400+ integrations.

## Image

| Registry | Image | Version |
|----------|-------|---------|
| Docker Hub | `n8nio/n8n` | `2.5.0` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `automation` |
| IP | `10.10.2.26` |
| Port | `5678` |
| URL | `https://n8n.home-infra.net` |

## Environment Variables

### Basic Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_HOST` | Host for n8n | `localhost` |
| `N8N_PORT` | Port for n8n | `5678` |
| `N8N_PROTOCOL` | Protocol (http/https) | `http` |
| `WEBHOOK_URL` | Webhook base URL | - |

### Authentication

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_BASIC_AUTH_ACTIVE` | Enable basic auth | `false` |
| `N8N_BASIC_AUTH_USER` | Basic auth username | - |
| `N8N_BASIC_AUTH_PASSWORD` | Basic auth password | - |

### Security

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_ENCRYPTION_KEY` | Encryption key for credentials | Auto-generated |
| `N8N_USER_FOLDER` | User data folder | `/home/node/.n8n` |

### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_TYPE` | Database type (`sqlite`, `postgresdb`) | `sqlite` |
| `DB_POSTGRESDB_HOST` | PostgreSQL host | - |
| `DB_POSTGRESDB_PORT` | PostgreSQL port | `5432` |
| `DB_POSTGRESDB_DATABASE` | PostgreSQL database | - |
| `DB_POSTGRESDB_USER` | PostgreSQL user | - |
| `DB_POSTGRESDB_PASSWORD` | PostgreSQL password | - |
| `DB_POSTGRESDB_SCHEMA` | PostgreSQL schema | `public` |

### Timezone

| Variable | Description | Default |
|----------|-------------|---------|
| `GENERIC_TIMEZONE` | Timezone for scheduled triggers | `America/New_York` |
| `TZ` | System timezone | - |

### Execution

| Variable | Description | Default |
|----------|-------------|---------|
| `EXECUTIONS_MODE` | Execution mode (`regular`, `queue`) | `regular` |
| `EXECUTIONS_DATA_SAVE_ON_ERROR` | Save execution data on error | `all` |
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` | Save execution data on success | `all` |
| `EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS` | Save manual executions | `true` |
| `EXECUTIONS_DATA_PRUNE` | Enable data pruning | `true` |
| `EXECUTIONS_DATA_MAX_AGE` | Max age of execution data | `336` (hours) |

### Logging & Monitoring

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_LOG_LEVEL` | Log level | `info` |
| `N8N_LOG_OUTPUT` | Log output (`console`, `file`) | `console` |
| `N8N_METRICS` | Enable Prometheus metrics | `false` |
| `N8N_METRICS_PREFIX` | Metrics prefix | `n8n_` |

### Queue Mode (Redis)

| Variable | Description | Default |
|----------|-------------|---------|
| `QUEUE_BULL_REDIS_HOST` | Redis host | `localhost` |
| `QUEUE_BULL_REDIS_PORT` | Redis port | `6379` |
| `QUEUE_BULL_REDIS_PASSWORD` | Redis password | - |
| `QUEUE_BULL_REDIS_DB` | Redis database | `0` |
| `N8N_DISABLE_PRODUCTION_MAIN_PROCESS` | Disable UI in queue mode | `false` |

### External Hooks

| Variable | Description | Default |
|----------|-------------|---------|
| `EXTERNAL_HOOK_FILES` | External hook files | - |

## Docker Secrets Support

Variables support the `_FILE` suffix pattern:
- `N8N_ENCRYPTION_KEY_FILE`
- `DB_POSTGRESDB_PASSWORD_FILE`

## Important Notes

- Always set `N8N_ENCRYPTION_KEY` for persistent credential encryption
- Set `WEBHOOK_URL` when behind a reverse proxy
- Use queue mode with Redis for high-availability setups

## Documentation

- [Environment Variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [Database Configuration](https://docs.n8n.io/hosting/configuration/environment-variables/database/)
- [Docker Installation](https://docs.n8n.io/hosting/installation/docker/)
- [GitHub](https://github.com/n8n-io/n8n)
- [Docker Hub](https://hub.docker.com/r/n8nio/n8n)
