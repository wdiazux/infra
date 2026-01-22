# ntfy

Self-hosted push notification service.

**Image**: `binwiederhier/ntfy:v2.16.0`
**Namespace**: `tools`
**IP**: `10.10.2.35`

## Environment Variables

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |
| `NTFY_BASE_URL` | Base URL for the server | - |
| `NTFY_LISTEN_HTTP` | HTTP listen address | `:80` |
| `NTFY_BEHIND_PROXY` | Running behind reverse proxy | `false` |

### Cache & Storage

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_CACHE_FILE` | Cache file path | - |
| `NTFY_CACHE_DURATION` | Cache duration | `12h` |
| `NTFY_ATTACHMENT_CACHE_DIR` | Attachment cache directory | - |
| `NTFY_ATTACHMENT_TOTAL_SIZE_LIMIT` | Total attachment size limit | `5G` |
| `NTFY_ATTACHMENT_FILE_SIZE_LIMIT` | Single file size limit | `15M` |
| `NTFY_ATTACHMENT_EXPIRY_DURATION` | Attachment expiry | `3h` |

### Authentication

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_AUTH_FILE` | Auth database file path | - |
| `NTFY_AUTH_DEFAULT_ACCESS` | Default access level | `read-write` |
| `NTFY_ENABLE_LOGIN` | Enable login page | `false` |
| `NTFY_ENABLE_SIGNUP` | Enable user signup | `false` |

### iOS Push (via upstream)

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_UPSTREAM_BASE_URL` | Upstream server for iOS push | `https://ntfy.sh` |

### SMTP (Email Notifications)

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_SMTP_SENDER_ADDR` | SMTP server address | - |
| `NTFY_SMTP_SENDER_USER` | SMTP username | - |
| `NTFY_SMTP_SENDER_PASS` | SMTP password | - |
| `NTFY_SMTP_SENDER_FROM` | SMTP from address | - |

### Web Interface

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_WEB_ROOT` | Web root (app/home/disable) | `app` |

### Rate Limiting

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_VISITOR_REQUEST_LIMIT_BURST` | Request burst limit | `60` |
| `NTFY_VISITOR_REQUEST_LIMIT_REPLENISH` | Replenish rate | `5s` |
| `NTFY_VISITOR_EMAIL_LIMIT_BURST` | Email burst limit | `16` |
| `NTFY_VISITOR_EMAIL_LIMIT_REPLENISH` | Email replenish rate | `1h` |

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/var/cache/ntfy` | Message cache |
| `/etc/ntfy` | Configuration files |

## Configuration File Alternative

Instead of environment variables, use `/etc/ntfy/server.yml`:

```yaml
base-url: "https://ntfy.example.com"
cache-file: "/var/cache/ntfy/cache.db"
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"
behind-proxy: true
```

## User Provisioning

Pre-provision users in `server.yml`:

```yaml
auth-users:
  - user: admin
    pass: "$2a$10$..."  # bcrypt hash
    role: admin
```

## Documentation

- [ntfy Configuration](https://docs.ntfy.sh/config/)
- [Installation Guide](https://docs.ntfy.sh/install/)
- [GitHub](https://github.com/binwiederhier/ntfy)
