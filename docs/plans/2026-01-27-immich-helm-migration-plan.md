# Immich Helm Chart Migration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Immich from raw Kubernetes manifests to the official Helm chart with CloudNative-PG for PostgreSQL.

**Architecture:** FluxCD HelmRelease for Immich (server + ML + Valkey) with a CNPG operator managing PostgreSQL using the VectorChord image. All services in `media` namespace, operator in `cnpg-system`.

**Tech Stack:** FluxCD HelmRelease v2, CloudNative-PG operator (v0.27.0), Immich Helm chart (v0.10.3, OCI), tensorchord/cloudnative-vectorchord:16.11 for PostgreSQL.

---

## Important Notes

- **Chart image tag:** The Immich chart defaults to `v2.0.0`. We must explicitly set the image tag to match the current deployed version. Since the user wants to follow chart releases, set it to the chart's intended version.
- **Library mount path:** Chart v0.10.0+ changed the default library mount from `/usr/src/app/upload` to `/data`. The NFS PVC (`immich-photos`) mounts at the chart's default path.
- **OIDC secrets:** The chart's `immich.configuration` supports inline YAML config. OIDC client-id and client-secret must be injected. Use `configurationKind: Secret` to allow secret references, or use environment variable overrides.
- **Service names:** The chart creates services named `<release-name>-server` and `<release-name>-machine-learning`. The HTTPRoute must reference `immich-server` (assuming release name `immich`).

---

### Task 1: Add Helm Repositories (CNPG + Immich)

**Files:**
- Modify: `kubernetes/infrastructure/controllers/helm-repositories.yaml` (append two new repos)

**Step 1: Add CNPG HelmRepository**

Append to `kubernetes/infrastructure/controllers/helm-repositories.yaml`:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: cnpg
  namespace: flux-system
spec:
  interval: 1h
  url: https://cloudnative-pg.github.io/charts
```

**Step 2: Add Immich OCI HelmRepository**

Append to the same file:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: immich
  namespace: flux-system
spec:
  type: oci
  interval: 1h
  url: oci://ghcr.io/immich-app/immich-charts
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/controllers/helm-repositories.yaml
git commit -m "feat(immich): add CNPG and Immich Helm repositories"
```

---

### Task 2: Deploy CloudNative-PG Operator

**Files:**
- Create: `kubernetes/infrastructure/controllers/cnpg-operator.yaml`
- Modify: `kubernetes/infrastructure/controllers/kustomization.yaml` (add reference)

**Step 1: Create CNPG operator HelmRelease**

Create `kubernetes/infrastructure/controllers/cnpg-operator.yaml`:

```yaml
# CloudNative-PG Operator
#
# Manages PostgreSQL clusters declaratively via Kubernetes CRDs.
# Used by Immich for database management with VectorChord extensions.
# https://cloudnative-pg.io/
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cnpg
  namespace: cnpg-system
spec:
  interval: 30m
  timeout: 10m
  chart:
    spec:
      chart: cloudnative-pg
      version: "0.27.0"
      sourceRef:
        kind: HelmRepository
        name: cnpg
        namespace: flux-system
      interval: 12h
  install:
    crds: CreateReplace
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    cleanupOnFail: true
    remediation:
      retries: 3
```

**Step 2: Add to infrastructure controllers kustomization**

Add `- cnpg-operator.yaml` to the resources list in `kubernetes/infrastructure/controllers/kustomization.yaml`, after the existing entries (before `../gateway`):

```yaml
  # PostgreSQL operator (CloudNative-PG)
  - cnpg-operator.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/controllers/cnpg-operator.yaml \
        kubernetes/infrastructure/controllers/kustomization.yaml
git commit -m "feat(infra): add CloudNative-PG operator HelmRelease"
```

---

### Task 3: Create CNPG Cluster for Immich

**Files:**
- Create: `kubernetes/apps/base/media/immich/cnpg-cluster.yaml`

**Step 1: Create the CNPG Cluster resource**

Create `kubernetes/apps/base/media/immich/cnpg-cluster.yaml`:

```yaml
# Immich PostgreSQL Cluster (CloudNative-PG)
#
# PostgreSQL 16 with VectorChord extension for vector search.
# Managed by the CloudNative-PG operator.
# https://cloudnative-pg.io/
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: immich-postgres
  namespace: media
spec:
  instances: 1
  imageName: ghcr.io/tensorchord/cloudnative-vectorchord:16.11
  postgresql:
    shared_preload_libraries:
      - "vchord.so"
    parameters:
      max_wal_size: "2GB"
      shared_buffers: "512MB"
      wal_compression: "on"
  bootstrap:
    initdb:
      database: immich
      owner: immich
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
        - CREATE EXTENSION IF NOT EXISTS vector;
  storage:
    size: 10Gi
    storageClass: longhorn
  resources:
    requests:
      memory: 512Mi
    limits:
      memory: 2Gi
```

**Step 2: Commit**

```bash
git add kubernetes/apps/base/media/immich/cnpg-cluster.yaml
git commit -m "feat(immich): add CNPG PostgreSQL cluster with VectorChord"
```

---

### Task 4: Create Immich HelmRelease

**Files:**
- Create: `kubernetes/apps/base/media/immich/helmrelease.yaml`

**Step 1: Create the HelmRelease**

Create `kubernetes/apps/base/media/immich/helmrelease.yaml`:

```yaml
# Immich HelmRelease
#
# Self-hosted photo and video backup solution.
# Uses the official immich Helm chart with CloudNative-PG for PostgreSQL.
# https://immich.app/
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: immich
  namespace: media
spec:
  interval: 30m
  timeout: 15m
  chart:
    spec:
      chart: immich
      version: "0.10.3"
      sourceRef:
        kind: HelmRepository
        name: immich
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
    # Shared controller settings (applied to all components)
    controllers:
      main:
        containers:
          main:
            env:
              TZ: "America/El_Salvador"
              # Database (CloudNative-PG)
              DB_HOSTNAME: immich-postgres-rw
              DB_PORT: "5432"
              DB_USERNAME: immich
              DB_DATABASE_NAME: immich
              DB_PASSWORD:
                valueFrom:
                  secretKeyRef:
                    name: immich-secrets
                    key: DB_PASSWORD
              # Disable service links to prevent IMMICH_PORT conflict
              # (handled by chart's enableServiceLinks if supported)

    # Immich configuration
    immich:
      persistence:
        library:
          existingClaim: immich-photos
      configuration:
        oauth:
          enabled: true
          issuerUrl: "https://auth.home-infra.net"
          clientId: "${OAUTH_CLIENT_ID}"
          clientSecret: "${OAUTH_CLIENT_SECRET}"
          scope: "openid email profile"
          autoRegister: true
          autoLaunch: false
          buttonText: "Login with Zitadel"
          signingAlgorithm: "RS256"
          profileSigningAlgorithm: "none"
          storageLabelClaim: "email"
          tokenEndpointAuthMethod: "client_secret_post"

    # Valkey (Redis replacement, chart-managed)
    valkey:
      enabled: true
      persistence:
        data:
          enabled: true
          type: persistentVolumeClaim
          size: 1Gi
          storageClass: longhorn
          accessMode: ReadWriteOnce

    # Server component
    server:
      enabled: true
      controllers:
        main:
          containers:
            main:
              env:
                IMMICH_CONFIG_FILE: ""
              envFrom:
                - secretRef:
                    name: immich-oidc-secrets
              resources:
                requests:
                  memory: 512Mi
                limits:
                  memory: 4Gi

    # Machine Learning component (NVIDIA GPU)
    machine-learning:
      enabled: true
      controllers:
        main:
          pod:
            runtimeClassName: nvidia
            enableServiceLinks: false
          containers:
            main:
              env:
                MACHINE_LEARNING_WORKERS: "1"
                NVIDIA_VISIBLE_DEVICES: "all"
              resources:
                requests:
                  memory: 100Mi
                  nvidia.com/gpu: "1"
                limits:
                  memory: 8Gi
                  nvidia.com/gpu: "1"
      persistence:
        cache:
          enabled: true
          type: persistentVolumeClaim
          existingClaim: immich-ml-cache
          accessMode: ReadWriteOnce
```

> **NOTE on OIDC:** The chart's `immich.configuration` creates a ConfigMap/Secret with the config. The `${OAUTH_CLIENT_ID}` and `${OAUTH_CLIENT_SECRET}` placeholders won't be expanded automatically. Two options:
>
> 1. Use `configurationKind: Secret` and inject via FluxCD `postBuild.substituteFrom`
> 2. Pass OIDC settings as env vars on the server container, referencing the existing `immich-oidc-secrets` Secret
>
> The HelmRelease above uses option 2: the server container gets `envFrom` referencing `immich-oidc-secrets`, and Immich reads OIDC config from environment variables. If Immich v2.x requires a config file for OIDC, we'll need to adjust to use an init container or `configurationKind: Secret` with FluxCD substitution.

