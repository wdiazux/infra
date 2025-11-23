# Infrastructure Code Audit - Findings and Fixes

**Date**: 2025-11-23
**Scope**: Packer, Terraform, Ansible - Best practices and functionality review
**Goal**: Ensure code works on first execution

---

## CRITICAL ISSUES (Must Fix Before Deployment)

### 1. ❌ CRITICAL: Talos Template Missing Longhorn Extensions in Header

**File**: `packer/talos/talos.pkr.hcl` (lines 7-10)
**Issue**: Template header comment lists GPU extensions but OMITS required Longhorn extensions
**Impact**: Users following template instructions will miss iscsi-tools and util-linux-tools → Longhorn will fail
**Current**:
```hcl
# 1. Generate schematic at https://factory.talos.dev/ with extensions:
#    - siderolabs/qemu-guest-agent
#    - nonfree-kmod-nvidia-production
#    - nvidia-container-toolkit-production
```

**Should be**:
```hcl
# 1. Generate schematic at https://factory.talos.dev/ with extensions:
#    REQUIRED:
#    - siderolabs/qemu-guest-agent (REQUIRED for Proxmox integration)
#    - siderolabs/iscsi-tools (REQUIRED for Longhorn storage)
#    - siderolabs/util-linux-tools (REQUIRED for Longhorn storage)
#    OPTIONAL (for GPU workloads):
#    - nonfree-kmod-nvidia-production (optional, GPU passthrough)
#    - nvidia-container-toolkit-production (optional, GPU in Kubernetes)
```

**Fix**: Update template header to match README.md documentation

---

## HIGH PRIORITY ISSUES

### 2. ⚠️  Code Duplication: debian vs debian-cloud Templates

**Files**:
- `packer/debian/` (ISO-based, 20-30 min build)
- `packer/debian-cloud/` (cloud image, 5-10 min build, MARKED AS PREFERRED)

**Issue**: Two separate Packer templates for same OS with different approaches
**Impact**:
- Confusion about which one to use
- Code maintenance burden (2x the code to maintain)
- Documentation inconsistency

**Analysis**:
- **debian-cloud** = Best practice (faster, official images, industry standard)
- **debian** = Works out-of-box (no manual setup required)
- **debian-cloud** requires manual pre-setup (import script on Proxmox host)

**Recommendation**:
- **Option A (Best Practice)**: Keep debian-cloud, delete debian (follow modern standards)
- **Option B (Simplicity)**: Keep debian, delete debian-cloud (homelab first-run success)
- **Option C (Both)**: Keep both but clarify in docs which is default

**User's Goal**: "make sure execution is going to work"
**Suggested Fix**: Option B (delete debian-cloud) - ISO templates work without manual setup

---

### 3. ⚠️  Code Duplication: ubuntu vs ubuntu-cloud Templates

**Files**:
- `packer/ubuntu/` (ISO-based)
- `packer/ubuntu-cloud/` (cloud image, MARKED AS PREFERRED)

**Issue**: Same as #2 above
**Recommended Fix**: Delete ubuntu-cloud for homelab simplicity

---

### 4. ⚠️  Template Name Inconsistency Across Documentation

**Files**:
- `terraform/terraform.tfvars.example`
- `terraform/README.md`
- `packer/*/README.md`

**Issue**: Different template names in different docs

**Examples**:
- terraform.tfvars.example: `ubuntu_template_name = "ubuntu-24.04-golden-template-20251118"`
- terraform/README.md: `ubuntu_template_name = "ubuntu-2404-cloud-template-20251119"`
- Packer example: `template_name = "ubuntu-24.04-golden-template"`

**Impact**: User confusion, potential template not found errors
**Fix**: Standardize on ONE naming scheme throughout all docs

---

## MEDIUM PRIORITY ISSUES

### 5. 📝 Packer Version Constraint Too Restrictive

**All Packer files**: `required_version = "~> 1.14.0"`

**Issue**: `~> 1.14.0` allows only 1.14.x (1.14.0-1.14.999)
**Best Practice**: Use `>= 1.14.0, < 2.0.0` for forward compatibility

