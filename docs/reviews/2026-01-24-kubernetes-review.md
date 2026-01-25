# Kubernetes Review - 2026-01-24

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| Warning | 5 |
| Info | 19 |

**Overall Status**: ✅ Production-Ready

All manifests use current API versions (apps/v1), include required labels, and follow the established patterns. The codebase follows documented resource and versioning strategies.

---

## Critical

_No critical issues found._

All workloads use stable API versions compatible with Kubernetes v1.35.0.

---

## Warning

### [K8S-W001] Missing `app.kubernetes.io/component` label
**Impact**: Inconsistent labeling for service discovery

| File | Service |
|------|---------|
| `kubernetes/apps/base/tools/attic/postgres-statefulset.yaml:11` | attic-db |

**Current**: Only has `app.kubernetes.io/name` and `app.kubernetes.io/part-of`
**Fix**: Add `app.kubernetes.io/component: database`

---

### [K8S-W002] Missing `fsGroupChangePolicy` in securityContext
**Impact**: Potential slow startup on large volumes

| File | Service |
|------|---------|
| `kubernetes/apps/base/tools/ntfy/deployment.yaml:26` | ntfy |
| `kubernetes/apps/base/management/wallos/deployment.yaml:29` | wallos |

**Fix**: Add `fsGroupChangePolicy: "OnRootMismatch"` to pod securityContext

---

### [K8S-W003] Missing TZ environment variable
**Impact**: Inconsistent timezone in logs and schedules

| File | Service |
|------|---------|
| `kubernetes/apps/base/printing/obico/ml-api-deployment.yaml` | obico-ml-api |
| `kubernetes/apps/base/printing/obico/redis-deployment.yaml` | obico-redis |
| `kubernetes/apps/base/tools/attic/postgres-statefulset.yaml` | attic-db |

**Fix**: Add `env: - name: TZ value: "America/El_Salvador"`

---

### [K8S-W004] Forgejo runner missing readinessProbe
**Impact**: Service may receive traffic before ready

| File | Container |
|------|-----------|
| `kubernetes/apps/base/forgejo/runner/deployment.yaml:104` | runner |

**Note**: The runner container only has a livenessProbe checking if the process is running. Consider adding a readinessProbe.

---

### [K8S-W005] Obico tasks sidecar missing probes
**Impact**: Unhealthy sidecar won't be detected

| File | Container |
|------|-----------|
| `kubernetes/apps/base/printing/obico/server-deployment.yaml:131` | tasks |

**Fix**: Add livenessProbe to the Celery worker sidecar.

---

## Info

### [K8S-I001] No CPU requests - By Design
Per `docs/reference/resource-strategy.md`, this single-node homelab intentionally omits CPU requests/limits for user apps:

> **CPU**: No requests, no limits (avoids scheduling issues, allows burst)
> Single-node means no scheduler competition - CPU requests just block deployments

This is the correct configuration for this environment.

---

### [K8S-I002] Image versioning follows documented policy
Per `docs/reference/resource-strategy.md` "Image Versioning Policy":

| Pattern | Policy | Status |
|---------|--------|--------|
| `:latest` for user apps | ✅ Allowed | IT-Tools, Attic, Copyparty follow policy |
| Rolling tags (`:release`) | ✅ Allowed with docs | Obico has exception comment |
| Major version tags (`:16-alpine`, `:8`) | ✅ Allowed | PostgreSQL, Redis follow policy |
| Pin all components | Required for Immich only | ✅ Compliant |

All images follow the documented versioning strategy.

---

### [K8S-I003] Services with excellent security hardening
The following services demonstrate best-practice security configurations:

| Service | Features |
|---------|----------|
| kube-state-metrics | `runAsNonRoot`, `readOnlyRootFilesystem`, `seccompProfile`, `capabilities.drop: ALL` |
| node-exporter | `runAsNonRoot`, `readOnlyRootFilesystem`, `seccompProfile`, `capabilities.drop: ALL` |
| zitadel-redis | `runAsNonRoot`, `seccompProfile`, `capabilities.drop: ALL` |
| paperless-redis | `runAsNonRoot`, `seccompProfile`, `capabilities.drop: ALL` |
| affine-redis | `runAsNonRoot`, `seccompProfile`, `capabilities.drop: ALL` |
| homepage | `runAsNonRoot`, `seccompProfile`, `capabilities.drop: ALL` |

---

### [K8S-I004] GPU workloads properly configured
All GPU workloads use:
- `runtimeClassName: nvidia`
- `nvidia.com/gpu` resource requests/limits
- `NVIDIA_VISIBLE_DEVICES` environment variable

| Service | GPU Usage |
|---------|-----------|
| comfyui | Image generation |
| ollama | LLM inference |
| emby | Video transcoding |
| obico-ml-api | Failure detection |
| immich-machine-learning | Facial recognition |

---

### [K8S-I005] Services using FluxCD image automation
The following services have properly configured image policies:

| Service | Policy Reference |
|---------|-----------------|
| victoriametrics | `flux-system:victoria-metrics` |
| vmagent | `flux-system:vmagent` |
| kube-state-metrics | `flux-system:kube-state-metrics` |
| grafana | `flux-system:grafana` |
| node-exporter | `flux-system:node-exporter` |
| twitch-miner | `flux-system:twitch-miner` |
| ollama | `flux-system:ollama` |
| open-webui | `flux-system:open-webui` |
| minio | `flux-system:minio` |
| ntfy | `flux-system:ntfy` |
| navidrome | `flux-system:navidrome` |
| prowlarr | `flux-system:prowlarr` |
| sonarr | `flux-system:sonarr` |
| bazarr | `flux-system:bazarr` |
| radarr | `flux-system:radarr` |
| n8n | `flux-system:n8n` |
| home-assistant | `flux-system:home-assistant` |
| emby | `flux-system:emby` |
| wallos | `flux-system:wallos` |
| qbittorrent | `flux-system:qbittorrent` |
| sabnzbd | `flux-system:sabnzbd` |
| homepage | `flux-system:homepage` |
| immich-machine-learning | `flux-system:immich-machine-learning` |
| immich-server | `flux-system:immich-server` |
| paperless-ngx | `flux-system:paperless-ngx` |
| tika | `flux-system:tika` |
| gotenberg | `flux-system:gotenberg` |
| affine | `flux-system:affine` |

