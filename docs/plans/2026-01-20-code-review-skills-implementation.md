# Code Review Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build systematic code review skills that validate IaC against official documentation and best practices.

**Architecture:** Layered skills with base `code-review` providing shared workflow (report generation, doc lookup), and technology-specific skills (`review-kubernetes`, `review-terraform`, etc.) adding domain checks.

**Tech Stack:** Claude Code skills (Markdown), Context7 for docs, WebFetch fallback, YAML/HCL parsing via grep/read.

---

## Task 1: Create Base Code Review Skill

**Files:**
- Create: `.claude/skills/code-review/SKILL.md`

**Step 1: Create skill directory**

Run: `mkdir -p /home/wdiaz/devland/infra/.claude/skills/code-review`

**Step 2: Write the base skill**

Create `.claude/skills/code-review/SKILL.md`:

```markdown
# Code Review Skill

Base skill for systematic IaC code reviews. Validates configurations against official documentation, checks for deprecated options, and ensures best practices.

## Purpose

This skill provides:
- Version-aware documentation lookup (Context7 + web fetch)
- Report generation with severity levels (critical/warning/info)
- Interactive fix mode after review
- Shared workflow for all technology-specific reviews

## When to Use

Invoke this skill when:
- Running a comprehensive review across multiple technologies
- You want auto-detection of what to review in a directory
- Orchestrating multiple technology-specific reviews

For single-technology reviews, use the specific skill directly:
- `/review-kubernetes` - Kubernetes manifests
- `/review-terraform` - Terraform configurations
- `/review-helm` - Helm charts
- `/review-ansible` - Ansible playbooks
- `/review-packer` - Packer templates
- `/review-fluxcd` - FluxCD resources

## Documentation Lookup Strategy

### Context7 (Primary)

Use Context7 for:
- Terraform providers (hashicorp, bpg/proxmox, siderolabs/talos)
- Helm
- Ansible
- Kubernetes API

### Web Fetch (Fallback)

Use WebFetch for:
| Tool | URL Pattern |
|------|-------------|
| Talos Linux | `https://www.talos.dev/v{VERSION}/reference/configuration/` |
| Proxmox Provider | `https://registry.terraform.io/providers/bpg/proxmox/{VERSION}/docs` |
| FluxCD | `https://fluxcd.io/flux/components/` |
| VictoriaMetrics | `https://docs.victoriametrics.com/` |

### Version Detection

1. **Terraform**: Parse `.terraform.lock.hcl` for provider versions
2. **Kubernetes**: Check `apiVersion` in manifests
3. **Helm**: Parse `Chart.yaml` for apiVersion
4. **Talos**: Check machine config or `talosctl version`
5. **FluxCD**: Check CRD apiVersions

## Report Format

Generate reports to `docs/reviews/YYYY-MM-DD-<technology>-review.md`:

```markdown
# [Technology] Review - YYYY-MM-DD

## Summary
- Critical: N
- Warning: N
- Info: N

## Critical

### [CODE-001] Issue title
- **File**: path/to/file.yaml:LINE
- **Current**: `problematic code`
- **Fix**: Description of fix
- **Docs**: URL to documentation

## Warning
...

## Info
...
```

### Severity Levels

- **Critical**: Deprecated/removed in current version, security issues, breaking changes
- **Warning**: Best practice violations, missing recommended fields
- **Info**: Style suggestions, minor improvements

## Workflow

1. **Scan**: Find relevant files in target path
2. **Detect**: Identify versions from lock files and configs
3. **Lookup**: Fetch documentation for detected versions
4. **Check**: Run technology-specific validations
5. **Report**: Generate markdown report with findings
6. **Prompt**: Ask "Found X issues. Work through fixes interactively?"

## Interactive Fix Mode

When user confirms interactive mode:
1. Present issues one at a time, starting with Critical
2. For each issue:
   - Show the problem and suggested fix
   - Ask: "Apply this fix? (yes/no/skip)"
   - If yes, make the edit
   - If skip, move to next issue
3. After all issues, re-run validation to confirm fixes

## Auto-Detection

When invoked without specifying technology, scan for:
- `*.tf` files → run review-terraform
- `kubernetes/` or `*.yaml` with K8s kinds → run review-kubernetes
- `Chart.yaml` → run review-helm
- `playbook*.yml` or `roles/` → run review-ansible
- `*.pkr.hcl` → run review-packer
- `*kustomization*.yaml` with Flux CRDs → run review-fluxcd
```

**Step 3: Commit**

```bash
git add .claude/skills/code-review/
git commit -m "feat(skills): Add base code-review skill with doc lookup workflow"
```

---

## Task 2: Create Kubernetes Reference Template

**Files:**
- Create: `docs/reference/k8s-service-template.md`

**Step 1: Write the reference document**

Create `docs/reference/k8s-service-template.md`:

```markdown
# Kubernetes Service Template