**Why**:
- Current version is overly restrictive
- When Packer 1.15.0 releases, templates will break
- Semantic versioning: ~> only allows patch releases

**Fix**: Change to `>= 1.14.2, < 2.0.0` (require bugfix version, allow minors)

---

### 6. 📝 Proxmox Plugin Version May Need Update

**All Packer files**: `version = ">= 1.2.2"`

**Issue**: No upper bound, should check latest version
**Current (2025)**: Proxmox plugin latest is likely 1.2.x+
**Best Practice**: Pin to major version to avoid breaking changes

**Recommended**:
```hcl
proxmox = {
  source  = "github.com/hashicorp/proxmox"
  version = "~> 1.2"  # or ">= 1.2.2, < 2.0.0"
}
```

**Fix**: Update to use ~> for major version stability

---

### 7. 📂 Potentially Unused Files

**Cloud Template Files** (if we delete cloud templates):
- `packer/debian-cloud/` (entire directory)
- `packer/ubuntu-cloud/` (entire directory)

**Total**: ~3,000+ lines of code, 10+ files

---

## BEST PRACTICE IMPROVEMENTS

### 8. ✅ Terraform Version Constraint

**File**: `terraform/versions.tf`

**Current**: Need to check if using latest best practices
**Best Practice (2025)**:
```hcl
terraform {
  required_version = ">= 1.13.5"  # Should be ">= 1.6.0" for latest features

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86.0"  # Check if latest
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"  # Check if latest
    }
  }
}
```

---

### 9. ✅ Ansible Best Practices Check

**Files**: `ansible/playbooks/*.yml`

**Need to verify**:
- Using `ansible.builtin.*` for core modules (best practice 2025)
- Not using deprecated modules
- Using `become: true` instead of `sudo: true`
- YAML formatting (spaces, no tabs)

---

## DOCUMENTATION ISSUES

### 10. 📚 README Template Name References

**File**: `terraform/README.md`

**Issue**: Shows cloud template names but tfvars.example shows ISO template names
**Fix**: Make consistent - use ISO template names if deleting cloud templates

---

### 11. 📚 Packer README References

**File**: `packer/README.md`

**Issue**: May reference both ISO and cloud methods inconsistently
**Fix**: Update to reflect chosen approach (ISO or cloud)

---

## VALIDATION CHECKLIST

Before committing fixes, verify:

- [ ] All Packer templates use consistent version constraints
- [ ] All template names match between Packer and Terraform
- [ ] No duplicate code (either ISO or cloud, not both)
- [ ] Talos template lists ALL required extensions (Longhorn + GPU + qemu)
- [ ] All documentation references correct template names
- [ ] No unused files remain
- [ ] Terraform version constraints follow latest best practices
- [ ] All provider versions are current and pinned appropriately

---

## RECOMMENDED FIXES (Priority Order)

1. **FIX CRITICAL**: Update Talos template header with Longhorn extensions
2. **DELETE**: Remove debian-cloud/ and ubuntu-cloud/ directories (simplify)
3. **UPDATE**: Standardize template names in all documentation
4. **UPDATE**: Packer version constraints from ~> 1.14.0 to >= 1.14.2, < 2.0.0
5. **UPDATE**: Pin Proxmox plugin to ~> 1.2
6. **VERIFY**: Terraform provider versions are latest
7. **VERIFY**: All documentation is consistent

---

## QUESTIONS FOR USER

1. **Template Strategy**: Keep ISO templates only (simpler, works out-of-box) or cloud templates (faster, best practice)?
   - Recommendation: ISO for homelab reliability

2. **Template Naming**: Standardize on which naming scheme?
   - Current: Multiple inconsistent names
   - Recommendation: `{os}-{version}-golden-template` (no timestamps)

---

## ESTIMATED IMPACT

**Files to modify**: ~15
**Files to delete** (if removing cloud templates): ~10
**Lines of code to change**: ~50
**Lines of code to remove**: ~3,000+
**Build time impact**: None (removing unused code)
**Deployment reliability**: ⬆️ Improved (less confusion, clearer docs)
