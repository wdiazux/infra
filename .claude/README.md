# Claude Code Skills and Agents

This directory contains custom skills and agents for the infrastructure project automation.

## Overview

**Skills** are lightweight, focused capabilities that Claude can use to perform specific tasks. They're perfect for validation, review, and analysis tasks.

**Agents** are more complex, autonomous systems that can handle multi-step workflows with tool use and iteration.

## Available Skills

### 1. Packer Validation (`packer-validation`)

**Purpose:** Validates Packer HCL templates against best practices

**When to use:**
- Before running `packer build`
- When creating/updating templates
- During code reviews

**Example:**
```
"Can you validate my Packer templates?"
```

**What it checks:**
- Syntax validation (`packer fmt`, `packer validate`)
- Deprecated options (boot_iso vs iso_url)
- Ansible provisioner configuration
- Proxmox-specific settings
- Disk optimization for ZFS
- Security (no hardcoded secrets)

### 2. Terraform Review (`terraform-review`)

**Purpose:** Reviews Terraform configurations for security and best practices

**When to use:**
- Before running `terraform apply`
- When creating modules
- During code reviews

**Example:**
```
"Can you review my Terraform configurations?"
```

**What it checks:**
- Syntax and formatting (`terraform fmt`, `terraform validate`)
- Provider version constraints
- Security scanning (`tflint`, `trivy`)
- Proxmox/Talos-specific validation
- Resource naming conventions
- Secret management

### 3. SOPS Management (`sops-management`)

**Purpose:** Manages encrypted secrets with SOPS + Age

**When to use:**
- Adding/updating secrets
- Rotating encryption keys
- Debugging secret access
- Before committing changes

**Example:**
```
"Can you help me add a new secret to SOPS?"
```

**What it does:**
- Validates .sops.yaml configuration
- Encrypts/decrypts secrets
- Checks for plaintext leaks
- Guides integration with Packer/Terraform
- Verifies Age key setup

### 4. Code Review (`code-review`)

**Purpose:** Base skill for comprehensive IaC code reviews across all technologies

**When to use:**
- Running multi-technology reviews
- Auto-detecting what to review in a directory
- Orchestrating technology-specific reviews

**Example:**
```
/code-review
/code-review terraform/
```

**What it does:**
- Auto-detects technologies in target path
- Orchestrates technology-specific review skills
- Generates reports to `docs/reviews/`
- Offers interactive fix mode

### 5. Review Kubernetes (`review-kubernetes`)

**Purpose:** Reviews Kubernetes manifests for API deprecations and best practices

**When to use:**
- Creating new K8s services
- Before committing manifest changes
- After upgrading Kubernetes version

**Example:**
```
/review-kubernetes
/review-kubernetes kubernetes/apps/base/monitoring/
```

