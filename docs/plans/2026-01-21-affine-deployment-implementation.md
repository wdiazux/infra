# Affine Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy Affine knowledge base application to Kubernetes with PostgreSQL, Redis, NFS storage, FluxCD automation, and Homepage integration.

**Architecture:** Three-tier deployment (PostgreSQL StatefulSet + Redis Deployment + Affine Server Deployment) in `tools` namespace, with NFS for uploads and Longhorn for database storage. LoadBalancer on 10.10.2.33 with dual-domain DNS.

**Tech Stack:** Kubernetes, Kustomize, FluxCD, PostgreSQL (pgvector), Redis, NFS, SOPS

**Design Doc:** `docs/plans/2026-01-21-affine-deployment-design.md`

---

### Task 1: Add IP to Cluster Variables

**Files:**
- Modify: `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml:50-57`

**Step 1: Add IP_AFFINE variable**

Add after `IP_ITTOOLS` line:

```yaml
  IP_AFFINE: "10.10.2.33"
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('kubernetes/infrastructure/cluster-vars/cluster-vars.yaml'))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
git commit -m "feat(cluster-vars): add IP_AFFINE for Affine service"
```

---

### Task 2: Create NFS PersistentVolume

**Files:**
- Create: `kubernetes/infrastructure/storage/nfs-documents-affine-pv.yaml`

**Step 1: Create the PV manifest**

```yaml
# NFS PersistentVolume for Affine uploads
# Mount: /mnt/tank/documents/Affine from NAS (10.10.2.5)
#
# Used by: Affine (tools namespace)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-documents-affine
  labels:
    type: nfs
    purpose: documents
    namespace: tools
spec:
  capacity:
    storage: 250Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  nfs:
    server: "${NAS_IP}"
    path: /mnt/tank/documents/Affine
  mountOptions:
    - nfsvers=4.1
    - hard
    - noatime
    - rsize=1048576
    - wsize=1048576
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('kubernetes/infrastructure/storage/nfs-documents-affine-pv.yaml'))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/storage/nfs-documents-affine-pv.yaml
git commit -m "feat(storage): add NFS PV for Affine uploads"
```

---

### Task 3: Create NFS PersistentVolumeClaim

**Files:**
- Create: `kubernetes/infrastructure/storage/nfs-documents-affine-pvc.yaml`

**Step 1: Create the PVC manifest**

```yaml
# NFS PersistentVolumeClaim for Affine uploads
#
# Binds to nfs-documents-affine PV.
# Used by: Affine server (storage directory)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: affine-storage
  namespace: tools
  labels:
    type: nfs
    purpose: documents
    app.kubernetes.io/name: affine
    app.kubernetes.io/part-of: affine
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: nfs-documents-affine
  resources:
    requests:
      storage: 250Gi
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('kubernetes/infrastructure/storage/nfs-documents-affine-pvc.yaml'))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/storage/nfs-documents-affine-pvc.yaml
git commit -m "feat(storage): add NFS PVC for Affine uploads"
```

---

### Task 4: Add NFS Resources to Storage Kustomization

**Files:**
- Modify: `kubernetes/infrastructure/storage/kustomization.yaml`

**Step 1: Add Affine NFS resources**

Add at end of resources list:

```yaml
  - nfs-documents-affine-pv.yaml
  - nfs-documents-affine-pvc.yaml
```

**Step 2: Verify kustomization builds**

