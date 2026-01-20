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
