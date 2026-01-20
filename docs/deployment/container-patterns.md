# Container Deployment Patterns

Common patterns for deploying containers to the Kubernetes cluster. Use this guide to choose the right approach and get started quickly.

## Pattern Selection

```
                    ┌─────────────────────────┐
                    │  New Container to Deploy │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   Needs persistent      │
                    │       storage?          │
                    └───────────┬─────────────┘
                           No   │   Yes
                    ┌───────────┴───────────┐
                    ▼                       ▼
            ┌───────────────┐    ┌─────────────────────┐
            │ Pattern 1:    │    │   Needs database    │
            │ Simple        │    │   (Postgres/Redis)? │
            │ Stateless     │    └──────────┬──────────┘
            └───────────────┘          No   │   Yes
                                ┌───────────┴───────────┐
                                ▼                       ▼
                    ┌───────────────────┐    ┌───────────────────┐
                    │   Needs GPU?      │    │ Pattern 3:        │
                    └─────────┬─────────┘    │ App + Database    │
                         No   │   Yes        └───────────────────┘
                    ┌─────────┴─────────┐
                    ▼                   ▼
        ┌───────────────────┐  ┌───────────────────┐
        │  Shares files     │  │ Pattern 4:        │
        │  with other apps? │  │ GPU Workload      │
        └─────────┬─────────┘  └───────────────────┘
             No   │   Yes
        ┌─────────┴─────────┐
        ▼                   ▼
┌───────────────────┐  ┌───────────────────┐
│ Pattern 2:        │  │ Pattern 5:        │
│ Local Storage     │  │ NFS Shared        │
└───────────────────┘  └───────────────────┘
```

### Quick Reference

| Pattern | Use When | Examples |
|---------|----------|----------|
| 1. Simple Stateless | Web tools, static sites, APIs without persistence | it-tools, homepage |
| 2. Local Storage | App needs its own data, no sharing required | wallos, ntfy, grafana |
| 3. App + Database | Needs Postgres/Redis, complex multi-component | paperless, n8n, immich |
| 4. GPU Workload | ML inference, video transcoding | ollama, comfyui, emby |
| 5. NFS Shared | Media files, downloads shared across apps | arr-stack, navidrome |

---

## Pattern 1: Simple Stateless

**When to use:** Web tools, dashboards, APIs that don't store data locally.

**Directory structure:**
```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml
├── deployment.yaml
└── service.yaml
```

### kustomization.yaml

```yaml
# <Service Name>
#
# Brief description of the service.
# https://link-to-docs
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

### deployment.yaml

```yaml
# <Service Name> Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: <namespace>
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: <namespace>
    spec:
      containers:
        - name: <service-name>
          image: <registry>/<image>:<tag> # {"$imagepolicy": "flux-system:<service-name>"}
          ports:
            - name: http
              containerPort: <port>
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
          resources:
            requests:
              cpu: 10m
              memory: 64Mi
            limits:
              memory: 256Mi
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
```

### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
  namespace: <namespace>
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.<IP>"
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: <service-name>
  ports:
    - name: http
      port: 80
      targetPort: http
```

### Checklist

- [ ] Pick unused IP from 10.10.2.21-150 range (check `docs/reference/network.md`)
- [ ] Add Flux ImagePolicy if using automatic updates
- [ ] Register in parent namespace kustomization

---

## Pattern 2: Local Storage

**When to use:** Apps that need their own persistent data (databases, config, uploads) but don't share files with other apps.

**Directory structure:**
```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── pvc.yaml
```

**What's different from Pattern 1:**
- Add `pvc.yaml` for Longhorn storage
- Add `securityContext` with `fsGroup`
- Add `volumeMounts` and `volumes`
- Use `strategy: Recreate` (required for RWO volumes)

### kustomization.yaml

```yaml
# <Service Name>
#
# Brief description.
# https://link-to-docs
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - pvc.yaml
  - deployment.yaml
  - service.yaml
```

### pvc.yaml

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <service-name>-data
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: <namespace>
spec:
  replicas: 1
  strategy:
    type: Recreate  # Required for RWO volumes
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: <namespace>
    spec:
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: <service-name>
          image: <registry>/<image>:<tag>
          ports:
            - name: http
              containerPort: <port>
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              memory: 512Mi
          volumeMounts:
            - name: data
              mountPath: /data  # Check image docs for correct path
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
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: <service-name>-data
```

### Multiple PVCs Example

```yaml
# pvc.yaml - can contain multiple PVCs
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <service-name>-db
  namespace: <namespace>
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 256Mi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <service-name>-uploads
  namespace: <namespace>
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

