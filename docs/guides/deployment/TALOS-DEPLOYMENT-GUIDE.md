# Talos Kubernetes: Complete Deployment Guide

**Date**: 2025-11-23
**Purpose**: Step-by-step guide for creating Talos Linux golden images with Packer and deploying single-node Kubernetes cluster with Terraform

---

## Overview

This guide walks through the complete workflow:
1. **Day 0**: Generate Talos Factory schematic with required extensions
2. **Day 1**: Build Talos golden image template with Packer
3. **Day 2**: Deploy single-node Kubernetes cluster with Terraform
4. **Day 3**: Install Cilium CNI and Longhorn storage

**Total Time**: ~30-40 minutes (including Kubernetes bootstrap)

---

## Prerequisites

### Tools Required

```bash
# Verify tool versions
packer version     # Should be 1.14.2+
terraform version  # Should be 1.9.0+
talosctl version   # Should be v1.11.4+
kubectl version    # Should be v1.31.0+
helm version       # Should be v3.16.0+
```

### Proxmox Access

- Proxmox VE 9.0 host
- API token with permissions: `PVEVMAdmin`, `PVEDatastoreUser`
- Storage pool (e.g., `tank`)
- Network bridge (e.g., `vmbr0`)
- **CRITICAL**: CPU type set to "host" (required for Talos v1.0+ and Cilium)

### Network Requirements

- Proxmox host has internet access (for downloading Talos images)
- Static IP for Talos node OR DHCP reservation
- DNS configured
- No firewall blocking ports: 50000 (Talos API), 6443 (Kubernetes API)

### Hardware Requirements (Single-Node Cluster)

**Minimum**:
- CPU: 2 cores
- RAM: 2GB
- Disk: 10GB

**Recommended for Production**:
- CPU: 6-8 cores
- RAM: 24-32GB
- Disk: 150-200GB
- GPU (optional): NVIDIA RTX 4000 for AI/ML workloads

---

## Part 1: Day 0 - Generate Talos Factory Schematic

### Step 1: Access Talos Factory

Navigate to: **https://factory.talos.dev/**

### Step 2: Select Platform

- **Platform**: Select "Metal" (for Talos 1.8.0+)
- **Architecture**: amd64

### Step 3: Add REQUIRED Extensions

**⚠️ CRITICAL**: You MUST include these extensions for Longhorn storage to work:

1. **siderolabs/qemu-guest-agent** (REQUIRED)
   - Purpose: Proxmox integration (VM status reporting, shutdown management)

2. **siderolabs/iscsi-tools** (REQUIRED)
   - Purpose: Longhorn storage support
   - **Without this, Longhorn volume creation will FAIL**

3. **siderolabs/util-linux-tools** (REQUIRED)
   - Purpose: Longhorn storage support (provides `nsenter`, `fstrim`)
   - **Without this, Longhorn volume mounting will FAIL**

### Step 4: Add OPTIONAL Extensions (for GPU Workloads)

If you plan to use NVIDIA GPU passthrough for AI/ML workloads:

4. **nonfree-kmod-nvidia-production** (OPTIONAL)
   - Purpose: NVIDIA proprietary GPU drivers

5. **nvidia-container-toolkit-production** (OPTIONAL)
   - Purpose: NVIDIA container runtime for GPU workloads in Kubernetes

### Step 5: Generate Schematic

1. Click "Generate Schematic"
2. Copy the **Schematic ID** (format: `abc123def456...`)
3. Save this ID - you'll need it for Packer

**Example Schematic ID**: `376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba`

### Step 6: Verify Schematic

Check the schematic includes all required extensions:

```bash
# View schematic details
curl https://factory.talos.dev/schematics/YOUR_SCHEMATIC_ID | jq .
```

Should show:
```json
{
  "customization": {
    "systemExtensions": {
      "officialExtensions": [
        "siderolabs/qemu-guest-agent",
        "siderolabs/iscsi-tools",
        "siderolabs/util-linux-tools"
      ]
    }
  }
}
```

---

## Part 2: Build Golden Image with Packer

### Step 1: Configure Packer Variables

```bash
cd packer/talos

# Copy example configuration
cp talos.auto.pkrvars.hcl.example talos.auto.pkrvars.hcl

# Edit configuration
vim talos.auto.pkrvars.hcl
```

