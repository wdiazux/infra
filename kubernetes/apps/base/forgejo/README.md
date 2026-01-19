# Forgejo Applications

Additional components for Forgejo Git server.

## Components

| Component | Description |
|-----------|-------------|
| runner/ | Forgejo Actions runner for CI/CD workflows |

## Prerequisites

Forgejo server must be deployed first via Terraform:
```bash
cd terraform/talos
terraform apply  # With enable_forgejo=true
```

## Forgejo Runner Setup

### 1. Enable Actions in Forgejo

Actions is enabled by default in `kubernetes/infrastructure/values/forgejo-values.yaml`:
```yaml
gitea:
  config:
    actions:
      ENABLED: true
```

### 2. Get Runner Registration Token

1. Access Forgejo at http://10.10.2.13
2. Go to **Site Administration** > **Actions** > **Runners**
3. Click **Create new Runner**
4. Copy the registration token

### 3. Create Runner Secret

```bash
# Create plaintext secret
cat > /tmp/forgejo-runner-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-runner-secret
  namespace: forgejo
type: Opaque
stringData:
  FORGEJO_INSTANCE: "http://forgejo-http.forgejo.svc.cluster.local"
  FORGEJO_RUNNER_TOKEN: "YOUR_TOKEN_HERE"
EOF

# Encrypt with SOPS
sops -e /tmp/forgejo-runner-secret.yaml > kubernetes/apps/base/forgejo/runner/secret.enc.yaml

# Remove plaintext
rm /tmp/forgejo-runner-secret.yaml

# Update kustomization to use encrypted secret
# Edit runner/kustomization.yaml: change secret.yaml to secret.enc.yaml
```

### 4. Deploy Runner

If using FluxCD:
```bash
git add kubernetes/apps/base/forgejo/
git commit -m "feat(forgejo): Add Actions runner"
git push

# Force reconciliation
flux reconcile kustomization apps
```

Manual deployment:
```bash
kubectl apply -k kubernetes/apps/base/forgejo/runner/
```

### 5. Verify Runner

```bash
# Check runner pod
kubectl get pods -n forgejo -l app.kubernetes.io/name=forgejo-runner

# View runner logs
kubectl logs -n forgejo -l app.kubernetes.io/name=forgejo-runner -c runner

# Check DinD sidecar
kubectl logs -n forgejo -l app.kubernetes.io/name=forgejo-runner -c docker-dind

# Verify in Forgejo UI
# Site Administration > Actions > Runners should show runner as "Online"
```

## Writing Workflows

Create workflow files in your repository at `.forgejo/workflows/`:

```yaml
# .forgejo/workflows/build.yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: echo "Hello from Forgejo Actions!"
```

### Available Runner Labels

| Label | Image | Use Case |
|-------|-------|----------|
| `ubuntu-latest` | node:20-bookworm | Node.js, general purpose |
| `ubuntu-22.04` | ubuntu:22.04 | Ubuntu-specific workflows |
| `docker` | docker:28-cli | Docker build/push |

### Using Docker in Workflows

```yaml
jobs:
  build:
    runs-on: docker
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t myapp:latest .
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Forgejo Runner Pod                                          │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│ │ Init: register  │  │ Runner          │  │ DinD Sidecar │ │
│ │ (one-time)      │──│ (fetches jobs)  │──│ (Docker API) │ │
│ └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                              │                    │         │
│                              └────────────────────┘         │
│                              /var/run/docker.sock           │
└─────────────────────────────────────────────────────────────┘
         │
         │ Polls for jobs
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Forgejo Server (10.10.2.13)                                 │
│ - Stores workflow definitions                                │
│ - Queues jobs                                                │
│ - Displays results                                           │
└─────────────────────────────────────────────────────────────┘
```

## Resources

- **CPU**: 0.5-3 cores (runner + DinD)
- **Memory**: 768Mi - 5Gi (depends on job complexity)
- **Storage**: 20Gi ephemeral (Docker layers, not persistent)

## Troubleshooting

### Runner not appearing in Forgejo UI

```bash
# Check init container logs for registration errors
kubectl logs -n forgejo deploy/forgejo-runner -c register

# Common issues:
# - Wrong token (regenerate in Forgejo UI)
# - Forgejo not ready (check forgejo pod health)
# - Network issues (check service DNS resolution)
```

### Jobs stuck in pending

```bash
# Check runner is connected
kubectl logs -n forgejo deploy/forgejo-runner -c runner | grep -i connected

# Verify labels match workflow runs-on
kubectl get configmap forgejo-runner-config -n forgejo -o yaml
```

### Docker build failures

```bash
# Check DinD sidecar is running
kubectl logs -n forgejo deploy/forgejo-runner -c docker-dind

# Verify Docker socket is available
kubectl exec -n forgejo deploy/forgejo-runner -c runner -- ls -la /var/run/docker.sock
```
