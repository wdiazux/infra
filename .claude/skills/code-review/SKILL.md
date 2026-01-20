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