**Required settings**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx"
proxmox_node     = "pve"
proxmox_skip_tls_verify = true

# Talos Configuration
talos_version      = "v1.11.4"
talos_schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"  # YOUR SCHEMATIC ID

# Template Configuration
template_name        = "talos-1.11.4-nvidia-template"
template_description = "Talos Linux v1.11.4 with Longhorn + NVIDIA support"
vm_id                = 9200

# VM Hardware
vm_cores  = 2
vm_memory = 2048
vm_disk_size    = "20G"  # Minimal for template
vm_disk_storage = "tank"
vm_cpu_type     = "host"  # CRITICAL: Must be 'host' for Talos v1.0+ and Cilium

# Network
vm_network_bridge = "vmbr0"

# Build Configuration
boot_wait   = "10s"
ssh_timeout = "2m"  # Talos doesn't have SSH, will timeout (expected)
```

### Step 2: Build the Template

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build Process**:
1. Packer downloads Talos Factory ISO (includes your extensions)
2. Creates VM with ISO attached
3. Boots Talos (automatic installation to disk)
4. Waits for boot to complete
5. Converts VM to template

**Build Time**: ~10-15 minutes

**Note**: Packer will timeout waiting for SSH - **this is expected** (Talos has no SSH access)

### Step 3: Verify Template

```bash
# SSH to Proxmox host
ssh root@proxmox

# List templates
qm list | grep -i template
# Should show: talos-1.11.4-nvidia-template

# Check template configuration
qm config 9200

# Verify CPU type is 'host'
qm config 9200 | grep cpu
# Should show: cpu: host
```

---

## Part 3: Deploy Kubernetes Cluster with Terraform

### Step 1: Configure Terraform Variables

```bash
cd ../../terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Key settings for Talos cluster**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx"
proxmox_node     = "pve"

# Talos Configuration
deploy_talos         = true
cluster_name         = "homelab"
talos_template_name  = "talos-1.11.4-nvidia-template"  # Must match Packer template
talos_version        = "v1.11.4"
kubernetes_version   = "v1.31.0"

# Node Configuration (Single-Node Cluster)
node_name    = "talos-01"
node_vm_id   = 100
node_cores   = 8
node_memory  = 32768  # 32GB RAM (adjust based on your hardware)
node_disk_size = 200  # 200GB for OS + Longhorn storage

# Networking
node_ip      = "10.10.2.10"
node_netmask = "24"
node_gateway = "10.10.2.1"
dns_servers  = ["8.8.8.8", "1.1.1.1"]
ntp_servers  = ["time.cloudflare.com"]

# Storage
install_disk = "/dev/sda"  # Main OS disk

# GPU Passthrough (Optional)
enable_gpu = true  # Set to false if no GPU
gpu_pci_id = "0000:01:00"  # Find with: lspci | grep -i nvidia
```

### Step 2: Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

**Terraform will**:
1. Look up Talos template on Proxmox
2. Clone template → create VM (ID 100)
3. Generate Talos machine secrets
4. Create machine configuration (with Longhorn requirements)
5. Apply configuration to node via Talos API
6. Bootstrap Kubernetes cluster
7. Generate kubeconfig

**Deploy Time**: ~5-10 minutes

### Step 3: Verify Cluster is Up

```bash
# Check Terraform outputs
terraform output

# Get kubeconfig
terraform output -raw kubeconfig > ~/.kube/config-talos
export KUBECONFIG=~/.kube/config-talos

# Verify node is ready (may take 2-3 minutes)
kubectl get nodes

# Should show:
# NAME       STATUS     ROLES           AGE   VERSION
# talos-01   NotReady   control-plane   2m    v1.31.0
```

**Note**: Node will be "NotReady" until CNI (Cilium) is installed in Part 4.

### Step 4: Configure talosctl

```bash
# Get Talos configuration
terraform output -raw talosconfig > ~/.talos/config

# Set as default
export TALOSCONFIG=~/.talos/config

# Verify Talos API access
talosctl -n 10.10.2.10 version

