# Review Kubernetes Skill

Reviews Kubernetes manifests for API deprecations, best practices, and structure consistency.

## Purpose

This skill validates:
- API version deprecations
- Required labels (app.kubernetes.io/*)
- Resource requests and limits
- Health probes (liveness, readiness, startup)
- Security contexts
- Structure consistency vs reference template
- Image tag practices

## When to Use

Invoke this skill when:
- Creating new Kubernetes services
- Updating existing deployments
- Before committing K8s manifest changes
- Auditing services for consistency
- After upgrading Kubernetes version

## IMPORTANT: Read Documentation First

**Before flagging any issues**, read these project-specific policy documents:

1. **`docs/reference/resource-strategy.md`** - Defines:
   - CPU/Memory resource policy (no CPU requests for user apps by design)
   - Image versioning policy (`:latest` allowed for user apps)
   - QoS class strategy per service category

2. **`docs/reference/k8s-service-template.md`** - Defines:
   - Required labels and structure
   - Health probe requirements
   - Security context requirements

3. **`docs/reference/security-strategy.md`** - Defines:
   - Acceptable privileged container use cases
   - Security posture for homelab

**Do not flag as warnings items that are intentionally configured per these documents.**

## Reference Pattern

This skill validates against the Grafana deployment pattern documented in:
`docs/reference/k8s-service-template.md`

## Checks Performed

### Critical (Must Fix)

1. **Deprecated API Versions**
   - `extensions/v1beta1` → `apps/v1`
   - `networking.k8s.io/v1beta1` → `networking.k8s.io/v1`
   - Check against current cluster version (v1.35.0)

2. **Security Issues**
   - Containers running as root without explicit need
   - Missing securityContext on privileged workloads
   - Secrets in plain text (should use SOPS .enc.yaml)

### Warning (Should Fix)

**Note**: Check `docs/reference/resource-strategy.md` before flagging resource or image issues.

1. **Missing Labels**
   - `app.kubernetes.io/name` - Required
   - `app.kubernetes.io/component` - Required
   - `app.kubernetes.io/part-of` - Required

2. **Missing Resources** (Check resource-strategy.md first!)
   - `resources.requests.cpu` - **BY DESIGN: Not required for user apps** (single-node homelab)
   - `resources.requests.memory` - Required (small value)
   - `resources.limits.memory` - Required

3. **Missing Probes**
   - `livenessProbe` - Required for all long-running containers
   - `readinessProbe` - Required for services

4. **Image Tags** (Check resource-strategy.md "Image Versioning Policy" first!)
   - `:latest` tag is **ALLOWED** for user apps per policy
   - Only flag if not covered by versioning policy OR missing inline exception comment
   - Immich components must be pinned to same version

5. **Missing Security Context**
   - `fsGroup` when mounting volumes
   - `fsGroupChangePolicy: "OnRootMismatch"` for faster startup

### Info (Nice to Have)

1. **Header Comments**
   - kustomization.yaml should have description header

2. **Environment**
   - TZ variable for timezone consistency

3. **Port Naming**
   - Use named ports (http, https, grpc) not just numbers

## Workflow

1. **Read documentation first** (CRITICAL):
   - `docs/reference/resource-strategy.md` - CPU/memory policy, image versioning
   - `docs/reference/k8s-service-template.md` - Structure requirements
   - `docs/reference/security-strategy.md` - Security posture
2. **Find manifests**: Glob for `*.yaml` in kubernetes/ directory
3. **Parse each file**: Extract kind, apiVersion, metadata, spec
4. **Check API versions**: Compare against deprecation list
5. **Check structure**: Validate against reference template
6. **Check labels**: Verify required labels present
7. **Check resources**: Verify against resource-strategy.md (no CPU requests is BY DESIGN)
8. **Check probes**: Verify health checks configured
9. **Check images**: Verify against Image Versioning Policy (`:latest` often allowed)
10. **Generate report**: Write to `docs/reviews/YYYY-MM-DD-kubernetes-review.md`
    - Mark items compliant with documented policy as "Info" not "Warning"
    - Only flag actual deviations from documented standards

## Documentation Lookup

For API deprecation information:
1. Use Context7 for `kubernetes/api` documentation
2. Check Kubernetes deprecation guide: https://kubernetes.io/docs/reference/using-api/deprecation-guide/

## Usage

```
# Review all Kubernetes manifests
/review-kubernetes

# Review specific namespace
/review-kubernetes kubernetes/apps/base/monitoring/

# Review single service
/review-kubernetes kubernetes/apps/base/ai/ollama/
```

## Example Output

```markdown
# Kubernetes Review - 2026-01-24

## Summary
- Critical: 0
- Warning: 2
- Info: 5

## Warning

### [K8S-W001] Missing app.kubernetes.io/component label
- **File**: kubernetes/apps/base/tools/attic/postgres-statefulset.yaml:11
- **Current**: Only has name and part-of labels
- **Fix**: Add `app.kubernetes.io/component: database`

### [K8S-W002] Missing TZ environment variable
- **File**: kubernetes/apps/base/printing/obico/ml-api-deployment.yaml
- **Fix**: Add `env: - name: TZ value: "America/El_Salvador"`

## Info

### [K8S-I001] No CPU requests - By Design
Per `docs/reference/resource-strategy.md`, this single-node homelab intentionally
omits CPU requests/limits for user apps to allow burst capacity.

### [K8S-I002] Image versioning follows documented policy
Per `docs/reference/resource-strategy.md` "Image Versioning Policy":
- `:latest` for user apps: ✅ Allowed
- Major version tags (`:16-alpine`): ✅ Allowed

### [K8S-I003] Resource strategy compliance
All services follow documented memory request/limit policy.
```

## Interactive Mode

After generating report, ask:
"Found X issues (Y critical, Z warnings). Work through fixes interactively?"

If yes, present each issue with suggested fix and apply on confirmation.
