# Helm Provider v3.x Upgrade Design

**Date**: 2026-01-15
**Status**: Approved
**Risk Level**: Low (dev/testing environment)

## Summary

Upgrade hashicorp/helm Terraform provider from v2.17.0 to v3.1.1.

## Breaking Changes in v3.x

1. **Block to list syntax**: `set {}` blocks become `set = [{}]` lists
2. **Provider config**: `kubernetes {}` block becomes `kubernetes = {}`
3. **Plugin framework**: Migrated to terraform-plugin-framework (Protocol 6)

## Scope

| File | Changes |
|------|---------|
| `terraform.tf` | Version: `~> 2.17.0` → `~> 3.1.0` |
| `providers.tf` | `kubernetes {}` → `kubernetes = {}` |
| `forgejo.tf` | 6 `set` + 2 `set_sensitive` blocks |
| `postgresql.tf` | 10 `set` + 1 `set_sensitive` blocks |
| `weave-gitops.tf` | 7 `set` + 1 `set_sensitive` blocks |

**Total**: 5 files, ~28 syntax changes

## Syntax Change Example

```hcl
# Before (v2.x)
set {
  name  = "image.tag"
  value = "1.0.0"
}

# After (v3.x)
set = [{
  name  = "image.tag"
  value = "1.0.0"
}]
```

## Execution Plan

1. Backup terraform state (optional)
2. Update all files with new syntax
3. Run `terraform init -upgrade`
4. Run `terraform plan` - verify no destroys
5. Run `terraform apply`

## Rollback Plan

If state migration fails:
1. Revert code changes via git
2. Run `terraform init` to restore v2.17.0
3. Worst case: destroy and recreate Helm releases

## Success Criteria

- `terraform plan` shows only in-place updates
- `terraform apply` completes without errors
- All Helm releases remain functional
