# AI Namespace

AI/ML services with GPU time-slicing support.

## Services

| Service | IP | Port | Purpose |
|---------|-----|------|---------|
| Ollama | 10.10.2.50 | 11434 | LLM inference API |
| Open WebUI | 10.10.2.51 | 80 | LLM chat interface |
| ComfyUI | 10.10.2.52 | 80 | Node-based image generation |

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

### Shared NFS Storage

| PVC | Purpose |
|-----|---------|
| nfs-ai-models | AI models shared across services |

### ComfyUI Storage (Hybrid)

ComfyUI uses a hybrid storage approach for optimal performance:

| PVC | Type | Size | Purpose |
|-----|------|------|---------|
| comfyui-data | Longhorn | 50Gi | App, outputs, custom nodes, cache |
| nfs-ai-models | NFS | Shared | Models only (large files) |

**Why hybrid?** Longhorn provides fast local storage for frequently accessed app data, while NFS stores large model files that can be shared with other AI services.

### ComfyUI Directory Structure

```
/root/ComfyUI/           # Longhorn (comfyui-data)
├── output/              # Generated images
├── input/               # Reference/input images
├── custom_nodes/        # ComfyUI extensions
└── models/              # NFS mount point (nfs-ai-models)
    ├── checkpoints/     # Main model files (SD 1.5, SDXL, Flux)
    ├── loras/           # LoRA models
    ├── vae/             # VAE models
    └── controlnet/      # ControlNet models
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
| Ollama | http://10.10.2.51 (via Open WebUI) |
| ComfyUI | http://10.10.2.52 |
| ComfyUI API | http://10.10.2.52/api |

### ComfyUI API Usage

ComfyUI has a powerful API for programmatic image generation:

```bash
# Queue a workflow
curl -X POST http://10.10.2.52/prompt \
  -H "Content-Type: application/json" \
  -d '{"prompt": {...workflow json...}}'

# Get queue status
curl http://10.10.2.52/queue

# Get history
curl http://10.10.2.52/history
```

## Accessing Ollama

Ollama is exposed via LoadBalancer at `http://10.10.2.50:11434`.

**Note:** Ollama has no built-in authentication. Only expose on trusted networks.

### Client Configuration

#### opencode / Continue / Other Tools

Set Ollama URL to: `http://10.10.2.50:11434`

#### Command Line (curl)

```bash
# List models
curl http://10.10.2.50:11434/api/tags

# Generate completion
curl http://10.10.2.50:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Hello, world!"
}'

# Chat
curl http://10.10.2.50:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

#### Python (ollama library)

```python
import ollama
from ollama import Client

client = Client(host='http://10.10.2.50:11434')
response = client.chat(model='llama3.2', messages=[
    {'role': 'user', 'content': 'Hello!'}
])
print(response['message']['content'])
```

#### Environment Variable

```bash
export OLLAMA_HOST=http://10.10.2.50:11434
```

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
