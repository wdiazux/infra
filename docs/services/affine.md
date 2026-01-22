# AFFiNE

Knowledge base combining docs, whiteboards, and databases.

**Image**: `ghcr.io/toeverything/affine:2026.1.21-canary.908`
**Supporting Images**:
- PostgreSQL: `pgvector/pgvector:pg17`
- Redis: `docker.io/library/redis:8`

**Namespace**: `tools`
**IP**: `10.10.2.33`

## Environment Variables

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `AFFINE_REVISION` | Version/revision | `stable` |
| `PORT` | HTTP port | `3010` |
| `NODE_ENV` | Node environment | `production` |

### Server Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `AFFINE_SERVER_HTTPS` | Enable HTTPS | `false` |
| `AFFINE_SERVER_EXTERNAL_URL` | External URL | - |
| `AFFINE_SERVER_HOST` | Server host | `localhost` |
| `AFFINE_INDEXER_ENABLED` | Enable indexer | `true` |

### Admin

| Variable | Description | Default |
|----------|-------------|---------|
| `AFFINE_ADMIN_EMAIL` | Admin email | - |
| `AFFINE_ADMIN_PASSWORD` | Admin password | - |

### Database

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection URL | - |
| `DB_USERNAME` | Database username | - |
| `DB_PASSWORD` | Database password | - |
| `DB_DATABASE` | Database name | `affine` |

### Redis

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_SERVER_HOST` | Redis host | - |
| `REDIS_SERVER_PORT` | Redis port | `6379` |
| `REDIS_SERVER_PASSWORD` | Redis password | - |

### Email (SMTP)

| Variable | Description | Default |
|----------|-------------|---------|
| `MAILER_HOST` | SMTP host | - |
| `MAILER_PORT` | SMTP port | - |
| `MAILER_USER` | SMTP username | - |
| `MAILER_PASSWORD` | SMTP password | - |
| `MAILER_SENDER` | SMTP sender address | - |

### OAuth (Optional)

| Variable | Description | Default |
|----------|-------------|---------|
| `OAUTH_GOOGLE_CLIENT_ID` | Google OAuth client ID | - |
| `OAUTH_GOOGLE_CLIENT_SECRET` | Google OAuth secret | - |
| `OAUTH_GITHUB_CLIENT_ID` | GitHub OAuth client ID | - |
| `OAUTH_GITHUB_CLIENT_SECRET` | GitHub OAuth secret | - |

### Storage Locations

| Variable | Description | Default |
|----------|-------------|---------|
| `UPLOAD_LOCATION` | Upload storage path | - |
| `CONFIG_LOCATION` | Config storage path | - |

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/root/.affine/config` | Configuration |
| `/root/.affine/storage` | File storage |

## Config File

Place `config.json` in `${CONFIG_LOCATION}/config.json`:

```json
{
  "server": {
    "externalUrl": "https://affine.example.com"
  }
}
```

## PostgreSQL with pgvector

AFFiNE requires PostgreSQL with pgvector extension:

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_USER: affine
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: affine
```

## Localhost vs Reverse Proxy

For localhost only:
```yaml
environment:
  AFFINE_SERVER_HTTPS: "false"
  AFFINE_SERVER_EXTERNAL_URL: "http://10.10.2.33:3010"
```

For reverse proxy:
```yaml
environment:
  AFFINE_SERVER_HTTPS: "true"
  AFFINE_SERVER_EXTERNAL_URL: "https://affine.example.com"
```

## Documentation

- [AFFiNE Self-Host Docs](https://docs.affine.pro/self-host-affine)
- [Environment Variables](https://docs.affine.pro/self-host-affine/references/environment-variables)
- [GitHub](https://github.com/toeverything/affine)
