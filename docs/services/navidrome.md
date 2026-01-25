# Navidrome

Self-hosted music streaming server compatible with Subsonic/Airsonic clients.

## Image

| Registry | Image | Version |
|----------|-------|---------|
| Docker Hub | `deluan/navidrome` | `0.59.0` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `media` |
| IP | `10.10.2.31` |
| Port | `4533` |
| URL | `https://music.home-infra.net` |

## Environment Variables

All configuration options use the `ND_` prefix. Any option from the config file can be used as an environment variable.

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `ND_MUSICFOLDER` | Path to music folder | `/music` |
| `ND_DATAFOLDER` | Path to data folder | `/data` |
| `ND_SCANSCHEDULE` | How often to scan for changes | `@every 1m` |
| `ND_LOGLEVEL` | Log level (error, warn, info, debug, trace) | `info` |
| `ND_SESSIONTIMEOUT` | Session timeout duration | `24h` |
| `ND_BASEURL` | Base URL for reverse proxy | - |
| `ND_PORT` | HTTP port | `4533` |

### UI Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `ND_UIWELCOMEMESSAGE` | Welcome message on login | - |
| `ND_DEFAULTTHEME` | Default UI theme | `Dark` |
| `ND_ENABLECOVERANIMATION` | Enable cover animation | `true` |

### Features

| Variable | Description | Default |
|----------|-------------|---------|
| `ND_ENABLEDOWNLOADS` | Allow downloading files | `true` |
| `ND_ENABLETRANSCODING` | Enable audio transcoding | `true` |
| `ND_ENABLESHARING` | Enable sharing features | `false` |
| `ND_AUTOIMPORTPLAYLISTS` | Auto-import playlists | `true` |

### Cache Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `ND_TRANSCODINGCACHESIZE` | Transcoding cache size | `100MB` |
| `ND_IMAGECACHESIZE` | Image cache size | `100MB` |

### External Integrations

| Variable | Description | Default |
|----------|-------------|---------|
| `ND_LASTFM_APIKEY` | Last.fm API key | - |
| `ND_LASTFM_SECRET` | Last.fm secret | - |
| `ND_SPOTIFY_ID` | Spotify client ID | - |
| `ND_SPOTIFY_SECRET` | Spotify client secret | - |

### Security

| Variable | Description | Default |
|----------|-------------|---------|
| `ND_PASSWORDENCRYPTIONKEY` | Encryption key for passwords | - |
| `ND_REVERSEPROXYUSERHEADER` | Header for reverse proxy auth | - |
| `ND_REVERSEPROXYWHITELIST` | Allowed IPs for reverse proxy auth | - |

## Duration Format

Duration values use format: `24h`, `30s`, `1h10m`

## Size Format

Size values use format: `100MB`, `1GB`, `150MiB`

## Documentation

- [Configuration Options](https://www.navidrome.org/docs/usage/configuration/options/)
- [Docker Installation](https://www.navidrome.org/docs/installation/docker/)
- [GitHub](https://github.com/navidrome/navidrome)
- [Docker Hub](https://hub.docker.com/r/deluan/navidrome)
