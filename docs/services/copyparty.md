# Copyparty

Portable file server with accelerated uploads, WebDAV, SFTP, and media indexing.

**Image**: `copyparty/ac:latest`
**Namespace**: `tools`
**IP**: `10.10.2.37`

## Configuration Method

Copyparty primarily uses a configuration file (`copyparty.conf`) rather than environment variables.

**Note**: Copyparty does not natively interpolate environment variables in its config file. A template engine workaround is recommended for secrets.

## Environment Variables

Limited environment variable support for disabling features:

| Variable | Description | Default |
|----------|-------------|---------|
| `NO_AUDIO_TRANSCODE` | Disable audio transcoding | - |
| `NO_THUMBNAILS` | Disable thumbnail generation | - |
| `NO_VTHUMB` | Disable video thumbnails | - |

## Command-Line Arguments

Most configuration is done via command-line arguments:

| Argument | Description |
|----------|-------------|
| `-v /path::rwmd` | Volume with read/write/move/delete permissions |
| `-a user:pass` | Add user with password |
| `-p PORT` | HTTP port |
| `--no-reload` | Disable config auto-reload |
| `--no-robots` | Disable robots.txt |

## Configuration File (`copyparty.conf`)

```ini
[global]
; General settings
p: 3923
; Number of upload threads
j: 4

[/files]
; Path mapping
src: /mnt/files
; Permissions: r=read, w=write, m=move, d=delete
perm: rwmd

[/public]
src: /mnt/public
perm: r
; Anonymous access
anon: true
```

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/mnt/files` | File storage |
| `/cfg` | Configuration files |
| `/db` | Database files |

## Image Variants

| Image | Features |
|-------|----------|
| `copyparty/ac` | Audio transcoding, image formats, video thumbnails |
| `copyparty/im` | Image formats only |
| `copyparty/min` | Minimal, no extras |

## Template Engine Workaround for Secrets

For environment variable support, use a template container:

```yaml
services:
  copyparty-config:
    image: hairyhenderson/gomplate
    command: ["-f", "/templates/copyparty.conf.tmpl", "-o", "/config/copyparty.conf"]
    volumes:
      - ./templates:/templates
      - copyparty-config:/config
    environment:
      - COPYPARTY_USER=${COPYPARTY_USER}
      - COPYPARTY_PASS=${COPYPARTY_PASS}

  copyparty:
    image: copyparty/ac:latest
    depends_on:
      copyparty-config:
        condition: service_completed_successfully
    volumes:
      - copyparty-config:/cfg:ro
```

## Example Deployment

```yaml
services:
  copyparty:
    image: copyparty/ac:latest
    command: >
      -v /data::rwmd
      -a admin:password
      -p 3923
    ports:
      - "3923:3923"
    volumes:
      - /path/to/files:/data
      - copyparty-db:/db
```

## Documentation

- [Copyparty GitHub](https://github.com/9001/copyparty)
- [Docker Hub](https://hub.docker.com/u/copyparty)
