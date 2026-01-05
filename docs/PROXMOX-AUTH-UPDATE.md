# Proxmox Authentication Variable Updates

**Date:** 2026-01-04 (Updated: 2026-01-05)
**Status:** ✅ Completed

## Summary

Updated all Proxmox authentication to use the correct format per official Packer plugin documentation.

**Update 2026-01-05:** Added `VM.GuestAgent.Audit` permission requirement and documented SSH timeout fixes.

## Changes Made

### Environment Variables

**Old (Incorrect):**
```bash
export PROXMOX_TOKEN="PVEAPIToken=terraform@pve!terraform-token=secret"
```

**New (Correct per Packer docs):**
```bash
export PROXMOX_USERNAME="terraform@pve!terraform-token"  # Token ID format
export PROXMOX_TOKEN="secret-value-only"                  # Just the secret
export PROXMOX_API_TOKEN="PVEAPIToken=terraform@pve!terraform-token=secret"  # For Terraform
```

### SOPS Secrets File Format

**File:** `secrets/proxmox-creds.enc.yaml`

```yaml
proxmox_url: "https://pve.home-infra.net:8006/api2/json"
proxmox_user: "terraform@pve"           # User@realm (NOT @pam)
proxmox_token_id: "terraform-token"      # Just token ID (NOT full format)
proxmox_token_secret: "your-secret-here" # Just the secret value
proxmox_node: "pve"
proxmox_storage_pool: "tank"
```

### Packer Variables

**All `packer/*/variables.pkr.hcl` files:**

```hcl
variable "proxmox_username" {
  type        = string
  description = "Proxmox token ID (format: user@realm!tokenid)"
  default     = env("PROXMOX_USERNAME")  # terraform@pve!terraform-token
  sensitive   = true
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret"
  default     = env("PROXMOX_TOKEN")  # Just the secret value
  sensitive   = true
}
```

### Packer Templates

**All `packer/*/*.pkr.hcl` files:**

```hcl
source "proxmox-clone" "debian" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username  # terraform@pve!terraform-token
  token                    = var.proxmox_token     # Just the secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify
  ...
}
```

## Files Updated

### Core Configuration (20 files)
- [x] `.envrc` - Auto-loads credentials from SOPS
- [x] `secrets/TEMPLATE-proxmox-creds.yaml` - Template updated
- [x] All 6 Packer `variables.pkr.hcl` files
- [x] All 6 Packer template `.pkr.hcl` files
- [x] All 7 Packer `.auto.pkrvars.hcl.example` files

### Documentation (13 files)
- [x] `secrets/README.md`
- [x] `terraform/README.md`
- [x] `packer/talos/README.md`
- [x] `docs/guides/deployment/TALOS-DEPLOYMENT-GUIDE.md`
- [x] `docs/guides/deployment/DEBIAN-DEPLOYMENT-GUIDE.md`
- [x] `docs/guides/deployment/ARCH-DEPLOYMENT-GUIDE.md`
- [x] `docs/guides/deployment/NIXOS-DEPLOYMENT-GUIDE.md`
- [x] `docs/guides/deployment/WINDOWS-DEPLOYMENT-GUIDE.md`
- [x] `PROXMOX-SETUP.md` (already correct)
- [x] `terraform/variables.tf` (pve.home-infra.net is correct)

## Reference

- **Official Packer Proxmox Plugin Docs:** https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/clone
- **Authentication Format:** When using API tokens, `username` must be `user@realm!tokenid`

## Verification

```bash
# Verify environment variables are set correctly
echo "PROXMOX_USERNAME: $PROXMOX_USERNAME"  # Should show: terraform@pve!terraform-token
echo "PROXMOX_TOKEN: $PROXMOX_TOKEN"        # Should show: secret value only

# Test Packer
cd packer/debian
packer validate .
packer build .
```

## Proxmox API Token Permissions

### Required Permissions for Packer/Terraform

The API token must have the following permissions for successful Packer builds:

```bash
# On Proxmox host, create or modify role
pveum role modify TerraformProv -privs 'Datastore.AllocateSpace,Datastore.Audit,Pool.Allocate,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,Sys.PowerMgmt,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt,VM.GuestAgent.Audit'
```

**Critical Permission:**
- `VM.GuestAgent.Audit` - Required for Packer to query QEMU guest agent for VM IP addresses
- Without this, Packer will fail with `403 Permission check failed`

### Verify Permissions

```bash
# Check current permissions
pveum user permissions terraform@pve | grep -i guest

# Should show: VM.GuestAgent.Audit (*)
```

## Known Issues & Fixes

### Issue: SSH Timeout - Permission Denied (2026-01-05)

**Error:** `403 Permission check failed (/vms/XXXX, VM.GuestAgent.Audit|VM.GuestAgent.Unrestricted)`

**Root Cause:** Packer uses QEMU guest agent to detect VM IP addresses. Without `VM.GuestAgent.Audit` permission, Packer cannot query the guest agent and times out waiting for SSH.

**Fix:** Add `VM.GuestAgent.Audit` permission to the Proxmox API token role (see above).

### Issue: VM Clone Boot Failure

**Error:** "PARTUUID does not exist. Dropping to a shell!"

**Fix:** Added to all Packer templates:
```hcl
full_clone = true  # Use full clone instead of linked clone
```

This ensures disk is properly cloned and bootable.

### Issue: Cloud-init Exit Code 2

**Error:** `Script exited with non-zero exit status: 2`

**Root Cause:** Proxmox cloud-init generates deprecation warnings about using `user` instead of `users`, causing "degraded done" status (exit code 2).

**Fix:** Accept exit code 2 as valid in Packer provisioners:
```hcl
provisioner "shell" {
  inline = ["cloud-init status --wait"]
  valid_exit_codes = [0, 2]  # Accept degraded/done
}
```
