# Comprehensive IaC Code Review - 2026-01-22

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| Warning  | 0 (2 fixed) |
| Info     | 5 |

**Overall Assessment**: The infrastructure codebase is well-structured, follows best practices, and is production-ready for a homelab environment.

**Related Reviews**:
- Terraform: `docs/reviews/2026-01-22-terraform-review.md` (completed today)
- Kubernetes: `docs/reviews/2026-01-21-kubernetes-review.md` (resource limits addressed today)

---

## Detected Versions

| Technology | Version | Status |
|------------|---------|--------|
| Terraform | >= 1.14.2 | Current |
| bpg/proxmox provider | 0.93.0 | Current |
| siderolabs/talos provider | 0.10.0 | Current |
| hashicorp/helm provider | 3.1.1 | Current |
| hashicorp/kubernetes provider | 2.36.0 | Current |
| Talos Linux | v1.12.1 | Current |
| Kubernetes | v1.35.0 | Current |
| FluxCD APIs | v1 (kustomize/helm/source/image) | Current |
| Packer | ~> 1.14.3 | Current |
| Ansible Collections | community.general >=12.0.1, kubernetes.core >=6.2.0 | Current |

---

## Warning (Fixed)

### [WARN-001] Packer template cloud-init exit code workaround ✅ FIXED

- **File**: `packer/ubuntu/ubuntu.pkr.hcl:103-113`
- **Issue**: `valid_exit_codes = [0, 2]` accepts degraded state without logging
- **Fix Applied**: Added conditional logging to distinguish between clean (0) and degraded (2) states
- **Docs**: https://cloudinit.readthedocs.io/en/latest/explanation/return_codes.html

### [WARN-002] Ansible shell module for CrowdSec collections ✅ FIXED

- **File**: `ansible/playbooks/day1_ubuntu_baseline.yml:180-199`
- **Issue**: Used `ansible.builtin.shell` with `--force` and `changed_when: false`
- **Fix Applied**: Split into idempotent tasks that check for existing collections before installing
- **Benefit**: Proper change detection, no unnecessary reinstalls

---

## Info

### [INFO-001] Memory ballooning implemented ✅

- **Files**: `terraform/talos/vm.tf:52-55`, `terraform/modules/proxmox-vm/main.tf:50-53`
- **Current**: `floating = var.node_memory` enables ballooning
- **Status**: Implemented today per Terraform review recommendation
- **Docs**: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#memory

### [INFO-002] Resource limits added ✅

- **Files**: 21 deployments in `kubernetes/apps/base/`
- **Current**: Memory limits added today per Kubernetes review
- **Policy**: Memory limits only (no CPU limits to allow burst on single-node)
- **Docs**: `docs/reference/resource-strategy.md`

### [INFO-003] NetworkPolicies implemented ✅

- **File**: `kubernetes/infrastructure/security/network-policies.yaml`
- **Status**: Comprehensive coverage for 10 namespaces (1343 lines)
- **Philosophy**: Default-deny egress with explicit allows
- **Docs**: `docs/reference/security-strategy.md`

### [INFO-004] FluxCD dependency ordering correct

- **File**: `kubernetes/clusters/homelab/infrastructure.yaml`
- **Status**: Proper `dependsOn` chains ensure correct deployment order
- **Pattern**: controllers → cluster-vars → namespaces → security → storage → configs

### [INFO-005] Privileged containers documented

- **Files**:
  - `kubernetes/apps/base/forgejo/runner/deployment.yaml` (DinD)
  - `kubernetes/apps/base/automation/home-assistant/deployment.yaml` (device discovery)
- **Status**: Both have inline comments explaining technical requirement
- **Docs**: `docs/reference/security-strategy.md#layer-3-container-security`

---

## Technologies Reviewed

### Terraform ✅
**Status**: Reviewed today - see `docs/reviews/2026-01-22-terraform-review.md`

**Highlights**:
- All providers up-to-date (0 deprecated features)
- Memory ballooning implemented (TF-W001 addressed)
- GPU passthrough correctly configured with resource mapping
- Comprehensive inline documentation

