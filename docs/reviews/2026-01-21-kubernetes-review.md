# Kubernetes Review - 2026-01-21

Automated review of Kubernetes manifests against reference template and best practices.

**Cluster Version**: v1.35.0
**Reference Template**: `docs/reference/k8s-service-template.md`

## Summary

| Category | Critical | Warning | Info |
|----------|----------|---------|------|
| API Versions | 0 | 0 | 0 |
| Labels | 0 | 1 | 0 |
| Resources | 0 | 21 | 0 |
| Health Probes | 0 | 1 | 0 |
| Security Contexts | 0 | 3 | 0 |
| Image Tags | 0 | 2 | 1 |
| **Total** | **0** | **28** | **1** |

## Statistics

- **Total Deployments**: 36
- **Total StatefulSets**: 6
- **Total DaemonSets**: 1
- **Namespaces Covered**: 11

## Critical (0)

None found. All API versions are current for Kubernetes v1.35.0.

## Warning (28)

### Labels

#### [K8S-001] Missing `app.kubernetes.io/part-of` label in DaemonSet
- **File**: `kubernetes/apps/base/monitoring/node-exporter/daemonset.yaml:8`
- **Current**: Has `app.kubernetes.io/name` and `app.kubernetes.io/component` but missing `part-of`
- **Fix**: Add `app.kubernetes.io/part-of: monitoring` to metadata.labels and spec.template.metadata.labels
- **Docs**: `docs/reference/k8s-service-template.md#required-labels`

### Missing Resource Requests/Limits

The following deployments are missing `resources` blocks entirely:

#### [K8S-002] Missing resource limits - it-tools
- **File**: `kubernetes/apps/base/tools/it-tools/deployment.yaml:32`
- **Current**: No `resources` block defined
- **Impact**: Pod could be OOM-killed or evicted without warning; no resource accounting
- **Fix**: Add:
```yaml
resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    memory: 128Mi
```

#### [K8S-003] Missing resource limits - attic
- **File**: `kubernetes/apps/base/tools/attic/deployment.yaml:50`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 128Mi request, 512Mi limit for Nix cache server)

#### [K8S-004] Missing resource limits - homepage
- **File**: `kubernetes/apps/base/tools/homepage/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 64Mi request, 256Mi limit)

#### [K8S-005] Missing resource limits - ntfy
- **File**: `kubernetes/apps/base/tools/ntfy/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 32Mi request, 128Mi limit)

#### [K8S-006] Missing resource limits - wallos
- **File**: `kubernetes/apps/base/management/wallos/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 64Mi request, 256Mi limit)

#### [K8S-007] Missing resource limits - navidrome
- **File**: `kubernetes/apps/base/media/navidrome/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 128Mi request, 512Mi limit for music streaming)

#### [K8S-008] Missing resource limits - open-webui
- **File**: `kubernetes/apps/base/ai/open-webui/deployment.yaml:31`
- **Current**: No `resources` block defined
- **Impact**: LLM frontend can consume significant memory
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit)

#### [K8S-009] Missing resource limits - radarr
- **File**: `kubernetes/apps/base/arr-stack/radarr/deployment.yaml:31`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 128Mi request, 512Mi limit)

#### [K8S-010] Missing resource limits - sonarr
- **File**: `kubernetes/apps/base/arr-stack/sonarr/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 128Mi request, 512Mi limit)

#### [K8S-011] Missing resource limits - bazarr
- **File**: `kubernetes/apps/base/arr-stack/bazarr/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 64Mi request, 256Mi limit)

#### [K8S-012] Missing resource limits - prowlarr
- **File**: `kubernetes/apps/base/arr-stack/prowlarr/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 64Mi request, 256Mi limit)

#### [K8S-013] Missing resource limits - sabnzbd
- **File**: `kubernetes/apps/base/arr-stack/sabnzbd/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit for download processing)

#### [K8S-014] Missing resource limits - qbittorrent
- **File**: `kubernetes/apps/base/arr-stack/qbittorrent/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 128Mi request, 512Mi limit)

#### [K8S-015] Missing resource limits - home-assistant
- **File**: `kubernetes/apps/base/automation/home-assistant/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit)

#### [K8S-016] Missing resource limits - n8n
- **File**: `kubernetes/apps/base/automation/n8n/deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit for workflow automation)

#### [K8S-017] Missing resource limits - affine-server
- **File**: `kubernetes/apps/base/tools/affine/server-deployment.yaml:77`
- **Current**: No `resources` block defined
- **Impact**: Knowledge base server can use significant memory
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit)

#### [K8S-018] Missing resource limits - affine-redis
- **File**: `kubernetes/apps/base/tools/affine/redis-deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 64Mi request, 256Mi limit)

#### [K8S-019] Missing resource limits - immich-server
- **File**: `kubernetes/apps/base/media/immich/server-deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit)

#### [K8S-020] Missing resource limits - paperless server
- **File**: `kubernetes/apps/base/management/paperless/server-deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit)

