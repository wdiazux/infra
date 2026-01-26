# General Cleanup Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure no duplicate, unused, or obsolete code exists. Verify documentation is up to date. Confirm first-deployment works automatically.

**Architecture:** Audit the entire infrastructure for cleanup issues, documentation accuracy, and deployment readiness.

**Tech Stack:** Terraform, Kubernetes, FluxCD, SOPS

---

## Audit Findings

### Code Quality Assessment

| Area | Status | Issues Found |
|------|--------|-------------|
| Unused Terraform variables | Clean | None |
| Commented-out code | Clean | Backend config (intentional documentation) |
| Dead code / unreachable | Clean | None |
| TODO/FIXME comments | Clean | None in .tf files |
| Deleted TEMPLATE files | Clean | Already replaced with .enc.yaml files |
| Duplicate resources | Clean | No duplicates across namespaces |
| Obsolete configs | Clean | No obsolete configs found |
| Weave GitOps | Active | Deployed and functional |

### Documentation Gaps Identified

1. Weave GitOps is deployed (via Terraform) but may not be documented as a service
2. Forward auth (Cilium Envoy ext_authz) disabled status needs documentation
3. Network reference docs may need updating for recent Gateway API migration (2026-01-25)
4. CHANGELOG.md needs entry for recent changes

### First-Deployment Readiness

The infrastructure is designed for automatic first deployment via:
1. Terraform bootstraps: VM, Talos, Cilium (inline), Longhorn, PostgreSQL, Forgejo
2. FluxCD syncs from Forgejo: all Kubernetes applications
3. Zitadel CronJob: OIDC applications and secrets (self-healing)
4. cert-manager via FluxCD: TLS certificates

**Potential issue:** The Zitadel OIDC setup job depends on Zitadel being fully deployed by FluxCD. Verify the dependency chain is correct for fresh deployments.

---

### Task 1: Verify TEMPLATE File Cleanup

**Files:**
- Check: `secrets/` directory

**Step 1: Verify deleted TEMPLATE files are not referenced**

Search across all Terraform and documentation files for references to:
- `TEMPLATE-git-creds.yaml`
- `TEMPLATE-nas-backup-creds.yaml`
- `TEMPLATE-proxmox-creds.yaml`

If any references exist, update them to point to the current `.enc.yaml` files.

**Step 2: Verify .enc.yaml files are properly referenced**

Check that `sops.tf` references the correct encrypted files:
- `secrets/git-creds.enc.yaml`
- `secrets/nas-backup-creds.enc.yaml`
- `secrets/proxmox-creds.enc.yaml`

**Step 3: Commit if any reference updates needed**

```bash
git add -A
git commit -m "fix: update references from TEMPLATE to encrypted secret files"
```

---

### Task 2: Verify Documentation Accuracy

**Files:**
- Read: `docs/reference/network.md`
- Read: `docs/services/forgejo.md`
- Read: `CLAUDE.md`

**Step 1: Verify network reference**

Check that `docs/reference/network.md` accurately reflects:
- All LoadBalancer IPs match `cluster-vars.yaml`
- Gateway API endpoint (10.10.2.20) is documented
- All web services listed with correct URLs
- No obsolete LoadBalancer IPs listed (services migrated to ClusterIP)

**Step 2: Verify CLAUDE.md accuracy**

Check that `CLAUDE.md` reflects:
- Current Talos version (v1.12.1)
- Current Kubernetes version (v1.35.0)
- Current provider versions
- Correct network table
- Recent changes section is up to date

**Step 3: Update any inaccurate documentation**

**Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "docs: update documentation to reflect current infrastructure state"
```

---

### Task 3: Verify First-Deployment Dependency Chain

**Step 1: Trace the deployment order**

Verify this dependency chain works for a fresh deployment:

```
1. Terraform creates Proxmox VM
2. Talos bootstraps with inline Cilium manifest
3. Node becomes Ready (CNI active)
4. Terraform creates namespaces, secrets
5. Terraform deploys Longhorn via Helm
6. Terraform deploys PostgreSQL via Helm
7. Terraform deploys Forgejo via Helm
8. Terraform generates Forgejo token
9. Terraform creates Forgejo repository
10. Terraform pushes code to Forgejo
11. Terraform installs FluxCD
12. Terraform creates SOPS age secret
13. Terraform creates GitRepository + Kustomization
14. FluxCD reconciles infrastructure (cert-manager, storage classes, namespaces, security)
15. FluxCD reconciles applications (all services)
16. Zitadel deploys via FluxCD HelmRelease
17. Zitadel OIDC initial Job creates applications and secrets
18. CronJob maintains OIDC state every 15 minutes
```

**Step 2: Check for missing depends_on**

Verify that:
- [ ] PostgreSQL waits for Longhorn (storage ready)
- [ ] Forgejo waits for PostgreSQL (database ready)
- [ ] Token generation waits for Forgejo (API ready)
- [ ] FluxCD waits for Forgejo token (Git credentials)
- [ ] Kustomization waits for GitRepository (source ready)
- [ ] SOPS secret created before Kustomization

**Step 3: Verify Zitadel OIDC Job tolerates startup delay**

The initial OIDC setup job should handle the case where Zitadel is not yet deployed by FluxCD. Check that:
- [ ] The job has sufficient retry logic
- [ ] `backoffLimit` is high enough for FluxCD reconciliation delay
- [ ] The job waits for Zitadel API availability (health check loop)

Read `kubernetes/apps/base/auth/zitadel/oidc-setup-job.yaml` and verify the retry/timeout configuration.

**Step 4: Document any issues found**

---

### Task 4: Verify No Unused Resources

**Step 1: Check for orphaned Kubernetes resources**

Search for resources that are defined but not included in any kustomization:

```bash
# List all YAML files in kubernetes/apps/base/
# Cross-reference with kustomization.yaml files
```

**Step 2: Check for unused Terraform outputs**

Review `outputs.tf` and verify all outputs are useful.

**Step 3: Check for unused Helm values files**

Verify all files in `kubernetes/infrastructure/values/` are referenced.

**Step 4: Commit any cleanup**

```bash
git add -A
git commit -m "chore: remove unused resources and clean up stale references"
```

---

### Task 5: Update CHANGELOG

**Files:**
- Modify: `docs/CHANGELOG.md`

**Step 1: Add entry for today's changes**

If the Terraform provider improvements, script extraction, or other cleanup tasks are implemented, add a dated entry to the changelog.

**Step 2: Commit**

```bash
git add docs/CHANGELOG.md
git commit -m "docs: update CHANGELOG with cleanup and organization changes"
```

---

## Validation Checklist

- [ ] No references to deleted TEMPLATE files
- [ ] All SOPS encrypted files are properly referenced
- [ ] Network documentation matches current cluster-vars
- [ ] CLAUDE.md reflects current versions and architecture
- [ ] First-deployment dependency chain is correct
- [ ] Zitadel OIDC job handles startup delay
- [ ] No orphaned resources in Kubernetes manifests
- [ ] No unused Terraform outputs
- [ ] CHANGELOG is up to date