Reference structure for Kubernetes services based on the Grafana deployment pattern.

## Directory Structure

```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml      # Required: lists all resources
├── deployment.yaml         # or statefulset.yaml for stateful apps
├── service.yaml            # Service exposure
├── pvc.yaml                # If persistent storage needed
├── secret.enc.yaml         # If secrets needed (SOPS encrypted)
├── configmap.yaml          # If configuration needed
└── rbac.yaml               # If RBAC needed
```

## Required: kustomization.yaml

Every service MUST have a kustomization.yaml with header comment:

```yaml
# Service Name Kustomization
#
# Brief description of what the service does.
# https://link-to-official-docs
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - pvc.yaml          # Storage first
  - configmap.yaml    # Config before deployment
  - secret.enc.yaml   # Secrets before deployment
  - deployment.yaml   # Workload
  - service.yaml      # Exposure
```

## Required: Labels

All workloads MUST include these labels:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: <server|database|cache|worker|ui>
    app.kubernetes.io/part-of: <namespace>
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
        app.kubernetes.io/component: <server|database|cache|worker|ui>
        app.kubernetes.io/part-of: <namespace>
```

## Required: Deployment Elements

### Security Context (when mounting volumes)

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: <GID>
        fsGroupChangePolicy: "OnRootMismatch"
```

### Resource Requests and Limits

```yaml
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    memory: 512Mi
```

Note: CPU limits are optional (can cause throttling).

### Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30
readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
```

For slow-starting apps, add startupProbe:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: http
  failureThreshold: 30
  periodSeconds: 10
```

### Named Ports

```yaml
ports:
  - name: http
    containerPort: 8080
    protocol: TCP
```

### Timezone

```yaml
env:
  - name: TZ
    value: "America/El_Salvador"
```

## Example: Complete Deployment

```yaml
# Service Name Deployment
#
# Brief description.
# https://docs-url
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
  namespace: my-namespace
  labels:
    app.kubernetes.io/name: my-service
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: my-namespace
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: my-service
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-service
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: my-namespace
    spec:
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: my-service
          image: myregistry/my-service:v1.2.3
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              memory: 512Mi
          volumeMounts:
            - name: data
              mountPath: /data
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: my-service-data
```

## Warnings (Review Flags)

The review-kubernetes skill flags these as warnings:

| Issue | Severity |
|-------|----------|
| Missing `app.kubernetes.io/name` label | Warning |
| Missing `app.kubernetes.io/component` label | Warning |
| Missing `app.kubernetes.io/part-of` label | Warning |
| Missing resource requests | Warning |
| Missing resource limits (memory) | Warning |
| Missing livenessProbe | Warning |
| Missing readinessProbe | Warning |
| Using `:latest` image tag | Warning |
| Missing kustomization.yaml header comment | Info |
| Missing TZ environment variable | Info |

---
**Last Updated**: 2026-01-20
```

**Step 2: Commit**

```bash
git add docs/reference/k8s-service-template.md
git commit -m "docs(reference): Add Kubernetes service template based on Grafana pattern"
```

---

## Task 3: Create Review Kubernetes Skill

**Files:**
- Create: `.claude/skills/review-kubernetes/SKILL.md`

**Step 1: Create skill directory**

Run: `mkdir -p /home/wdiaz/devland/infra/.claude/skills/review-kubernetes`

**Step 2: Write the skill**

Create `.claude/skills/review-kubernetes/SKILL.md`:

```markdown
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
```

**Step 3: Commit**

```bash
git add .claude/skills/review-kubernetes/
git commit -m "feat(skills): Add review-kubernetes skill for manifest validation"
```

---

## Task 4: Enhance Terraform Review Skill

**Files:**
- Modify: `.claude/skills/terraform-review/SKILL.md`

**Step 1: Read current content**

Read `.claude/skills/terraform-review/SKILL.md` to understand current structure.

**Step 2: Enhance with documentation lookup**

Update `.claude/skills/terraform-review/SKILL.md` to add:

```markdown
## Documentation Lookup

### Version Detection

Parse `.terraform.lock.hcl` to extract provider versions:
```hcl
provider "registry.terraform.io/bpg/proxmox" {
  version = "0.92.0"
  ...
}
```

### Context7 Lookup

Use Context7 for:
- `hashicorp/terraform` - Core Terraform
- `bpg/proxmox` - Proxmox provider
- `siderolabs/talos` - Talos provider

### Web Fetch Fallback

| Provider | Documentation URL |
|----------|-------------------|
| bpg/proxmox | `https://registry.terraform.io/providers/bpg/proxmox/{VERSION}/docs` |
| siderolabs/talos | `https://registry.terraform.io/providers/siderolabs/talos/{VERSION}/docs` |