**Step 2: Commit**

```bash
git add kubernetes/apps/base/media/immich/helmrelease.yaml
git commit -m "feat(immich): add Immich HelmRelease with GPU and OIDC support"
```

---

### Task 5: Update HTTPRoute Service Reference

**Files:**
- Modify: `kubernetes/apps/base/media/immich/httproute.yaml`

**Step 1: Update the backend service name**

The Helm chart creates a service named `immich-server` (release name + component). Update the HTTPRoute backend reference:

Change in `kubernetes/apps/base/media/immich/httproute.yaml`:

```yaml
# Old:
      backendRefs:
        - name: immich
          port: 80

# New:
      backendRefs:
        - name: immich-server
          port: 80
```

> **Verify:** After deployment, confirm the actual service name created by the chart with `kubectl get svc -n media`. The bjw-s common library names services as `<release>-<component>`. If the chart creates just `immich` as the service name, revert this change.

**Step 2: Commit**

```bash
git add kubernetes/apps/base/media/immich/httproute.yaml
git commit -m "fix(immich): update HTTPRoute to reference Helm chart service name"
```

---

### Task 6: Update Immich Kustomization (remove old, add new)

**Files:**
- Modify: `kubernetes/apps/base/media/immich/kustomization.yaml`

**Step 1: Rewrite the kustomization**

Replace the contents of `kubernetes/apps/base/media/immich/kustomization.yaml`:

```yaml
# Immich Kustomization
#
# Self-hosted photo and video backup solution.
# Deployed via official Helm chart with CloudNative-PG for PostgreSQL.
# https://immich.app/
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - secret.enc.yaml
  - cnpg-cluster.yaml
  - helmrelease.yaml
  - pvc.yaml
  - httproute.yaml
```

**Step 2: Commit**

```bash
git add kubernetes/apps/base/media/immich/kustomization.yaml
git commit -m "refactor(immich): update kustomization for Helm chart migration"
```

---

### Task 7: Remove Old Manifest Files

**Files:**
- Delete: `kubernetes/apps/base/media/immich/postgres-statefulset.yaml`
- Delete: `kubernetes/apps/base/media/immich/redis-deployment.yaml`
- Delete: `kubernetes/apps/base/media/immich/server-deployment.yaml`
- Delete: `kubernetes/apps/base/media/immich/ml-deployment.yaml`
- Delete: `kubernetes/apps/base/media/immich/services.yaml`

**Step 1: Remove the old files**

```bash
git rm kubernetes/apps/base/media/immich/postgres-statefulset.yaml \
       kubernetes/apps/base/media/immich/redis-deployment.yaml \
       kubernetes/apps/base/media/immich/server-deployment.yaml \
       kubernetes/apps/base/media/immich/ml-deployment.yaml \
       kubernetes/apps/base/media/immich/services.yaml
```

**Step 2: Commit**

```bash
git commit -m "refactor(immich): remove raw manifests replaced by Helm chart"
```

---

### Task 8: Remove Immich Image Automation Policies

**Files:**
- Modify: `kubernetes/infrastructure/image-automation/policies/media.yaml`

**Step 1: Remove the immich-server and immich-machine-learning entries**

Remove these four resources from `kubernetes/infrastructure/image-automation/policies/media.yaml`:
- `ImageRepository` named `immich-server`
- `ImagePolicy` named `immich-server`
- `ImageRepository` named `immich-machine-learning`
- `ImagePolicy` named `immich-machine-learning`

Keep the `emby` and `navidrome` entries intact.

The file should contain only:

```yaml
# Media Namespace Image Policies
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: emby
  namespace: flux-system
spec:
  image: lscr.io/linuxserver/emby
  interval: 12h
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: emby
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: emby
  filterTags:
    # Match stable 4.x versions only (exclude beta 7.x/8.x)
    pattern: '^4\.([0-9]+)\.([0-9]+)$'
    extract: '4.$1.$2'
  policy:
    semver:
      range: ">=4.9.0 <5.0.0"
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: navidrome
  namespace: flux-system
spec:
  image: docker.io/deluan/navidrome
  interval: 12h
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: navidrome
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: navidrome
  filterTags:
    pattern: '^[0-9]+\.[0-9]+\.[0-9]+$'
  policy:
    semver:
      range: ">=0.50.0 <2.0.0"
```

