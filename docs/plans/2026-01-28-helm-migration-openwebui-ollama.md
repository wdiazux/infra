# Helm Migration: Open WebUI & Ollama Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Open WebUI and Ollama from raw Kustomize manifests to official Helm charts for easier upgrades and access to new features (Redis, Pipelines, Tika).

**Architecture:** FluxCD HelmRelease resources replace raw Deployment/StatefulSet manifests. Helm charts manage their own Services and PVCs. HTTPRoute and SOPS secrets remain unchanged.

**Tech Stack:** FluxCD HelmRelease, open-webui/open-webui v10.2.1, otwld/ollama-helm v1.39.0, Kustomize

---

## Task 1: Add Helm Repositories

**Files:**
- Modify: `kubernetes/infrastructure/controllers/helm-repositories.yaml`

**Step 1: Add open-webui and ollama HelmRepository resources**

Append to `kubernetes/infrastructure/controllers/helm-repositories.yaml`:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: open-webui
  namespace: flux-system
spec:
  interval: 1h
  url: https://helm.openwebui.com/
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: ollama
  namespace: flux-system
spec:
  interval: 1h
  url: https://otwld.github.io/ollama-helm/
```

**Step 2: Commit**

```bash
git add kubernetes/infrastructure/controllers/helm-repositories.yaml
git commit -m "feat: add open-webui and ollama helm repositories"
```

**Step 3: Push and verify Flux reconciliation**

```bash
git push
flux reconcile source helm open-webui -n flux-system
flux reconcile source helm ollama -n flux-system
```

Expected: Both repositories show `Ready: True`

```bash
kubectl get helmrepository -n flux-system open-webui ollama
```

---

## Task 2: Create Ollama HelmRelease

**Files:**
- Create: `kubernetes/apps/base/ai/ollama/helmrelease.yaml`

**Step 1: Create the HelmRelease file**

Create `kubernetes/apps/base/ai/ollama/helmrelease.yaml`:

```yaml
# Ollama HelmRelease
#
# LLM inference backend with NVIDIA GPU support.
# Chart: https://github.com/otwld/ollama-helm
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ollama
  namespace: ai
spec:
  interval: 30m
  timeout: 15m
  chart:
    spec:
      chart: ollama
      version: "1.39.0"
      sourceRef:
        kind: HelmRepository
        name: ollama
        namespace: flux-system
      interval: 12h
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  values:
    image:
      tag: "0.15.2"

    ollama:
      gpu:
        enabled: true
        type: nvidia
        number: 1
      mountPath: /root/.ollama

    runtimeClassName: nvidia

    extraEnv:
      - name: TZ
        value: "America/El_Salvador"
      - name: OLLAMA_NUM_PARALLEL
        value: "2"
      - name: OLLAMA_MAX_LOADED_MODELS
        value: "1"
      - name: OLLAMA_KEEP_ALIVE
        value: "15m"
      - name: OLLAMA_FLASH_ATTENTION
        value: "1"

    persistentVolume:
      enabled: true
      existingClaim: nfs-ai-models
      subPath: ollama

    resources:
      requests:
        memory: 100Mi
      limits:
        memory: 32Gi

    service:
      type: ClusterIP
      port: 11434
```

**Step 2: Verify file created**

```bash
cat kubernetes/apps/base/ai/ollama/helmrelease.yaml | head -20
```

Expected: File content visible

---

## Task 3: Update Ollama Kustomization and Delete Old Manifests

**Files:**
- Modify: `kubernetes/apps/base/ai/ollama/kustomization.yaml`
- Delete: `kubernetes/apps/base/ai/ollama/statefulset.yaml`
- Delete: `kubernetes/apps/base/ai/ollama/service.yaml`

**Step 1: Update kustomization.yaml**

Replace contents of `kubernetes/apps/base/ai/ollama/kustomization.yaml`:

```yaml
# Ollama Kustomization
#
# Managed by Helm chart: otwld/ollama-helm
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - helmrelease.yaml
```

**Step 2: Delete old manifests**

```bash
rm kubernetes/apps/base/ai/ollama/statefulset.yaml
rm kubernetes/apps/base/ai/ollama/service.yaml
```

**Step 3: Commit Ollama migration**

```bash
git add kubernetes/apps/base/ai/ollama/
git commit -m "feat(ai): migrate ollama to helm chart

