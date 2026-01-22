# Paperless-ngx

Document management system with OCR capabilities.

**Image**: `ghcr.io/paperless-ngx/paperless-ngx:2.20.5`
**Supporting Images**:
- Tika: `docker.io/apache/tika:3.2.3.0`
- Gotenberg: `docker.io/gotenberg/gotenberg:8.25.1`
- PostgreSQL: `docker.io/library/postgres:18`
- Redis: `docker.io/library/redis:8`

**Namespace**: `management`
**IP**: `10.10.2.36`

## Environment Variables

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_URL` | Public URL (required for external access) | - |
| `PAPERLESS_SECRET_KEY` | Django secret key | Auto-generated |
| `PAPERLESS_TIME_ZONE` | Timezone | `UTC` |
| `PAPERLESS_OCR_LANGUAGE` | OCR language(s) | `eng` |

### Admin Setup

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_ADMIN_USER` | Auto-create admin username | - |
| `PAPERLESS_ADMIN_PASSWORD` | Auto-create admin password | - |
| `PAPERLESS_ADMIN_MAIL` | Admin email | - |

### User Mapping

| Variable | Description | Default |
|----------|-------------|---------|
| `USERMAP_UID` | User ID for container | `1000` |
| `USERMAP_GID` | Group ID for container | `1000` |

### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_DBENGINE` | Database engine (`postgresql`, `mariadb`) | `sqlite` |
| `PAPERLESS_DBHOST` | Database host | - |
| `PAPERLESS_DBPORT` | Database port | - |
| `PAPERLESS_DBNAME` | Database name | - |
| `PAPERLESS_DBUSER` | Database username | - |
| `PAPERLESS_DBPASS` | Database password | - |
| `PAPERLESS_REDIS` | Redis URL | `redis://localhost:6379` |

### Storage Paths

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_CONSUMPTION_DIR` | Consumption directory | `/consume` |
| `PAPERLESS_DATA_DIR` | Data directory | `/data` |
| `PAPERLESS_MEDIA_ROOT` | Media storage path | `/media` |
| `PAPERLESS_TRASH_DIR` | Trash directory | - |

### Consumer Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_CONSUMER_POLLING` | Polling interval (seconds, 0=inotify) | `0` |
| `PAPERLESS_CONSUMER_DELETE_DUPLICATES` | Delete duplicate documents | `false` |
| `PAPERLESS_CONSUMER_RECURSIVE` | Recursive consumption | `false` |
| `PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS` | Use subdirs as tags | `false` |
| `PAPERLESS_FILENAME_FORMAT` | Filename format for documents | - |

### Tika Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_TIKA_ENABLED` | Enable Tika for Office docs | `0` |
| `PAPERLESS_TIKA_ENDPOINT` | Tika server URL | - |
| `PAPERLESS_TIKA_GOTENBERG_ENDPOINT` | Gotenberg server URL | - |

### OCR Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_OCR_LANGUAGE` | OCR languages (e.g., `eng+deu`) | `eng` |
| `PAPERLESS_OCR_MODE` | OCR mode (`skip`, `redo`, `force`) | `skip` |
| `PAPERLESS_OCR_OUTPUT_TYPE` | Output type (`pdf`, `pdfa`) | `pdfa` |
| `PAPERLESS_OCR_PAGES` | Number of pages to OCR (0=all) | `0` |

### Scripts

| Variable | Description | Default |
|----------|-------------|---------|
| `PAPERLESS_PRE_CONSUME_SCRIPT` | Pre-consume script path | - |
| `PAPERLESS_POST_CONSUME_SCRIPT` | Post-consume script path | - |

## Docker Secrets Support

Variables support the `_FILE` suffix pattern:
- `PAPERLESS_DBPASS_FILE`
- `PAPERLESS_SECRET_KEY_FILE`

## Tika/Gotenberg Setup

For Office document support (Word, Excel, PowerPoint):

```yaml
services:
  tika:
    image: apache/tika:3.2.3.0

  gotenberg:
    image: gotenberg/gotenberg:8.25.1
    command:
      - "gotenberg"
      - "--chromium-disable-javascript=true"
      - "--chromium-allow-list=file:///tmp/.*"
```

## Documentation

- [Paperless-ngx Configuration](https://docs.paperless-ngx.com/configuration/)
- [Docker Setup](https://docs.paperless-ngx.com/setup/)
