# AI Namespace Design

**Date:** 2026-01-16
**Status:** Approved
**Author:** Claude (brainstorming session)

---

## Overview

Create a new `ai` namespace for AI/ML services with GPU time-slicing to share the NVIDIA RTX 4000 SFF (24GB VRAM) across multiple workloads.

### Services

| Service | IP | Port | Purpose |
|---------|-----|------|---------|
| Ollama | ClusterIP | 11434 | LLM inference backend |
| Open WebUI | 10.10.2.25 | 80 → 8080 | LLM chat interface |
| Faster-Whisper | 10.10.2.27 | 80 → 9000 | Speech-to-text API |
| Stable Diffusion | 10.10.2.26 | 80 → 7860 | Image generation UI |

### Design Decisions

- **GPU Time-Slicing** - All GPU services share single RTX 4000 via NVIDIA time-slicing (4 replicas)
- **Maximum Quality Models** - large-v3 (Whisper), SDXL (SD), 13B-30B (Ollama)
- **Longhorn Storage** - Block storage for all persistent data
- **SOPS Secrets** - Encrypted secrets for API keys and authentication
- **Adjusted Resources** - Fitted to 12 cores / 96GB RAM available

---

## Resource Allocation

### Per-Service Resources

| Service | CPU Req | CPU Lim | Mem Req | Mem Lim | GPU |
|---------|---------|---------|---------|---------|-----|
| Ollama | 2 | 6 | 12Gi | 20Gi | 1 (time-sliced) |
| Open WebUI | 250m | 500m | 512Mi | 1Gi | None |
| Faster-Whisper | 2 | 4 | 8Gi | 16Gi | 1 (time-sliced) |
| Stable Diffusion | 4 | 8 | 24Gi | 32Gi | 1 (time-sliced) |

### Total Resource Usage

| Resource | Requests | Limits | Available |
|----------|----------|--------|-----------|
| CPU | 8.25 cores | 18.5 cores | 12 cores |
| Memory | 44.5Gi | 69Gi | 96GB |
| GPU | 3 time-sliced | 3 time-sliced | 1 (24GB) |

---

## File Structure

```
kubernetes/
├── apps/base/ai/
│   ├── kustomization.yaml
│   ├── README.md
│   ├── ollama/
│   │   ├── kustomization.yaml
│   │   ├── statefulset.yaml
│   │   └── service.yaml
│   ├── open-webui/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── secret.yaml          # SOPS-encrypted
│   ├── faster-whisper/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── stable-diffusion/
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       └── secret.yaml          # SOPS-encrypted
├── apps/production/ai/
│   └── kustomization.yaml
├── infrastructure/namespaces/
│   └── ai.yaml
└── infrastructure/storage/
    ├── ollama-pvc.yaml
    ├── open-webui-pvc.yaml
    ├── whisper-pvc.yaml
    └── stable-diffusion-pvc.yaml
```

---

## Storage Configuration

### Longhorn PVCs

| Service | PVC Name | Size | Purpose |
|---------|----------|------|---------|
| Ollama | ollama-models | 100Gi | LLM models (7B-30B) |
| Open WebUI | open-webui-data | 10Gi | User data, conversations |
| Faster-Whisper | whisper-models | 50Gi | Whisper model cache |
| Stable Diffusion | sd-data | 150Gi | Checkpoints, LoRAs, outputs |

---

## GPU Time-Slicing Configuration

### NVIDIA GPU Operator ConfigMap

Required to enable GPU sharing across pods:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: time-slicing-config
  namespace: gpu-operator
data:
  any: |-
    version: v1
    flags:
      migStrategy: none
    sharing:
      timeSlicing:
        renameByDefault: false
        failRequestsGreaterThanOne: false
        resources:
          - name: nvidia.com/gpu
            replicas: 4
```

Apply to GPU Operator:
```bash
kubectl patch clusterpolicy/cluster-policy \
  -n gpu-operator --type merge \
  -p '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config"}}}}'
