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

1. **Missing Labels**
   - `app.kubernetes.io/name` - Required
   - `app.kubernetes.io/component` - Required
   - `app.kubernetes.io/part-of` - Required

2. **Missing Resources**
   - `resources.requests.cpu` - Recommended
   - `resources.requests.memory` - Required
   - `resources.limits.memory` - Required

3. **Missing Probes**
   - `livenessProbe` - Required for all long-running containers
   - `readinessProbe` - Required for services

4. **Image Tags**
   - Using `:latest` tag (prefer specific versions for reproducibility)

5. **Missing Security Context**
   - `fsGroup` when mounting volumes

### Info (Nice to Have)

1. **Header Comments**
   - kustomization.yaml should have description header

2. **Environment**
   - TZ variable for timezone consistency

3. **Port Naming**
   - Use named ports (http, https, grpc) not just numbers

## Workflow

1. **Find manifests**: Glob for `*.yaml` in kubernetes/ directory
2. **Parse each file**: Extract kind, apiVersion, metadata, spec
3. **Check API versions**: Compare against deprecation list
4. **Check structure**: Validate against reference template
5. **Check labels**: Verify required labels present
6. **Check resources**: Verify requests/limits set
7. **Check probes**: Verify health checks configured
8. **Check images**: Flag :latest tags
9. **Generate report**: Write to `docs/reviews/YYYY-MM-DD-kubernetes-review.md`

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
# Kubernetes Review - 2026-01-20

## Summary
- Critical: 0
- Warning: 4
- Info: 2

## Warning

### [K8S-001] Missing resource limits
- **File**: kubernetes/apps/base/ai/open-webui/deployment.yaml:26
- **Current**: No `resources` block defined
- **Fix**: Add resources.requests and resources.limits
- **Docs**: docs/reference/k8s-service-template.md#resource-requests-and-limits

### [K8S-002] Missing app.kubernetes.io/component label
- **File**: kubernetes/apps/base/ai/ollama/statefulset.yaml:11
- **Current**: Only has name and part-of labels
- **Fix**: Add `app.kubernetes.io/component: server`

## Info

### [K8S-003] Using :latest image tag
- **File**: kubernetes/apps/base/monitoring/grafana/deployment.yaml:32
- **Current**: `image: grafana/grafana:latest`
- **Fix**: Pin to specific version like `grafana/grafana:11.0.0`
```

## Interactive Mode

After generating report, ask:
"Found X issues (Y critical, Z warnings). Work through fixes interactively?"

If yes, present each issue with suggested fix and apply on confirmation.
