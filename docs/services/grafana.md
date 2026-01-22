# Grafana

Observability and data visualization platform.

**Image**: `grafana/grafana:12.3.1`
**Namespace**: `monitoring`
**IP**: `10.10.2.23`

## Environment Variables

Environment variables follow the pattern `GF_<SECTION>_<KEY>`:

### Security

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_SECURITY_ADMIN_USER` | Admin username | `admin` |
| `GF_SECURITY_ADMIN_PASSWORD` | Admin password | `admin` |
| `GF_SECURITY_SECRET_KEY` | Secret key for signing | - |
| `GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION` | Skip admin creation | `false` |

### Server

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_SERVER_ROOT_URL` | Root URL for reverse proxy | - |
| `GF_SERVER_HTTP_PORT` | HTTP port | `3000` |
| `GF_SERVER_PROTOCOL` | Protocol (http/https) | `http` |
| `GF_SERVER_DOMAIN` | Domain name | `localhost` |
| `GF_SERVER_SERVE_FROM_SUB_PATH` | Serve from sub-path | `false` |

### Database

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_DATABASE_TYPE` | Database type (sqlite3, mysql, postgres) | `sqlite3` |
| `GF_DATABASE_HOST` | Database host | - |
| `GF_DATABASE_NAME` | Database name | - |
| `GF_DATABASE_USER` | Database user | - |
| `GF_DATABASE_PASSWORD` | Database password | - |
| `GF_DATABASE_SSL_MODE` | SSL mode | `disable` |

### Users

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_USERS_ALLOW_SIGN_UP` | Allow user sign-up | `false` |
| `GF_USERS_ALLOW_ORG_CREATE` | Allow org creation | `false` |
| `GF_USERS_DEFAULT_THEME` | Default theme (dark/light) | `dark` |
| `GF_USERS_AUTO_ASSIGN_ORG` | Auto-assign to org | `true` |
| `GF_USERS_AUTO_ASSIGN_ORG_ROLE` | Default role | `Viewer` |

### Authentication

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_AUTH_ANONYMOUS_ENABLED` | Enable anonymous access | `false` |
| `GF_AUTH_ANONYMOUS_ORG_ROLE` | Anonymous user role | `Viewer` |
| `GF_AUTH_BASIC_ENABLED` | Enable basic auth | `true` |
| `GF_AUTH_DISABLE_LOGIN_FORM` | Disable login form | `false` |

### SMTP (Email)

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_SMTP_ENABLED` | Enable SMTP | `false` |
| `GF_SMTP_HOST` | SMTP host:port | - |
| `GF_SMTP_USER` | SMTP username | - |
| `GF_SMTP_PASSWORD` | SMTP password | - |
| `GF_SMTP_FROM_ADDRESS` | From address | - |
| `GF_SMTP_FROM_NAME` | From name | `Grafana` |

### Plugins

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_PLUGINS_PREINSTALL` | Plugins to install (comma-separated) | - |
| `GF_INSTALL_PLUGINS` | Legacy plugin installation | - |

### Performance

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_ENABLE_GZIP` | Enable gzip compression | `false` |

### Logging

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_LOG_MODE` | Log mode (console, file) | `console` |
| `GF_LOG_LEVEL` | Log level | `info` |

## Docker Secrets Support

Variables support the `__FILE` suffix pattern:
- `GF_SECURITY_ADMIN_PASSWORD__FILE`
- `GF_DATABASE_PASSWORD__FILE`

## Provisioning

Mount provisioning files:
```yaml
volumes:
  - ./provisioning/datasources:/etc/grafana/provisioning/datasources
  - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards
```

Use `$ENV_VAR` or `${ENV_VAR}` syntax in provisioning files.

## Documentation

- [Configure Grafana Docker](https://grafana.com/docs/grafana/latest/setup-grafana/configure-docker/)
- [Environment Variables](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