**Step 2: Commit**

```bash
git add kubernetes/infrastructure/image-automation/policies/media.yaml
git commit -m "refactor(immich): remove image automation policies (now using Helm chart)"
```

---

### Task 9: Update SOPS Secret for CNPG Compatibility

**Files:**
- Modify: `kubernetes/apps/base/media/immich/secret.enc.yaml`

**Step 1: Verify secret keys**

The CNPG Cluster `bootstrap.initdb.secret` expects a Secret with specific keys. CNPG uses `username` and `password` keys by default. The existing `immich-secrets` has `DB_PASSWORD` and `POSTGRES_PASSWORD`.

We need to ensure the secret works with both the CNPG Cluster and the Immich HelmRelease. Options:
- CNPG can use `superuserSecret` with `username`/`password` keys
- Or CNPG generates its own credentials and we read them

**Recommended approach:** Let CNPG generate its own credentials. It auto-creates a Secret named `immich-postgres-app` with `username`, `password`, `dbname`, `host`, `port`, `uri` keys. Update the HelmRelease to reference this auto-generated secret instead of the manual `immich-secrets`.

Update the HelmRelease `DB_PASSWORD` env var to:

```yaml
DB_PASSWORD:
  valueFrom:
    secretKeyRef:
      name: immich-postgres-app
      key: password
```

And update `DB_USERNAME`:

```yaml
DB_USERNAME:
  valueFrom:
    secretKeyRef:
      name: immich-postgres-app
      key: username
```

This means the existing `DB_PASSWORD` and `POSTGRES_PASSWORD` keys in `immich-secrets` are no longer needed for the database. The `immich-oidc-secrets` Secret (for OIDC) is still used.

> **Note:** No changes to `secret.enc.yaml` are needed if we use CNPG-generated credentials. The old DB password keys become unused but harmless. They can be cleaned up later.

**Step 2: Update HelmRelease with CNPG-generated secret references**

This is handled in Task 4's HelmRelease. Update the DB env vars to use `immich-postgres-app`:

```yaml
DB_HOSTNAME: immich-postgres-rw
DB_PORT: "5432"
DB_USERNAME:
  valueFrom:
    secretKeyRef:
      name: immich-postgres-app
      key: username
DB_DATABASE_NAME: immich
DB_PASSWORD:
  valueFrom:
    secretKeyRef:
      name: immich-postgres-app
      key: password
```

**Step 3: Commit** (if changes made)

```bash
git add kubernetes/apps/base/media/immich/helmrelease.yaml
git commit -m "fix(immich): use CNPG-generated database credentials"
```

---

### Task 10: Verify Deployment

**Step 1: Check CNPG operator is running**

```bash
export KUBECONFIG=terraform/talos/kubeconfig
kubectl get pods -n cnpg-system
```

Expected: `cnpg-cloudnative-pg-*` pod in Running state.

**Step 2: Check CNPG cluster is ready**

```bash
kubectl get cluster -n media
kubectl get pods -n media -l cnpg.io/cluster=immich-postgres
```

Expected: `immich-postgres-1` pod in Running state, Cluster status `Cluster in healthy state`.

**Step 3: Check Immich HelmRelease is reconciled**

```bash
flux get helmrelease -n media immich
kubectl get pods -n media
```

Expected: `immich-server-*`, `immich-machine-learning-*`, `immich-valkey-*` pods running.

**Step 4: Check services**

```bash
kubectl get svc -n media | grep immich
```

Expected: Services for server, ML, valkey, and CNPG postgres (rw/r/ro).

**Step 5: Verify GPU access on ML pod**

```bash
kubectl exec -n media deploy/immich-machine-learning -- nvidia-smi
```

Expected: NVIDIA GPU listed.

**Step 6: Test web access**

Open `https://photos.reynoza.org` and verify:
- Page loads
- Zitadel SSO login works
- Photo library is accessible

**Step 7: Check for OIDC issues**

If OIDC doesn't work via `immich.configuration`, fall back to the init container approach by adding an init container override in the HelmRelease server values.

---

## Rollback Plan

If the migration fails:

1. Revert the git commits (old manifests are in git history)
2. FluxCD will reconcile back to the raw manifests
3. The old PostgreSQL StatefulSet will recreate with its Longhorn PVC (data preserved)

```bash
git revert HEAD~8..HEAD  # Revert all migration commits
git push
flux reconcile kustomization apps --with-source
```