### Checklist

- [ ] Check image docs for correct data path and UID/GID
- [ ] Set `fsGroup` to match container's expected GID
- [ ] Size PVC appropriately (can resize later with Longhorn)
- [ ] Use `Recreate` strategy to avoid multi-attach errors

---

## Pattern 3: App + Database

**When to use:** Apps requiring PostgreSQL, Redis, or other database backends. Multi-component services with dependencies.

**Directory structure:**
```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml
├── server-deployment.yaml      # Main application
├── postgres-statefulset.yaml   # Database (StatefulSet)
├── redis-deployment.yaml       # Cache (optional)
├── services.yaml               # All services in one file
├── pvc.yaml                    # App-specific storage
└── secret.enc.yaml             # SOPS encrypted credentials
```

### kustomization.yaml

```yaml
# <Service Name>
#
# Brief description.
# https://link-to-docs
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - pvc.yaml
  - secret.enc.yaml
  - postgres-statefulset.yaml
  - redis-deployment.yaml       # If needed
  - services.yaml
  - server-deployment.yaml      # Main app last (depends on others)
```

### secret.enc.yaml (before encryption)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <service-name>-secrets
  namespace: <namespace>
type: Opaque
stringData:
  POSTGRES_PASSWORD: "generate-secure-password"
  SECRET_KEY: "generate-random-key"
```

Encrypt before committing:
```bash
sops -e secret.yaml > secret.enc.yaml
rm secret.yaml  # Never commit unencrypted
```

### postgres-statefulset.yaml

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: <service-name>-postgres
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <service-name>-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: <service-name>
spec:
  serviceName: <service-name>-postgres
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>-postgres
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>-postgres
        app.kubernetes.io/component: database
        app.kubernetes.io/part-of: <service-name>
    spec:
      securityContext:
        fsGroup: 999  # postgres group
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: postgres
          image: postgres:17
          ports:
            - name: postgres
              containerPort: 5432
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: POSTGRES_DB
              value: "<service-name>"
            - name: POSTGRES_USER
              value: "<service-name>"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: <service-name>-secrets
                  key: POSTGRES_PASSWORD
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              memory: 512Mi
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          livenessProbe:
            exec:
              command: [pg_isready, -U, <service-name>]
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            exec:
              command: [pg_isready, -U, <service-name>]
            initialDelaySeconds: 5
            periodSeconds: 10
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        storageClassName: longhorn
        resources:
          requests:
            storage: 5Gi
```

### server-deployment.yaml (with init container)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>-server
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <service-name>-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: <service-name>
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>-server
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: <service-name>
    spec:
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      enableServiceLinks: false  # Prevents port conflicts

      initContainers:
        - name: wait-for-db
          image: postgres:17
          command:
            - /bin/sh
            - -c
            - |
              until pg_isready -h <service-name>-postgres -U <service-name>; do
                echo "Waiting for database..."
                sleep 2
              done
              echo "Database ready"

      containers:
        - name: server
          image: <registry>/<image>:<tag>
          ports:
            - name: http
              containerPort: 8000
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: DATABASE_URL
              value: "postgresql://<service-name>:$(POSTGRES_PASSWORD)@<service-name>-postgres:5432/<service-name>"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: <service-name>-secrets
                  key: POSTGRES_PASSWORD
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              memory: 1Gi
          volumeMounts:
            - name: data
              mountPath: /data
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: <service-name>-data
```

### services.yaml

```yaml
# Internal service for database (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: <service-name>-postgres
  namespace: <namespace>
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: <service-name>-postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: postgres
---
# External service for web UI (LoadBalancer)
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
  namespace: <namespace>
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.<IP>"
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: <service-name>-server
  ports:
    - name: http
      port: 80
      targetPort: http