### Kubernetes ✅
**Status**: Reviewed yesterday, issues addressed today

**Addressed Today**:
- 21 deployments received memory limits
- 3 securityContext gaps fixed (immich-redis, immich-ml, obico-redis)
- node-exporter DaemonSet received `app.kubernetes.io/part-of` label

**Unchanged (Acceptable)**:
- No CPU limits (intentional for single-node burst)
- `:latest` tags on it-tools and attic (documented exceptions)

### FluxCD ✅
**Status**: Current API versions (v1), proper structure

**Best Practices Observed**:
- Kustomize overlay pattern (base/production)
- SOPS decryption integration for secrets
- Image automation policies for updates
- `dependsOn` for deployment ordering

### Packer ✅
**Status**: Cloud-init logging improved (WARN-001 fixed)

**Best Practices Observed**:
- Cloud image approach (faster than ISO)
- Semantic versioning for templates
- Manifest generation for tracking
- SFTP for file transfer (recommended)
- Exit code logging for debugging

### Ansible ✅
**Status**: CrowdSec idempotency improved (WARN-002 fixed)

**Best Practices Observed**:
- FQCN module names throughout
- Breaking change documentation in requirements.yml
- Handlers for service restarts
- OS-specific task organization

---

## Security Posture

**Reference**: `docs/reference/security-strategy.md`

| Layer | Status | Implementation |
|-------|--------|----------------|
| Secrets Management | ✅ Active | SOPS + Age encryption |
| Network Isolation | ✅ Active | NetworkPolicies (10 namespaces) |
| Container Security | ✅ Active | SecurityContexts, justified privileged |
| Pod Security Standards | ⚠️ Not Implemented | Deferred (conflicts with required privileged) |
| Image Security | ✅ Active | Version pinning, documented exceptions |
| RBAC | ⚠️ Minimal | Default + custom for monitoring |
| Backup Security | ✅ Active | Velero + verification procedures |

---

## Recommendations

### No Action Required

All identified issues from recent reviews have been addressed:
1. ✅ Memory ballooning added (2026-01-22)
2. ✅ Resource limits added to 21 deployments (2026-01-22)
3. ✅ SecurityContext gaps fixed (2026-01-22)
4. ✅ NetworkPolicies comprehensive (2026-01-22)

### Optional Future Improvements

From `docs/reference/security-strategy.md#future-enhancements`:
- Centralized logging (Loki or similar)
- Trivy automation for image scanning
- Kubernetes audit logs
- Pod Security Standards (audit/warn mode)

---

## Review Coverage

### Files Scanned

| Category | Count | Coverage |
|----------|-------|----------|
| Terraform (.tf) | 31 | 100% |
| Kubernetes (.yaml) | 100+ | Sampled |
| Packer (.pkr.hcl) | 10 | 100% |
| Ansible (.yml) | 15 | 100% |
| Lock files | 2 | 100% |

### Documentation Verified

| Document | Status |
|----------|--------|
| CLAUDE.md | ✅ Current |
| security-strategy.md | ✅ Current (updated 2026-01-22) |
| resource-strategy.md | ✅ Current (updated 2026-01-22) |
| CHANGELOG.md | ✅ Current |

---

## Conclusion

The infrastructure is **production-ready** with mature IaC practices:

✅ All provider versions current
✅ No deprecated APIs in use
✅ Comprehensive inline documentation
✅ Defense-in-depth security layers
✅ Resource limits implemented
✅ NetworkPolicies deployed
✅ Regular review cadence established
✅ All warnings addressed

**Recent improvements** (last 48 hours):
- Memory ballooning on VMs
- Resource limits on 21 deployments
- NetworkPolicies for 10 namespaces
- Security strategy documentation
- Packer cloud-init logging (this review)
- Ansible CrowdSec idempotency (this review)

---

**Review Date**: 2026-01-22
**Reviewer**: Claude Code (code-review skill)
**Previous Reviews**:
- Terraform: 2026-01-22
- Kubernetes: 2026-01-21
**Next Recommended Review**: 2026-04-22 (quarterly)