Run: `kubectl kustomize kubernetes/infrastructure/storage/ > /dev/null && echo "OK"`
Expected: `OK`

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/storage/kustomization.yaml
git commit -m "feat(storage): add Affine NFS to kustomization"
```

---

### Task 5: Create Affine Directory Structure

**Files:**
- Create: `kubernetes/apps/base/tools/affine/` directory

**Step 1: Create directory**

Run: `mkdir -p kubernetes/apps/base/tools/affine`

**Step 2: Verify**

Run: `ls -la kubernetes/apps/base/tools/affine/`
Expected: empty directory listing

---

### Task 6: Create Affine Secret

**Files:**
- Create: `kubernetes/apps/base/tools/affine/secret.enc.yaml`

**Step 1: Create unencrypted secret**

Create `kubernetes/apps/base/tools/affine/secret.yaml` (temporary):

```yaml
# Affine Secrets
apiVersion: v1
kind: Secret
metadata:
  name: affine-secrets
  namespace: tools
  labels:
    app.kubernetes.io/name: affine
    app.kubernetes.io/part-of: affine
type: Opaque
stringData:
  POSTGRES_PASSWORD: "<generate-random-32-char>"
```

**Step 2: Generate random password**

Run: `openssl rand -base64 24`
Replace `<generate-random-32-char>` with output.

**Step 3: Encrypt with SOPS**

Run: `sops -e kubernetes/apps/base/tools/affine/secret.yaml > kubernetes/apps/base/tools/affine/secret.enc.yaml`

**Step 4: Remove unencrypted file**

Run: `rm kubernetes/apps/base/tools/affine/secret.yaml`

**Step 5: Verify encrypted file**

Run: `sops -d kubernetes/apps/base/tools/affine/secret.enc.yaml | grep -q POSTGRES_PASSWORD && echo "OK"`
Expected: `OK`

**Step 6: Commit**

```bash
git add kubernetes/apps/base/tools/affine/secret.enc.yaml
git commit -m "feat(affine): add encrypted secrets"
```

---

### Task 7: Create PostgreSQL StatefulSet

**Files:**
- Create: `kubernetes/apps/base/tools/affine/postgres-statefulset.yaml`

**Step 1: Create the StatefulSet manifest**

```yaml
# Affine PostgreSQL StatefulSet
#
# PostgreSQL 17 with pgvector for Affine metadata and vector search.
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: affine-postgres
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: affine
spec:
  serviceName: affine-postgres
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: affine-postgres
  template:
    metadata:
      labels:
        app.kubernetes.io/name: affine-postgres
        app.kubernetes.io/component: database
        app.kubernetes.io/part-of: affine
    spec:
      securityContext:
        fsGroup: 999
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: postgres
          image: pgvector/pgvector:pg17
          ports:
            - name: postgres
              containerPort: 5432
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: POSTGRES_DB
              value: affine
            - name: POSTGRES_USER
              value: affine
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: affine-secrets
                  key: POSTGRES_PASSWORD
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - affine
                - -d
                - affine
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - affine
                - -d
                - affine
            initialDelaySeconds: 5
            periodSeconds: 10
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: longhorn
        resources:
          requests:
            storage: 5Gi
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; list(yaml.safe_load_all(open('kubernetes/apps/base/tools/affine/postgres-statefulset.yaml')))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/postgres-statefulset.yaml
git commit -m "feat(affine): add PostgreSQL StatefulSet with pgvector"
```

---

### Task 8: Create Redis Deployment

**Files:**
- Create: `kubernetes/apps/base/tools/affine/redis-deployment.yaml`

**Step 1: Create the Deployment manifest**

```yaml
# Affine Redis Deployment
#
# Redis 8 for caching and session management.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: affine-redis
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: affine
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: affine-redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: affine-redis
        app.kubernetes.io/component: cache
        app.kubernetes.io/part-of: affine
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: redis
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          image: docker.io/library/redis:8
          ports:
            - name: redis
              containerPort: 6379
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
          volumeMounts:
            - name: data
              mountPath: /data
          livenessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: affine-redis
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; list(yaml.safe_load_all(open('kubernetes/apps/base/tools/affine/redis-deployment.yaml')))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/redis-deployment.yaml
git commit -m "feat(affine): add Redis deployment"
```

---

### Task 9: Create Redis PVC

**Files:**
- Create: `kubernetes/apps/base/tools/affine/pvc.yaml`

**Step 1: Create the PVC manifest**

```yaml
# Affine Redis PVC
#
# Longhorn storage for Redis persistence.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: affine-redis
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: affine
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('kubernetes/apps/base/tools/affine/pvc.yaml'))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/pvc.yaml
git commit -m "feat(affine): add Redis PVC"
```

---

### Task 10: Create Affine Server Deployment

**Files:**
- Create: `kubernetes/apps/base/tools/affine/server-deployment.yaml`

**Step 1: Create the Deployment manifest**

```yaml
# Affine Server Deployment
#
# Main application server for Affine knowledge base.
# https://docs.affine.pro/
apiVersion: apps/v1
kind: Deployment
metadata:
  name: affine-server
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: affine
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: affine-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: affine-server
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: affine
    spec:
      enableServiceLinks: false
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      initContainers:
        # Wait for PostgreSQL to be ready
        - name: wait-for-db
          image: pgvector/pgvector:pg17
          command:
            - sh
            - -c
            - |
              until pg_isready -h affine-postgres -p 5432 -U affine; do
                echo "Waiting for PostgreSQL..."
                sleep 2
              done
              echo "PostgreSQL is ready"
        # Wait for Redis to be ready
        - name: wait-for-redis
          image: docker.io/library/redis:8
          command:
            - sh
            - -c
            - |
              until redis-cli -h affine-redis ping; do
                echo "Waiting for Redis..."
                sleep 2
              done
              echo "Redis is ready"
      containers:
        - name: affine
          image: ghcr.io/toeverything/affine-graphql:stable # {"$imagepolicy": "flux-system:affine"}
          ports:
            - name: http
              containerPort: 3010
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: NODE_ENV
              value: "production"
            - name: AFFINE_SERVER_EXTERNAL_URL
              value: "http://affine.${DOMAIN_PRIMARY}"
            - name: AFFINE_SERVER_HOST
              value: "0.0.0.0"
            - name: AFFINE_SERVER_PORT
              value: "3010"
            # Database
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: affine-secrets
                  key: POSTGRES_PASSWORD
            # Redis
            - name: REDIS_SERVER_HOST
              value: "affine-redis"
            - name: REDIS_SERVER_PORT
              value: "6379"
          volumeMounts:
            - name: storage
              mountPath: /root/.affine/storage
          startupProbe:
            httpGet:
              path: /
              port: http
            failureThreshold: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: affine-storage
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; list(yaml.safe_load_all(open('kubernetes/apps/base/tools/affine/server-deployment.yaml')))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/server-deployment.yaml
git commit -m "feat(affine): add server deployment with init containers"
```

---

### Task 11: Create Services

**Files:**
- Create: `kubernetes/apps/base/tools/affine/services.yaml`

**Step 1: Create the Services manifest**

```yaml
# Affine Services
---
# PostgreSQL Service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: affine-postgres
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: affine
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: affine-postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
      protocol: TCP