```

### Checklist

- [ ] Generate secure passwords (`openssl rand -base64 32`)
- [ ] Encrypt secrets with SOPS before committing
- [ ] Use `enableServiceLinks: false` to prevent env var conflicts
- [ ] Add init container to wait for database readiness
- [ ] Database uses StatefulSet with volumeClaimTemplates
- [ ] Internal services use ClusterIP, external use LoadBalancer

---

## Pattern 4: GPU Workload

**When to use:** ML inference (LLMs, image generation), video transcoding, any CUDA workload.

**Directory structure:**
```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml
├── statefulset.yaml    # Prefer StatefulSet for stable identity
├── service.yaml
└── pvc.yaml            # Or reference shared NFS for models
```

**Key differences:**
- `runtimeClassName: nvidia` (mandatory)
- GPU resource requests/limits
- Extended startup probes (models take minutes to load)
- High memory limits (16-32GB common)

### statefulset.yaml

```yaml
# <Service Name> StatefulSet
#
# GPU-accelerated workload.
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: <service-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: inference
    app.kubernetes.io/part-of: <namespace>
spec:
  serviceName: <service-name>
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
        app.kubernetes.io/component: inference
        app.kubernetes.io/part-of: <namespace>
    spec:
      runtimeClassName: nvidia  # Required for GPU access
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: <service-name>
          image: <registry>/<image>:<tag>
          ports:
            - name: http
              containerPort: <port>
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: NVIDIA_VISIBLE_DEVICES
              value: "all"
            - name: CUDA_VISIBLE_DEVICES
              value: "0"
          resources:
            requests:
              memory: 512Mi
              nvidia.com/gpu: "1"
            limits:
              memory: 32Gi
              nvidia.com/gpu: "1"
          volumeMounts:
            - name: data
              mountPath: /data
          startupProbe:
            httpGet:
              path: /
              port: http
            failureThreshold: 60    # 10 minutes (60 * 10s)
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 30
            timeoutSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 10
            timeoutSeconds: 5
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: <service-name>-data
```

### Hybrid Storage (Local + NFS for Models)

```yaml
# Fast local storage + shared NFS for large models
      volumeMounts:
        - name: app-data
          mountPath: /app
        - name: models-nfs
          mountPath: /app/models
          subPath: <service-name>/models
      volumes:
        - name: app-data
          persistentVolumeClaim:
            claimName: <service-name>-data    # Longhorn
        - name: models-nfs
          persistentVolumeClaim:
            claimName: nfs-ai-models          # Shared NFS
```

### Memory Optimization (PyTorch/CUDA)

```yaml
          env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "garbage_collection_threshold:0.9,max_split_size_mb:512"
            - name: OLLAMA_NUM_PARALLEL
              value: "2"
            - name: OLLAMA_MAX_LOADED_MODELS
              value: "1"
```

### Checklist

- [ ] Verify GPU available: `kubectl get nodes -o json | jq '.items[].status.allocatable'`
- [ ] Set `runtimeClassName: nvidia`
- [ ] Request exactly 1 GPU (single GPU in homelab)
- [ ] Extended startupProbe for model loading (5-15 minutes)
- [ ] High memory limit based on model requirements
- [ ] Consider NFS for large shared models

---

## Pattern 5: NFS Shared Storage

**When to use:** Media apps sharing files, download managers, anything needing access to NAS storage shared across multiple pods.

**Directory structure:**
```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml
├── deployment.yaml
└── service.yaml
# PVCs defined centrally in infrastructure/storage/ or namespace storage.yaml
```

**Key differences:**
- References pre-existing NFS PVCs (not created per-app)
- Uses `subPath` to organize within shared volume
- PUID/PGID environment variables for permission mapping
- Config on Longhorn, media on NFS

### Shared Storage Architecture

```
NFS Server (10.10.2.5)
├── /mnt/tank/media/
│   ├── movies/      ← radarr, emby
│   ├── tv/          ← sonarr, emby
│   └── music/       ← navidrome
├── /mnt/tank/downloads/
│   ├── usenet/      ← sabnzbd, radarr, sonarr
│   └── torrents/    ← qbittorrent, radarr, sonarr
└── /mnt/tank/photos/  ← immich
```

### Central NFS PV/PVC (infrastructure/storage/)

```yaml
# nfs-media-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-media
spec:
  capacity:
    storage: 10Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  nfs:
    server: 10.10.2.5
    path: /mnt/tank/media
---
# nfs-media-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-media
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: nfs-media
  resources:
    requests:
      storage: 10Ti
