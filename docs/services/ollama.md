# Ollama

Local LLM inference server.

**Image**: `ollama/ollama:0.14.2`
**Namespace**: `ai`
**IP**: `10.10.2.50`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_HOST` | Bind address and port | `127.0.0.1:11434` |
| `OLLAMA_MODELS` | Directory for model storage | `/root/.ollama/models` |
| `OLLAMA_KEEP_ALIVE` | Time to keep models loaded in memory | `5m` |
| `OLLAMA_NUM_PARALLEL` | Number of parallel requests to process | `1` |
| `OLLAMA_MAX_LOADED_MODELS` | Maximum number of models to load simultaneously | `1` |
| `OLLAMA_MAX_QUEUE` | Maximum number of requests to queue | `512` |
| `OLLAMA_FLASH_ATTENTION` | Enable Flash Attention (set to `1`) | `0` |
| `OLLAMA_KV_CACHE_TYPE` | K/V cache quantization type | `f16` |
| `OLLAMA_ORIGINS` | Allowed CORS origins | `localhost` |
| `OLLAMA_DEBUG` | Enable debug logging | `false` |
| `OLLAMA_VULKAN` | Enable Vulkan GPU support (experimental) | `0` |
| `OLLAMA_SCHED_SPREAD` | Spread load across GPUs | `false` |
| `OLLAMA_MULTIUSER_CACHE` | Optimize KV cache for multi-user scenarios | `false` |
| `HTTPS_PROXY` | HTTPS proxy URL | - |
| `NO_PROXY` | Hosts to bypass proxy | - |

## GPU Configuration

For NVIDIA GPU support:
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

- [Ollama FAQ](https://docs.ollama.com/faq)
- [Docker Hub](https://hub.docker.com/r/ollama/ollama)
