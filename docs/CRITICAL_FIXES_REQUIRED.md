# CRITICAL FIXES REQUIRED - Version-Specific Issues

**Date:** 2025-11-22
**Priority:** HIGH

This document summarizes CRITICAL issues found during version-specific verification that require immediate attention.

---

## ❌ BREAKING ISSUE: Cilium `enableBBR` Field

### Problem

**File:** `/home/user/infra/kubernetes/cilium/cilium-values.yaml`
**Line:** 291

**Current (INVALID) Configuration:**
```yaml
# Enable BBR congestion control (better performance)
enableBBR: false
```

**Issue:**
- The `enableBBR` field does NOT exist at the root level in Cilium v1.18.0
- This will be ignored or cause errors during Helm installation

### Solution

**Replace with:**
```yaml
# Enable bandwidth manager with BBR congestion control
bandwidthManager:
  enabled: true
  bbr: true  # Enable BBR TCP congestion control for Pods
```

**Verification:**
- Field confirmed in [Cilium v1.18.0 values.yaml](https://raw.githubusercontent.com/cilium/cilium/v1.18.0/install/kubernetes/cilium/values.yaml)
- Line 287-291 should be completely replaced

---

## ⚠️ RECOMMENDED: Cilium Routing Mode Optimization

### Problem

**File:** `/home/user/infra/kubernetes/cilium/cilium-values.yaml`
**Lines:** 93-97

**Current Configuration:**
```yaml
# Tunnel mode for pod-to-pod communication
# Options: vxlan (default), geneve, disabled (native routing)
tunnelProtocol: vxlan

# Enable native routing if your network supports it (better performance)
# autoDirectNodeRoutes: true
# tunnelProtocol: disabled
```

**Issue:**
- Setting `tunnelProtocol: disabled` has known issues in Cilium v1.18.0
- Reference: [GitHub Issue #39756](https://github.com/cilium/cilium/issues/39756)
- The `routingMode` field is the correct way to configure routing

### Solution

**For Native Routing (Recommended for Proxmox same-L2 network):**
```yaml
# Native routing mode (better performance, no encapsulation overhead)
routingMode: native
autoDirectNodeRoutes: true
```

**OR for Tunnel Mode (Current setup, more compatible):**
```yaml
# Tunnel mode for pod-to-pod communication
routingMode: tunnel
tunnelProtocol: vxlan
```

**Verification:**
- Confirmed in [Cilium v1.18.0 documentation](https://docs.cilium.io/en/stable/helm-reference/)
- Native routing requires nodes to share the same L2 network segment

---

## ⚠️ RECOMMENDED: Longhorn Performance Tuning

### Problem

**File:** `/home/user/infra/kubernetes/longhorn/longhorn-values.yaml`
**Lines:** Missing (should add after line 42)

**Current Configuration:**
- No concurrent operation limits set
- Default values allow unlimited concurrent operations

**Issue:**
- On single-node setup, unlimited concurrent rebuilds can saturate I/O
- Can cause performance degradation during volume operations

### Solution

**Add to `defaultSettings` section:**
```yaml
defaultSettings:
  # ... existing settings ...

  # Concurrent operation limits (prevent I/O saturation on single node)
  concurrentReplicaRebuildPerNodeLimit: 2
  concurrentVolumeBackupRestorePerNodeLimit: 2

  # Replica replenishment wait time (5 minutes)
  replicaReplenishmentWaitInterval: 300

  # Backup settings (if using NFS backup target)
  backupConcurrentLimit: 2
  restoreConcurrentLimit: 2
```

**Verification:**
- All fields confirmed in [Longhorn v1.7.2 Settings Reference](https://longhorn.io/docs/1.7.2/references/settings/)
- Recommended for single-node setups in [Longhorn Best Practices](https://longhorn.io/docs/1.7.1/best-practices/)

---

## Summary of Actions

### Priority 1: MUST FIX (Breaking)

1. ❌ **Cilium `enableBBR`** - Replace with `bandwidthManager.bbr`
   - **File:** `/home/user/infra/kubernetes/cilium/cilium-values.yaml`
   - **Lines:** 287-291
   - **Impact:** Field does not exist, will be ignored

### Priority 2: SHOULD FIX (Performance)

1. ⚠️ **Cilium routing mode** - Use `routingMode` field instead of `tunnelProtocol: disabled`
   - **File:** `/home/user/infra/kubernetes/cilium/cilium-values.yaml`
   - **Lines:** 93-97
   - **Impact:** Better performance with native routing

2. ⚠️ **Longhorn concurrency limits** - Add performance tuning settings
   - **File:** `/home/user/infra/kubernetes/longhorn/longhorn-values.yaml`
   - **Lines:** Add after line 42
   - **Impact:** Prevents I/O saturation on single node

### Priority 3: VERIFIED (No Action)

1. ✅ All Longhorn `defaultSettings` fields are valid for v1.7.x
2. ✅ Talos machine configuration structure is correct for v1.11.4
3. ✅ Cilium security context is correct for Talos
4. ✅ Storage class parameters are compatible with Kubernetes v1.31.0

---

## Quick Fix Commands

### 1. Fix Cilium enableBBR field

Edit the file:
```bash
cd /home/user/infra/kubernetes/cilium
# Edit cilium-values.yaml, replace lines 287-291
```

### 2. (Optional) Switch to native routing

Edit the file:
```bash
cd /home/user/infra/kubernetes/cilium
# Edit cilium-values.yaml, replace lines 93-97
```

### 3. Add Longhorn performance tuning

Edit the file:
```bash
cd /home/user/infra/kubernetes/longhorn
# Edit longhorn-values.yaml, add settings after line 42
```

---

## Testing After Changes

### Test Cilium changes:
```bash
# Validate Helm chart
helm template cilium cilium/cilium --namespace kube-system --values cilium-values.yaml > /dev/null

# Dry-run upgrade
helm upgrade cilium cilium/cilium --namespace kube-system --values cilium-values.yaml --dry-run

# Check status after applying
cilium status
kubectl get pods -n kube-system -l k8s-app=cilium
```

### Test Longhorn changes:
```bash
# Validate Helm chart
helm template longhorn longhorn/longhorn --namespace longhorn-system --values longhorn-values.yaml > /dev/null

# Check settings in UI after applying
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080 and verify settings
```

---

## See Also

- [Full Version Verification Report](/home/user/infra/docs/VERSION_VERIFICATION_REPORT.md)
- [Cilium v1.18.0 Helm Reference](https://docs.cilium.io/en/stable/helm-reference/)
- [Longhorn v1.7.2 Settings Reference](https://longhorn.io/docs/1.7.2/references/settings/)
- [Talos v1.11 Configuration Reference](https://www.talos.dev/v1.11/reference/configuration/)