### Deprecation Checking

For each resource/attribute:
1. Look up in provider docs for current version
2. Check if marked deprecated
3. Find replacement if deprecated
4. Flag with appropriate severity

## Report Generation

Generate reports to `docs/reviews/YYYY-MM-DD-terraform-review.md` following the standard format from code-review skill.

## Enhanced Checks

### Deprecated Attributes (Critical)

Check provider changelogs and docs for:
- Removed attributes in current version
- Deprecated attributes with replacement
- Changed attribute types

### Version Drift (Warning)

Flag when:
- Provider version is >2 minor versions behind latest
- Terraform version constraint allows old versions
- Required providers missing version constraints
```

**Step 3: Commit**

```bash
git add .claude/skills/terraform-review/
git commit -m "feat(skills): Enhance terraform-review with doc lookup and reporting"
```

---

## Task 5: Create Review Helm Skill

**Files:**
- Create: `.claude/skills/review-helm/SKILL.md`

**Step 1: Create skill directory**

Run: `mkdir -p /home/wdiaz/devland/infra/.claude/skills/review-helm`

**Step 2: Write the skill**

Create `.claude/skills/review-helm/SKILL.md`:

```markdown
# Review Helm Skill

Reviews Helm charts for API versions, best practices, and deprecated values.

## Purpose

This skill validates:
- Chart API version (v1 vs v2)
- Required Chart.yaml fields
- Values.yaml structure and defaults
- Template best practices
- Deprecated Helm features

## When to Use

Invoke this skill when:
- Creating new Helm charts
- Updating existing charts
- Before packaging/releasing charts
- After upgrading Helm version

## Checks Performed

### Critical

1. **Chart API Version**
   - v1 is deprecated, use apiVersion: v2
   - Check `Chart.yaml` apiVersion field

2. **Missing Required Fields**
   - `name` - Required
   - `version` - Required (SemVer)
   - `apiVersion` - Required

### Warning

1. **Missing Recommended Fields**
   - `description` - Recommended
   - `appVersion` - Recommended
   - `type` (application/library) - Recommended

2. **Values Issues**
   - Hardcoded values that should be configurable
   - Missing default values for required fields
   - Unused values (defined but not referenced)

3. **Template Issues**
   - Missing `{{- include "chart.labels" . }}` for standard labels
   - Hardcoded namespaces in templates
   - Missing NOTES.txt

### Info

1. **Documentation**
   - Missing README.md
   - Missing values schema (values.schema.json)

## Documentation Lookup

Use Context7 for:
- `helm/helm` - Helm documentation
- Chart best practices

## Workflow

1. Find Chart.yaml files
2. Parse chart metadata
3. Scan values.yaml
4. Check templates for issues
5. Generate report

## Usage

```
/review-helm
/review-helm path/to/chart/
```
```

**Step 3: Commit**

```bash
git add .claude/skills/review-helm/
git commit -m "feat(skills): Add review-helm skill for Helm chart validation"
```

---

## Task 6: Create Review Ansible Skill

**Files:**
- Create: `.claude/skills/review-ansible/SKILL.md`

**Step 1: Create skill directory**

Run: `mkdir -p /home/wdiaz/devland/infra/.claude/skills/review-ansible`

**Step 2: Write the skill**

Create `.claude/skills/review-ansible/SKILL.md`:

```markdown
# Review Ansible Skill

Reviews Ansible playbooks and roles for deprecated modules, FQCN usage, and best practices.

## Purpose

This skill validates:
- Deprecated module usage
- Fully Qualified Collection Names (FQCN)
- Privilege escalation patterns
- Variable management
- Idempotency

## When to Use

Invoke this skill when:
- Creating new playbooks or roles
- Updating existing Ansible code
- Before running playbooks
- After upgrading Ansible version

## Checks Performed

### Critical

1. **Deprecated Modules**
   - `command` with shell features → use `shell`
   - Old module names → FQCN equivalents
   - Removed modules in current Ansible version

2. **Security Issues**
   - Plaintext passwords in playbooks
   - Missing `no_log: true` for sensitive tasks

### Warning

1. **FQCN Usage**
   - Use `ansible.builtin.copy` not `copy`
   - Use `ansible.builtin.template` not `template`

2. **Privilege Escalation**
   - Missing `become: true` when needed
   - Inconsistent become usage

3. **Variables**
   - Hardcoded values that should be variables
   - Undefined variables without defaults
   - Unused variables

### Info

1. **Style**
   - Missing task names
   - Long lines (>120 chars)
   - Missing handlers for restarts

## Documentation Lookup

Use Context7 for:
- `ansible/ansible` - Core modules
- Collection documentation

## Workflow

