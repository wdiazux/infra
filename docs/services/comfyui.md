# ComfyUI

Node-based Stable Diffusion image generation interface.

**Image**: `yanwk/comfyui-boot:cu128-slim`
**Namespace**: `ai`
**IP**: `10.10.2.52`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLI_ARGS` | Command-line arguments for ComfyUI | - |
| `NVIDIA_VISIBLE_DEVICES` | GPU devices to expose | `all` |
| `NVIDIA_DRIVER_CAPABILITIES` | Driver capabilities | `compute,utility` |

## Common CLI_ARGS Options

| Argument | Description |
|----------|-------------|
| `--disable-xformers` | Disable xFormers |
| `--use-pytorch-cross-attention` | Use PyTorch cross-attention instead of xFormers |
| `--listen 0.0.0.0` | Listen on all interfaces |
| `--port 8188` | Set the port |
| `--lowvram` | Enable low VRAM mode |
| `--cpu` | Run on CPU only |

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/home/runner` | All data (models, outputs, etc.) |
| `/home/runner/ComfyUI/models` | Model storage |
| `/home/runner/ComfyUI/input` | Input images |
| `/home/runner/ComfyUI/output` | Generated images |

## GPU Configuration

Requires NVIDIA GPU with CUDA support:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

## Documentation

- [ComfyUI-Docker GitHub](https://github.com/YanWenKun/ComfyUI-Docker)
- [Docker Hub](https://hub.docker.com/r/yanwk/comfyui-boot)
