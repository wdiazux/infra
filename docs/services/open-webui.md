# Open WebUI

User-friendly AI interface with Pipelines, document processing, and SSO.

---

## Overview

Open WebUI provides a ChatGPT-like interface for local LLMs. It connects to Ollama for inference and includes advanced features like Pipelines, document processing (Tika), and image generation (ComfyUI).

| Property | Value |
|----------|-------|
| Namespace | `ai` |
| Chart | `open-webui/open-webui` |
| Chart Version | `10.2.1` |
| URL | `https://chat.home-infra.net` |

---

## Deployment

| Property | Value |
|----------|-------|
| Service Type | ClusterIP |
| Port | `80` (container: `8080`) |
| Access | Gateway API HTTPRoute |
| Storage | 10Gi (Longhorn) |

---

## Features

| Feature | Status | Description |
|---------|--------|-------------|
| Ollama Integration | Enabled | `http://ollama:11434` |
| Pipelines | Enabled | Extensible function framework |
| Tika | Enabled | Document processing (PDF, DOCX, etc.) |
| Redis/Websocket | Enabled | Multi-user real-time support |
| Image Generation | Enabled | ComfyUI integration |
| OIDC SSO | Enabled | Zitadel authentication |

---

## Current Configuration

### Ollama Connection

```yaml
ollamaUrls:
  - http://ollama:11434
```

### Pipelines

Pipelines provide extensibility for custom functions and integrations.

| Setting | Value |
|---------|-------|
| Enabled | `true` |
| Storage | 2Gi (Longhorn) |
| Memory Limit | 1Gi |

### Tika (Document Processing)

Apache Tika enables processing of uploaded documents (PDF, Word, Excel, etc.).

| Setting | Value |
|---------|-------|
| Enabled | `true` |

### Redis/Websocket

Redis enables real-time features and multi-user synchronization.

| Setting | Value |
|---------|-------|
| Enabled | `true` |
| Memory Limit | 128Mi |

### Image Generation (ComfyUI)

| Setting | Value |
|---------|-------|
| Enabled | `true` |
| URL | `http://comfyui:80/` |
| Prompt Generation | Enabled |

### Resources

| Resource | Requests | Limits |
|----------|----------|--------|
| Memory | 256Mi | 2Gi |

---

## Authentication (Zitadel OIDC)

Open WebUI uses Zitadel for single sign-on:

| Setting | Value |
|---------|-------|
| Provider | Zitadel |
| Discovery URL | `https://auth.home-infra.net/.well-known/openid-configuration` |
| Scopes | `openid profile email` |
| Auto Signup | Enabled |
| Merge by Email | Enabled |

OIDC credentials are managed via CronJob-generated secrets (`open-webui-oidc-secrets`).

---

## Environment Variables

### Authentication & Security

| Variable | Description | Default |
|----------|-------------|---------|
| `WEBUI_SECRET_KEY` | **Critical**: Secret key for session management | `t0p-s3cr3t` |
| `WEBUI_AUTH` | Enable/disable authentication | `true` |
| `ENABLE_SIGNUP` | Allow new user registrations | `true` |
| `ENABLE_PASSWORD_AUTH` | Allow password-based login | `true` |
| `JWT_EXPIRES_IN` | Token expiration duration | `4w` |
| `DEFAULT_USER_ROLE` | Default role for new users (`pending`, `user`, `admin`) | `pending` |

### OIDC Configuration

| Variable | Description |
|----------|-------------|
| `ENABLE_OAUTH_SIGNUP` | Allow OAuth registration |
| `OAUTH_PROVIDER_NAME` | Display name for OAuth button |
| `OPENID_PROVIDER_URL` | OIDC discovery endpoint |
| `OAUTH_CLIENT_ID` | OIDC client ID |
| `OAUTH_CLIENT_SECRET` | OIDC client secret |
| `OAUTH_SCOPES` | Requested scopes |
| `OAUTH_MERGE_ACCOUNTS_BY_EMAIL` | Link accounts by email |

### Ollama Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_OLLAMA_API` | Enable Ollama API connectivity | `true` |
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` |
| `OLLAMA_BASE_URLS` | Multiple Ollama instances (semicolon-separated) | - |

### Image Generation

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_IMAGE_GENERATION` | Enable image generation features | `false` |
| `AUTOMATIC1111_BASE_URL` | AUTOMATIC1111 API URL | - |
| `COMFYUI_BASE_URL` | ComfyUI API URL | - |
| `ENABLE_IMAGE_PROMPT_GENERATION` | AI-generated image prompts | `false` |

