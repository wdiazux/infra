# Review FluxCD Skill

Reviews FluxCD GitOps resources for API versions, health checks, and best practices.

## Purpose

This skill validates:
- Flux CRD API versions
- Health check configuration
- Timeout and retry settings
- Dependency management
- Reconciliation intervals

## When to Use

Invoke this skill when:
- Creating new Flux resources (Kustomizations, HelmReleases)
- Updating GitOps configuration
- After upgrading FluxCD version
- Troubleshooting reconciliation issues

## Checks Performed

### Critical

1. **API Version Alignment**
   - Match CRD versions to installed Flux version
   - `kustomize.toolkit.fluxcd.io/v1` for current Flux

2. **Missing Source References**
   - Kustomizations without sourceRef
   - HelmReleases without chart source

### Warning

1. **Missing Health Checks**
   - Kustomizations should have `healthChecks` for critical resources

2. **Missing Timeouts**
   - `timeout` not set (defaults may be too short)
   - `retryInterval` not configured

3. **Reconciliation**
   - Very short intervals (<1m) causing load
   - Very long intervals (>1h) delaying updates

4. **Dependencies**
   - Missing `dependsOn` for ordered deployments
   - Circular dependencies

### Info

1. **Suspend Status**
   - Resources with `suspend: true` (intentional?)

2. **Pruning**
   - `prune: false` may leave orphaned resources

## Documentation Lookup

Use WebFetch for:
- `https://fluxcd.io/flux/components/kustomize/kustomizations/`
- `https://fluxcd.io/flux/components/helm/helmreleases/`

## Workflow

1. Find Flux resources (Kustomization, HelmRelease, GitRepository, etc.)
2. Check API versions against installed Flux
3. Validate required fields
4. Check health/timeout configuration
5. Generate report

## Usage

```
/review-fluxcd
/review-fluxcd kubernetes/clusters/
/review-fluxcd kubernetes/infrastructure/
```
