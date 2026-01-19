# AI Namespace

AI/ML services with GPU time-slicing support.

## Services

| Service | IP | Port | Purpose |
|---------|-----|------|---------|
| Ollama | ClusterIP | 11434 | LLM inference backend |
| Open WebUI | 10.10.2.25 | 80 | LLM chat interface |
| Stable Diffusion | 10.10.2.26 | 80 | Image generation UI |

## GPU Configuration

All GPU services share the NVIDIA RTX 4000 SFF (24GB VRAM) via time-slicing:

- **Time-slicing replicas**: 4 (configured in `infrastructure/configs/nvidia-time-slicing.yaml`)
- **No memory isolation**: Concurrent heavy usage may cause OOM
- **Model idle timeouts**: Services unload models when idle to free VRAM

### VRAM Budget (24GB Total)

| Service | Model | Idle | Active |
|---------|-------|------|--------|
| Ollama | 13B-30B | 0 | 8-16GB |
| Stable Diffusion | SDXL | 0 | 8-12GB |

**Recommendation**: Avoid running Ollama and Stable Diffusion at maximum capacity simultaneously.

## Storage

All services use Longhorn block storage:

| PVC | Size | Purpose |
|-----|------|---------|
| ollama-models | 100Gi | LLM models |
| open-webui-data | 10Gi | User data, conversations |
| sd-data | 150Gi | Checkpoints, LoRAs, outputs |

## Secrets Setup

Before deploying, encrypt the secrets with SOPS:

### Open WebUI

```bash
# Generate secret key
WEBUI_SECRET=$(openssl rand -hex 32)

# Edit the secret file
sops kubernetes/apps/base/ai/open-webui/secret.yaml
# Replace REPLACE_WITH_GENERATED_KEY with $WEBUI_SECRET

# Encrypt
sops -e --in-place kubernetes/apps/base/ai/open-webui/secret.yaml
```

### Stable Diffusion

```bash
# Edit and encrypt
sops kubernetes/apps/base/ai/stable-diffusion/secret.yaml
# Replace REPLACE_WITH_SECURE_PASSWORD with a strong password

sops -e --in-place kubernetes/apps/base/ai/stable-diffusion/secret.yaml
```

## First-Time Setup

### Pull Initial Models

After Ollama is running:

```bash
# Pull a model
kubectl exec -it -n ai ollama-0 -- ollama pull llama3.2

# List models
kubectl exec -it -n ai ollama-0 -- ollama list
```

### Download Stable Diffusion Models

Models must be manually downloaded to the `sd-data` PVC:

1. Access the pod: `kubectl exec -it -n ai deploy/stable-diffusion -- bash`
2. Download models to `/stable-diffusion-webui/models/Stable-diffusion/`
3. Refresh the model list in the WebUI

## API Endpoints

| Service | Swagger/API Docs |
|---------|------------------|
| Ollama | http://10.10.2.25 (via Open WebUI) |
| Stable Diffusion | http://10.10.2.26/docs |
