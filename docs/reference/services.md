# Services Reference

Complete list of deployed services with container versions and update status.

---

## Version Summary

| Status | Count | Description |
|--------|-------|-------------|
| :white_check_mark: Current | Services using latest or recent stable version |
| :arrow_up: Update Available | Newer version available |
| :warning: Using Latest Tag | Using `latest` tag (version varies) |

---

## AI Namespace

Services for AI/ML workloads with GPU acceleration.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Ollama | `ollama/ollama:latest` | latest | :warning: Using Latest Tag |
| Open WebUI | `ghcr.io/open-webui/open-webui:latest` | latest | :warning: Using Latest Tag |
| ComfyUI | `yanwk/comfyui-boot:cu128-slim` | cu128-slim | :white_check_mark: Current |

**Access:**
- Ollama: http://10.10.2.20:11434
- Open WebUI: http://10.10.2.19
- ComfyUI: http://10.10.2.28

---

## Monitoring Namespace

Observability stack for metrics collection and visualization.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| VictoriaMetrics | `victoriametrics/victoria-metrics:v1.111.0` | v1.134.0 | :arrow_up: Update Available |
| VMAgent | `victoriametrics/vmagent:v1.111.0` | v1.134.0 | :arrow_up: Update Available |
| Grafana | `grafana/grafana:11.4.0` | 12.4.x | :arrow_up: Update Available |
| kube-state-metrics | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0` | v2.18.0 | :arrow_up: Update Available |
| Node Exporter | `quay.io/prometheus/node-exporter:v1.8.2` | v1.10.2 | :arrow_up: Update Available |

**Access:**
- Grafana: http://10.10.2.23
- VictoriaMetrics: http://10.10.2.24

---

## Media Namespace

Photo backup and media streaming services.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Immich Server | `ghcr.io/immich-app/immich-server:v2.4.0` | v2.4.1 | :arrow_up: Minor Update |
| Immich ML | `ghcr.io/immich-app/immich-machine-learning:v2.4.0-cuda` | v2.4.1-cuda | :arrow_up: Minor Update |
| Immich Postgres | `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` | Custom | :white_check_mark: Current |
| Valkey (Redis) | `valkey/valkey:9` | 9.x | :white_check_mark: Current |
| Emby | `lscr.io/linuxserver/emby:latest` | latest | :warning: Using Latest Tag |
| Navidrome | `docker.io/deluan/navidrome:latest` | latest | :warning: Using Latest Tag |

**Access:**
- Immich: http://10.10.2.22
- Emby: http://10.10.2.30
- Navidrome: http://10.10.2.31

---

## Arr-Stack Namespace

Media automation and download management.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| SABnzbd | `ghcr.io/hotio/sabnzbd:latest` | latest | :warning: Using Latest Tag |
| qBittorrent | `ghcr.io/hotio/qbittorrent:latest` | latest | :warning: Using Latest Tag |
| Prowlarr | `ghcr.io/hotio/prowlarr:latest` | latest | :warning: Using Latest Tag |
| Radarr | `ghcr.io/hotio/radarr:latest` | latest | :warning: Using Latest Tag |
| Sonarr | `ghcr.io/hotio/sonarr:latest` | latest | :warning: Using Latest Tag |
| Bazarr | `ghcr.io/hotio/bazarr:latest` | latest | :warning: Using Latest Tag |

**Access:**
- SABnzbd: http://10.10.2.40
- qBittorrent: http://10.10.2.41
- Prowlarr: http://10.10.2.42
- Radarr: http://10.10.2.43
- Sonarr: http://10.10.2.44
- Bazarr: http://10.10.2.45

---

## Automation Namespace

Home automation and workflow services.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:stable` | 2026.1.2 | :white_check_mark: Current (stable tag) |
| n8n | `n8nio/n8n:latest` | 2.x | :warning: Using Latest Tag |
| PostgreSQL | `postgres:16-alpine` | 16-alpine | :white_check_mark: Current |

**Access:**
- Home Assistant: http://10.10.2.25
- n8n: http://10.10.2.26

---

## Backup Namespace

Disaster recovery infrastructure.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| MinIO | `minio/minio:latest` | latest | :warning: Using Latest Tag |
| MinIO Client | `minio/mc:latest` | latest | :warning: Using Latest Tag |

**Access:**
- MinIO Console: http://10.10.2.17

---

## Forgejo Namespace

Git server and CI/CD.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Forgejo Runner | `code.forgejo.org/forgejo/runner:6.3.1` | v11.0.0 | :arrow_up: Update Available |
| Docker DinD | `docker:28-dind` | 28-dind | :white_check_mark: Current |

**Access:**
- Forgejo HTTP: http://10.10.2.13
- Forgejo SSH: ssh://git@10.10.2.14

---

## Management Namespace

