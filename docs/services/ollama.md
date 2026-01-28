# Ollama

Local LLM inference server with NVIDIA GPU acceleration.

---

## Overview

Ollama provides a local API for running large language models. It supports NVIDIA GPU acceleration and integrates with Open WebUI for a ChatGPT-like interface.

| Property | Value |
|----------|-------|
| Namespace | `ai` |
| Chart | `otwld/ollama` |
| Chart Version | `1.39.0` |
| Image | `ollama/ollama:0.15.2` |

---

## Deployment

| Property | Value |
|----------|-------|
| Service Type | LoadBalancer |
| IP | `10.10.2.50` |
| Port | `11434` |
| GPU | NVIDIA RTX 4000 SFF |
| Runtime | `nvidia` |

---

## Current Configuration

### GPU Settings

| Setting | Value |
|---------|-------|
| GPU Enabled | `true` |
| GPU Type | `nvidia` |
| GPU Count | `1` |
| Runtime Class | `nvidia` |

### Performance Tuning

| Setting | Value | Description |
|---------|-------|-------------|
| `OLLAMA_NUM_PARALLEL` | `2` | Parallel request processing |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in memory |
| `OLLAMA_KEEP_ALIVE` | `15m` | Model memory retention |
| `OLLAMA_FLASH_ATTENTION` | `1` | Enable Flash Attention |

### Storage

| Setting | Value |
|---------|-------|
| Mount Path | `/root/.ollama` |
| PVC | `nfs-ai-models` |
| SubPath | `ollama` |

### Resources

| Resource | Requests | Limits |
|----------|----------|--------|
| Memory | 100Mi | 32Gi |

---

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

---

## Common Operations

### Pull Models

```bash
# From within the cluster
kubectl exec -n ai deployment/ollama -- ollama pull llama3.2

# Via API
curl http://10.10.2.50:11434/api/pull -d '{"name": "llama3.2"}'
```

### List Models

```bash
# CLI
kubectl exec -n ai deployment/ollama -- ollama list

# API
curl http://10.10.2.50:11434/api/tags
```

### Run Inference

```bash
# CLI
kubectl exec -n ai deployment/ollama -- ollama run llama3.2 "Hello, world!"

# API
curl http://10.10.2.50:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Hello, world!"
}'
```

### Delete Model

```bash
kubectl exec -n ai deployment/ollama -- ollama rm llama3.2
```

---

## Verification

```bash
# Check pod status
kubectl get pods -n ai -l app.kubernetes.io/name=ollama

# Check GPU allocation
kubectl describe pod -n ai -l app.kubernetes.io/name=ollama | grep -A5 "nvidia.com/gpu"

# Check service
kubectl get svc -n ai ollama

# Test API
curl http://10.10.2.50:11434/api/version
```

---

## Troubleshooting

### GPU Not Available

```bash
# Check NVIDIA device plugin
kubectl get pods -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin

# Check GPU resources on node
kubectl describe node | grep -A5 "nvidia.com/gpu"

# Check Ollama logs for CUDA errors
kubectl logs -n ai deployment/ollama --tail=100 | grep -i cuda
```

### Model Loading Slow

```bash
# Check if model is on NFS (slow) vs local
kubectl exec -n ai deployment/ollama -- df -h /root/.ollama

# Consider increasing OLLAMA_LOAD_TIMEOUT
```

### Out of Memory

```bash
# Check memory usage
kubectl top pod -n ai -l app.kubernetes.io/name=ollama

# Reduce loaded models
# OLLAMA_MAX_LOADED_MODELS=1

# Reduce context length for large models
# OLLAMA_CONTEXT_LENGTH=2048
```

---

## Integration

### Open WebUI

Open WebUI connects to Ollama via internal service:
```
http://ollama:11434
```

### External Access

Direct API access via LoadBalancer:
```
http://10.10.2.50:11434
```

---

## Documentation

- [Ollama Documentation](https://ollama.com/docs)
- [Ollama FAQ](https://docs.ollama.com/faq)
- [API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Model Library](https://ollama.com/library)
- [GitHub](https://github.com/ollama/ollama)

---

**Last Updated:** 2026-01-28