1. Find playbooks (*.yml, *.yaml)
2. Find roles (roles/*/tasks/*.yml)
3. Parse tasks and check modules
4. Validate FQCN usage
5. Check for deprecated patterns
6. Generate report

## Usage

```
/review-ansible
/review-ansible ansible/playbooks/
/review-ansible ansible/roles/my-role/
```
```

**Step 3: Commit**

```bash
git add .claude/skills/review-ansible/
git commit -m "feat(skills): Add review-ansible skill for playbook validation"
```

---

## Task 7: Create Review Packer Skill

**Files:**
- Modify: `.claude/skills/packer-validation/SKILL.md` (enhance existing)

**Step 1: Read and enhance existing skill**

The project already has `packer-validation`. Enhance it with:
- Documentation lookup via Context7
- Report generation to docs/reviews/
- Deprecation checking against Packer version

**Step 2: Add doc lookup and reporting sections**

Add to existing SKILL.md:

```markdown
## Documentation Lookup

Use Context7 for:
- `hashicorp/packer` - Core Packer
- Builder-specific documentation

### Version Detection

Check `required_plugins` block in .pkr.hcl files.

## Report Generation

Generate reports to `docs/reviews/YYYY-MM-DD-packer-review.md`.
```

**Step 3: Commit**

```bash
git add .claude/skills/packer-validation/
git commit -m "feat(skills): Enhance packer-validation with doc lookup and reporting"
```

---

## Task 8: Create Review FluxCD Skill

**Files:**
- Create: `.claude/skills/review-fluxcd/SKILL.md`

**Step 1: Create skill directory**

Run: `mkdir -p /home/wdiaz/devland/infra/.claude/skills/review-fluxcd`

**Step 2: Write the skill**

Create `.claude/skills/review-fluxcd/SKILL.md`:

```markdown
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
```

**Step 3: Commit**

```bash
git add .claude/skills/review-fluxcd/
git commit -m "feat(skills): Add review-fluxcd skill for GitOps validation"
```

---

## Task 9: Create Slash Commands

**Files:**
- Create: `.claude/commands/code-review.md`
- Create: `.claude/commands/review-kubernetes.md`
- Create: `.claude/commands/review-terraform.md`
- Create: `.claude/commands/review-helm.md`
- Create: `.claude/commands/review-ansible.md`
- Create: `.claude/commands/review-packer.md`
- Create: `.claude/commands/review-fluxcd.md`

**Step 1: Create code-review command**

Create `.claude/commands/code-review.md`:

```markdown
---
name: code-review
description: Run comprehensive IaC code review
---

Run code review: $ARGUMENTS

Use the **code-review** skill to perform a comprehensive review.

If no path specified, auto-detect technologies in current directory.
If path specified, review that specific path.

Generate report to `docs/reviews/YYYY-MM-DD-<technology>-review.md`.

After review, ask if user wants to work through fixes interactively.
```

**Step 2: Create technology-specific commands**

Create each command file following the pattern:

`.claude/commands/review-kubernetes.md`:
```markdown
---
name: review-kubernetes
description: Review Kubernetes manifests for best practices
---

Review Kubernetes manifests: $ARGUMENTS

Use the **review-kubernetes** skill.

Default path: `kubernetes/apps/`
If path specified, review that path.

Check against reference: `docs/reference/k8s-service-template.md`
```

(Repeat pattern for other technologies)

**Step 3: Commit**

```bash
git add .claude/commands/code-review.md
git add .claude/commands/review-*.md
git commit -m "feat(commands): Add slash commands for code review skills"
```

---

## Task 10: Update README and Final Commit

**Files:**
- Modify: `.claude/README.md`

**Step 1: Add new skills to README**

Update the Available Skills section to include:
- code-review
- review-kubernetes
- review-helm
- review-ansible
- review-fluxcd

**Step 2: Final commit**

```bash
git add .claude/README.md
git commit -m "docs: Update Claude README with new code review skills"
```

---

## Summary

| Task | Files | Commits |
|------|-------|---------|
| 1 | `.claude/skills/code-review/SKILL.md` | 1 |
| 2 | `docs/reference/k8s-service-template.md` | 1 |
| 3 | `.claude/skills/review-kubernetes/SKILL.md` | 1 |
| 4 | `.claude/skills/terraform-review/SKILL.md` | 1 |
| 5 | `.claude/skills/review-helm/SKILL.md` | 1 |
| 6 | `.claude/skills/review-ansible/SKILL.md` | 1 |
| 7 | `.claude/skills/packer-validation/SKILL.md` | 1 |
| 8 | `.claude/skills/review-fluxcd/SKILL.md` | 1 |
| 9 | `.claude/commands/*.md` (7 files) | 1 |
| 10 | `.claude/README.md` | 1 |

**Total: 10 tasks, 10 commits**

---
**Last Updated**: 2026-01-20