- Replace StatefulSet with HelmRelease (otwld/ollama-helm v1.39.0)
- Preserve GPU, NFS storage, and env var configuration
- Delete old statefulset.yaml and service.yaml"
```

**Step 4: Push and verify**

```bash
git push
```

Wait for Flux to reconcile (~1-2 min), then verify:

```bash
kubectl get helmrelease -n ai ollama
```

Expected: `Ready: True`, `Status: Release reconciliation succeeded`

```bash
kubectl get pods -n ai -l app.kubernetes.io/name=ollama
```

Expected: Ollama pod running with 1/1 Ready

---

## CHECKPOINT 1: Ollama Migration Complete

**Verification commands:**

```bash
# HelmRelease status
kubectl get helmrelease -n ai ollama -o wide

# Pod status
kubectl get pods -n ai -l app.kubernetes.io/name=ollama

# Service exists
kubectl get svc -n ai ollama

# GPU attached
kubectl describe pod -n ai -l app.kubernetes.io/name=ollama | grep -A5 "nvidia.com/gpu"

# Ollama responding
kubectl exec -n ai -it deploy/ollama -- ollama list
```

**If issues:** Check HelmRelease events: `kubectl describe helmrelease -n ai ollama`

**Rollback:** `git revert HEAD && git push`

---

## Task 4: Create Open WebUI HelmRelease

**Files:**
- Create: `kubernetes/apps/base/ai/open-webui/helmrelease.yaml`

**Step 1: Create the HelmRelease file**

Create `kubernetes/apps/base/ai/open-webui/helmrelease.yaml`:

```yaml
# Open WebUI HelmRelease
#
# Web interface for LLMs with Redis, Pipelines, and Tika support.
# Chart: https://github.com/open-webui/helm-charts
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: open-webui
  namespace: ai
spec:
  interval: 30m
  timeout: 10m
  chart:
    spec:
      chart: open-webui
      version: "10.2.1"
      sourceRef:
        kind: HelmRepository
        name: open-webui
        namespace: flux-system
      interval: 12h
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  values:
    # Disable bundled Ollama (we manage separately)
    ollama:
      enabled: false

    # Enable Pipelines for extensibility
    pipelines:
      enabled: true
      persistence:
        enabled: true
        size: 2Gi
        storageClass: longhorn
      resources:
        requests:
          memory: 128Mi
        limits:
          memory: 1Gi

    # Enable Tika for document processing
    tika:
      enabled: true

    # Enable Redis for websocket support
    websocket:
      enabled: true
      redis:
        enabled: true
        resources:
          requests:
            memory: 32Mi
          limits:
            memory: 128Mi

    # Ollama connection
    ollamaUrls:
      - http://ollama:11434

    # Image generation with ComfyUI
    extraEnvVars:
      - name: ENABLE_IMAGE_GENERATION
        value: "true"
      - name: COMFYUI_BASE_URL
        value: "http://comfyui:80/"
      - name: ENABLE_IMAGE_PROMPT_GENERATION
        value: "true"
      - name: WEBUI_SECRET_KEY
        valueFrom:
          secretKeyRef:
            name: open-webui-secrets
            key: WEBUI_SECRET_KEY

    # Zitadel OIDC
    sso:
      enabled: true
      oidc:
        enabled: true
        providerUrl: "https://auth.home-infra.net/.well-known/openid-configuration"
        scopes: "openid profile email"
        mergeAccountsByEmail: true
        existingSecret: open-webui-oidc-secrets
        secretKeys:
          clientId: client-id
          clientSecret: client-secret

    # Persistence
    persistence:
      enabled: true
      size: 10Gi
      storageClass: longhorn
      accessModes:
        - ReadWriteOnce

    # Service (ClusterIP, HTTPRoute handles ingress)
    service:
      type: ClusterIP
      port: 80
      containerPort: 8080

    # Ingress disabled (using Gateway API HTTPRoute)
    ingress:
      enabled: false

    # Resources
    resources:
      requests:
        memory: 256Mi
      limits:
        memory: 2Gi

    # Pod security
    podSecurityContext:
      fsGroup: 1000
      fsGroupChangePolicy: "OnRootMismatch"