#### [K8S-021] Missing resource limits - obico-server
- **File**: `kubernetes/apps/base/printing/obico/server-deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 1Gi limit)

#### [K8S-022] Missing resource limits - obico-ml-api
- **File**: `kubernetes/apps/base/printing/obico/ml-api-deployment.yaml`
- **Current**: No `resources` block defined
- **Fix**: Add resources block (recommend 256Mi request, 2Gi limit for ML inference)

### Health Probes

#### [K8S-023] Missing readiness probe - forgejo-runner
- **File**: `kubernetes/apps/base/forgejo/runner/deployment.yaml:121`
- **Current**: Has liveness probe but no readiness probe for runner container
- **Impact**: Service may route traffic before runner is fully operational
- **Note**: Acceptable for CI runner; readinessProbe is optional for non-service workloads

### Security Context

#### [K8S-024] Missing securityContext for obico-redis
- **File**: `kubernetes/apps/base/printing/obico/redis-deployment.yaml:26`
- **Current**: No pod-level securityContext defined
- **Fix**: Add fsGroup if mounting persistent volumes, or add container-level securityContext

#### [K8S-025] Missing securityContext for immich-ml
- **File**: `kubernetes/apps/base/media/immich/ml-deployment.yaml:30`
- **Current**: No securityContext (using runtimeClassName: nvidia)
- **Note**: GPU workloads often require privileged access; acceptable if intentional

#### [K8S-026] Missing securityContext for immich-redis
- **File**: `kubernetes/apps/base/media/immich/redis-deployment.yaml`
- **Current**: No pod-level securityContext defined
- **Fix**: Add securityContext with appropriate fsGroup

### Image Tags

#### [K8S-027] Using `:latest` tag - it-tools
- **File**: `kubernetes/apps/base/tools/it-tools/deployment.yaml:34`
- **Image**: `corentinth/it-tools:latest`
- **Note**: Documented exception - official repo inactive since Oct 2024; acceptable for stateless utility
- **Status**: Has IMAGE POLICY EXCEPTION comment - acceptable

#### [K8S-028] Using `:latest` tag - attic
- **File**: `kubernetes/apps/base/tools/attic/deployment.yaml:51`
- **Image**: `ghcr.io/zhaofengli/attic:latest`
- **Note**: Documented exception - Attic doesn't publish semantic version tags
- **Status**: Has IMAGE POLICY EXCEPTION comment - acceptable

## Info (1)

#### [K8S-029] Using `:latest` tag in Job - minio init-bucket
- **File**: `kubernetes/apps/base/backup/minio/init-bucket-job.yaml:25`
- **Image**: `minio/mc:latest`
- **Impact**: One-time Job; low risk but could pin to specific version
- **Recommendation**: Pin to specific version like `minio/mc:RELEASE.2025-10-15T17-29-55Z`

## Compliant Workloads

The following workloads fully comply with the reference template:

| Workload | Namespace | Type | Labels | Resources | Probes | Security |
|----------|-----------|------|--------|-----------|--------|----------|
| ollama | ai | StatefulSet | ✅ | ✅ | ✅ | ✅ |
| comfyui | ai | Deployment | ✅ | ✅ | ✅ | ✅ |
| immich-machine-learning | media | Deployment | ✅ | ✅ | ✅ | ⚠️ |
| emby | media | Deployment | ✅ | ⚠️ | ✅ | ✅ |
| grafana | monitoring | Deployment | ✅ | ✅ | ✅ | ✅ |
| victoriametrics | monitoring | Deployment | ✅ | ✅ | ✅ | ✅ |
| vmagent | monitoring | Deployment | ✅ | ✅ | ✅ | ✅ |
| kube-state-metrics | monitoring | Deployment | ✅ | ✅ | ✅ | ✅ |
| node-exporter | monitoring | DaemonSet | ⚠️ | ✅ | ✅ | ✅ |
| minio | backup | Deployment | ✅ | ✅ | ✅ | ✅ |
| twitch-miner | misc | Deployment | ✅ | ✅ | ⚠️ | ✅ |
| forgejo-runner | forgejo | Deployment | ✅ | ✅ | ⚠️ | ✅ |
| postgres (all) | various | StatefulSet | ✅ | ✅ | ✅ | ✅ |
| redis (paperless) | management | Deployment | ✅ | ✅ | ✅ | ✅ |

## Recommendations

### Priority 1: Add Resource Limits
21 deployments are missing resource definitions. This should be addressed to:
- Prevent noisy neighbor problems on the single-node cluster
- Enable proper resource accounting in monitoring
- Prevent unexpected OOM kills

**Suggested approach**: Start with memory-intensive workloads (AI, media, automation) then address utilities.

### Priority 2: Security Context Consistency
3 workloads missing explicit securityContext. Consider adding:
```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
```

### Priority 3: No Action Required
- `:latest` tags with documented exceptions are acceptable
- Missing readinessProbe on CI runners is acceptable (non-service workloads)

## Verification Commands

```bash
# Check for pods without resource limits
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.namespace + "/" + .metadata.name'

# Check for pods without probes
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].livenessProbe == null) | .metadata.namespace + "/" + .metadata.name'

# Check image tags in use
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.containers[*].image}{"\n"}{end}' | grep latest
```

---
**Generated**: 2026-01-21
**Tool**: review-kubernetes skill
**Next Review**: Recommended after adding resource limits