Document management and subscription tracking.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Paperless-ngx | `ghcr.io/paperless-ngx/paperless-ngx:latest` | latest | :warning: Using Latest Tag |
| Gotenberg | `docker.io/gotenberg/gotenberg:8.25` | 8.x | :white_check_mark: Current |
| Apache Tika | `docker.io/apache/tika:latest` | latest | :warning: Using Latest Tag |
| PostgreSQL | `docker.io/library/postgres:18` | 18 | :white_check_mark: Current |
| Redis | `docker.io/library/redis:8` | 8 | :white_check_mark: Current |
| Wallos | `docker.io/bellamy/wallos:latest` | latest | :warning: Using Latest Tag |

**Access:**
- Paperless-ngx: http://10.10.2.36
- Wallos: http://10.10.2.34

---

## Printing Namespace

3D printer monitoring.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Obico ML API | `ghcr.io/wdiazux/obico-ml-api:cuda12.3` | Custom | :white_check_mark: Current |
| Obico Web | `ghcr.io/gabe565/obico/web:latest` | latest | :warning: Using Latest Tag |
| Redis | `redis:7-alpine` | 7-alpine | :white_check_mark: Current |

**Access:**
- Obico: http://10.10.2.27

---

## Tools Namespace

Developer utilities and services.

| Service | Current Image | Latest Version | Status |
|---------|---------------|----------------|--------|
| Attic | `ghcr.io/zhaofengli/attic:latest` | latest | :warning: Using Latest Tag |
| Homepage | `ghcr.io/gethomepage/homepage:latest` | latest | :warning: Using Latest Tag |
| IT-Tools | `corentinth/it-tools:latest` | latest | :warning: Using Latest Tag |
| ntfy | `binwiederhier/ntfy:v2.11.0` | v2.11.0 | :white_check_mark: Current |
| PostgreSQL | `postgres:16-alpine` | 16-alpine | :white_check_mark: Current |

**Access:**
- Attic: http://10.10.2.29
- Homepage: http://10.10.2.21
- IT-Tools: http://10.10.2.32
- ntfy: http://10.10.2.35

---

## Update Priority

### High Priority (Security/Stability)

| Service | Current | Latest | Notes |
|---------|---------|--------|-------|
| VictoriaMetrics | v1.111.0 | v1.134.0 | Security updates, Go upgrades |
| VMAgent | v1.111.0 | v1.134.0 | Security updates, Go upgrades |
| kube-state-metrics | v2.13.0 | v2.18.0 | Kubernetes metrics improvements |
| Node Exporter | v1.8.2 | v1.10.2 | Bug fixes |

### Medium Priority (Features)

| Service | Current | Latest | Notes |
|---------|---------|--------|-------|
| Grafana | 11.4.0 | 12.4.x | Major version with new features |
| Forgejo Runner | 6.3.1 | v11.0.0 | Major version upgrade |

### Low Priority (Minor Updates)

| Service | Current | Latest | Notes |
|---------|---------|--------|-------|
| Immich Server | v2.4.0 | v2.4.1 | Patch release |
| Immich ML | v2.4.0-cuda | v2.4.1-cuda | Patch release |

---

## Version Pinning Recommendations

### Services Using `:latest` Tag

Consider pinning these services to specific versions for reproducibility:

```yaml
# Instead of :latest, use specific versions:
ghcr.io/hotio/radarr:release-5.17.2.9580
ghcr.io/hotio/sonarr:release-4.0.13.2932
n8nio/n8n:1.74.2
minio/minio:RELEASE.2026-01-15T00-00-00Z
```

### Benefits of Version Pinning

1. **Reproducibility**: Same version across environments
2. **Rollback**: Easy to revert to previous version
3. **Security**: Audit trail of deployed versions
4. **Stability**: Avoid unexpected breaking changes

---

## Checking for Updates

```bash
# Check running container versions
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | sort

# Check for Helm chart updates
flux get helmreleases -A

# Check specific image on Docker Hub
skopeo inspect docker://grafana/grafana:latest | jq '.Labels["org.opencontainers.image.version"]'
```

---

## Sources

- [Grafana Docker Hub](https://hub.docker.com/r/grafana/grafana)
- [VictoriaMetrics Releases](https://github.com/VictoriaMetrics/VictoriaMetrics/releases)
- [Immich Releases](https://github.com/immich-app/immich/releases)
- [kube-state-metrics Releases](https://github.com/kubernetes/kube-state-metrics/releases)
- [Node Exporter Releases](https://github.com/prometheus/node_exporter/releases)
- [ntfy Releases](https://github.com/binwiederhier/ntfy/releases)
- [Forgejo Runner Releases](https://code.forgejo.org/forgejo/runner/releases)
- [Open WebUI Releases](https://github.com/open-webui/open-webui/releases)
- [Home Assistant Releases](https://github.com/home-assistant/core/releases)
- [n8n Releases](https://github.com/n8n-io/n8n/releases)
- [Gotenberg Releases](https://github.com/gotenberg/gotenberg/releases)

---

**Last Updated:** 2026-01-20