```

---

## Ollama Configuration

### Container

```yaml
image: ollama/ollama:latest
containerPort: 11434
```

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| OLLAMA_NUM_PARALLEL | 2 | Concurrent requests |
| OLLAMA_MAX_LOADED_MODELS | 1 | Single model focus |
| OLLAMA_KEEP_ALIVE | 30m | Model retention timeout |
| OLLAMA_FLASH_ATTENTION | 1 | Enable flash attention |
| NVIDIA_VISIBLE_DEVICES | all | GPU access |

### Volume Mounts

| Mount Path | Source |
|------------|--------|
| /root/.ollama | ollama-models (Longhorn) |

### Health Checks

- **Liveness:** HTTP GET `/` port 11434, initial delay 60s
- **Readiness:** HTTP GET `/` port 11434, initial delay 30s

---

## Open WebUI Configuration

### Container

```yaml
image: ghcr.io/open-webui/open-webui:main
containerPort: 8080
```

### Environment Variables

| Variable | Value |
|----------|-------|
| OLLAMA_BASE_URL | http://ollama:11434 |
| WEBUI_AUTH | true |
| DATA_DIR | /app/backend/data |

### Secret Environment Variables (SOPS)

| Variable | Description |
|----------|-------------|
| WEBUI_SECRET_KEY | JWT signing key (32 chars) |

### Volume Mounts

| Mount Path | Source |
|------------|--------|
| /app/backend/data | open-webui-data (Longhorn) |

### Health Checks

- **Liveness:** HTTP GET `/health` port 8080, initial delay 30s
- **Readiness:** HTTP GET `/health` port 8080, initial delay 10s

---

## Faster-Whisper Configuration

### Container

```yaml
image: onerahmet/openai-whisper-asr-webservice:latest-gpu
containerPort: 9000
```

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| ASR_ENGINE | faster_whisper | Use faster-whisper backend |
| ASR_MODEL | large-v3 | Maximum quality model |
| ASR_DEVICE | cuda | GPU acceleration |
| MODEL_IDLE_TIMEOUT | 300 | Unload after 5 min idle |

### Volume Mounts

| Mount Path | Source |
|------------|--------|
| /root/.cache/huggingface | whisper-models (Longhorn) |

### Health Checks

- **Liveness:** HTTP GET `/status` port 9000, initial delay 120s
- **Readiness:** HTTP GET `/status` port 9000, initial delay 60s

---

## Stable Diffusion Configuration

### Container

```yaml
image: runpod/a1111:1.10.0.post7
containerPort: 7860
```

### Launch Arguments

```
--listen --port 7860 --api --xformers --opt-split-attention-v2
```

### Environment Variables

| Variable | Value |
|----------|-------|
| CUDA_VISIBLE_DEVICES | 0 |
| TORCH_CUDNN_BENCHMARK | 1 |

### Secret Environment Variables (SOPS)

| Variable | Description |
|----------|-------------|
| WEBUI_AUTH_USER | API username |
| WEBUI_AUTH_PASS | API password |

### Volume Mounts

| Mount Path | Source | SubPath |
|------------|--------|---------|
| /stable-diffusion-webui/models | sd-data | models |
| /stable-diffusion-webui/outputs | sd-data | outputs |

### Health Checks

- **Liveness:** HTTP GET `/info` port 7860, initial delay 180s
- **Readiness:** HTTP GET `/info` port 7860, initial delay 120s

---

## Services (LoadBalancer)

### Ollama Service (ClusterIP)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ai
spec:
  type: ClusterIP
  ports:
    - port: 11434
      targetPort: 11434
      protocol: TCP
```

### Open WebUI Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: open-webui
  namespace: ai
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.25"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
```

### Faster-Whisper Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: faster-whisper
  namespace: ai
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.27"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 9000
      protocol: TCP
```

### Stable Diffusion Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: stable-diffusion
  namespace: ai
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.26"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 7860
      protocol: TCP
```

---

## Additional Changes Required

### Emby IP Change

Update Emby service from 10.10.2.30 to 10.10.2.30:

**File:** `kubernetes/apps/base/media/emby/service.yaml`
```yaml
annotations:
  io.cilium/lb-ipam-ips: "10.10.2.30"  # Changed from 10.10.2.30
