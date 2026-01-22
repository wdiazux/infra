# Forgejo Runner

CI/CD runner for Forgejo Actions (GitHub Actions compatible).

**Image**: `code.forgejo.org/forgejo/runner:11`
**Supporting Image**: `docker:28-dind` (Docker-in-Docker)
**Namespace**: `forgejo`

## Environment Variables

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `CONFIG_FILE` | Runner config file path | `.runner` |
| `FORGEJO_URL` | Forgejo instance URL | - |
| `FORGEJO_TOKEN` | Runner registration token | - |

### Docker Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKER_HOST` | Docker daemon URL | `unix:///var/run/docker.sock` |
| `DOCKER_TLS_VERIFY` | Verify TLS | - |
| `DOCKER_CERT_PATH` | TLS certificate path | - |

### Docker-in-Docker Settings

For DinD setups, pass to job containers:

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKER_HOST` | DinD daemon URL | `tcp://localhost:2376` |
| `DOCKER_TLS_VERIFY` | TLS verification | `1` |
| `DOCKER_CERT_PATH` | Client cert path | `/certs/client` |

## Runner Configuration File (`config.yml`)

```yaml
log:
  level: info

runner:
  # Number of concurrent jobs
  capacity: 1
  # Maximum job execution time
  timeout: 3h
  # Labels to identify this runner
  labels:
    - "ubuntu-latest:docker://node:20-bullseye"
    - "ubuntu-22.04:docker://node:20-bullseye"

container:
  # Network mode (host, bridge, or custom)
  network: ""
  # Enable privileged mode (required for DinD)
  privileged: false
  # Docker host (empty, "automount", or explicit path)
  docker_host: ""
  # Allowed volume mounts
  valid_volumes: []
  # Extra container options
  options: ""

cache:
  # Enable action cache
  enabled: true
  # Cache directory
  dir: ""
  # Cache server host
  host: ""
  # Cache server port
  port: 0
```

## Registration

Register runner with Forgejo:

```bash
forgejo-runner register \
  --instance https://forgejo.example.com \
  --token <registration-token> \
  --name my-runner \
  --labels "ubuntu-latest:docker://node:20-bullseye"
```

## Docker Socket Setup

Mount Docker socket for container job execution:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

## Docker-in-Docker Setup

```yaml
services:
  runner:
    image: code.forgejo.org/forgejo/runner:11
    environment:
      DOCKER_HOST: tcp://docker:2376
      DOCKER_TLS_VERIFY: 1
      DOCKER_CERT_PATH: /certs/client
    volumes:
      - runner-certs:/certs/client:ro
      - runner-data:/data
    depends_on:
      - docker

  docker:
    image: docker:28-dind
    privileged: true
    environment:
      DOCKER_TLS_CERTDIR: /certs
    volumes:
      - runner-certs:/certs
```

## Network Configuration

For custom networks with cache support:

```yaml
container:
  network: docker_default
```

## Required Capabilities

For privileged operations:

```yaml
cap_add:
  - NET_ADMIN
devices:
  - /dev/net/tun:/dev/net/tun
```

## Example Deployment

```yaml
services:
  forgejo-runner:
    image: code.forgejo.org/forgejo/runner:11
    command: daemon
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config.yml:/data/config.yml
      - runner-data:/data
    environment:
      CONFIG_FILE: /data/config.yml
```

## Documentation

- [Forgejo Runner Installation](https://forgejo.org/docs/latest/admin/actions/runner-installation/)
- [Docker Access in Actions](https://forgejo.org/docs/next/admin/actions/docker-access/)
- [Configuration Cheat Sheet](https://forgejo.org/docs/next/admin/config-cheat-sheet/)
