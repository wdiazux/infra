# VictoriaMetrics

Fast, cost-effective monitoring solution and time series database.

## Images

| Component | Registry | Image | Version |
|-----------|----------|-------|---------|
| VictoriaMetrics | Docker Hub | `victoriametrics/victoria-metrics` | `v1.134.0` |
| VMAgent | Docker Hub | `victoriametrics/vmagent` | `v1.134.0` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `monitoring` |
| IP | `10.10.2.24` |
| Port | `8428` |
| URL | `https://metrics.home-infra.net` |

## Configuration Method

VictoriaMetrics uses command-line flags. Enable environment variable reading with `-envflag.enable`.

## Environment Variables

### Environment Flag Support

| Variable | Description | Default |
|----------|-------------|---------|
| `-envflag.enable` | Enable reading flags from env vars | `false` |
| `-envflag.prefix` | Prefix for environment variables | - |

When enabled, flags like `-storageDataPath` become `storageDataPath` env var (or with prefix: `VM_storageDataPath`).

### Common Flags (as Environment Variables)

| Flag / Env Var | Description | Default |
|----------------|-------------|---------|
| `storageDataPath` | Data storage path | `victoria-metrics-data` |
| `retentionPeriod` | Data retention period (months) | `1` |
| `httpListenAddr` | HTTP listen address | `:8428` |
| `search.maxConcurrentRequests` | Max concurrent queries | CPU cores * 2 |
| `search.maxQueueDuration` | Max queue duration for queries | `10s` |
| `search.maxMemoryPerQuery` | Max memory per query | - |
| `memory.allowedPercent` | Memory usage percentage | `60` |

### Performance Tuning

| Variable | Description | Default |
|----------|-------------|---------|
| `GOMAXPROCS` | Go max processes | Number of CPUs |
| `GOGC` | Go garbage collection target | `100` |

### VMAgent Specific

| Flag / Env Var | Description | Default |
|----------------|-------------|---------|
| `promscrape.config` | Prometheus scrape config path | - |
| `remoteWrite.url` | Remote write URL | - |
| `remoteWrite.maxDiskUsagePerURL` | Max disk buffer per URL | `0` (unlimited) |

## Config File Placeholders

Use `%{ENV_VAR}` in config files for environment variable substitution:

```yaml
scrape_configs:
  - job_name: 'example'
    bearer_token: '%{BEARER_TOKEN}'
```

## Prometheus-Compatible Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/api/v1/write` | Remote write |
| `/api/v1/query` | Instant query |
| `/api/v1/query_range` | Range query |
| `/metrics` | Self metrics |

## Retention Examples

```bash
# Keep data for 1 month
-retentionPeriod=1

# Keep data for 1 year
-retentionPeriod=12

# Keep data for 2 years
-retentionPeriod=24
```

## Example Deployment

```yaml
services:
  victoriametrics:
    image: victoriametrics/victoria-metrics:v1.134.0
    command:
      - '-storageDataPath=/storage'
      - '-retentionPeriod=12'
      - '-httpListenAddr=:8428'
    volumes:
      - vm-data:/storage
    ports:
      - "8428:8428"
```

## Documentation

- [VictoriaMetrics Settings](https://docs.victoriametrics.com/victoriametrics/)
- [VMAgent Docs](https://docs.victoriametrics.com/vmagent.html)
- [Quick Start](https://docs.victoriametrics.com/Quick-Start.html)
- [GitHub](https://github.com/VictoriaMetrics/VictoriaMetrics)
- [Docker Hub](https://hub.docker.com/r/victoriametrics/victoria-metrics)