---

### [K8S-I006] All workloads have health probes
All 50+ containers have livenessProbe and readinessProbe configured (except minor exceptions noted in warnings).

---

### [K8S-I007] Consistent header comments
All deployment files include descriptive header comments with service description and documentation links.

---

### [K8S-I008] Consistent label structure
All workloads follow the `app.kubernetes.io/*` labeling convention:
- `app.kubernetes.io/name` - Service name
- `app.kubernetes.io/component` - server, database, cache, etc.
- `app.kubernetes.io/part-of` - Namespace or parent service

---

### [K8S-I009] StatefulSets properly configured
All StatefulSets include:
- `serviceName` matching the service
- `volumeClaimTemplates` for persistent storage
- Appropriate `storageClassName: longhorn`

---

### [K8S-I010] Services using enableServiceLinks: false
The following services disable Kubernetes service link injection to prevent port conflicts:

| Service | Reason |
|---------|--------|
| immich-server | Prevents IMMICH_PORT conflict |
| immich-machine-learning | Prevents IMMICH_PORT conflict |
| paperless-server | Prevents PAPERLESS_PORT conflict |
| affine-server | Prevents port conflict |

---

### [K8S-I011] Init containers for database dependencies
Services properly wait for database dependencies:

| Service | Waits For |
|---------|-----------|
| attic | PostgreSQL |
| paperless-server | PostgreSQL, Redis |
| affine-server | PostgreSQL, Redis |

---

### [K8S-I012] Named ports consistently used
All services use named ports (http, redis, postgres, etc.) instead of just port numbers.

---

### [K8S-I013] Privileged containers properly documented
All privileged containers have justification comments explaining why elevated permissions are required:

| File | Container | Justification |
|------|-----------|---------------|
| `home-assistant/deployment.yaml:84` | home-assistant | mDNS/SSDP/UPnP device discovery |
| `forgejo/runner/deployment.yaml:154` | docker-dind | Docker-in-Docker for CI/CD |

---

### [K8S-I014] Root containers properly documented
All containers running as root have justification comments:

| File | Container | Justification |
|------|-----------|---------------|
| `minio/deployment.yaml:44` | minio | NFS permission compatibility |
| `forgejo/runner/deployment.yaml:44` | register (init) | Docker socket access |
| `forgejo/runner/deployment.yaml:111` | runner | Docker socket access |

---

### [K8S-I015] Resource strategy compliance
All services follow `docs/reference/resource-strategy.md`:

| Category | Memory Request | Memory Limit | CPU | Compliant |
|----------|----------------|--------------|-----|-----------|
| Core Infrastructure | ✅ Set | ✅ Set | ✅ Set | ✅ |
| AI/GPU Workloads | ✅ Small | ✅ Large | ✅ None | ✅ |
| Databases | ✅ Small | ✅ Medium | ✅ None | ✅ |
| Heavy Apps | ✅ Medium | ✅ Large | ✅ None | ✅ |
| Medium Apps | ✅ Small | ✅ Medium | ✅ None | ✅ |
| Light Apps | ✅ Minimal | ✅ Small | ✅ None | ✅ |
| Redis/Cache | ✅ Small | ✅ Small | ✅ None | ✅ |

---

### [K8S-I016] Latest tag exceptions documented
Services using `:latest` have inline exception comments:

| Service | Comment Location |
|---------|-----------------|
| it-tools | deployment.yaml:7-10 |
| attic | deployment.yaml:6-9 |
| obico-server | deployment.yaml:6-8 (uses `:release`) |
| copyparty | documented in `docs/services/copyparty.md` |

---

### [K8S-I017] Memory limits prevent OOM kills
All user apps have memory limits set to protect against runaway processes, per resource strategy.

---

### [K8S-I018] QoS class appropriate for workload type
- **Burstable**: All user apps (memory-only resources)
- **Guaranteed**: Core infrastructure only (Cilium, Longhorn, Flux)

---

### [K8S-I019] Documentation references
Key documentation that governs Kubernetes configuration:

| Document | Purpose |
|----------|---------|
| `docs/reference/resource-strategy.md` | CPU/Memory policy, image versioning |
| `docs/reference/k8s-service-template.md` | Manifest structure standards |
| `docs/reference/security-strategy.md` | Security posture and threat model |

---

## Recommendations

### To Fix
1. Add `app.kubernetes.io/component: database` label to attic-db
2. Add `fsGroupChangePolicy: "OnRootMismatch"` to ntfy and wallos
3. Add TZ environment variable to obico-ml-api, obico-redis, attic-db
4. Add readinessProbe to forgejo-runner container
5. Add livenessProbe to obico tasks sidecar

### Optional Improvements
_None - all services follow documented standards_

---

## Comparison to Previous Review

_This is the first Kubernetes-specific review. Previous Terraform review: 2026-01-22._

---

## Next Steps

1. Fix the 5 minor warnings
2. Schedule next review for 2026-04-24 (quarterly)

---

**Reviewed by**: Claude Opus 4.5
**Review Date**: 2026-01-24
**Next Review**: 2026-04-24 (quarterly)
