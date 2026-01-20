# Automated Image Updates

Flux Image Automation automatically detects new container versions and creates weekly update branches in Forgejo for review.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        Every 12 Hours                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ImageRepository scans registries for new tags               │
│                         ↓                                        │
│  2. ImagePolicy selects latest stable version                   │
│                         ↓                                        │
│  3. ImageUpdateAutomation detects changes                       │
│                         ↓                                        │
│  4. Creates/updates branch: image-updates/2026-wXX              │
│                         ↓                                        │
│  5. Pushes to Forgejo for review                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Reviewing and Merging Updates

### 1. Check for Update Branches

```bash
# List remote branches
git fetch forgejo
git branch -r | grep image-updates

# Or check Forgejo web UI:
# https://git.home-infra.net/wdiaz/infra/branches
```

### 2. Review Changes

```bash
# View what changed
git log forgejo/main..forgejo/image-updates/2026-w04 --oneline

# See detailed diff
git diff forgejo/main..forgejo/image-updates/2026-w04
```

Or in Forgejo: **Branches → image-updates/2026-wXX → Compare**

### 3. Merge Updates

**Option A: Via Forgejo (Recommended)**
1. Go to repository in Forgejo
2. Click **New Pull Request**
3. Set base: `main`, compare: `image-updates/2026-wXX`
4. Review changes, then **Merge**

**Option B: Via CLI**
```bash
git fetch forgejo
git checkout main
git merge forgejo/image-updates/2026-w04
git push forgejo main
```

### 4. Flux Deploys Automatically

After merge, FluxCD detects changes and deploys updated images to the cluster.

```bash
# Watch deployment
flux logs -f

# Check reconciliation
flux get kustomizations
```

## Adding a New Service to Automation

### Step 1: Identify Image Tag Pattern

Check the registry for how tags are formatted:

| Pattern | Example | Policy Type |
|---------|---------|-------------|
| Semver | `v1.2.3`, `1.2.3` | `semver` |
| Release prefix | `release-1.2.3` | `alphabetical` |
| Date-based | `RELEASE.2025-01-20T...` | `alphabetical` |

### Step 2: Create ImageRepository + ImagePolicy

Add to the appropriate file in `kubernetes/infrastructure/image-automation/policies/`:

**Semver example:**
```yaml
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  image: registry/my-app
  interval: 12h
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: my-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-app
  filterTags:
    pattern: '^v[0-9]+\.[0-9]+\.[0-9]+$'  # Matches v1.2.3
  policy:
    semver:
      range: ">=1.0.0"
```

**Release-prefix example (hotio images):**
```yaml
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  image: ghcr.io/hotio/my-app
  interval: 12h
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: my-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-app
  filterTags:
    pattern: '^release-[0-9]+\.[0-9]+\.[0-9]+$'
  policy:
    alphabetical:
      order: asc
```

**Date-based example (MinIO):**
```yaml
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: my-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-app
  filterTags:
    pattern: '^RELEASE\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z$'
  policy:
    alphabetical:
      order: asc
```

### Step 3: Add Policy Marker to Deployment

Update the deployment manifest with the policy marker:

```yaml
containers:
  - name: my-app
    image: registry/my-app:v1.2.3 # {"$imagepolicy": "flux-system:my-app"}
```

The marker format is: `# {"$imagepolicy": "flux-system:<policy-name>"}`

### Step 4: Commit and Apply

```bash
git add kubernetes/infrastructure/image-automation/policies/*.yaml
git add kubernetes/apps/base/<namespace>/<service>/deployment.yaml
git commit -m "feat(images): Add my-app to image automation"
git push
```

## Manually Triggering Updates

### Force Immediate Scan

```bash
# Trigger all image repositories to scan now
flux reconcile image repository --all

# Trigger specific image
flux reconcile image repository ollama
```

### Force Update Automation Run

```bash
flux reconcile image update image-updates
```

### Check Current Detected Versions

```bash
# List all image policies with current versions
flux get image policy -A

# Check specific policy
flux get image policy ollama
```

## Excluding Images from Automation

Some images should NOT be automated:

| Image | Reason |
|-------|--------|
| CUDA-specific tags | e.g., `cu128-slim` - tied to driver version |
| Custom images | Built locally, no registry tags |
| Extension-specific | e.g., `postgres:14-vectorchord0.4.3` |
| Pinned for stability | Breaking changes between versions |

**To exclude:** Simply don't create ImageRepository/ImagePolicy for the image. The deployment will keep using the manually specified tag.

## Troubleshooting

### Image Not Updating

**Check if ImageRepository is scanning:**
```bash
flux get image repository my-app

# Should show "Last scan result: X tags"
# If 0 tags, check the image path and registry access
```

**Check if ImagePolicy is selecting:**
```bash
flux get image policy my-app

# Should show "Latest image: registry/my-app:vX.X.X"
# If empty, check filterTags pattern
```

**Check if marker is correct:**
```bash
grep -r "imagepolicy.*my-app" kubernetes/apps/
# Should find: # {"$imagepolicy": "flux-system:my-app"}
```

### Wrong Version Selected

**Check filter pattern:**
```bash
kubectl get imagepolicy my-app -n flux-system -o yaml | grep -A5 filterTags
```

**Test pattern against tags:**
```bash
# List available tags
skopeo list-tags docker://registry/my-app | jq '.Tags[]' | head -20

# Test regex
echo "v1.2.3" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
```

### Branch Not Created

**Check ImageUpdateAutomation status:**
```bash
kubectl describe imageupdateautomation image-updates -n flux-system
```

**Check Flux logs:**
```bash
flux logs --kind=ImageUpdateAutomation
```

**Verify git credentials:**
```bash
kubectl get secret flux-system -n flux-system -o yaml
```

### Merge Conflicts

If the weekly branch has conflicts with main:

```bash
# Fetch latest
git fetch forgejo

# Create local branch from update branch
git checkout -b fix-image-updates forgejo/image-updates/2026-w04

# Rebase onto main
git rebase forgejo/main

# Resolve conflicts, then push
git push forgejo fix-image-updates:image-updates/2026-w04 --force
```

## Policy Files Reference

| File | Images |
|------|--------|
| `policies/ai.yaml` | ollama, open-webui |
| `policies/arr-stack.yaml` | radarr, sonarr, bazarr, prowlarr, qbittorrent, sabnzbd |
| `policies/automation.yaml` | n8n, home-assistant |
| `policies/backup.yaml` | minio, minio-mc |
| `policies/documents.yaml` | paperless, tika, gotenberg |
| `policies/media.yaml` | emby, navidrome, immich |
| `policies/misc.yaml` | wallos, twitch-miner, busybox |
| `policies/monitoring.yaml` | grafana, victoriametrics, vmagent, node-exporter, kube-state-metrics |
| `policies/tools.yaml` | homepage, ntfy, it-tools |

## Quick Reference

| Task | Command |
|------|---------|
| List update branches | `git branch -r \| grep image-updates` |
| Check policy status | `flux get image policy -A` |
| Force scan all | `flux reconcile image repository --all` |
| Force automation run | `flux reconcile image update image-updates` |
| View automation logs | `flux logs --kind=ImageUpdateAutomation` |
| Check specific image | `flux get image policy <name>` |

---

**Related Documentation:**
- [FluxCD Documentation](../services/fluxcd.md)
- [Container Deployment Patterns](../deployment/container-patterns.md)

---

**Last Updated:** 2026-01-20
