# Talos Production Services Guide

**Complete service stack for production Talos Kubernetes infrastructure**

Last Updated: 2025-11-23 | Talos: 1.11.5 | Kubernetes: 1.31.x

---

## Table of Contents

1. [Overview](#overview)
2. [Core Services (Selected)](#core-services-selected)
3. [Source Control - Forgejo](#source-control---forgejo)
4. [CI/CD Options](#cicd-options)
5. [Monitoring Stack](#monitoring-stack)
6. [GPU Workloads](#gpu-workloads)
7. [Application Examples](#application-examples)
8. [Deployment Workflows](#deployment-workflows)
9. [Production Best Practices](#production-best-practices)

---

## Overview

This guide documents the complete production service stack for your Talos homelab, including installation steps, configuration examples, and operational procedures.

### Service Selection Philosophy

- **Core Services:** Already selected and documented
- **Recommended Services:** Production-ready with complete examples
- **Optional Services:** For specific use cases

### Deployment Priority

**Phase 1: Foundation** (✅ Complete)
1. Talos Cluster
2. Cilium Networking
3. Longhorn Storage

**Phase 2: GitOps** (Next - High Priority)
1. FluxCD Bootstrap
2. SOPS + Age Setup
3. Git Repository Structure

**Phase 3: Infrastructure** (After GitOps)
1. Monitoring Stack
2. Logging (Loki)
3. Alerting

**Phase 4: Development** (When Needed)
1. Forgejo (Self-hosted Git)
2. Forgejo Actions (CI/CD)
3. Container Registry

**Phase 5: Applications** (Your Workloads)
1. Databases
2. Media Servers
3. AI/ML Workloads
4. Custom Applications

---

## Core Services (Selected)

### 1. GitOps - FluxCD ✅ SELECTED

**Status:** Production-ready
**Purpose:** Continuous delivery and GitOps automation
**Installation:** See [SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md](SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md)

**Why FluxCD:**
- Native Kubernetes integration
- SOPS decryption built-in
- Helm support with hooks
- Popular in Talos community
- Lightweight (100m CPU, 256Mi RAM)

**Quick Reference:**
```bash
# Check FluxCD status
flux get all

# Force reconciliation
flux reconcile kustomization apps --with-source

# Suspend/resume
flux suspend kustomization apps
flux resume kustomization apps
```

---

### 2. Secrets Management - SOPS + Age ✅ SELECTED

**Status:** Production-ready
**Purpose:** Encrypted secrets in Git
**Installation:** See [SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md](SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md)

**Why SOPS + Age:**
- Zero infrastructure overhead
- FluxCD native integration
- Simple key management
- GitOps-friendly
- Age encryption (modern, secure)

**Quick Reference:**
```bash
# Encrypt secret
sops -e secret.yaml > secret.sops.yaml

# Edit encrypted secret
sops secret.sops.yaml

# Decrypt to view
sops -d secret.sops.yaml
```

---

### 3. Storage - Longhorn ✅ SELECTED

**Status:** Production-ready
**Purpose:** Distributed block storage
**Installation:** See `kubernetes/longhorn/INSTALLATION.md`

**Why Longhorn:**
- Snapshots and backups
- Volume resize
- Web UI for management
- Easy expansion to HA (1→3 replicas)
- NFS backup to external NAS (10.10.2.5)

**Quick Reference:**
```bash
# Check Longhorn status
kubectl -n longhorn-system get pods

# Access UI (port-forward)
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Create backup
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: backup-$(date +%Y%m%d-%H%M%S)
  namespace: longhorn-system
spec:
  snapshotName: snap-$(date +%Y%m%d)
EOF
```

**Storage Classes:**
```yaml
# Fast SSD storage (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"  # Single node
  staleReplicaTimeout: "30"
  dataLocality: "best-effort"
reclaimPolicy: Delete
allowVolumeExpansion: true
---
# Retain policy (for important data)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-retain
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "30"
reclaimPolicy: Retain  # Don't delete volume when PVC deleted
allowVolumeExpansion: true
```

---

### 4. Networking - Cilium ✅ SELECTED

**Status:** Production-ready
**Purpose:** CNI, L2 LoadBalancer, network policies
**Installation:** See `kubernetes/cilium/INSTALLATION.md`

**Why Cilium:**
- eBPF-based (high performance)
- L2 LoadBalancer (no MetalLB needed)
- Network policies
- Hubble observability
- Service mesh capabilities

**LoadBalancer IP Pool:**
```yaml
# Already configured: 10.10.2.240/28 (15 IPs)
# See: kubernetes/cilium/l2-ippool.yaml
```

**Quick Reference:**
```bash
# Check Cilium status
cilium status

# Test connectivity
cilium connectivity test

# View network policies
kubectl get ciliumnetworkpolicies -A

# Hubble UI (optional)
cilium hubble ui
```

---

## Source Control - Forgejo

**Status:** Recommended for self-hosted GitOps
**Purpose:** Self-hosted Git platform with CI/CD

### Why Forgejo?

- ✅ **Lightweight:** Single binary, ~100MB RAM
- ✅ **Community-driven:** Fork of Gitea with FOSS principles
- ✅ **Federation:** ActivityPub support
- ✅ **CI/CD built-in:** Forgejo Actions (GitHub Actions compatible)
- ✅ **Container registry:** Built-in Docker registry
- ✅ **Migration:** Easy migration from GitHub/GitLab

### Complete Installation

**Step 1: Create Namespace and Storage**

```yaml
# forgejo-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: forgejo
  labels:
    app: forgejo
---
# forgejo-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: forgejo-data
  namespace: forgejo
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 20Gi  # Adjust based on needs
```

**Step 2: PostgreSQL Database (Recommended)**

```yaml
# forgejo-postgres.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: forgejo
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: forgejo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        env:
        - name: POSTGRES_DB
          value: forgejo
        - name: POSTGRES_USER
          valueFrom:
            secretRef:
              name: forgejo-db-creds  # Created with SOPS
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretRef:
              name: forgejo-db-creds  # Created with SOPS
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: forgejo
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

**Step 3: Forgejo Application**

```yaml
# forgejo-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forgejo
  namespace: forgejo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: forgejo
  template:
    metadata:
      labels:
        app: forgejo
    spec:
      containers:
      - name: forgejo
        image: codeberg.org/forgejo/forgejo:9
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 22
          name: ssh
        env:
        - name: USER_UID
          value: "1000"
        - name: USER_GID
          value: "1000"
        - name: FORGEJO__database__DB_TYPE
          value: postgres
        - name: FORGEJO__database__HOST
          value: postgres:5432
        - name: FORGEJO__database__NAME
          value: forgejo
        - name: FORGEJO__database__USER
          valueFrom:
            secretRef:
              name: forgejo-db-creds
              key: username
        - name: FORGEJO__database__PASSWD
          valueFrom:
            secretRef:
              name: forgejo-db-creds
              key: password
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: forgejo-data
---
apiVersion: v1
kind: Service
metadata:
  name: forgejo
  namespace: forgejo
spec:
  type: LoadBalancer  # Cilium L2 will assign IP from pool
  selector:
    app: forgejo
  ports:
    - port: 3000
      targetPort: 3000
      name: http
    - port: 22
      targetPort: 22
      name: ssh
```

**Step 4: Database Credentials (SOPS Encrypted)**

```yaml
# Create with SOPS:
# 1. Create plaintext:
#    kubectl create secret generic forgejo-db-creds \
#      --from-literal=username=forgejo \
#      --from-literal=password=SecurePassword123 \
#      --dry-run=client -o yaml > forgejo-db-creds.yaml
#
# 2. Encrypt:
#    sops -e forgejo-db-creds.yaml > clusters/homelab/secrets/forgejo-db-creds.sops.yaml
#
# 3. Commit encrypted file to Git
# 4. FluxCD will decrypt and apply automatically
```

**Step 5: Deploy**

```bash
# Manual deployment
kubectl apply -f forgejo-namespace.yaml
kubectl apply -f forgejo-postgres.yaml
kubectl apply -f forgejo-deployment.yaml

# Or with FluxCD (recommended):
# Place all YAML in clusters/homelab/apps/forgejo/
# FluxCD will auto-deploy

# Check status
kubectl -n forgejo get pods

# Get LoadBalancer IP
kubectl -n forgejo get svc forgejo

# Access Forgejo
# http://<LoadBalancer-IP>:3000 (e.g., http://10.10.2.241:3000)
```

**Step 6: Initial Setup**

1. Access Forgejo UI
2. Complete installation wizard:
   - Database: PostgreSQL (already configured)
   - Domain: `git.yourdomain.com` or IP address
   - SSH Port: 22
   - Admin account: Create your account
3. Configure email (optional)
4. Enable Forgejo Actions (CI/CD)

### Forgejo Actions (CI/CD)

**Enable Actions:**

1. In Forgejo UI: Site Administration → Configuration → Actions
2. Enable "Enable Actions"
3. Deploy Forgejo Act Runner

**Act Runner Deployment:**

```yaml
# forgejo-runner.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forgejo-runner
  namespace: forgejo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: forgejo-runner
  template:
    metadata:
      labels:
        app: forgejo-runner
    spec:
      containers:
      - name: runner
        image: code.forgejo.org/forgejo/runner:latest
        env:
        - name: FORGEJO_URL
          value: "http://forgejo:3000"
        - name: FORGEJO_TOKEN
          valueFrom:
            secretRef:
              name: forgejo-runner-token  # From Forgejo UI
              key: token
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
        - name: runner-data
          mountPath: /data
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock  # Note: Podman compatibility
      - name: runner-data
        emptyDir: {}
```

**Example Forgejo Actions Workflow:**

```yaml
# .forgejo/workflows/build.yml
name: Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          echo "Building application..."
          # Your build commands
      - name: Test
        run: |
          echo "Running tests..."
          # Your test commands
```

---

## CI/CD Options

### Option 1: Forgejo Actions (Recommended if using Forgejo)

**Pros:**
- ✅ Built-in to Forgejo
- ✅ GitHub Actions compatible
- ✅ Self-hosted (full control)
- ✅ No external dependencies

**Cons:**
- ❌ Requires Forgejo deployment
- ❌ Smaller ecosystem than GitHub Actions

**When to use:** After deploying Forgejo

---

### Option 2: GitHub Actions

**Pros:**
- ✅ Fully managed (no infrastructure)
- ✅ Extensive marketplace
- ✅ Free tier (2,000 minutes/month)
- ✅ Mature and stable

**Cons:**
- ❌ External dependency
- ❌ Requires GitHub account
- ❌ Limited to GitHub-hosted code

**When to use:** Current setup, or if not using self-hosted Git

**Example Workflow:**

```yaml
# .github/workflows/deploy.yml
name: Deploy to Talos
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}

      - name: Deploy
        run: |
          kubectl apply -f manifests/
          kubectl rollout status deployment/myapp
```

---

### Option 3: Podman (Local Development)

**Pros:**
- ✅ Daemonless (no Docker daemon)
- ✅ Rootless containers
- ✅ Docker-compatible CLI
- ✅ Already documented in CLAUDE.md

**Cons:**
- ❌ Local only (not CI/CD)
- ❌ Manual workflow

**When to use:** Local development and testing before Git push

**Quick Reference:**
```bash
# Build image
podman build -t myapp:latest .

# Test locally
podman run -p 8080:8080 myapp:latest

# Push to registry
podman push myapp:latest ghcr.io/user/myapp:latest
```

---

## Monitoring Stack

**Status:** Highly Recommended
**Purpose:** Observability, metrics, logging, alerting

### kube-prometheus-stack (All-in-One)

**What's Included:**
- ✅ Prometheus (metrics collection)
- ✅ Grafana (visualization)
- ✅ Alertmanager (alerting)
- ✅ Node Exporter (node metrics)
- ✅ kube-state-metrics (K8s metrics)
- ✅ Pre-built dashboards (50+)

**Installation:**

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install with custom values
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=longhorn \
  --set grafana.enabled=true \
  --set grafana.adminPassword='admin' \
  --set grafana.service.type=LoadBalancer \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi \
  --set grafana.persistence.storageClassName=longhorn
```

**Custom Values File (Better Approach):**

```yaml
# monitoring-stack-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: longhorn
          resources:
            requests:
              storage: 20Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

grafana:
  enabled: true
  adminPassword: "ChangeMe123!"  # Use SOPS encrypted secret instead
  service:
    type: LoadBalancer
  persistence:
    enabled: true
    size: 5Gi
    storageClassName: longhorn
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  # Pre-installed dashboards
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: longhorn
          resources:
            requests:
              storage: 2Gi

# Optional: Disable components you don't need
kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheusOperator:
  enabled: true
```

**Install with values file:**

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring-stack-values.yaml
```

**Access Grafana:**

```bash
# Get LoadBalancer IP
kubectl -n monitoring get svc kube-prometheus-stack-grafana

# Access in browser
# http://<LoadBalancer-IP>  (e.g., http://10.10.2.242)
# Default credentials: admin / admin (change immediately)
```

**Pre-built Dashboards:**

Once logged in, explore:
- **Kubernetes / Compute Resources / Cluster** - Overall cluster metrics
- **Kubernetes / Compute Resources / Namespace (Pods)** - Per-namespace resources
- **Kubernetes / Compute Resources / Node (Pods)** - Per-node resources
- **Node Exporter / Nodes** - Server hardware metrics

### Loki (Logging)

**Purpose:** Log aggregation and querying

**Installation:**

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki stack
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.persistence.storageClassName=longhorn
```

**Configure Grafana Data Source:**

1. Login to Grafana
2. Configuration → Data Sources → Add data source
3. Select "Loki"
4. URL: `http://loki:3100`
5. Save & Test

**Query Logs:**

```logql
# All logs from a namespace
{namespace="default"}

# Logs from specific pod
{pod="nginx-demo-xxxxx"}

# Search for errors
{namespace="default"} |= "error"

# Rate of errors
rate({namespace="default"} |= "error" [5m])
```

---

## GPU Workloads

**Status:** Optional (if using NVIDIA GPU passthrough)
**Purpose:** AI/ML workloads, GPU-accelerated applications

### Prerequisites

1. ✅ GPU passed through to Talos VM (configured in Terraform)
2. ✅ Talos image with NVIDIA extensions (from Talos Factory)
3. ✅ GPU visible in Talos: `talosctl -n 10.10.2.10 get extensions`

### NVIDIA GPU Operator

**Installation:**

```bash
# Add NVIDIA Helm repo
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# Install GPU Operator
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true \
  --set operator.defaultRuntime=containerd
```

**Verify GPU Available:**

```bash
# Check GPU nodes
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Should show:
# "nvidia.com/gpu": "1"
```

**Test GPU Pod:**

```yaml
# gpu-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cuda-vector-add
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-vector-add
    image: "nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda11.7.1"
    resources:
      limits:
        nvidia.com/gpu: 1
```

```bash
# Deploy test
kubectl apply -f gpu-test.yaml

# Check logs (should see CUDA operations)
kubectl logs cuda-vector-add

# Expected output:
# [Vector addition of 50000 elements]
# Copy input data from the host memory to the CUDA device
# CUDA kernel launch with 196 blocks of 256 threads
# Copy output data from the CUDA device to the host memory
# Test PASSED
```

### GPU-Accelerated Applications

**Example: Ollama (LLM Inference)**

```yaml
# ollama-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ai
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: models
          mountPath: /root/.ollama
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 8Gi
          requests:
            cpu: 1000m
            memory: 4Gi
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: ollama-models
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-models
  namespace: ai
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi  # LLM models are large
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ai
spec:
  type: LoadBalancer
  selector:
    app: ollama
  ports:
    - port: 11434
      targetPort: 11434
```

**Usage:**

```bash
# Access Ollama API
curl http://<LoadBalancer-IP>:11434/api/generate \
  -d '{"model":"llama2","prompt":"Why is the sky blue?"}'
```

---

## Application Examples

### Database - PostgreSQL

```yaml
# postgres-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: database
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: database
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: database
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: myapp
        - name: POSTGRES_USER
          valueFrom:
            secretRef:
              name: postgres-creds  # SOPS encrypted
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretRef:
              name: postgres-creds  # SOPS encrypted
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: database
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  clusterIP: None  # Headless service for StatefulSet
```

### Media Server - Jellyfin

```yaml
# jellyfin-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: media
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jellyfin-config
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jellyfin
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jellyfin
  template:
    metadata:
      labels:
        app: jellyfin
    spec:
      containers:
      - name: jellyfin
        image: jellyfin/jellyfin:latest
        ports:
        - containerPort: 8096
          name: http
        env:
        - name: TZ
          value: "America/El_Salvador"
        volumeMounts:
        - name: config
          mountPath: /config
        - name: cache
          mountPath: /cache
        - name: media
          mountPath: /media
          readOnly: true
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
            nvidia.com/gpu: 1  # GPU transcoding
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: jellyfin-config
      - name: cache
        emptyDir:
          sizeLimit: 10Gi
      - name: media
        nfs:
          server: 10.10.2.5  # External NAS
          path: /mnt/tank/media
          readOnly: true
---
apiVersion: v1
kind: Service
metadata:
  name: jellyfin
  namespace: media
spec:
  type: LoadBalancer
  selector:
    app: jellyfin
  ports:
    - port: 8096
      targetPort: 8096
```

---

## Deployment Workflows

### Manual Deployment

```bash
# 1. Create namespace and resources
kubectl apply -f namespace.yaml
kubectl apply -f pvc.yaml
kubectl apply -f secret.yaml  # SOPS encrypted
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# 2. Verify deployment
kubectl -n <namespace> get pods
kubectl -n <namespace> get svc

# 3. Check logs
kubectl -n <namespace> logs -f deployment/<name>
```

### GitOps Deployment (Recommended)

**Directory Structure:**
```
clusters/homelab/
├── infrastructure/
│   ├── sources/
│   │   └── helm-repos.yaml
│   ├── monitoring/
│   │   ├── namespace.yaml
│   │   ├── kustomization.yaml
│   │   └── helm-release.yaml
│   └── longhorn/
│       ├── namespace.yaml
│       ├── kustomization.yaml
│       └── helm-release.yaml
├── apps/
│   ├── forgejo/
│   │   ├── namespace.yaml
│   │   ├── postgres.yaml
│   │   ├── deployment.yaml
│   │   └── kustomization.yaml
│   └── jellyfin/
│       ├── namespace.yaml
│       ├── deployment.yaml
│       └── kustomization.yaml
└── secrets/
    ├── forgejo-db-creds.sops.yaml
    ├── postgres-creds.sops.yaml
    └── monitoring-credentials.sops.yaml
```

**Kustomization Example:**

```yaml
# clusters/homelab/apps/forgejo/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: forgejo
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/homelab/apps/forgejo
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: forgejo
      namespace: forgejo
```

**HelmRelease Example:**

```yaml
# clusters/homelab/infrastructure/monitoring/helm-release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: kube-prometheus-stack
  namespace: monitoring
spec:
  interval: 30m
  chart:
    spec:
      chart: kube-prometheus-stack
      version: '>=51.0.0 <52.0.0'
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  values:
    prometheus:
      prometheusSpec:
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              accessModes: ["ReadWriteOnce"]
              storageClassName: longhorn
              resources:
                requests:
                  storage: 20Gi
    grafana:
      enabled: true
      adminPassword:  # Reference SOPS encrypted secret
        valueFrom:
          secretKeyRef:
            name: grafana-admin-secret
            key: password
      service:
        type: LoadBalancer
```

---

## Production Best Practices

### Resource Limits

**Always set resource limits:**

```yaml
resources:
  requests:
    memory: "256Mi"  # Guaranteed minimum
    cpu: "100m"
  limits:
    memory: "512Mi"  # Maximum allowed
    cpu: "500m"
```

**Why:**
- Prevents single pod from consuming all resources
- Enables proper scheduling
- Improves cluster stability

### Health Checks

**Implement liveness and readiness probes:**

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

### Backup Strategy

**Critical Data:**
1. **Longhorn Volumes:** Daily backups to NAS (10.10.2.5)
2. **Database Dumps:** Automated with CronJob
3. **Git Repositories:** Forgejo backup to NAS
4. **Configuration:** All in Git (GitOps)

**Example Database Backup CronJob:**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: database
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16-alpine
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgres -U $POSTGRES_USER $POSTGRES_DB | \
              gzip > /backup/backup-$(date +%Y%m%d-%H%M%S).sql.gz
            env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-creds
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-creds
                  key: password
            - name: POSTGRES_DB
              value: myapp
            volumeMounts:
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup
            nfs:
              server: 10.10.2.5
              path: /mnt/tank/backups/postgres
```

### Monitoring Alerts

**Configure Alertmanager:**

```yaml
# alertmanager-config.yaml (via SOPS)
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
    receivers:
    - name: 'default'
      email_configs:
      - to: 'admin@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@gmail.com'
        auth_password: 'app-password'  # Encrypt with SOPS!
```

---

## Service URLs Summary

| Service | URL | Port | Credentials |
|---------|-----|------|-------------|
| **Talos API** | https://10.10.2.10:50000 | 50000 | talosconfig |
| **Kubernetes API** | https://10.10.2.10:6443 | 6443 | kubeconfig |
| **Longhorn UI** | http://10.10.2.241 | 80 | None |
| **Grafana** | http://10.10.2.242:3000 | 3000 | admin/(SOPS) |
| **Forgejo** | http://10.10.2.243:3000 | 3000 | (initial setup) |
| **Jellyfin** | http://10.10.2.244:8096 | 8096 | (initial setup) |

*LoadBalancer IPs auto-assigned from Cilium pool: 10.10.2.240/28*

---

## Quick Deployment Commands

```bash
# Monitoring Stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace --values monitoring-values.yaml

# Loki
helm install loki grafana/loki-stack -n monitoring --set grafana.enabled=false

# Forgejo (manual)
kubectl apply -f forgejo/

# GPU Operator (if using GPU)
helm install gpu-operator nvidia/gpu-operator -n gpu-operator --create-namespace

# Database
kubectl apply -f postgres-deployment.yaml

# Media Server
kubectl apply -f jellyfin-deployment.yaml
```

---

## Troubleshooting

### Pod Won't Start

```bash
# Check pod status
kubectl -n <namespace> get pods

# View events
kubectl -n <namespace> describe pod <pod-name>

# Check logs
kubectl -n <namespace> logs <pod-name>
kubectl -n <namespace> logs <pod-name> --previous  # Previous container
```

### LoadBalancer No External-IP

```bash
# Check Cilium L2 pool
kubectl get ciliumloadbalancerippool

# Check L2 announcement policy
kubectl get ciliuml2announcementpolicy

# View Cilium logs
kubectl -n kube-system logs -l app.kubernetes.io/name=cilium
```

### Storage Issues

```bash
# Check PVC status
kubectl -n <namespace> get pvc

# Check Longhorn volumes
kubectl -n longhorn-system get volumes

# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

---

## Related Documentation

- **[SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md](SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md)** - Secrets management
- **[TALOS-GETTING-STARTED.md](TALOS-GETTING-STARTED.md)** - Talos basics
- **[kubernetes/longhorn/INSTALLATION.md](../kubernetes/longhorn/INSTALLATION.md)** - Storage setup
- **[kubernetes/cilium/INSTALLATION.md](../kubernetes/cilium/INSTALLATION.md)** - Networking setup

---

**Your Talos cluster is ready for production services!** 🚀

## Next Steps

1. ✅ Core infrastructure deployed (Talos, Cilium, Longhorn)
2. ➡️ **Deploy FluxCD + SOPS** (follow SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md)
3. ➡️ **Deploy monitoring stack** (kube-prometheus-stack + Loki)
4. ➡️ **Deploy Forgejo** (self-hosted Git + CI/CD)
5. ➡️ **Deploy applications** (databases, media servers, AI/ML)
