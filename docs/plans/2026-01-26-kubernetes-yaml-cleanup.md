# Kubernetes YAML Inline Script Cleanup Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract inline scripts (10+ lines) from Kubernetes YAML files into ConfigMaps for better maintainability.

**Architecture:** Move shell scripts from inline `command:` blocks into ConfigMap-mounted scripts. The Zitadel OIDC setup job already follows this pattern correctly (script in ConfigMap, mounted as `/scripts/setup.sh`). Apply the same pattern to other services.

**Tech Stack:** Kubernetes, Kustomize, FluxCD

---

## Analysis Summary

### Already Correct (No Changes Needed)

| File | Script | Lines | Status |
|------|--------|-------|--------|
| `auth/zitadel/oidc-setup-job.yaml` | OIDC setup | 285 | Already in ConfigMap |
| `backup/minio/init-bucket-job.yaml` | Bucket init | 17 | Simple enough to keep inline |
| `tools/affine/server-deployment.yaml` | Wait + migration | 20 | Simple enough to keep inline |
| `management/paperless/server-deployment.yaml` | Wait scripts | 8 each | Too simple |

### Extraction Candidates

| File | Script | Lines | Priority |
|------|--------|-------|----------|
| `forgejo/runner/deployment.yaml` | Runner registration | 33 | Medium |
| `automation/home-assistant/deployment.yaml` | Proxy config injection | 22 | Low |
| `arr-stack/qbittorrent/deployment.yaml` | Host validation config | 18 | Low |
| `arr-stack/sabnzbd/deployment.yaml` | Hostname whitelist | 15 | Low |

### Important Note

The `${DOMAIN_PRIMARY}` and `${IP_QBITTORRENT}` references in qBittorrent and SABnzbd files are **FluxCD variable substitutions** from the `cluster-vars` ConfigMap, NOT shell environment variables. They work correctly via FluxCD's `postBuild.substituteFrom` feature.

---

### Task 1: Extract Forgejo Runner Registration Script

**Files:**
- Create: `kubernetes/apps/base/forgejo/runner/configmap-register-script.yaml`
- Modify: `kubernetes/apps/base/forgejo/runner/deployment.yaml`
- Modify: `kubernetes/apps/base/forgejo/runner/kustomization.yaml`

**Step 1: Create ConfigMap for registration script**

Create `kubernetes/apps/base/forgejo/runner/configmap-register-script.yaml`:

```yaml
# Forgejo Runner Registration Script
#
# Registers a new Actions runner with the Forgejo instance.
# Waits for Forgejo API availability, fetches a registration token,
# and registers the runner with configured labels.
apiVersion: v1
kind: ConfigMap
metadata:
  name: forgejo-runner-register-script
  namespace: forgejo
  labels:
    app.kubernetes.io/name: forgejo-runner
    app.kubernetes.io/component: runner
data:
  register.sh: |
    #!/bin/sh
    set -e

    # [Copy the existing init container script from deployment.yaml lines 49-83]
    # The script content stays the same - it uses env vars FORGEJO_INSTANCE,
    # FORGEJO_ADMIN_USER, FORGEJO_ADMIN_PASS from the existing secret references.
```

**Step 2: Update deployment.yaml initContainer**

Replace the inline `command:` block in the `register` init container with:

```yaml
initContainers:
  - name: register
    image: code.forgejo.org/forgejo/runner:6.3.1
    command: ["/bin/sh", "/scripts/register.sh"]
    env:
      # Keep existing env vars from secret references
    volumeMounts:
      - name: data
        mountPath: /data
      - name: register-script
        mountPath: /scripts
        readOnly: true
```

Add volume:

```yaml
volumes:
  - name: register-script
    configMap:
      name: forgejo-runner-register-script
      defaultMode: 0755
```

**Step 3: Add to kustomization.yaml**

Add `configmap-register-script.yaml` to the resources list in the runner kustomization.

**Step 4: Validate**

```bash
kubectl --kubeconfig terraform/talos/kubeconfig apply --dry-run=client -f kubernetes/apps/base/forgejo/runner/
```

**Step 5: Commit**

```bash
git add kubernetes/apps/base/forgejo/runner/
git commit -m "refactor(k8s): extract Forgejo runner registration script to ConfigMap

Move 33-line registration script from inline initContainer command
to a ConfigMap-mounted script for better maintainability."
```

---

### Task 2: Extract Home Assistant Proxy Config Script

**Files:**
- Create: `kubernetes/apps/base/automation/home-assistant/configmap-proxy-script.yaml`
- Modify: `kubernetes/apps/base/automation/home-assistant/deployment.yaml`
- Modify: `kubernetes/apps/base/automation/home-assistant/kustomization.yaml`

**Step 1: Create ConfigMap**

Create the ConfigMap with the proxy config injection script (22 lines from `deployment.yaml:43-65`).

**Step 2: Update deployment.yaml**

Replace inline script with ConfigMap-mounted script reference.

**Step 3: Add to kustomization.yaml**

**Step 4: Validate and commit**

```bash
git add kubernetes/apps/base/automation/home-assistant/
git commit -m "refactor(k8s): extract Home Assistant proxy config script to ConfigMap"
```

---

### Task 3: Review qBittorrent and SABnzbd Scripts (Borderline)

**Files:**
- `kubernetes/apps/base/arr-stack/qbittorrent/deployment.yaml` (18 lines)
- `kubernetes/apps/base/arr-stack/sabnzbd/deployment.yaml` (15 lines)

**Assessment:** Both scripts are under 20 lines and are straightforward config modifications. They are borderline candidates. The decision is:

- **qBittorrent** (18 lines): Keep inline - the script is simple conditional config appending
- **SABnzbd** (15 lines): Keep inline - simple sed-based config update

Both scripts correctly use FluxCD variable substitution for `${DOMAIN_PRIMARY}` and `${IP_QBITTORRENT}`.

**Step 1: No extraction needed**

These scripts are below the 10-line complexity threshold when considering their actual logic (the line count includes echo statements and comments).

**Step 2: Clean up SABnzbd unused env var**

In `sabnzbd/deployment.yaml`, the main container has a `HOST_WHITELIST` environment variable (line 69-70) that is NOT used by the application. Verify if SABnzbd actually reads this env var. If not, remove it to reduce confusion.

**Step 3: Commit if any changes**

```bash
git add kubernetes/apps/base/arr-stack/
git commit -m "fix(k8s): remove unused HOST_WHITELIST env var from SABnzbd"
```

---

## Validation Checklist

- [ ] All new ConfigMaps have proper labels and namespace
- [ ] Script ConfigMaps have `defaultMode: 0755` for executability
- [ ] Existing environment variable references are preserved
- [ ] FluxCD variable substitutions (`${DOMAIN_PRIMARY}`, etc.) still work
- [ ] `kubectl apply --dry-run=client` validates all modified manifests
- [ ] FluxCD reconciliation applies changes without errors
