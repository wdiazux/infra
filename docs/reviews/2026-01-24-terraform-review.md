# Terraform Review - 2026-01-24

## Summary

Comprehensive review of Terraform configurations across the infrastructure repository.

- **Total Terraform Code**: ~5,200 lines across 32 files
- **Provider Versions**: 1 minor update available
- **Critical Issues**: 0
- **Warnings**: 1
- **Info**: 2
- **Overall Status**: ✅ Excellent - production-ready

## Provider Versions

### Current Versions (from .terraform.lock.hcl)

| Provider | Current | Latest | Constraint | Status |
|----------|---------|--------|------------|--------|
| bpg/proxmox | 0.93.0 | 0.93.0 | ~> 0.93.0 | ✅ Latest |
| siderolabs/talos | 0.10.0 | 0.10.1 | ~> 0.10.0 | ⚠️ Update available |
| hashicorp/helm | 3.1.1 | 3.1.1 | ~> 3.1.0 | ✅ Latest |
| hashicorp/kubernetes | 2.36.0 | ~2.36.x | ~> 2.36.0 | ✅ Current |
| hashicorp/local | 2.5.3 | ~2.5.x | ~> 2.5.3 | ✅ Current |
| hashicorp/null | 3.2.4 | ~3.2.x | ~> 3.2.4 | ✅ Current |
| carlpett/sops | 1.1.1 | ~1.1.x | ~> 1.1.1 | ✅ Current |

### Provider Update Notes

**siderolabs/talos 0.10.1** (Available):
- Patch release with bug fixes
- No breaking changes from 0.10.0
- **Action**: Optional update via `terraform init -upgrade`

### Breaking Changes Since Last Review (2026-01-22)

None detected. All providers remain compatible.

---

## Warnings

### [TF-W001] Unused Variable

**File**: `terraform/talos/variables-network.tf:110`
**Severity**: Low
**TFLint Rule**: `terraform_unused_declarations`

**Finding**:
```hcl
variable "ingress_controller_ip" {
  description = "LoadBalancer IP for Cilium Ingress Controller"
  type        = string
  default     = "10.10.2.20"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.ingress_controller_ip))
    error_message = "ingress_controller_ip must be a valid IPv4 address."
  }
}
```

**Analysis**: This variable was originally defined for Cilium Ingress Controller but is no longer used since migrating to Gateway API. The IP `10.10.2.20` is now used by the Gateway API instead.

**Recommendation**: Either:
1. Remove the variable (preferred - reduces confusion)
2. Rename to `gateway_api_ip` and use it in `cilium-inline.tf`
3. Add a comment documenting its reserved status

**Action Required**: Low priority - cosmetic improvement

---

## Info

### [TF-I001] Talos Provider Update Available

**File**: `terraform/talos/.terraform.lock.hcl:122-143`

**Current**: 0.10.0
**Available**: 0.10.1

**Note**: A patch release is available. The `~> 0.10.0` constraint allows this update.

**Update Command**:
```bash
cd terraform/talos
terraform init -upgrade
```

**Risk**: Low - patch releases typically contain bug fixes only

**Action Required**: Optional - update at your convenience

---

### [TF-I002] Memory Ballooning Implemented

**File**: `terraform/talos/vm.tf:52-55`, `terraform/modules/proxmox-vm/main.tf:51-54`

**Previous State** (2026-01-22): Warning - memory ballooning not configured
**Current State**: ✅ Fixed

```hcl
memory {
  dedicated = var.node_memory
  floating  = var.node_memory  # Memory ballooning enabled
}
```

**Status**: Addressed since last review

---

## Security Review

### ✅ Security Strengths

| Category | Implementation | Status |
|----------|---------------|--------|
| Secrets Management | SOPS + Age encryption | ✅ Excellent |
| Provider Auth | API tokens (not passwords) | ✅ Secure |
| File Permissions | kubeconfig/talosconfig 0600 | ✅ Correct |
| Sensitive Outputs | Marked as `sensitive = true` | ✅ Proper |
| Validation | Input validation on all IPs | ✅ Comprehensive |
| Network | VLAN support configured | ✅ Ready |

### Security Configurations Verified

1. **SOPS Integration** (`sops.tf`):
   - Proxmox credentials encrypted
   - Git credentials encrypted
   - NAS backup credentials encrypted
   - Cloudflare API token encrypted
   - Pangolin tunnel credentials encrypted

2. **Kubernetes Secrets**:
   - `kubernetes_secret.longhorn_backup` - NFS credentials
   - `kubernetes_secret.cloudflare_api_token` - cert-manager DNS-01

3. **RBAC** (`cilium-inline.tf:265-288`):
   - Talos node reader ClusterRole properly scoped
   - Minimal permissions (get, list, watch nodes)

4. **Container Security** (`addons.tf:218-230`):
   - NVIDIA device plugin drops ALL capabilities
   - `allowPrivilegeEscalation: false`

### ⚠️ Acknowledged Risks (Acceptable for Homelab)

1. **Terraform State Contains Decoded Secrets**
   - Documented in CLAUDE.md
   - Mitigated: Local state only, physical security

2. **TLS Verification** (`proxmox_tls_insecure`):
   - May be `true` for self-signed certs
   - Common for homelab Proxmox installations

---

## Code Quality Analysis

### Validation Results

| Check | Result |
|-------|--------|
| `terraform validate` (talos) | ✅ Success |
| `terraform validate` (traditional-vms) | ✅ Success |
| `terraform fmt -check` | ✅ No changes needed |
| `trivy config terraform/` | ✅ 0 misconfigurations |
| `tflint` (talos) | ⚠️ 1 warning (unused variable) |
| `tflint` (traditional-vms) | ✅ No issues |