# Check cluster health
talosctl -n 10.10.2.10 health
```

---

## Part 4: Install CNI and Storage

### ⚠️ CRITICAL: Installation Order

**YOU MUST install in this order**:
1. **FIRST**: Cilium CNI
2. **SECOND**: Longhorn storage

**Why**: Longhorn requires a functioning network. Without Cilium, Longhorn pods will fail to start.

---

### Step 1: Install Cilium CNI (REQUIRED FIRST)

```bash
# Add Cilium Helm repo
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install Cilium
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445

# Wait for Cilium to be ready (~2 minutes)
kubectl -n kube-system rollout status daemonset/cilium
```

**Verify Cilium**:
```bash
# Check Cilium status
cilium status --wait

# Verify node is now Ready
kubectl get nodes
# Should show: STATUS = Ready

# Test connectivity
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600
kubectl exec test-pod -- ping -c 3 8.8.8.8
kubectl delete pod test-pod
```

**Installation Notes**: See `kubernetes/cilium/INSTALLATION.md` for detailed configuration.

---

### Step 2: Install Longhorn Storage (AFTER Cilium)

**Prerequisites Check**:
```bash
# Verify system extensions are present
talosctl -n 10.10.2.10 get extensions

# Should show:
# - iscsi-tools
# - util-linux-tools
# - qemu-guest-agent
```

**Install Longhorn**:
```bash
# Add Longhorn Helm repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Create namespace
kubectl create namespace longhorn-system

# Install Longhorn (single-node configuration)
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values ../kubernetes/longhorn/longhorn-values.yaml
```

**Longhorn configuration** (`kubernetes/longhorn/longhorn-values.yaml`):
```yaml
defaultSettings:
  defaultReplicaCount: 1  # Single-node = 1 replica (no redundancy)
  defaultDataLocality: best-effort

persistence:
  defaultClass: true
  defaultClassReplicaCount: 1

longhornUI:
  replicas: 1
```

**Verify Longhorn**:
```bash
# Wait for Longhorn pods to be ready (~3-5 minutes)
kubectl -n longhorn-system get pods

# Check Longhorn manager
kubectl -n longhorn-system rollout status deployment/longhorn-driver-deployer

# Test storage class
kubectl get storageclass
# Should show: longhorn (default)

# Create test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC is bound
kubectl get pvc test-pvc
# Should show: STATUS = Bound

# Clean up test
kubectl delete pvc test-pvc
```

**Access Longhorn UI**:
```bash
# Port-forward Longhorn UI
kubectl -n longhorn-system port-forward service/longhorn-frontend 8080:80

# Open browser: http://localhost:8080
```

**Installation Notes**: See `kubernetes/longhorn/INSTALLATION.md` for detailed configuration.

---

### Step 3: Allow Workloads on Control Plane (Single-Node Only)

For single-node clusters, remove the taint that prevents workloads from running on control plane:

```bash
# Remove control-plane taint
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Verify taint removed
kubectl describe node talos-01 | grep Taints
# Should show: Taints: <none>
```

---

## Part 5: Deploy Test Workload

### Test 1: Simple Deployment

```bash
# Deploy nginx
kubectl create deployment nginx --image=nginx --replicas=1

# Expose via LoadBalancer (Cilium L2 announcement)
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check external IP assigned
kubectl get svc nginx
# Should show EXTERNAL-IP (from Cilium L2 pool)

# Test access
curl http://<EXTERNAL-IP>
```

### Test 2: Persistent Storage

```bash
# Deploy PostgreSQL with Longhorn storage
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
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
        image: postgres:16
        env:
        - name: POSTGRES_PASSWORD
          value: supersecret
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-pvc
EOF

# Verify deployment
kubectl get pods -l app=postgres
kubectl get pvc postgres-pvc

# Test database
kubectl exec -it deployment/postgres -- psql -U postgres -c "SELECT version();"
```

### Test 3: GPU Workload (if GPU enabled)

```bash
# Install NVIDIA GPU Operator
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=false  # Drivers in Talos image via extensions

# Deploy GPU test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.2.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

