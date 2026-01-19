# Custom Obico ML API with CUDA 12

Custom build of the Obico ML API with CUDA 12.4 support for compatibility with modern NVIDIA drivers.

## Why Custom Image?

The default `gabe565/obico/ml-api` image uses CUDA 11.4.3 which is incompatible with newer NVIDIA drivers (12.x). This causes `CUDA_ERROR_INVALID_DEVICE` errors on systems with CUDA 12+ drivers.

This custom image rebuilds the ML API with:
- CUDA 12.4 runtime and cuDNN
- Ubuntu 22.04 base
- Recompiled Darknet libraries with GPU support
- ONNX Runtime GPU for inference

## Building

### Prerequisites

- Docker or Podman with buildx support
- ~10GB disk space for build
- Internet access for downloading dependencies

### Build Commands

```bash
# Make build script executable
chmod +x build.sh

# Build image
./build.sh

# Build and push to registry
./build.sh --push

# Build and push with :latest tag
./build.sh --push --latest
```

### Manual Build

```bash
docker build -t ghcr.io/wdiazux/obico-ml-api:cuda12 .
docker push ghcr.io/wdiazux/obico-ml-api:cuda12
```

## Usage in Kubernetes

Update the deployment to use the custom image:

```yaml
spec:
  containers:
    - name: ml-api
      image: ghcr.io/wdiazux/obico-ml-api:cuda12
      env:
        - name: HAS_GPU
          value: "True"
        - name: NVIDIA_VISIBLE_DEVICES
          value: "all"
      resources:
        limits:
          nvidia.com/gpu: "1"
```

## Testing

```bash
# Test GPU detection
docker run --rm --gpus all ghcr.io/wdiazux/obico-ml-api:cuda12 \
    python3 -c "import torch; print(torch.cuda.is_available())"

# Test health endpoint
docker run -d -p 3333:3333 --gpus all ghcr.io/wdiazux/obico-ml-api:cuda12
curl http://localhost:3333/hc/
```

## Image Tags

| Tag | CUDA Version | Description |
|-----|--------------|-------------|
| `cuda12` | 12.4.1 | CUDA 12 with cuDNN |
| `latest` | 12.4.1 | Same as cuda12 |

## Troubleshooting

### CUDA Error on Startup

If you still see CUDA errors, verify:
1. NVIDIA Container Toolkit is installed
2. GPU time-slicing is configured (if sharing GPU)
3. RuntimeClass is set to `nvidia`

### CPU Fallback

To run in CPU-only mode:

```yaml
env:
  - name: HAS_GPU
    value: "False"
  - name: CUDA_VISIBLE_DEVICES
    value: ""
```

## Source

Based on [TheSpaghettiDetective/obico-server](https://github.com/TheSpaghettiDetective/obico-server) ML API.