### Best Practices Observed

1. **Provider Version Pinning**
   - All providers use `~>` for patch flexibility
   - Lock file maintains reproducibility

2. **Code Organization**
   - Logical file separation (vm.tf, config.tf, secrets.tf, etc.)
   - Network variables in dedicated file
   - Service configurations in dedicated file

3. **Documentation**
   - Excellent inline comments (Longhorn requirements, GPU auth, etc.)
   - File headers explain purpose
   - Notes sections for verification commands

4. **Lifecycle Management**
   - Preconditions validate template existence
   - `ignore_changes` prevents drift recreation
   - `depends_on` chains properly ordered
   - Pre-destroy cleanup for Longhorn, FluxCD, Forgejo

5. **Error Handling**
   - Timeout loops with informative messages
   - Graceful fallbacks where appropriate
   - `on_failure = continue` for destroy operations

6. **DRY Principle**
   - Locals compute derived values
   - Module reuse for traditional VMs
   - Variables have sensible defaults

### Code Patterns

**for_each Pattern** (`traditional-vms/main.tf`):
```hcl
module "traditional_vm" {
  source   = "../modules/proxmox-vm"
  for_each = local.enabled_vms
  # Safe add/remove without cascade destruction
}
```

**Conditional Resources**:
```hcl
resource "kubernetes_namespace" "cert_manager" {
  count = var.auto_bootstrap && var.enable_cert_manager ? 1 : 0
}
```

**terraform_data for Destroy Hooks** (`pre-destroy.tf`):
```hcl
resource "terraform_data" "longhorn_pre_destroy" {
  triggers_replace = { kubeconfig = local.kubeconfig_path }
  provisioner "local-exec" {
    when = destroy
    # Cleanup logic
  }
}
```

---

## Configuration Highlights

### Talos Machine Configuration (`config.tf`)

**Strengths**:
- Three-layer Longhorn setup documented (extensions, modules, mounts)
- Kernel modules properly loaded (nbd, iscsi_tcp, nvidia)
- KubePrism enabled for API caching
- Graceful shutdown configured (60s/30s)
- PodGC threshold reduced to 10 for homelab

### Cilium Inline Manifest (`cilium-inline.tf`)

**Strengths**:
- Solves CNI chicken-and-egg problem
- Gateway API enabled with ALPN
- L2 announcements configured
- Resource limits appropriate for homelab
- Security context drops SYS_MODULE

### Pre-Destroy Cleanup (`pre-destroy.tf`)

**Strengths**:
- Longhorn deleting-confirmation-flag set
- FluxCD suspended before destroy
- Webhook configurations removed
- Namespace finalizers cleared
- Comprehensive documentation

---

## Metrics

| Metric | Value |
|--------|-------|
| Total Lines | ~5,200 |
| Files | 32 |
| Providers | 7 |
| Resources (talos) | ~30 |
| Variables (talos) | ~70 |
| Outputs (talos) | 20 |

---

## Recommendations

### Priority: Low

1. **Remove Unused Variable** [TF-W001]
   - File: `terraform/talos/variables-network.tf:110-119`
   - Action: Delete `ingress_controller_ip` or rename to `gateway_api_ip`
   - Effort: 5 minutes

2. **Update Talos Provider** [TF-I001]
   - Command: `terraform init -upgrade`
   - Risk: Low (patch release)
   - Effort: 2 minutes

### Priority: None (Maintenance)

1. **Continue Quarterly Reviews**
   - Next review: 2026-04-24
   - Monitor provider releases

2. **Track Upstream Changes**
   - [bpg/proxmox releases](https://github.com/bpg/terraform-provider-proxmox/releases)
   - [siderolabs/talos releases](https://github.com/siderolabs/terraform-provider-talos/releases)

---

## Comparison with Previous Review

| Item | 2026-01-22 | 2026-01-24 | Change |
|------|------------|------------|--------|
| Critical Issues | 0 | 0 | ✅ Same |
| Warnings | 2 | 1 | ✅ Improved |
| Info | 3 | 2 | ✅ Improved |
| Memory Ballooning | ⚠️ Missing | ✅ Fixed | ✅ Addressed |
| Provider Updates | 0 | 1 | ℹ️ Normal |
| Security | Excellent | Excellent | ✅ Maintained |

---

## Conclusion

Your Terraform configuration remains **production-ready** with excellent practices:

✅ All providers current (1 optional patch update)
✅ No deprecated features in use
✅ Memory ballooning now enabled (fixed since 2026-01-22)
✅ Comprehensive inline documentation
✅ Proper secrets management with SOPS
✅ Good module abstraction
✅ Security best practices followed
✅ 0 security misconfigurations (Trivy)

The single warning (unused variable) is a minor cosmetic issue that doesn't affect functionality.

### Quick Actions

```bash
# Optional: Update Talos provider
cd terraform/talos
terraform init -upgrade

# Optional: Remove unused variable
# Edit variables-network.tf:110-119

# Verify configuration
terraform validate
tflint
```

---

**Sources**:
- [bpg/proxmox Releases](https://github.com/bpg/terraform-provider-proxmox/releases)
- [siderolabs/talos Releases](https://github.com/siderolabs/terraform-provider-talos/releases)
- [Terraform Registry - bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest)
- [Terraform Registry - siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos/latest)

---

**Review Date**: 2026-01-24
**Reviewer**: Claude Code (Terraform Review Skill)
**Previous Review**: 2026-01-22
**Next Review**: 2026-04-24 (quarterly)
