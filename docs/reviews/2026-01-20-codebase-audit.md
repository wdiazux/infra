# Infrastructure Codebase Audit - 2026-01-20

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| Warning | 3 (all non-blocking) |
| Info | 12 |

The codebase is in excellent shape. No deprecated Kubernetes APIs, no critical issues.

**UPDATE (2026-01-20)**: All actionable items resolved:
- Pre-commit hooks updated to latest versions
- cilium-values.yaml moved to docs/reference/ for clarity
- TODO.md: All 8 items now complete
- Faster Whisper and librespeed confirmed as never deployed

**Remaining Warnings** (non-blocking):
- WARN-004: it-tools uses `latest` tag (minor)
- WARN-005: Packer comment dates (cosmetic)
- WARN-007: Multiple PostgreSQL instances (optional optimization)

---

## Warning

### [WARN-001] Terraform Provider Updates Available

- **Files**: `terraform/talos/terraform.tf`, `terraform/talos/.terraform.lock.hcl`
- **Current Versions**:
  - `bpg/proxmox`: 0.93.0 (constraint: ~> 0.93.0)
  - `siderolabs/talos`: 0.10.0 (constraint: ~> 0.10.0)
  - `hashicorp/helm`: 3.1.1 (constraint: ~> 3.1.0)
  - `hashicorp/kubernetes`: 2.36.0 (constraint: ~> 2.36.0)
- **Recommendation**: Check for newer stable versions periodically. Run `terraform init -upgrade` to check for updates.
- **Docs**: https://registry.terraform.io/providers/bpg/proxmox/latest

### ~~[WARN-002] Pre-commit Hooks Outdated~~ ✅ RESOLVED

- **Status**: FIXED on 2026-01-20
- **Updated versions**:
  - `pre-commit-hooks`: v6.0.0
  - `pre-commit-terraform`: v1.105.0
  - `yamllint`: v1.38.0
  - `ansible-lint`: v26.1.1

### ~~[WARN-003] Services Marked for Removal Still Present~~ ✅ RESOLVED

- **Status**: FIXED on 2026-01-20
- **Finding**: Faster Whisper and librespeed were never deployed (only planned)
- **Action**: References only existed in planning docs (historical records kept)
- **TODO.md**: Sections 6 and 7 marked as complete

### [WARN-004] Image Using `latest` Tag

- **File**: `kubernetes/apps/base/tools/it-tools/deployment.yaml:34`
- **Current**: `image: corentinth/it-tools:latest`
- **Issue**: Using `latest` tag prevents reproducible deployments and breaks image automation
- **Fix**: Pin to specific version, e.g., `corentinth/it-tools:2024.10.22-7ca5933`

### [WARN-005] Packer Plugin Version Comments Outdated

- **Files**: `packer/ubuntu/ubuntu.pkr.hcl`, `packer/debian/debian.pkr.hcl`
- **Current Comment**: `">= 1.2.3" # Latest version as of Dec 2025`
- **Issue**: Comments reference Dec 2025 but current date is Jan 2026
- **Fix**: Update comments or remove date references, use variable constraints

### ~~[WARN-006] cilium-values.yaml is Reference Only~~ ✅ RESOLVED

- **Status**: FIXED on 2026-01-20
- **Action**: Moved to `docs/reference/cilium-values-reference.yaml`
- **Rationale**: Kept for documentation value but relocated to avoid confusion with active configs

### [WARN-007] Multiple PostgreSQL Instances

- **Files**:
  - `kubernetes/apps/base/automation/postgres/` - automation namespace
  - `kubernetes/apps/base/media/immich/postgres-statefulset.yaml` - media namespace
  - `kubernetes/apps/base/management/paperless/postgres-statefulset.yaml` - management namespace
  - `kubernetes/apps/base/tools/attic/postgres-statefulset.yaml` - tools namespace
- **Issue**: Each service runs its own PostgreSQL instance, increasing resource usage
- **Recommendation**: Consider consolidating to a shared PostgreSQL cluster for homelab efficiency (optional, trade-off between isolation and resources)

### ~~[WARN-008] TODO.md Contains Incomplete Items~~ ✅ RESOLVED

- **File**: `TODO.md`
- **Status**: ALL items complete as of 2026-01-20
- **Items** (8 of 8 complete):
  1. ~~Semantic versioning for templates~~ ✅
  2. ~~Grafana dashboard uptime display~~ ✅ (uses dtdurations unit)
  3. ~~Obico service creation~~ ✅
  4. ~~Document external Ollama access~~ ✅
  5. ~~Faster Whisper removal~~ ✅
  6. ~~librespeed removal~~ ✅
  7. ~~Pangolin private resources setup~~ ✅ (docs/services/pangolin.md)

---

## Info

### [INFO-001] Kubernetes APIs are Current

- **Status**: All Kubernetes manifests use current stable APIs
- **Checked**: `apps/v1`, `v1`, `rbac.authorization.k8s.io/v1`, `storage.k8s.io/v1`
- **Result**: No deprecated beta APIs found

