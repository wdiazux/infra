# Open WebUI

User-friendly AI interface supporting Ollama and OpenAI API.

**Image**: `ghcr.io/open-webui/open-webui:v0.7.2`
**Namespace**: `ai`
**IP**: `10.10.2.19`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` |
| `OLLAMA_BASE_URLS` | Multiple Ollama instances (semicolon-separated) | - |
| `OPENAI_API_KEY` | OpenAI API key | - |
| `OPENAI_API_BASE_URL` | OpenAI-compatible API URL | - |
| `WEBUI_SECRET_KEY` | Secret key for session management (persistent recommended) | Auto-generated |
| `WEBUI_AUTH` | Enable/disable authentication | `true` |
| `WEBUI_NAME` | Custom name for the WebUI | `Open WebUI` |
| `DEFAULT_USER_ROLE` | Default role for new users | `pending` |
| `ENABLE_SIGNUP` | Allow new user registrations | `true` |
| `ENABLE_LOGIN_FORM` | Show login form | `true` |
| `ENABLE_IMAGE_GENERATION` | Enable image generation features | `false` |
| `AUTOMATIC1111_BASE_URL` | AUTOMATIC1111 API URL | - |
| `COMFYUI_BASE_URL` | ComfyUI API URL | - |
| `ENABLE_RAG_WEB_SEARCH` | Enable web search in RAG | `false` |
| `RAG_EMBEDDING_MODEL` | Embedding model for RAG | `sentence-transformers/all-MiniLM-L6-v2` |
| `ENABLE_PERSISTENT_CONFIG` | Force reading environment variables | `true` |
| `HF_HUB_OFFLINE` | Run in offline mode (set to `1`) | `0` |
| `DATA_DIR` | Data directory | `/app/backend/data` |

## Important Notes

- Set `WEBUI_SECRET_KEY` to avoid logout after container recreation
- Use `ENABLE_PERSISTENT_CONFIG=False` to force reading env vars over database values

## Documentation

- [Open WebUI Environment Configuration](https://docs.openwebui.com/getting-started/env-configuration/)
- [GitHub](https://github.com/open-webui/open-webui)