---
# Redis Service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: affine-redis
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: affine
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: affine-redis
  ports:
    - name: redis
      port: 6379
      targetPort: 6379
      protocol: TCP
---
# Affine Server Service (LoadBalancer)
apiVersion: v1
kind: Service
metadata:
  name: affine
  namespace: tools
  labels:
    app.kubernetes.io/name: affine-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: affine
  annotations:
    io.cilium/lb-ipam-ips: "${IP_AFFINE}"
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: affine-server
  ports:
    - name: http
      port: 80
      targetPort: 3010
      protocol: TCP
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; list(yaml.safe_load_all(open('kubernetes/apps/base/tools/affine/services.yaml')))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/services.yaml
git commit -m "feat(affine): add services (postgres, redis, loadbalancer)"
```

---

### Task 12: Create Kustomization

**Files:**
- Create: `kubernetes/apps/base/tools/affine/kustomization.yaml`

**Step 1: Create the Kustomization manifest**

```yaml
# Affine Kustomization
#
# Knowledge base and note-taking application.
# https://docs.affine.pro/
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - secret.enc.yaml
  - postgres-statefulset.yaml
  - redis-deployment.yaml
  - server-deployment.yaml
  - services.yaml
  - pvc.yaml
```

**Step 2: Verify kustomization builds**

Run: `kubectl kustomize kubernetes/apps/base/tools/affine/ > /dev/null && echo "OK"`
Expected: `OK`

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/kustomization.yaml
git commit -m "feat(affine): add kustomization"
```

