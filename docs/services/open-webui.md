# Open WebUI

User-friendly AI interface supporting Ollama and OpenAI API.

## Image

| Registry | Image | Version |
|----------|-------|---------|
| GitHub Container Registry | `ghcr.io/open-webui/open-webui` | `v0.7.2` |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `ai` |
| IP | `10.10.2.51` |
| Port | `8080` |
| URL | `https://chat.home-infra.net` |

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

### Ollama Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_OLLAMA_API` | Enable Ollama API connectivity | `true` |
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` |
| `OLLAMA_BASE_URLS` | Multiple Ollama instances (semicolon-separated) | - |

### OpenAI Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key | - |
| `OPENAI_API_BASE_URL` | OpenAI-compatible API URL | - |

### Image Generation

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_IMAGE_GENERATION` | Enable image generation features | `false` |
| `AUTOMATIC1111_BASE_URL` | AUTOMATIC1111 API URL | - |
| `COMFYUI_BASE_URL` | ComfyUI API URL | - |

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

## Important Notes

- **Set `WEBUI_SECRET_KEY`** to a secure, persistent value to maintain OAuth sessions across restarts
- Use `ENABLE_PERSISTENT_CONFIG=false` to force reading env vars over database values
- First registered user automatically becomes admin

## Documentation

- [Environment Configuration](https://docs.openwebui.com/getting-started/env-configuration/)
- [GitHub](https://github.com/open-webui/open-webui)
- [Docker Hub](https://hub.docker.com/r/ghcr.io/open-webui/open-webui)
