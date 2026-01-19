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

## Accessing Ollama Remotely

Ollama runs as a ClusterIP service (internal only). To access it from your local machine for use with VS Code, Continue, or other clients:

### Option 1: Port Forwarding (Recommended)

Forward the Ollama port to your local machine:

```bash
# Set kubeconfig
export KUBECONFIG=/path/to/infra/terraform/talos/kubeconfig

# Forward Ollama port to localhost:11434
kubectl port-forward -n ai svc/ollama 11434:11434

# Keep this terminal open while using Ollama
```

Then configure your client to use `http://localhost:11434` as the Ollama URL.

### Option 2: Port Forwarding in Background

Run port forwarding in the background:

```bash
# Start in background
kubectl port-forward -n ai svc/ollama 11434:11434 &

# To stop later
pkill -f "port-forward.*ollama"
```

### Client Configuration

#### VS Code with Continue Extension

1. Install the Continue extension in VS Code
2. Open Continue settings
3. Set Ollama URL: `http://localhost:11434`
4. Select a model (must be pulled first via `ollama pull`)

#### Command Line (curl)

```bash
# List models
curl http://localhost:11434/api/tags

# Generate completion
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Hello, world!"
}'

# Chat
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

#### Python (ollama library)

```python
import ollama

# Ensure OLLAMA_HOST is set or use default localhost:11434
response = ollama.chat(model='llama3.2', messages=[
    {'role': 'user', 'content': 'Hello!'}
])
print(response['message']['content'])
```

### Note on Direct LoadBalancer Access

Ollama intentionally uses ClusterIP (not LoadBalancer) because:
- API has no built-in authentication
- Exposing directly could allow unauthorized model access
- Port forwarding provides secure, on-demand access

If you need persistent external access, consider using Open WebUI at http://10.10.2.25 which provides authentication and a web interface.