---

### Task 13: Add Affine to Tools Kustomization

**Files:**
- Modify: `kubernetes/apps/base/tools/kustomization.yaml`

**Step 1: Read current file to find insertion point**

Run: `cat kubernetes/apps/base/tools/kustomization.yaml`

**Step 2: Add affine to resources list**

Add `- affine` to the resources list (alphabetically or at end).

**Step 3: Verify kustomization builds**

Run: `kubectl kustomize kubernetes/apps/base/tools/ > /dev/null && echo "OK"`
Expected: `OK`

**Step 4: Commit**

```bash
git add kubernetes/apps/base/tools/kustomization.yaml
git commit -m "feat(tools): add Affine to namespace kustomization"
```

---

### Task 14: Create FluxCD ImageRepository

**Files:**
- Create: `kubernetes/infrastructure/image-automation/affine-imagerepository.yaml`

**Step 1: Find image-automation directory**

Run: `find kubernetes -type d -name "image-automation" -o -name "image-policies" 2>/dev/null | head -5`

**Step 2: Create ImageRepository manifest**

Create in the appropriate directory (adjust path based on step 1):

```yaml
# Affine ImageRepository
#
# Tracks available tags for Affine container image.
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: affine
  namespace: flux-system
spec:
  image: ghcr.io/toeverything/affine-graphql
  interval: 1h
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/image-automation/affine-imagerepository.yaml
git commit -m "feat(flux): add Affine ImageRepository"
```

---

### Task 15: Create FluxCD ImagePolicy

**Files:**
- Create: `kubernetes/infrastructure/image-automation/affine-imagepolicy.yaml`

**Step 1: Create ImagePolicy manifest**

```yaml
# Affine ImagePolicy
#
# Selects the latest stable tag for Affine.
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: affine
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: affine
  filterTags:
    pattern: '^stable-(?P<ts>[0-9]+)$'
    extract: '$ts'
  policy:
    numerical:
      order: asc
```

**Step 2: Commit**

```bash
git add kubernetes/infrastructure/image-automation/affine-imagepolicy.yaml
git commit -m "feat(flux): add Affine ImagePolicy for auto-updates"
```

---

### Task 16: Add Image Automation to Kustomization

**Files:**
- Modify: `kubernetes/infrastructure/image-automation/kustomization.yaml` (or equivalent)

**Step 1: Add Affine resources to kustomization**

Add to resources list:
```yaml
  - affine-imagerepository.yaml
  - affine-imagepolicy.yaml
```

**Step 2: Verify kustomization builds**

Run: `kubectl kustomize kubernetes/infrastructure/image-automation/ > /dev/null && echo "OK"`
Expected: `OK`

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/image-automation/kustomization.yaml
git commit -m "feat(flux): add Affine to image automation kustomization"
```

---

### Task 17: Update DNS Script

**Files:**
- Modify: `scripts/generate-dns-config.py:46-58`

**Step 1: Add Affine to MULTI_SUFFIX_SERVICES**

Add to the `MULTI_SUFFIX_SERVICES` dictionary:

```python
    "affine": ["home.arpa", "home-infra.net"],