```

**Step 2: Verify file created**

```bash
cat kubernetes/apps/base/ai/open-webui/helmrelease.yaml | head -20
```

Expected: File content visible

---

## Task 5: Update Open WebUI Kustomization and Delete Old Manifests

**Files:**
- Modify: `kubernetes/apps/base/ai/open-webui/kustomization.yaml`
- Delete: `kubernetes/apps/base/ai/open-webui/deployment.yaml`
- Delete: `kubernetes/apps/base/ai/open-webui/service.yaml`

**Step 1: Update kustomization.yaml**

Replace contents of `kubernetes/apps/base/ai/open-webui/kustomization.yaml`:

```yaml
# Open WebUI Kustomization
#
# Managed by Helm chart: open-webui/open-webui
# HTTPRoute and secrets remain as Kustomize resources
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - helmrelease.yaml
  - httproute.yaml
  - secret.enc.yaml
```

**Step 2: Delete old manifests**

```bash
rm kubernetes/apps/base/ai/open-webui/deployment.yaml
rm kubernetes/apps/base/ai/open-webui/service.yaml
```

**Step 3: Verify httproute.yaml and secret.enc.yaml still exist**

```bash
ls -la kubernetes/apps/base/ai/open-webui/
```

Expected: `helmrelease.yaml`, `httproute.yaml`, `kustomization.yaml`, `secret.enc.yaml`

---

## Task 6: Delete Shared Storage File and Commit Open WebUI Migration

**Files:**
- Delete: `kubernetes/apps/base/ai/storage.yaml`
- Modify: `kubernetes/apps/base/ai/kustomization.yaml`

**Step 1: Delete storage.yaml**

```bash
rm kubernetes/apps/base/ai/storage.yaml
```

**Step 2: Update parent kustomization to remove storage.yaml reference**

Modify `kubernetes/apps/base/ai/kustomization.yaml`:

```yaml
# AI Namespace Applications
#
# AI/ML services with GPU time-slicing support.
# Services: Ollama, Open WebUI, ComfyUI
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Services (storage managed by Helm charts)
  - ollama
  - open-webui
  - comfyui
```

**Step 3: Commit Open WebUI migration**

```bash
git add kubernetes/apps/base/ai/
git commit -m "feat(ai): migrate open-webui to helm chart

- Replace Deployment with HelmRelease (open-webui/open-webui v10.2.1)
- Enable Redis websocket, Pipelines, and Tika sub-charts
- Preserve OIDC, ComfyUI integration, and Gateway API HTTPRoute
- Delete old deployment.yaml, service.yaml, storage.yaml
- PVCs now managed by Helm charts"
```

**Step 4: Push and verify**

```bash
git push
```

Wait for Flux to reconcile (~2-3 min for all components), then verify:

```bash
kubectl get helmrelease -n ai
```

Expected: Both `ollama` and `open-webui` show `Ready: True`

---

## CHECKPOINT 2: Open WebUI Migration Complete

**Verification commands:**

```bash
# All HelmReleases ready
kubectl get helmrelease -n ai

# All pods running
kubectl get pods -n ai

