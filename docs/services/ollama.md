# Ollama

Local LLM inference server.

## Image

| Registry | Image | Version |
|----------|-------|---------|
| Docker Hub | `ollama/ollama` | `0.14.2` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `ai` |
| IP | `10.10.2.50` |
| Port | `11434` |

## Environment Variables

### Core Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_HOST` | Bind address and port | `127.0.0.1:11434` |
| `OLLAMA_MODELS` | Directory for model storage | `/root/.ollama/models` |
| `OLLAMA_ORIGINS` | Allowed CORS origins (comma-separated) | `127.0.0.1,0.0.0.0` |
| `OLLAMA_DEBUG` | Enable debug logging | `false` |

### Performance & Memory

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_KEEP_ALIVE` | Time to keep models loaded in memory | `5m` |
| `OLLAMA_LOAD_TIMEOUT` | Timeout for loading models | `5m` |
| `OLLAMA_NUM_PARALLEL` | Number of parallel requests to process | `1` |
| `OLLAMA_MAX_LOADED_MODELS` | Maximum number of models to load simultaneously | `1` |
| `OLLAMA_MAX_QUEUE` | Maximum number of requests to queue | `512` |
| `OLLAMA_CONTEXT_LENGTH` | Default context window size | `4096` |
| `OLLAMA_FLASH_ATTENTION` | Enable Flash Attention (set to `1`) | `0` |
| `OLLAMA_KV_CACHE_TYPE` | K/V cache quantization type (`f16`, `q8_0`, `q4_0`) | `f16` |
| `OLLAMA_MULTIUSER_CACHE` | Optimize KV cache for multi-user scenarios | `false` |

### GPU Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_SCHED_SPREAD` | Spread load across multiple GPUs | `false` |
| `OLLAMA_VULKAN` | Enable Vulkan GPU support (experimental) | `0` |
| `CUDA_VISIBLE_DEVICES` | Specify which GPUs to use | all |

### Network & Proxy

| Variable | Description | Default |
|----------|-------------|---------|
| `HTTPS_PROXY` | HTTPS proxy URL for model downloads | - |
| `HTTP_PROXY` | HTTP proxy URL | - |
| `NO_PROXY` | Hosts to bypass proxy | - |

## GPU Support

For NVIDIA GPU support in Kubernetes:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

## Documentation

- [Ollama FAQ](https://docs.ollama.com/faq)
- [Docker Hub](https://hub.docker.com/r/ollama/ollama)
- [GitHub](https://github.com/ollama/ollama)
