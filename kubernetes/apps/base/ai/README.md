# AI Namespace

AI/ML services with GPU time-slicing support.

## Services

| Service | IP | Port | Purpose |
|---------|-----|------|---------|
| Ollama | ClusterIP | 11434 | LLM inference backend |
| Open WebUI | 10.10.2.25 | 80 | LLM chat interface |
| ComfyUI | 10.10.2.26 | 80 | Node-based image generation |

## GPU Configuration

All GPU services share the NVIDIA RTX 4000 SFF (20GB VRAM) via time-slicing:

- **Time-slicing replicas**: 4 (configured in `infrastructure/configs/nvidia-time-slicing.yaml`)
- **No memory isolation**: Concurrent heavy usage may cause OOM
- **Model idle timeouts**: Services unload models when idle to free VRAM

### VRAM Budget (20GB Total)

| Service | Model | Idle | Active |
|---------|-------|------|--------|
| Ollama | 13B-30B | 0 | 8-16GB |
| ComfyUI | SDXL/Flux | 0 | 8-16GB |

**Recommendation**: Avoid running Ollama and ComfyUI at maximum capacity simultaneously.

## Storage

All services use NFS storage for models:

| PVC | Size | Purpose |
|-----|------|---------|
| nfs-ai-models | Shared | All AI models, outputs, configs |

### ComfyUI Directory Structure

```
comfyui/
├── models/           # Checkpoints, LoRAs, VAE, ControlNet
│   ├── checkpoints/  # Main model files (SD 1.5, SDXL, Flux)
│   ├── loras/        # LoRA models
│   ├── vae/          # VAE models
│   └── controlnet/   # ControlNet models
├── output/           # Generated images
├── input/            # Reference/input images
└── custom_nodes/     # ComfyUI extensions
```

## Secrets Setup

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

## First-Time Setup

### Pull Ollama Models

After Ollama is running:

```bash
# Pull a model
kubectl exec -it -n ai ollama-0 -- ollama pull llama3.2

# List models
kubectl exec -it -n ai ollama-0 -- ollama list
```

### Download ComfyUI Models

ComfyUI uses the `yanwk/comfyui-boot` image which auto-downloads ComfyUI and ComfyUI-Manager on first boot.

Models must be manually downloaded to the NFS storage:

```bash
# Access the pod
kubectl exec -it -n ai deploy/comfyui -- bash

# Download a model (example: SDXL base)
cd /root/ComfyUI/models/checkpoints
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# For Flux models, you may need HuggingFace authentication
```

**Recommended Models:**
- **SDXL**: `sd_xl_base_1.0.safetensors` (6.9GB)
- **Flux.1-dev**: Requires HF token, ~12GB
- **SD 1.5**: `v1-5-pruned-emaonly.safetensors` (4.3GB)

### Install Custom Nodes

ComfyUI supports extensions via custom nodes. ComfyUI-Manager is pre-installed with the `yanwk/comfyui-boot` image.

```bash
kubectl exec -it -n ai deploy/comfyui -- bash
cd /root/ComfyUI/custom_nodes

# Install additional custom nodes via ComfyUI-Manager UI
# Or manually clone:
git clone https://github.com/example/custom-node.git

# Restart pod to load new nodes
kubectl rollout restart -n ai deploy/comfyui
```

## API Endpoints

| Service | Access |
|---------|--------|
| Ollama | http://10.10.2.25 (via Open WebUI) |
| ComfyUI | http://10.10.2.26 |
| ComfyUI API | http://10.10.2.26/api |

### ComfyUI API Usage

ComfyUI has a powerful API for programmatic image generation:

```bash
# Queue a workflow
curl -X POST http://10.10.2.26/prompt \
  -H "Content-Type: application/json" \
  -d '{"prompt": {...workflow json...}}'

# Get queue status
curl http://10.10.2.26/queue

# Get history
curl http://10.10.2.26/history
```

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

## ComfyUI vs AUTOMATIC1111

ComfyUI was chosen over AUTOMATIC1111 (Stable Diffusion WebUI) because:

| Feature | ComfyUI | AUTOMATIC1111 |
|---------|---------|---------------|
| Interface | Node-based workflow | Traditional UI |
| Flexibility | Highly customizable | Extension-based |
| Performance | More efficient | Heavier |
| Flux Support | Native | Limited |
| Learning Curve | Steeper | Easier |

ComfyUI's node-based approach allows complex workflows that are reproducible and shareable.
