# Code Review Skills Design

Systematic code review skills that validate IaC against official documentation and best practices.

## Problem

- Configs drift as tools release new versions
- Accumulated technical debt needs cleanup
- Services built at different times have inconsistent patterns

## Solution

Layered skill architecture with a base skill handling common workflow and technology-specific skills adding domain knowledge.

## Architecture

### Base Skill: `code-review`

Entry point handling:
- Report generation with severity levels (critical/warning/info)
- Context7 integration for supported docs
- Web fetch fallback for Talos, Proxmox, FluxCD docs
- Interactive fix mode after report generation

### Technology-Specific Skills

| Skill | Scope |
|-------|-------|
| `review-terraform` | Terraform configs, provider versions, deprecated attributes |
| `review-kubernetes` | K8s manifests, API versions, structure consistency |
| `review-helm` | Helm charts, values, deprecated chart APIs |
| `review-ansible` | Playbooks, roles, deprecated modules |
| `review-packer` | Templates, builder configs, deprecated options |
| `review-fluxcd` | GitOps resources, Flux-specific CRDs |

## Check Coverage

### review-terraform

- Provider versions vs latest stable
- Deprecated resource attributes
- Required provider constraints present
- Variable/output descriptions
- Sensitive values marked correctly
- Unused variables/locals

### review-kubernetes

- API version deprecations (e.g., `extensions/v1beta1` → `apps/v1`)
- Missing standard labels (`app.kubernetes.io/*`)
- Missing resource requests/limits
- Missing health probes
- Missing security contexts
- Structure consistency vs reference (Grafana pattern)
- Image tags using `:latest`

### review-helm

- Chart API version (v1 vs v2)
- Deprecated values in values.yaml
- Missing Chart.yaml fields
- Unused template helpers

### review-ansible

- Deprecated modules
- FQCN usage (fully qualified collection names)
- Missing `become` declarations
- Hardcoded values that should be variables

### review-packer

- HCL2 vs legacy JSON format
- Deprecated builder options
- Missing required fields per builder type

### review-fluxcd

- API version alignment with installed Flux version
- Missing health checks on Kustomizations
- Missing timeout/retry configurations

## Workflow

### Invocation

```bash
# Review specific technology
/review-terraform
/review-kubernetes

# Review specific path
/review-terraform terraform/talos/

# Base skill auto-detects and runs all applicable
/code-review
```

### Process

1. Scan target path for relevant files
2. Detect versions in use (from provider locks, Chart.yaml, etc.)
3. Fetch documentation for those specific versions
4. Run checks, collect findings
5. Generate report to `docs/reviews/YYYY-MM-DD-<technology>-review.md`
6. Display summary, ask: "Work through fixes interactively?"

## Report Format

```markdown
# Terraform Review - 2026-01-20

## Summary
- Critical: 2
- Warning: 5
- Info: 3

## Critical

### [TF-001] Deprecated attribute `security_groups` in aws_instance
- **File**: terraform/talos/main.tf:45
- **Current**: `security_groups = ["default"]`
- **Fix**: Use `vpc_security_group_ids` instead
- **Docs**: https://registry.terraform.io/providers/...

## Warning
...
```

### Severity Levels

- **Critical**: Deprecated/removed in current version, security issues
- **Warning**: Best practice violations, missing recommended fields
- **Info**: Style suggestions, minor improvements

## Documentation Lookup

### Context7 (primary)

- Terraform providers: `hashicorp/terraform`, `bpg/proxmox`, `siderolabs/talos`
- Helm: `helm/helm`
- Ansible: `ansible/ansible`
- Kubernetes: `kubernetes/api`

### Web Fetch (fallback)

| Tool | Documentation URL |
|------|-------------------|
| Talos Linux | `https://www.talos.dev/v1.12/reference/configuration/` |
| Proxmox provider | `https://registry.terraform.io/providers/bpg/proxmox/latest/docs` |
| FluxCD | `https://fluxcd.io/flux/components/` |
| VictoriaMetrics | `https://docs.victoriametrics.com/` |

### Version-Aware Lookup

1. Parse version from lock files / configs
2. Construct versioned doc URL (e.g., `talos.dev/v1.12/` not `/latest/`)
3. Query Context7 with version constraint when supported
4. Cache results within session

## Kubernetes Structure Reference

Based on analysis of existing services, Grafana is the best-structured reference.

### Required File Structure

```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml      # Required: lists all resources
├── deployment.yaml         # or statefulset.yaml
├── service.yaml
├── pvc.yaml                # If stateful
├── secret.enc.yaml         # If secrets needed (SOPS encrypted)
└── configmap.yaml          # If config needed
```

### Required kustomization.yaml Header

```yaml
# Service Name Kustomization
#
# Brief description of what the service does.
# https://link-to-official-docs
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ...
```

### Required Labels

```yaml
labels:
  app.kubernetes.io/name: <service-name>
  app.kubernetes.io/component: <server|database|cache|worker>
  app.kubernetes.io/part-of: <namespace>
```

### Required Deployment Elements

- `securityContext` with `fsGroup` when mounting volumes
- `resources.requests` (cpu, memory)
- `resources.limits` (memory at minimum)
- `livenessProbe` and `readinessProbe`
- Named ports (e.g., `name: http`)
- TZ environment variable: `America/El_Salvador`

### Flagged as Warnings

- Missing any required label
- Missing probes
- Missing resource limits
- Using `:latest` image tag
- Missing header comment in kustomization.yaml

## Deliverables

### Skills (`.claude/skills/`)

| File | Purpose |
|------|---------|
| `code-review.md` | Base skill - shared workflow, report generation |
| `review-terraform.md` | Terraform-specific checks |
| `review-kubernetes.md` | K8s manifest checks + structure validation |
| `review-helm.md` | Helm chart checks |
| `review-ansible.md` | Ansible playbook/role checks |
| `review-packer.md` | Packer template checks |
| `review-fluxcd.md` | FluxCD resource checks |

### Supporting Files

| File | Purpose |
|------|---------|
| `docs/reference/k8s-service-template.md` | Reference structure documentation |
| `docs/reviews/` | Directory for generated review reports |

### Implementation Order

1. Base `code-review` skill (shared logic)
2. `review-kubernetes` (most used, has structure validation)
3. `review-terraform` (core IaC)
4. Remaining skills in any order

---
**Last Updated**: 2026-01-20
