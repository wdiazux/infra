# Claude Code Optimization Design

**Date:** 2026-01-19
**Status:** Approved
**Author:** Claude (brainstorming session)

## Overview

Optimize Claude Code setup for the infrastructure project to reduce repetitive commands, add safety validation, and provide workflow guidance.

## Goals

1. **Reduce repetitive commands** - Custom slash commands for common operations
2. **Add safety validation** - Hooks to prevent dangerous operations
3. **Provide workflow guidance** - Sub-agents for complex multi-step processes

## Constraints

- Project-level configuration only (`.claude/` in repo)
- No custom skills (superpowers plugin provides these)
- No additional MCP servers (existing plugins sufficient)
- Single-node homelab context

## Directory Structure

```
.claude/
├── settings.json              # Hooks configuration
├── agents/
│   ├── k8s-debugger.md        # Troubleshooting sub-agent
│   ├── terraform-ops.md       # Terraform sub-agent
│   └── service-deployer.md    # Deployment guide sub-agent
├── commands/
│   ├── k8s-status.md          # /k8s-status
│   ├── tf-plan.md             # /tf-plan
│   ├── tf-apply.md            # /tf-apply
│   ├── deploy-service.md      # /deploy-service
│   ├── update-service.md      # /update-service
│   └── debug.md               # /debug
└── scripts/
    ├── validate-kubectl.sh    # kubectl safety
    ├── validate-terraform.sh  # terraform safety
    ├── validate-secrets.sh    # secret exposure
    └── session-init.sh        # session setup
```

## Hooks Configuration

### settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/scripts/validate-kubectl.sh"
          },
          {
            "type": "command",
            "command": ".claude/scripts/validate-terraform.sh"
          },
          {
            "type": "command",
            "command": ".claude/scripts/validate-secrets.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/scripts/session-init.sh"
          }
        ]
      }
    ]
  }
}
```

## Validation Scripts

### validate-kubectl.sh

Validates kubectl commands for safety:

| Pattern | Action | Reason |
|---------|--------|--------|
| `kubectl delete namespace` | Hard block (exit 2) | Destroys entire namespace |
| `kubectl delete pv` | Hard block (exit 2) | Loses persistent data |
| `kubectl delete pvc --all` | Hard block (exit 2) | Bulk data loss |
| `kubectl delete` (other) | Confirm (ask) | Might be intentional |
| `kubectl scale.*replicas.*0` | Confirm (ask) | Service outage |
| `kubectl drain` | Confirm (ask) | Node evacuation |
| `kubectl cordon` | Confirm (ask) | Prevents scheduling |

### validate-terraform.sh

Validates terraform commands for safety:

| Pattern | Action | Reason |
|---------|--------|--------|
| `terraform destroy` | Hard block (exit 2) | Infrastructure destruction |
| `terraform apply -auto-approve` | Warn (stderr) | Bypasses review |
| `terraform apply` | Confirm (ask) | Requires plan review |
| `terraform plan/init/validate` | Pass (exit 0) | Safe operations |

### validate-secrets.sh

Prevents accidental secret exposure:

| Pattern | Action | Reason |
|---------|--------|--------|
| `cat.*\.env` | Warn (stderr) | May expose secrets |
| `grep.*(password\|secret\|token\|key)` | Warn (stderr) | May expose secrets |
| `echo.*=.*` in sensitive context | Warn (stderr) | May log secrets |
| `sops -d` | Pass (exit 0) | Proper decryption |

### session-init.sh

Sets up session environment:

1. Exports `KUBECONFIG=terraform/talos/kubeconfig` via `CLAUDE_ENV_FILE`
2. Returns project context as `additionalContext`:
   - Single-node homelab reminder
   - Network range: 10.10.2.0/24
   - Key IP allocations summary

## Sub-Agents

### k8s-debugger.md

**Purpose:** Systematic Kubernetes troubleshooting

**Tools:** Bash, Read, Grep, Glob (read-only operations)

**Workflow:**
1. Set KUBECONFIG
2. Check pod status (`kubectl get pods -A | grep -v Running`)
3. Describe failing resource
4. Check logs (current + previous container)
5. Check events (`kubectl get events --sort-by=.lastTimestamp`)
6. Check service/endpoints
7. Check network policies if applicable
8. Summarize root cause and recommend fix

### terraform-ops.md

**Purpose:** Safe Terraform operations with validation

**Tools:** Bash, Read, Grep, Glob

**Workflow:**
1. Verify working directory exists
2. Check git status for uncommitted changes
3. Run `terraform init -upgrade`
4. Run `terraform validate`
5. Run `terraform plan -out=tfplan`
6. Review and explain changes
7. Wait for user confirmation before apply
8. Run `terraform apply tfplan`
9. Verify state after apply
10. Clean up tfplan file

### service-deployer.md

**Purpose:** Guided new service deployment following project conventions

**Tools:** Bash, Read, Write, Edit, Grep, Glob

**Checklist:**
1. [ ] Choose namespace (existing or new)
2. [ ] Allocate IP from network table (10.10.2.21-150 range)
3. [ ] Create directory: `kubernetes/apps/base/{namespace}/{service}/`
4. [ ] Create deployment.yaml
5. [ ] Create service.yaml with LoadBalancer IP
6. [ ] Create configmap.yaml (if needed)
7. [ ] Create secrets with SOPS encryption (if needed)
8. [ ] Add to kustomization.yaml
9. [ ] Update CLAUDE.md network table
10. [ ] Update homepage configmap if applicable
11. [ ] Commit changes
12. [ ] Run `flux reconcile kustomization flux-system --with-source`
13. [ ] Verify deployment: `kubectl get pods -n {namespace}`
14. [ ] Test service accessibility

## Custom Commands

### /k8s-status

Check Kubernetes cluster health:

```markdown
Check Kubernetes cluster status using KUBECONFIG=terraform/talos/kubeconfig:

1. Show node status: `kubectl get nodes -o wide`
2. Show node resource usage: `kubectl top nodes`
3. List problematic pods: `kubectl get pods -A | grep -v -E 'Running|Completed'`
4. Show recent warning events: `kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | head -20`
5. Check Flux status: `flux get all -A`
6. Summarize cluster health
```

### /tf-plan

Run Terraform plan:

```markdown
Run Terraform plan for: $ARGUMENTS (defaults to terraform/talos)

1. cd to specified directory
2. Run `terraform init -upgrade`
3. Run `terraform validate`
4. Run `terraform plan -out=tfplan`
5. Summarize: X to add, Y to change, Z to destroy
6. Highlight any destructive changes
```

### /tf-apply

Apply Terraform changes:

```markdown
Apply Terraform changes for: $ARGUMENTS (defaults to terraform/talos)

1. Verify tfplan file exists (if not, run /tf-plan first)
2. Show plan summary
3. Ask for explicit confirmation
4. Run `terraform apply tfplan`
5. Verify apply succeeded
6. Run `terraform output` to show results
7. Clean up tfplan file
```

### /deploy-service

Deploy new service:

```markdown
Deploy new service: $ARGUMENTS

Use the service-deployer agent to guide through the complete deployment workflow.
The agent will walk through each step with checkboxes and verify completion.
```

### /update-service

Update existing service:

```markdown
Update existing service: $ARGUMENTS

1. Identify current deployment location
2. Show current configuration
3. Ask what changes are needed
4. Make changes to manifests
5. Commit changes
6. Run `flux reconcile`
7. Watch rollout: `kubectl rollout status`
8. Verify service is healthy
9. Document rollback command if needed
```

### /debug

Systematic troubleshooting:

```markdown
Debug issue: $ARGUMENTS

Use the k8s-debugger agent for systematic troubleshooting.
The agent will follow a structured debugging flow and report findings.
```

## CLAUDE.md Optimization

### Sections to Keep (essential)
- Project Overview & Homelab Philosophy
- Repository Structure
- Technology Stack & Versions
- Network Configuration Table
- Talos Implementation Details
- Quick Reference Commands

### Sections to Consolidate
| Current | Action |
|---------|--------|
| AI Assistant Guidelines (~50 lines) | Reduce to 10 lines of project-specific rules |
| Documentation Sync Map | Move to docs/CONTRIBUTING.md |
| Reference Materials | Keep top 5, move rest to docs/reference/links.md |
| Version History | Keep last 5, archive to docs/CHANGELOG.md |

### Sections to Add
- Pointer to `.claude/` directory for custom commands/hooks/agents
- Quick command reference table

### Target
Reduce from ~600 lines to ~350 lines while maintaining all essential information.

## Implementation Order

1. Create `.claude/` directory structure
2. Create validation scripts (make executable)
3. Create settings.json with hooks
4. Create sub-agents
5. Create commands
6. Optimize CLAUDE.md
7. Test hooks and commands
8. Commit all changes

## Testing Plan

1. **Hooks testing:**
   - Verify `kubectl delete namespace` is blocked
   - Verify `terraform destroy` is blocked
   - Verify `terraform apply` asks for confirmation
   - Verify session sets KUBECONFIG

2. **Commands testing:**
   - Run `/k8s-status` and verify output
   - Run `/tf-plan` on terraform/talos
   - Run `/debug` with a test issue

3. **Sub-agents testing:**
   - Invoke k8s-debugger manually
   - Invoke service-deployer for a test service

## References

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Sub-agents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase)
