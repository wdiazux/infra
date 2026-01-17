# GPU Passthrough

NVIDIA GPU passthrough for AI/ML workloads.

---

## Overview

GPU passthrough is configured **automatically** via Terraform when `enable_gpu_passthrough = true` (default).

**What's Automatic:**
- PCI passthrough configuration
- NVIDIA device plugin deployment
- RuntimeClass creation

**Configuration:** `terraform/talos/variables.tf`, `terraform/talos/vm.tf`

---

## Hardware

| Component | Value |
|-----------|-------|
| GPU | NVIDIA RTX 4000 SFF Ada |
| PCI ID | 07:00.0 (GPU), 07:00.1 (Audio) |
| VRAM | 20GB |

**Limitation:** Consumer GPUs don't support vGPU. The GPU can only be assigned to ONE VM at a time.

---

## Prerequisites

### Talos Image Extensions

Your Talos schematic must include:
- `siderolabs/nonfree-kmod-nvidia-production`
- `siderolabs/nvidia-container-toolkit-production`

### Proxmox Setup

1. IOMMU enabled in BIOS
2. GPU mapping created in Proxmox UI:
   - Datacenter → Resource Mappings → PCI Devices
   - Name: `nvidia-gpu`
   - Device: RTX 4000 SFF

---

## Verification

### Check GPU in Node

```bash
# Verify GPU is detected
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
# Should show: "1"

# Check NVIDIA device plugin
kubectl get pods -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin
```

### Check Talos Extensions

```bash
talosctl -n 10.10.2.10 get extensions | grep nvidia
# Should show nvidia extensions loaded
```

---

## Using GPU in Pods

### Basic GPU Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: OnFailure
  runtimeClassName: nvidia
  containers:
    - name: cuda
      image: nvidia/cuda:12.0-base
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
```

### Test GPU

```bash
kubectl apply -f gpu-test.yaml
kubectl logs gpu-test
# Should show GPU information
```

---

## Example Workloads

### Ollama (LLM Inference)

```yaml
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
      runtimeClassName: nvidia
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
              memory: 16Gi
            requests:
              cpu: 2000m
              memory: 8Gi
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
  storageClassName: longhorn-default
  resources:
    requests:
      storage: 50Gi
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

### Using Ollama

```bash
# Deploy
kubectl create namespace ai
kubectl apply -f ollama.yaml

# Get LoadBalancer IP
kubectl get svc ollama -n ai

# Pull a model
curl http://<IP>:11434/api/pull -d '{"name": "llama2"}'

# Generate text
curl http://<IP>:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'
```

### Jellyfin (GPU Transcoding)

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
      runtimeClassName: nvidia
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
              readOnly: true
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: 4Gi
            requests:
              cpu: 500m
              memory: 1Gi
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

## RuntimeClass

The `nvidia` RuntimeClass is created automatically:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
```

Use in pods:
```yaml
spec:
  runtimeClassName: nvidia
```

---

## Troubleshooting

### GPU Not Detected

```bash
# Check device plugin logs
kubectl logs -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin

# Verify extensions in Talos
talosctl -n 10.10.2.10 get extensions

# Check if GPU is passed through in Proxmox
# VM → Hardware → Should show PCI Device
```

### nvidia-smi Fails in Pod

```bash
# Ensure runtimeClassName is set
# Check pod spec:
spec:
  runtimeClassName: nvidia

# Verify CUDA compatibility
kubectl run cuda-check --rm -it --restart=Never \
  --image=nvidia/cuda:12.0-base \
  --overrides='{"spec":{"runtimeClassName":"nvidia","resources":{"limits":{"nvidia.com/gpu":1}}}}' \
  -- nvidia-smi
```

### Insufficient GPU Resources

```bash
# Check GPU allocation
kubectl describe nodes | grep -A5 "Allocated resources"

# Only 1 GPU available - ensure no other pods are using it
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) | .metadata.name'
```

### GPU Not Available After Reboot

1. Check Proxmox GPU mapping still exists
2. Verify IOMMU is enabled
3. Check Talos extensions loaded:
   ```bash
   talosctl -n 10.10.2.10 get extensions
   ```

---

## Resources

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [Talos NVIDIA Guide](https://www.talos.dev/v1.12/talos-guides/configuration/nvidia-gpu/)
- [Kubernetes GPU Scheduling](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)

---

## Deployed GPU Workloads

Current services using GPU acceleration:

| Service | Namespace | GPU Usage | Purpose |
|---------|-----------|-----------|---------|
| Ollama | ai | Full GPU | LLM inference (primary) |
| Immich ML | media | CUDA | Photo/video ML processing |
| Stable Diffusion | ai | Full GPU | Image generation |
| Emby | media | NVENC/NVDEC | Hardware transcoding |

**Note:** GPU time-slicing is configured via `nvidia.com/gpu` resource requests. Ollama keeps models in VRAM (5m keep-alive), allowing other workloads to share GPU when idle.

---

**Last Updated:** 2026-01-17