# Check GPU detection
kubectl logs gpu-test
# Should show GPU details
```

---

## Troubleshooting

### Issue: Packer build times out waiting for SSH

**Symptoms**:
```
Timeout waiting for SSH to become available
```

**Solution**: This is EXPECTED behavior. Talos doesn't have SSH. Packer will timeout after `ssh_timeout` and continue.

**Action**: No action needed. Verify template was created: `qm list | grep 9200`

### Issue: Node shows "NotReady" after deployment

**Symptoms**:
```bash
kubectl get nodes
# NAME       STATUS     ROLES           AGE   VERSION
# talos-01   NotReady   control-plane   5m    v1.31.0
```

**Solutions**:
1. Check if Cilium is installed: `kubectl -n kube-system get pods -l app.kubernetes.io/name=cilium`
2. If not installed, install Cilium first (Part 4, Step 1)
3. If installed, check Cilium logs: `kubectl -n kube-system logs -l app.kubernetes.io/name=cilium`

### Issue: Longhorn volumes fail to create

**Symptoms**:
```
Events:
  Warning  ProvisioningFailed  Failed to provision volume: iSCSI daemon not running
```

**Solutions**:
1. **Verify system extensions**: `talosctl -n 10.10.2.10 get extensions`
   - Must show: `iscsi-tools`, `util-linux-tools`
2. **If missing**: Rebuild Talos image with correct schematic ID (Part 1)
3. **Check kernel modules**: `talosctl -n 10.10.2.10 get systemextensions`
4. **Verify kubelet extra mounts**: See `talos/patches/longhorn-requirements.yaml`

### Issue: Longhorn pods stuck in Pending

**Symptoms**:
```bash
kubectl -n longhorn-system get pods
# NAME                                    READY   STATUS    RESTARTS   AGE
# longhorn-manager-xxxxx                  0/1     Pending   0          5m
```

**Solutions**:
1. **Check if Cilium is installed and ready**:
   ```bash
   kubectl -n kube-system get pods -l app.kubernetes.io/name=cilium
   ```
2. **If Cilium not ready**: Wait for Cilium to fully start
3. **Check control-plane taint**: `kubectl describe node talos-01 | grep Taints`
4. **If tainted**: Remove taint: `kubectl taint nodes --all node-role.kubernetes.io/control-plane-`

### Issue: Can't access Talos API

**Symptoms**:
```
error: failed to connect: connection refused
```

**Solutions**:
1. Verify Talos node is running: `ssh root@proxmox 'qm list | grep 1000'`
2. Check Talos API port 50000: `nc -zv 10.10.2.10 50000`
3. Verify firewall allows port 50000
4. Check talosconfig: `cat ~/.talos/config | grep endpoints`
5. Try with explicit node: `talosctl -n 10.10.2.10 version`

### Issue: GPU not detected in Kubernetes

**Symptoms**:
```bash
kubectl describe node talos-01 | grep -i gpu
# (No output)
```

**Solutions**:
1. Verify GPU extensions in schematic: `curl https://factory.talos.dev/schematics/YOUR_SCHEMATIC_ID | jq .`
2. Check GPU passthrough in Proxmox: `ssh root@proxmox 'qm config 100 | grep hostpci'`
3. Verify IOMMU enabled: `ssh root@proxmox 'dmesg | grep -i iommu'`
4. Install NVIDIA GPU Operator: See Part 5, Test 3
5. Check GPU driver loaded: `talosctl -n 10.10.2.10 dmesg | grep nvidia`

---

## Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│            Day 0: Generate Talos Factory Schematic          │
├─────────────────────────────────────────────────────────────┤
│ 1. Visit https://factory.talos.dev/                         │
│ 2. Select "Metal" platform                                  │
│ 3. Add REQUIRED extensions:                                 │
│    - siderolabs/qemu-guest-agent                            │
│    - siderolabs/iscsi-tools (for Longhorn)                  │
│    - siderolabs/util-linux-tools (for Longhorn)             │
│ 4. Add OPTIONAL extensions (GPU):                           │
│    - nonfree-kmod-nvidia-production                         │
│    - nvidia-container-toolkit-production                    │
│ 5. Copy Schematic ID                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│          Day 1: Build Golden Image (10-15 min)              │
├─────────────────────────────────────────────────────────────┤
│ cd packer/talos                                              │
│ cp talos.auto.pkrvars.hcl.example talos.auto.pkrvars.hcl   │
│ vim talos.auto.pkrvars.hcl  # Set schematic ID              │
│ packer init .                                                │
│ packer build .                                               │
│ → Downloads Talos Factory ISO with extensions               │
│ → Creates VM, boots Talos, converts to template             │
│ → Template: "talos-1.11.4-nvidia-template"                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│       Day 2: Deploy Kubernetes Cluster (5-10 min)           │
├─────────────────────────────────────────────────────────────┤
│ cd terraform                                                 │
│ cp terraform.tfvars.example terraform.tfvars                │
│ vim terraform.tfvars  # Configure cluster settings           │
│ terraform init                                               │
│ terraform apply                                              │
│ → Clones template → creates Talos VM                        │
│ → Generates machine config with Longhorn requirements       │
│ → Bootstraps Kubernetes v1.31.0                             │
│ → Exports kubeconfig and talosconfig                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│            Day 3: Install CNI + Storage (10 min)            │
├─────────────────────────────────────────────────────────────┤
│ ⚠️  CRITICAL: Install in this order!                        │
│                                                              │
│ Step 1: Install Cilium CNI (FIRST)                          │
│ helm install cilium cilium/cilium --namespace kube-system   │
│ → Provides networking for all pods                          │
│ → Node becomes "Ready"                                       │
│                                                              │
│ Step 2: Install Longhorn Storage (SECOND)                   │
│ helm install longhorn longhorn/longhorn \                   │
│   --namespace longhorn-system \                             │
│   --values kubernetes/longhorn/longhorn-values.yaml         │
│ → Provides persistent storage                               │
│ → Creates default StorageClass                              │
│                                                              │
│ Step 3: Remove Control Plane Taint (Single-Node)            │
│ kubectl taint nodes --all \                                 │
│   node-role.kubernetes.io/control-plane-                    │
│ → Allows workloads on control plane                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Optional: Deploy Test Workloads                 │
├─────────────────────────────────────────────────────────────┤
│ • Simple deployment (nginx)                                  │
│ • Persistent storage (PostgreSQL)                            │
│ • GPU workload (CUDA test)                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Single-Node to HA Migration Path

Start with single-node, expand to 3-node HA later:

```bash
# Add 2 more Talos nodes (same template)
cd terraform
vim terraform.tfvars
# Set: node_count = 3

terraform apply

# Longhorn will automatically distribute replicas across 3 nodes
# Update Longhorn replica count:
kubectl -n longhorn-system edit settings default-replica-count
# Change from 1 to 3
```

### 2. Regular Talos Upgrades

Keep Talos and Kubernetes up-to-date:

```bash
# Upgrade Talos
talosctl -n 10.10.2.10 upgrade --image factory.talos.dev/installer/YOUR_SCHEMATIC_ID:v1.12.0

# Upgrade Kubernetes
talosctl -n 10.10.2.10 upgrade-k8s --to v1.32.0
```

### 3. Backup Etcd Regularly

```bash
# Create etcd snapshot
talosctl -n 10.10.2.10 etcd snapshot etcd-backup.db

# Store backup securely
```

### 4. Monitor Resource Usage

```bash
# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

### 5. Use GitOps for Application Deployment

```bash
# Install FluxCD
flux bootstrap github \
  --owner=wdiazux \
  --repository=homelab \
  --path=clusters/homelab
```

---

## Next Steps

1. ✅ Complete Talos Kubernetes deployment
2. Deploy applications (Plex, Jellyfin, AI/ML workloads)
3. Configure Longhorn backups to external NAS
4. Set up monitoring and alerting
5. Implement GitOps workflow with FluxCD
6. Scale to 3-node HA cluster (optional)

---

## Related Documentation

- **Packer Talos Template**: `packer/talos/README.md`
- **Terraform Talos Configuration**: `terraform/main.tf`
- **Cilium Installation Guide**: `kubernetes/cilium/INSTALLATION.md`
- **Longhorn Installation Guide**: `kubernetes/longhorn/INSTALLATION.md`
- **Talos Machine Config Patches**: `talos/patches/longhorn-requirements.yaml`
- **Debian Deployment Guide**: `docs/DEBIAN-DEPLOYMENT-GUIDE.md`

---

**Last Updated**: 2025-11-23
**Maintained By**: wdiazux
