# Attic

Self-hosted Nix binary cache with multi-tenancy support.

**Image**: `ghcr.io/zhaofengli/attic:latest`
**Namespace**: `tools`
**IP**: `10.10.2.29`

## Configuration Method

Attic uses a TOML configuration file (`server.toml`). Environment variables can be used within the config using `%{ENV_VAR}` syntax.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ATTIC_SERVER_DATABASE_URL` | Database connection URL | - |
| `ATTIC_SERVER_LISTEN` | Listen address | `[::]:8080` |
| `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` | JWT secret (base64 encoded) | - |
| `RUST_LOG` | Rust log level | `info` |

## Config File Template (`server.toml`)

```toml
listen = "[::]:8080"

# Database configuration
[database]
url = "postgres://user:pass@localhost/attic"

# Storage backend
[storage]
type = "local"
path = "/var/lib/attic/storage"

# Or use S3-compatible storage:
# [storage]
# type = "s3"
# region = "us-east-1"
# bucket = "attic-cache"
# endpoint = "https://s3.example.com"

# JWT signing
[token]
hs256-secret-base64 = "%{ATTIC_JWT_SECRET}"

# Chunking settings
[chunking]
nar-size-threshold = 65536
min-size = 16384
avg-size = 65536
max-size = 262144
```

## Environment Variable Substitution

Use `%{VAR_NAME}` in config files:

```toml
[database]
url = "%{DATABASE_URL}"

[token]
hs256-secret-base64 = "%{JWT_SECRET}"
```

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/var/lib/attic` | Data storage |
| `/etc/attic/server.toml` | Configuration file |

## Token Generation

Generate admin token:

```bash
docker exec -it attic sh -c 'atticadm make-token \
  --sub "admin" \
  --validity "10y" \
  --pull "*" \
  --push "*" \
  --create-cache "*" \
  --configure-cache "*" \
  --configure-cache-retention "*" \
  --destroy-cache "*" \
  --delete "*" \
  -f "/etc/attic/server.toml"'
```

## Cache Operations

```bash
# Login
attic login myserver https://attic.example.com <token>

# Create cache
attic cache create myserver:mycache

# Push store path
attic push myserver:mycache /nix/store/...

# Configure cache
attic cache configure myserver:mycache --retention-period "30 days"
```

## PostgreSQL Setup

Attic requires PostgreSQL:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: attic
      POSTGRES_USER: attic
      POSTGRES_PASSWORD: secret
```

## Documentation

- [Attic GitHub](https://github.com/zhaofengli/attic)
- [Docker Compose Guide](https://nexveridian.com/blog/attic-compose/)