### General Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `WEBUI_URL` | Full URL where Open WebUI is reachable | `http://localhost:3000` |
| `WEBUI_NAME` | Custom name for the WebUI | `Open WebUI` |
| `PORT` | Application port | `8080` |
| `ENV` | Environment mode (`dev`, `prod`) | `prod` |
| `DATA_DIR` | Data directory | `/app/backend/data` |
| `ENABLE_PERSISTENT_CONFIG` | Database settings override env vars | `true` |

### RAG & Search

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_RAG_WEB_SEARCH` | Enable web search in RAG | `false` |
| `RAG_EMBEDDING_MODEL` | Embedding model for RAG | `sentence-transformers/all-MiniLM-L6-v2` |
| `HF_HUB_OFFLINE` | Run in offline mode (set to `1`) | `0` |

---

## Common Operations

### Access Web UI

```bash
# Via Gateway API
open https://chat.home-infra.net

# Via port-forward (troubleshooting)
kubectl port-forward -n ai svc/open-webui 8080:80
open http://localhost:8080
```

### View Logs

```bash
# Main application
kubectl logs -n ai deployment/open-webui --tail=100

# Pipelines
kubectl logs -n ai deployment/open-webui-pipelines --tail=100

# Tika
kubectl logs -n ai deployment/open-webui-tika --tail=100
```

### Manage Users

```bash
# Access admin panel via web UI
# Settings > Admin > Users
```

---

## Verification

```bash
# Check all Open WebUI pods
kubectl get pods -n ai -l app.kubernetes.io/instance=open-webui

# Check services
kubectl get svc -n ai | grep open-webui

# Test Ollama connectivity from Open WebUI
kubectl exec -n ai deployment/open-webui -- curl -s http://ollama:11434/api/tags

# Check OIDC configuration
kubectl get secret -n ai open-webui-oidc-secrets
```

---

## Troubleshooting

### OIDC Login Fails

```bash
# Check OIDC secrets exist
kubectl get secret -n ai open-webui-oidc-secrets -o yaml

# Verify OIDC discovery is reachable
kubectl exec -n ai deployment/open-webui -- \
  curl -s https://auth.home-infra.net/.well-known/openid-configuration

# Check Open WebUI logs for OAuth errors
kubectl logs -n ai deployment/open-webui | grep -i oauth
```

### Ollama Not Responding

```bash
# Check Ollama service
kubectl get svc -n ai ollama

# Test connectivity
kubectl exec -n ai deployment/open-webui -- curl -s http://ollama:11434/api/version

# Check Ollama pod status
kubectl get pods -n ai -l app.kubernetes.io/name=ollama
```

### Image Generation Not Working

```bash
# Check ComfyUI is running
kubectl get pods -n ai -l app=comfyui

# Test ComfyUI connectivity
kubectl exec -n ai deployment/open-webui -- curl -s http://comfyui:80/

# Verify ENABLE_IMAGE_GENERATION is set
kubectl get deployment -n ai open-webui -o yaml | grep IMAGE_GENERATION
```

### Document Upload Fails

```bash
# Check Tika pod
kubectl get pods -n ai -l app.kubernetes.io/component=tika

# Check Tika logs
kubectl logs -n ai deployment/open-webui-tika --tail=50
```

---

## Secrets

| Secret | Keys | Purpose |
|--------|------|---------|
| `open-webui-secrets` | `WEBUI_SECRET_KEY` | Session encryption (SOPS) |
| `open-webui-oidc-secrets` | `client-id`, `client-secret` | OIDC credentials (CronJob-managed) |

---

## Important Notes

- **Set `WEBUI_SECRET_KEY`** to a secure, persistent value to maintain OAuth sessions across restarts
- Use `ENABLE_PERSISTENT_CONFIG=false` to force reading env vars over database values
- First registered user automatically becomes admin (before OIDC is configured)

---

## Documentation

- [Open WebUI Documentation](https://docs.openwebui.com/)
- [Environment Configuration](https://docs.openwebui.com/getting-started/env-configuration/)
- [Pipelines](https://docs.openwebui.com/features/plugin/pipelines/)
- [GitHub](https://github.com/open-webui/open-webui)

---

**Last Updated:** 2026-01-28