**What it checks:**
- Deprecated API versions
- Required labels (app.kubernetes.io/*)
- Resource requests and limits
- Health probes (liveness, readiness)
- Security contexts
- Image tag practices

### 6. Review Helm (`review-helm`)

**Purpose:** Reviews Helm charts for API versions and best practices

**When to use:**
- Creating new Helm charts
- Before packaging/releasing charts
- After upgrading Helm version

**Example:**
```
/review-helm
/review-helm path/to/chart/
```

**What it checks:**
- Chart API version (v1 vs v2)
- Required Chart.yaml fields
- Values.yaml structure
- Template best practices

### 7. Review Ansible (`review-ansible`)

**Purpose:** Reviews Ansible playbooks for deprecated modules and FQCN usage

**When to use:**
- Creating new playbooks or roles
- Before running playbooks
- After upgrading Ansible version

**Example:**
```
/review-ansible
/review-ansible ansible/playbooks/
```

**What it checks:**
- Deprecated modules
- FQCN usage (ansible.builtin.*)
- Privilege escalation patterns
- Security issues (plaintext passwords, missing no_log)

### 8. Review FluxCD (`review-fluxcd`)

**Purpose:** Reviews FluxCD GitOps resources for API versions and health checks

**When to use:**
- Creating Flux Kustomizations or HelmReleases
- After upgrading FluxCD version
- Troubleshooting reconciliation issues

**Example:**
```
/review-fluxcd
/review-fluxcd kubernetes/clusters/
```

**What it checks:**
- CRD API version alignment
- Source references
- Health check configuration
- Timeout and retry settings
- Dependency management

## How to Use Skills

Skills are automatically discovered by Claude Code. Simply ask Claude to perform tasks related to the skill:

**Direct invocation:**
```
"Use the packer-validation skill to check my templates"
```

**Natural language:**
```
"Can you validate my Packer templates?"
"Review my Terraform code for security issues"
"Help me encrypt a new secret with SOPS"
```

Claude will automatically select and use the appropriate skill based on your request.

## Creating New Skills

1. **Create skill directory:**
   ```bash
   mkdir -p .claude/skills/my-new-skill
   ```

2. **Create SKILL.md:**
   ```bash
   touch .claude/skills/my-new-skill/SKILL.md
   ```

3. **Define the skill:**
   ```markdown
   # My New Skill

   Purpose description here.

   ## When to Use

   List scenarios...

   ## What This Skill Does

   1. Step one
   2. Step two
   ```

4. **Test the skill:**
   ```
   "Use my-new-skill to [task]"
   ```

## Best Practices

### Skill Design

- **Focus on one thing:** Each skill should have a clear, specific purpose
- **Clear triggers:** Document when the skill should be used
- **Actionable steps:** List concrete validation/review steps
- **Examples:** Provide usage examples
- **Tool integration:** Reference actual commands (packer validate, tflint, etc.)

### Using Skills Effectively

- **Be specific:** "Validate Packer templates" is clearer than "check my code"
- **Provide context:** Mention which files/directories to check
- **Review results:** Always review skill outputs before taking action
- **Iterate:** Use skills multiple times during development

### Security

- **Never commit secrets:** Use SOPS for all sensitive data
- **Validate before commit:** Run skills before git commits
- **Regular reviews:** Periodically review all configurations
- **Update skills:** Keep skills current with tool updates

## Integration with Project Workflow

### Pre-commit Checks

Use skills before committing:
```bash
# Example workflow
1. Edit Packer template
2. Ask Claude: "Validate my Packer templates"
3. Fix any issues found
4. Ask Claude: "Check for any plaintext secrets"
5. Commit changes
```

### Pull Request Reviews

Use skills during PR review:
```bash
1. Claude reviews changed files
2. Runs appropriate skills (packer-validation, terraform-review)
3. Reports findings
4. Suggests fixes
```

### Development Workflow

```mermaid
graph LR
    A[Edit Code] --> B[Ask Claude to Validate]
    B --> C{Issues Found?}
    C -->|Yes| D[Fix Issues]
    C -->|No| E[Commit]
    D --> B
```

## File Structure

```
.claude/
├── README.md                           # This file
├── commands/
│   ├── code-review.md                  # Comprehensive IaC review
│   ├── review-kubernetes.md            # K8s manifest review
│   ├── review-terraform.md             # Terraform review
│   ├── review-helm.md                  # Helm chart review
│   ├── review-ansible.md               # Ansible playbook review
│   ├── review-packer.md                # Packer template review
│   └── review-fluxcd.md                # FluxCD resource review
├── skills/
│   ├── code-review/
│   │   └── SKILL.md                    # Base code review skill
│   ├── review-kubernetes/
│   │   └── SKILL.md                    # Kubernetes review skill
│   ├── review-helm/
│   │   └── SKILL.md                    # Helm review skill
│   ├── review-ansible/
│   │   └── SKILL.md                    # Ansible review skill
│   ├── review-fluxcd/
│   │   └── SKILL.md                    # FluxCD review skill
│   ├── packer-validation/
│   │   └── SKILL.md                    # Packer validation skill
│   ├── terraform-review/
│   │   └── SKILL.md                    # Terraform review skill
│   └── sops-management/
│       └── SKILL.md                    # SOPS management skill
└── agents/
    └── (future complex agents here)
```

## Common Commands

```bash
# List available skills
/skills

# Manage agents
/agents

# View skill help
Ask Claude: "What skills are available?"

# Use a specific skill
Ask Claude: "Use [skill-name] to [task]"

# Debug skill issues
claude --debug
```

## Troubleshooting

**Skill not found:**
- Check .claude/skills/ directory exists
- Verify SKILL.md file exists
- Check file formatting

**Skill not triggering:**
- Be more explicit in request
- Mention skill name directly
- Check skill's "When to Use" section

**Skill errors:**
- Check tool availability (packer, terraform, tflint, etc.)
- Verify paths are correct
- Check environment variables

## Future Enhancements

Planned additions:
- **vm-deployment agent** - Multi-step VM deployment automation
- **packer-builder agent** - Complete image build workflow
- **infrastructure-audit agent** - Comprehensive security audit
- **review-cilium skill** - Cilium network policy validation

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Skills Guide](https://docs.anthropic.com/claude-code/skills)
- [Agent SDK](https://docs.anthropic.com/claude-agent-sdk)
- Project: [CLAUDE.md](/home/wdiaz/devland/infra/CLAUDE.md)

## Contributing

When adding new skills:
1. Create skill in `.claude/skills/[skill-name]/`
2. Document in SKILL.md
3. Test thoroughly
4. Update this README
5. Commit to repository

---

**Last Updated:** 2026-01-20
**Project:** Infrastructure as Code (Proxmox + Talos)
**Maintainer:** wdiaz