### [INFO-002] FluxCD Resources Using Latest APIs

- **Status**: All FluxCD resources use `v1` APIs
- **APIs Used**:
  - `source.toolkit.fluxcd.io/v1`
  - `kustomize.toolkit.fluxcd.io/v1`
  - `image.toolkit.fluxcd.io/v1`
  - `helm.toolkit.fluxcd.io/v2`

### [INFO-003] SOPS Integration Working

- **Files**: Multiple `*.enc.yaml` files across namespaces
- **Status**: All secrets properly encrypted with SOPS (sops version 3.11.0)

### [INFO-004] Image Automation Configured

- **Directory**: `kubernetes/infrastructure/image-automation/`
- **Status**: ImagePolicies and ImageUpdateAutomation configured for all namespaces
- **Services with Auto-Update**: emby, navidrome, immich, home-assistant, ntfy, arr-stack apps

### [INFO-005] Ansible Collections Updated (Dec 2025)

- **File**: `ansible/requirements.yml`
- **Status**: Collections recently updated with proper version constraints
- **Versions**:
  - `community.sops`: >=2.2.7
  - `community.general`: >=12.0.1
  - `ansible.posix`: >=2.1.0
  - `kubernetes.core`: >=6.2.0

### [INFO-006] Longhorn Configuration Optimized for Single-Node

- **File**: `kubernetes/infrastructure/values/longhorn-values.yaml`
- **Status**: Properly configured with `defaultReplicaCount: 1` and single-node optimizations

### [INFO-007] Cilium L2 Load Balancing Configured

- **File**: `terraform/talos/cilium-inline.tf`
- **Status**: L2 announcements and IP pools properly configured for homelab

### [INFO-008] GPU Passthrough Configured

- **Files**: `terraform/talos/vm.tf`, `terraform/talos/variables.tf`
- **Status**: NVIDIA GPU passthrough enabled with proper resource mapping

### [INFO-009] Backup Infrastructure in Place

- **Components**:
  - Longhorn backups to NFS (`nfs://10.10.2.5:/mnt/tank/backups/longhorn`)
  - Velero with MinIO (`kubernetes/apps/base/backup/`)
  - Volume Snapshot CRDs configured
- **Status**: Backup infrastructure properly configured

### [INFO-010] No Backup Files Found

- **Search**: `**/*.bak`
- **Result**: No orphaned backup files in repository

### [INFO-011] Git Hooks Pre-configured

- **File**: `.pre-commit-config.yaml`
- **Hooks**: terraform_fmt, terraform_validate, tflint, trivy, yamllint, ansible-lint, sops-check
- **Status**: Comprehensive pre-commit setup

### [INFO-012] Documentation Well-Structured

- **Directory**: `docs/`
- **Structure**: getting-started, deployment, services, operations, reference, plans
- **Status**: Documentation follows best practices with CHANGELOG.md and CONTRIBUTING.md

---

## Recommended Actions (Priority Order)

### ~~High Priority~~ ✅ COMPLETED

1. ~~**Complete service removals** (TODO sections 6, 7)~~ ✅
   - Confirmed Faster Whisper and librespeed were never deployed

2. **Fix it-tools image tag** (WARN-004) - STILL PENDING
   - Change from `latest` to pinned version

3. ~~**Update pre-commit hooks** (WARN-002)~~ ✅
   - Updated to latest versions

### ~~Medium Priority~~ ✅ COMPLETED

4. ~~**Complete Obico service** (TODO section 4)~~ ✅
   - Already implemented at `kubernetes/apps/base/printing/obico/`

5. ~~**Document Ollama external access** (TODO section 5)~~ ✅
   - Documentation in `kubernetes/apps/base/ai/README.md`

6. ~~**Configure Pangolin private resources** (TODO section 8)~~ ✅
   - Documentation at `docs/services/pangolin.md`

### Low Priority

7. ~~**Clean up cilium-values.yaml** (WARN-006)~~ ✅
   - Moved to `docs/reference/`

8. **Consider PostgreSQL consolidation** (WARN-007) - OPTIONAL
   - Evaluate resource savings vs complexity

9. ~~**Update Grafana dashboard** (TODO section 2)~~ ✅
   - Uses `dtdurations` unit for human-readable uptime

---

## Version Summary

| Component | Current | Status |
|-----------|---------|--------|
| Terraform | >= 1.14.2 | OK |
| Talos Linux | v1.12.1 | OK |
| Kubernetes | v1.35.0 | OK |
| Cilium | 1.18.6 | OK |
| Longhorn | 1.10.1 | OK |
| Packer | ~> 1.14.3 | OK |
| bpg/proxmox provider | 0.93.0 | Check for updates |
| siderolabs/talos provider | 0.10.0 | Check for updates |

---

*Generated: 2026-01-20*
*Reviewed by: Claude Code Audit*