```

### Documentation Updates

| File | Changes |
|------|---------|
| `CLAUDE.md` | Add AI services to Network Configuration table, update Emby IP |
| `docs/reference/network.md` | Add Open WebUI, Stable Diffusion, Faster-Whisper; update Emby |
| `kubernetes/apps/base/ai/README.md` | New documentation file |
| `kubernetes/apps/base/media/README.md` | Update Emby IP reference |

---

## Implementation Steps

1. **GPU Time-Slicing Setup**
   - Create time-slicing ConfigMap
   - Patch NVIDIA GPU Operator cluster policy
   - Verify GPU sharing works

2. **Create Namespace**
   - Add `kubernetes/infrastructure/namespaces/ai.yaml`
   - Update namespaces kustomization

3. **Create Storage**
   - Create Longhorn PVCs for all services
   - Add to infrastructure/storage kustomization

4. **Deploy Ollama**
   - Create StatefulSet with GPU resources
   - Create ClusterIP service
   - Test with `ollama pull llama3.2`

5. **Deploy Open WebUI**
   - Create SOPS-encrypted secret
   - Create Deployment
   - Create LoadBalancer service
   - Test connection to Ollama

6. **Deploy Faster-Whisper**
   - Create Deployment with GPU
   - Create LoadBalancer service
   - Test transcription API

7. **Deploy Stable Diffusion**
   - Create SOPS-encrypted secret
   - Create Deployment with GPU
   - Create LoadBalancer service
   - Test image generation

8. **Update Emby IP**
   - Modify service annotation
   - Reconcile FluxCD

9. **Update Documentation**
   - Update CLAUDE.md network table
   - Update docs/reference/network.md
   - Create ai namespace README

10. **Final Verification**
    - Test all services accessible
    - Verify GPU time-slicing works
    - Test concurrent GPU usage

---

## Access Points (Post-Deployment)

| Service | URL | Purpose |
|---------|-----|---------|
| Open WebUI | http://10.10.2.25 | Chat with LLMs |
| Stable Diffusion | http://10.10.2.26 | Generate images |
| Faster-Whisper | http://10.10.2.27 | Transcribe audio (API) |

---

## Secret Setup (Manual Steps)

### Open WebUI Secret

```bash
# Generate secret key
WEBUI_SECRET=$(openssl rand -hex 32)

# Create plaintext secret
cat > /tmp/open-webui-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: open-webui-secrets
  namespace: ai
type: Opaque
stringData:
  WEBUI_SECRET_KEY: "$WEBUI_SECRET"
EOF

# Encrypt with SOPS
sops -e /tmp/open-webui-secret.yaml > kubernetes/apps/base/ai/open-webui/secret.yaml

# Clean up
rm /tmp/open-webui-secret.yaml
```

### Stable Diffusion Secret

```bash
# Create plaintext secret
cat > /tmp/sd-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: stable-diffusion-secrets
  namespace: ai
type: Opaque
stringData:
  WEBUI_AUTH_USER: "admin"
  WEBUI_AUTH_PASS: "your-secure-password"
EOF

# Encrypt with SOPS
sops -e /tmp/sd-secret.yaml > kubernetes/apps/base/ai/stable-diffusion/secret.yaml

# Clean up
rm /tmp/sd-secret.yaml
```

---

## GPU Usage Notes

### Time-Slicing Behavior

- All pods can access GPU simultaneously
- No memory isolation - concurrent heavy usage may cause OOM
- Model idle timeouts help free VRAM when not in use

### Recommended Usage Patterns

| Scenario | Expected Behavior |
|----------|-------------------|
| Single service active | Full GPU performance |
| LLM + Whisper | Generally safe (8-16GB + 10GB) |
| LLM + SD (SDXL) | Risk of OOM if both generating |
| All three active | Works for idle/light loads only |

### VRAM Budget (24GB Total)

| Service | Idle | Active |
|---------|------|--------|
| Ollama (13B) | 0 | 8-16GB |
| Faster-Whisper (large-v3) | 0 | 6-10GB |
| Stable Diffusion (SDXL) | 0 | 8-12GB |

---

**Last Updated:** 2026-01-16