```

**Step 2: Verify script runs**

Run: `./scripts/generate-dns-config.py --dry-run | grep -A2 affine`
Expected: Shows affine entry with correct IP

**Step 3: Commit**

```bash
git add scripts/generate-dns-config.py
git commit -m "feat(dns): add Affine to multi-suffix services"
```

---

### Task 18: Update Homepage ConfigMap

**Files:**
- Modify: `kubernetes/apps/base/tools/homepage/configmap.yaml`

**Step 1: Add Affine to Tools section**

Find the `- Tools:` section and add Affine as the first entry:

```yaml
    - Tools:
        - Affine:
            icon: affine.png
            href: http://affine.${DOMAIN_INTERNAL}
            description: Knowledge Base & Notes
        - IT-Tools:
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('kubernetes/apps/base/tools/homepage/configmap.yaml'))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/homepage/configmap.yaml
git commit -m "feat(homepage): add Affine widget to Tools section"
```

---

### Task 19: Generate DNS Configurations

**Files:**
- Generate: `scripts/controld/domains.yaml`
- Generate: `scripts/pangolin/resources.yaml`

**Step 1: Run DNS generator**

Run: `./scripts/generate-dns-config.py`
Expected: Files generated successfully

**Step 2: Verify Affine appears in output**

Run: `grep -A2 "affine" scripts/controld/domains.yaml`
Expected: Shows affine with IP 10.10.2.33

**Step 3: Commit generated files**

```bash
git add scripts/controld/domains.yaml scripts/pangolin/resources.yaml
git commit -m "chore(dns): regenerate configs with Affine"
```

---

### Task 20: Fix Server Deployment DATABASE_URL

**Files:**
- Modify: `kubernetes/apps/base/tools/affine/server-deployment.yaml`

**Step 1: Fix DATABASE_URL environment variable**

The DATABASE_URL should be constructed properly, not just the password. Replace the DATABASE_URL env section:

```yaml
            # Database - construct URL with password from secret
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: affine-secrets
                  key: POSTGRES_PASSWORD
            - name: DATABASE_URL
              value: "postgresql://affine:$(POSTGRES_PASSWORD)@affine-postgres:5432/affine"
```

**Step 2: Verify YAML syntax**

Run: `python -c "import yaml; list(yaml.safe_load_all(open('kubernetes/apps/base/tools/affine/server-deployment.yaml')))"`
Expected: No output (success)

**Step 3: Commit**

```bash
git add kubernetes/apps/base/tools/affine/server-deployment.yaml
git commit -m "fix(affine): correct DATABASE_URL construction"
```

---

### Task 21: Deploy and Verify

**Step 1: Reconcile FluxCD**

Run: `flux reconcile kustomization flux-system --with-source`
Expected: Reconciliation successful

**Step 2: Watch pod creation**

Run: `kubectl get pods -n tools -l app.kubernetes.io/part-of=affine -w`
Expected: postgres, redis, and server pods start

**Step 3: Check all pods are running**

Run: `kubectl get pods -n tools -l app.kubernetes.io/part-of=affine`
Expected: All pods Running/Ready

**Step 4: Verify service has IP**

Run: `kubectl get svc -n tools affine`
Expected: EXTERNAL-IP shows 10.10.2.33

**Step 5: Test HTTP access**

Run: `curl -s -o /dev/null -w "%{http_code}" http://10.10.2.33/`
Expected: 200 (or 30x redirect)

---

### Task 22: Final Verification and Squash Commits (Optional)

**Step 1: Verify all components**

Run:
```bash
echo "=== Pods ===" && kubectl get pods -n tools -l app.kubernetes.io/part-of=affine
echo "=== Services ===" && kubectl get svc -n tools -l app.kubernetes.io/part-of=affine
echo "=== PVCs ===" && kubectl get pvc -n tools -l app.kubernetes.io/part-of=affine
echo "=== ImagePolicy ===" && flux get image policy affine
```

**Step 2: Access Affine UI**

Open browser: `http://affine.home-infra.net` or `http://affine.home.arpa`
Expected: Affine welcome/setup page

**Step 3: Squash commits (optional)**

If desired, squash all Affine commits into one:
```bash
git rebase -i HEAD~20  # Adjust number based on commit count
# Mark all but first as 'squash'
# Edit final commit message
```
