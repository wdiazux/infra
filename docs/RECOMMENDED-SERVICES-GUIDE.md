# Recommended Services for Talos Homelab

**Complete service stack for production Talos infrastructure**

Last Updated: 2025-11-23

---

## Service Categories

### 1. GitOps & Secrets ✅

**FluxCD** - Continuous Delivery
- **Status:** SELECTED
- **Purpose:** GitOps automation
- **Installation:** See `SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md`

**SOPS + Age** - Secrets Management
- **Status:** SELECTED
- **Purpose:** Encrypted secrets in Git
- **Installation:** See `SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md`

---

### 2. Storage ✅

**Longhorn** - Distributed Block Storage
- **Status:** SELECTED
- **Purpose:** Primary persistent storage
- **Installation:** See `kubernetes/longhorn/INSTALLATION.md`
- **Features:** Snapshots, backups to NAS, web UI, volume resize

---

### 3. Networking ✅

**Cilium** - eBPF-based CNI
- **Status:** SELECTED
- **Purpose:** Networking, L2 LoadBalancer, network policies
- **Installation:** See `kubernetes/cilium/INSTALLATION.md`
- **L2 Pool:** 10.10.2.240/28 (15 IPs for LoadBalancer services)

---

### 4. Source Control (Recommended)

**Forgejo** - Self-hosted Git Platform

**Why Forgejo:**
- Lightweight (single binary, ~100MB RAM)
- Community-driven fork of Gitea
- Federation support (ActivityPub)
- Built-in CI/CD (Forgejo Actions)
- GitHub Actions compatible

**Quick Installation:**

```yaml
# forgejo-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: forgejo
---
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
      storage: 10Gi
---
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
  type: LoadBalancer
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

**Access:** http://10.10.2.241:3000 (LoadBalancer IP)

---

### 5. CI/CD (Recommended)

**Option A: Forgejo Actions** (Recommended if using Forgejo)
- **Pros:** Built-in, GitHub Actions compatible, lightweight
- **Setup:** Enable in Forgejo settings
- **Runners:** Deploy Forgejo runners as pods

**Option B: GitHub Actions**
- **Pros:** Fully managed, extensive marketplace
- **Cons:** External dependency, requires GitHub
- **Use:** Temporary until Forgejo is ready

**Option C: Podman** (Local development)
- **Pros:** Daemonless, rootless, Docker-compatible
- **Setup:** Already documented in CLAUDE.md
- **Use:** Local builds before Git push

---

### 6. Monitoring Stack (Recommended)

**kube-prometheus-stack** (All-in-one Helm chart)

**Includes:**
- Prometheus - Metrics collection
- Grafana - Visualization
- Alertmanager - Alerting
- Node Exporter - Node metrics
- Pre-built dashboards

**Quick Installation:**

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install (basic config)
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=30d \
  --set grafana.enabled=true \
  --set grafana.adminPassword='admin' \
  --set grafana.service.type=LoadBalancer

# Access Grafana
kubectl -n monitoring get svc kube-prometheus-stack-grafana
# Default credentials: admin / admin (change immediately)
```

**Loki** (Optional - Logging)

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Install Loki
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

---

### 7. GPU Workloads (Optional)

**NVIDIA GPU Operator**

**Prerequisites:**
- GPU passthrough configured (see terraform/main.tf)
- Talos image with NVIDIA extensions

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
  --set toolkit.enabled=true
```

**Test GPU:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cuda-test
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.3.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

---

### 8. Application Services

**Media Server (Example: Jellyfin)**

```yaml
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
        volumeMounts:
        - name: config
          mountPath: /config
        - name: media
          mountPath: /media
        resources:
          limits:
            nvidia.com/gpu: 1  # GPU transcoding
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: jellyfin-config
      - name: media
        nfs:
          server: 10.10.2.5
          path: /mnt/tank/media
```

---

## Deployment Priority

### Phase 1: Core Infrastructure (Done)
1. ✅ Talos Cluster
2. ✅ Cilium Networking
3. ✅ Longhorn Storage

### Phase 2: GitOps & Secrets (Next)
1. FluxCD bootstrap
2. SOPS + Age setup
3. Migrate secrets to SOPS

### Phase 3: Source Control
1. Deploy Forgejo
2. Migrate repos from GitHub
3. Configure Forgejo Actions runners

### Phase 4: Monitoring
1. kube-prometheus-stack
2. Loki (logging)
3. Configure alerts

### Phase 5: Applications
1. GPU Operator (if using AI/ML)
2. Media services (Jellyfin, Plex)
3. Databases (PostgreSQL, Redis)
4. Custom applications

---

## Service URLs (After Deployment)

| Service | URL | Credentials |
|---------|-----|-------------|
| Kubernetes API | https://10.10.2.10:6443 | kubeconfig |
| Talos API | https://10.10.2.10:50000 | talosconfig |
| Longhorn UI | http://10.10.2.241 | None (configure ingress) |
| Grafana | http://10.10.2.242:3000 | admin / (password) |
| Forgejo | http://10.10.2.243:3000 | (initial setup) |
| Jellyfin | http://10.10.2.244:8096 | (initial setup) |

*Note: LoadBalancer IPs auto-assigned from 10.10.2.240/28 pool*

---

## Quick Installation Commands

```bash
# FluxCD
flux bootstrap github --owner=<user> --repository=<repo> --path=./clusters/homelab

# Longhorn
kubectl apply -f kubernetes/longhorn/longhorn-values.yaml

# Monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring

# Forgejo
kubectl apply -f forgejo-deployment.yaml

# GPU Operator (if using GPU)
helm install gpu-operator nvidia/gpu-operator -n gpu-operator --create-namespace
```

---

## Resource Requirements

| Service | CPU | Memory | Storage |
|---------|-----|--------|---------|
| FluxCD | 100m | 256Mi | - |
| Longhorn | 200m | 512Mi | 10Gi (overhead) |
| Prometheus | 500m | 2Gi | 20Gi |
| Grafana | 100m | 256Mi | 2Gi |
| Loki | 200m | 512Mi | 10Gi |
| Forgejo | 200m | 256Mi | 10Gi |
| GPU Operator | 100m | 256Mi | - |
| Jellyfin | 1000m | 2Gi | 10Gi config |

**Total (with all services):** ~3 CPU cores, ~6GB RAM, ~60GB storage

---

## Next Steps

1. Complete FluxCD + SOPS setup (Phase 2)
2. Deploy monitoring stack for observability
3. Deploy Forgejo and migrate Git repositories
4. Configure GPU workloads (if applicable)
5. Deploy production applications

## Related Documentation

- `SOPS-FLUXCD-IMPLEMENTATION-GUIDE.md` - Secrets management setup
- `kubernetes/longhorn/INSTALLATION.md` - Storage setup
- `kubernetes/cilium/INSTALLATION.md` - Networking setup
- `TALOS-GETTING-STARTED.md` - Cluster basics

---

**Your Talos cluster is ready for production workloads!** 🚀