```

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: <namespace>
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: <namespace>
    spec:
      securityContext:
        fsGroup: 3001
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: <service-name>
          image: <registry>/<image>:<tag>
          ports:
            - name: http
              containerPort: <port>
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: PUID
              value: "1000"
            - name: PGID
              value: "3001"
            - name: UMASK
              value: "002"
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              memory: 1Gi
          volumeMounts:
            - name: config
              mountPath: /config
            - name: media
              mountPath: /movies
              subPath: movies
            - name: media
              mountPath: /tv
              subPath: tv
            - name: downloads
              mountPath: /downloads
              subPath: usenet
          livenessProbe:
            httpGet:
              path: /ping
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /ping
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: <service-name>-config
        - name: media
          persistentVolumeClaim:
            claimName: nfs-media
        - name: downloads
          persistentVolumeClaim:
            claimName: nfs-downloads
```

### Permission Mapping

```
NAS User/Group        Container        Purpose
─────────────────────────────────────────────────
wdiaz (1000)          PUID=1000        File ownership
media (3001)          PGID=3001        Shared group access
                      UMASK=002        rw-rw-r-- permissions
```

### Checklist

- [ ] NFS PV/PVC created at infrastructure level first
- [ ] Verify NFS export permissions on NAS
- [ ] Match PUID/PGID to NAS user/group
- [ ] Use `subPath` to organize within shared volume
- [ ] Local config on Longhorn (fast), media on NFS (shared)
- [ ] Set appropriate UMASK for group write

---

## Common Configurations Reference

### Health Probes

```yaml
# HTTP web apps
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30

# Databases (PostgreSQL)
livenessProbe:
  exec:
    command: [pg_isready, -U, <username>]
  initialDelaySeconds: 30
  periodSeconds: 30

# Redis/Valkey
livenessProbe:
  exec:
    command: [redis-cli, ping]
  initialDelaySeconds: 10
  periodSeconds: 30

# Slow-starting apps
startupProbe:
  httpGet:
    path: /
    port: http
  failureThreshold: 30
  periodSeconds: 10
```

### Resource Presets

```yaml
# Minimal (static sites)
resources:
  requests: {cpu: 10m, memory: 64Mi}
  limits: {memory: 256Mi}

# Standard (web apps)
resources:
  requests: {cpu: 50m, memory: 128Mi}
  limits: {memory: 512Mi}

# Database
resources:
  requests: {cpu: 50m, memory: 256Mi}
  limits: {memory: 1Gi}

# Heavy (media processing)
resources:
  requests: {cpu: 250m, memory: 512Mi}
  limits: {memory: 4Gi}

# GPU workload
resources:
  requests: {memory: 512Mi, nvidia.com/gpu: "1"}
  limits: {memory: 32Gi, nvidia.com/gpu: "1"}
```

### Init Containers

```yaml
# Wait for PostgreSQL
- name: wait-for-db
  image: postgres:17
  command: [sh, -c, "until pg_isready -h <svc>-postgres -U <user>; do sleep 2; done"]

# Wait for Redis
- name: wait-for-redis
  image: redis:8
  command: [sh, -c, "until redis-cli -h <svc>-redis ping; do sleep 2; done"]

# Wait for HTTP endpoint
- name: wait-for-api
  image: busybox:1.37
  command: [sh, -c, "until wget -q -O- http://<svc>:8080/health; do sleep 2; done"]
```

### Security Context

```yaml
# Standard
securityContext:
  fsGroup: 1000
  fsGroupChangePolicy: "OnRootMismatch"

# Hardened
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault

# Privileged (document why!)
# SECURITY: Required for <reason>
securityContext:
  privileged: true
```

### Service Types

```yaml
# External (LoadBalancer with static IP)
metadata:
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.<IP>"
spec:
  type: LoadBalancer

# Internal only (ClusterIP)
spec:
  type: ClusterIP

# Headless (for StatefulSet DNS)
spec:
  type: ClusterIP
  clusterIP: None
```

### Storage Classes

| Class | Type | Use Case |
|-------|------|----------|
| `longhorn` | Block (RWO) | App data, databases, config |
| `longhorn-retain` | Block (RWO) | Critical data |
| `""` (empty) | NFS (RWX) | Shared media, downloads |

---

## Related Documentation

- [Service Template Reference](../reference/k8s-service-template.md) - Required labels, probes, resources
- [Service Management](../operations/service-management.md) - Scale, update, delete services
- [Network Reference](../reference/network.md) - IP allocation
- [Secrets Management](../operations/secrets.md) - SOPS encryption

---

**Last Updated:** 2026-01-20
