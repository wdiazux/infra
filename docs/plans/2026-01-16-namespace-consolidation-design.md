# Namespace Consolidation Design

**Date:** 2026-01-16
**Status:** Approved

## Overview

Consolidate application namespaces for organizational simplicity. Currently each app has its own namespace; this creates unnecessary sprawl for a homelab setup.

## Target Structure

| Namespace | Services | Purpose |
|-----------|----------|---------|
| `tools` | speedtest, it-tools | Developer/network utilities |
| `misc` | twitch-miner | Personal automation |

## File Changes

```
kubernetes/apps/base/
├── tools/                    # NEW - shared namespace
│   └── namespace.yaml
├── misc/                     # NEW - shared namespace
│   └── namespace.yaml
├── speedtest/
│   ├── namespace.yaml        # DELETE
│   └── *.yaml               # Update namespace references
├── it-tools/
│   ├── namespace.yaml        # DELETE
│   └── *.yaml               # Update namespace references
└── twitch-miner/
    ├── namespace.yaml        # DELETE
    └── *.yaml               # Update namespace references
```

## Implementation Steps

1. **Create new namespace folders and files**
   - `kubernetes/apps/base/tools/namespace.yaml`
   - `kubernetes/apps/base/misc/namespace.yaml`

2. **Update each app's kustomization.yaml**
   - Remove `namespace.yaml` from resources
   - Add reference to shared namespace folder
   - Update any namespace references

3. **Update deployments, services, PVCs**
   - Change `namespace:` field from app-specific to `tools` or `misc`

4. **Update parent kustomization**
   - Add `tools/` and `misc/` to resources
   - Ensure correct ordering (namespaces before apps)

5. **Delete old namespace files**
   - Remove `speedtest/namespace.yaml`
   - Remove `it-tools/namespace.yaml`
   - Remove `twitch-miner/namespace.yaml`

6. **Apply changes**
   - FluxCD will reconcile automatically
   - Old namespaces need manual deletion after apps migrate

## Manifest Contents

### tools/namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tools
  labels:
    app.kubernetes.io/name: tools
    purpose: utilities
```

### misc/namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: misc
  labels:
    app.kubernetes.io/name: misc
    purpose: personal
```

## Cleanup

After FluxCD reconciles and apps are running in new namespaces:

```bash
kubectl delete namespace speedtest
kubectl delete namespace it-tools
kubectl delete namespace twitch-miner
```

## Decisions

- **Fresh start for PVCs** - Data in existing PVCs is not critical; new PVCs will be created in the new namespaces
- **In-place update** - Simple approach, brief downtime acceptable for homelab