# Expected pods: ollama, open-webui, open-webui-pipelines, open-webui-redis, open-webui-tika
```

**If HelmRelease shows errors:** `kubectl describe helmrelease -n ai open-webui`

**Rollback:** `git revert HEAD~2..HEAD && git push` (reverts both commits)

---

## Task 7: Verify All Integrations

**Step 1: Check pod status**

```bash
kubectl get pods -n ai -o wide
```

Expected: All pods Running with 1/1 Ready

**Step 2: Check services**

```bash
kubectl get svc -n ai
```

Expected: Services for `ollama`, `open-webui`, `open-webui-pipelines`, `open-webui-redis`, `open-webui-tika`

**Step 3: Test HTTPRoute connectivity**

```bash
curl -sI https://chat.home-infra.net | head -5
```

Expected: `HTTP/2 200` or `HTTP/2 302` (redirect to login)

**Step 4: Test Ollama connection from Open WebUI**

```bash
kubectl logs -n ai -l app.kubernetes.io/name=open-webui --tail=50 | grep -i ollama
```

Expected: No connection errors to Ollama

**Step 5: Verify OIDC configuration**

```bash
kubectl exec -n ai deploy/open-webui -- env | grep -E "OPENID|OAUTH"
```

Expected: OIDC environment variables set

**Step 6: Check Pipelines running**

```bash
kubectl logs -n ai -l app.kubernetes.io/name=open-webui-pipelines --tail=20
```

Expected: Pipelines service started successfully

**Step 7: Check Tika running**

```bash
kubectl logs -n ai -l app.kubernetes.io/name=open-webui-tika --tail=20
```

Expected: Tika service started

**Step 8: Check Redis running**

```bash
kubectl exec -n ai deploy/open-webui-redis -- redis-cli ping
```

Expected: `PONG`

---

## CHECKPOINT 3: Full Integration Verification

**Summary checklist:**

| Component | Verification | Expected |
|-----------|-------------|----------|
| Ollama HelmRelease | `kubectl get hr -n ai ollama` | Ready: True |
| Open WebUI HelmRelease | `kubectl get hr -n ai open-webui` | Ready: True |
| Ollama pod | `kubectl get pod -n ai -l app.kubernetes.io/name=ollama` | Running |
| Open WebUI pod | `kubectl get pod -n ai -l app.kubernetes.io/name=open-webui` | Running |
| Pipelines pod | `kubectl get pod -n ai -l app.kubernetes.io/name=open-webui-pipelines` | Running |
| Tika pod | `kubectl get pod -n ai -l app.kubernetes.io/name=open-webui-tika` | Running |
| Redis pod | `kubectl get pod -n ai -l app.kubernetes.io/name=open-webui-redis` | Running |
| HTTPRoute | `curl -sI https://chat.home-infra.net` | HTTP 200/302 |
| GPU attached | `kubectl describe pod -n ai -l app.kubernetes.io/name=ollama \| grep nvidia` | nvidia.com/gpu: 1 |

---

## Task 8: Manual UI Verification

**Step 1: Open browser and test login**

Navigate to: `https://chat.home-infra.net`

Expected: Zitadel OIDC login button visible

**Step 2: Login and test chat**

- Login with Zitadel credentials
- Start a new chat
- Send a test message

Expected: Response from Ollama model

**Step 3: Test image generation (if ComfyUI running)**

- In chat settings, enable image generation
- Request an image

Expected: Image generated via ComfyUI

---

## Task 9: Final Commit - Update Documentation

**Files:**
- Modify: `docs/plans/2026-01-28-helm-migration-openwebui-ollama.md`

**Step 1: Update plan status**

Change `**Status:** Approved` to `**Status:** Completed`

**Step 2: Commit**

```bash
git add docs/plans/2026-01-28-helm-migration-openwebui-ollama.md
git commit -m "docs: mark helm migration plan as completed"
git push
```

---

## Rollback Procedure

If critical issues occur at any point:

```bash
# Revert all migration commits
git log --oneline -5  # Find commits to revert
git revert <commit-hash>..HEAD
git push
```

Flux will automatically restore previous manifests.

For faster rollback, scale down HelmRelease-managed resources:

```bash
kubectl scale deployment -n ai open-webui --replicas=0
kubectl scale statefulset -n ai ollama --replicas=0
```

---

## Notes

- Old PVCs can be deleted if migration causes data issues (fresh start acceptable)
- HTTPRoute remains unchanged (Gateway API routing)
- SOPS-encrypted secrets remain unchanged and are referenced by HelmRelease
- ComfyUI integration preserved via `extraEnvVars`
- Flux ImagePolicy for auto-updates will need reconfiguration for HelmRelease (future task)
