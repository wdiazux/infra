# Kubernetes Applications

This directory contains application deployments managed by FluxCD with SOPS-encrypted secrets.

## Directory Structure

```
apps/
├── base/                        # Base application definitions
│   ├── <namespace>/             # Namespace folder (e.g., tools, media)
│   │   ├── kustomization.yaml   # Lists services in this namespace
│   │   ├── storage.yaml         # Optional: shared PVCs
│   │   └── <service>/           # Service subfolder
│   │       ├── kustomization.yaml
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── secret.yaml      # SOPS-encrypted (or .enc.yaml)
│   │
│   ├── tools/                   # Developer utilities
│   │   ├── it-tools/
│   │   └── speedtest/
│   ├── misc/                    # Miscellaneous apps
│   │   └── twitch-miner/
│   ├── arr-stack/               # Media acquisition (Sonarr, Radarr, etc.)
│   │   ├── sabnzbd/
│   │   ├── qbittorrent/
│   │   ├── prowlarr/
│   │   ├── radarr/
│   │   ├── sonarr/
│   │   └── bazarr/
│   └── media/                   # Media streaming
│       ├── emby/
│       └── navidrome/
│
└── production/                  # Production overlay
    └── kustomization.yaml       # References namespace folders

# Namespaces are defined in infrastructure/namespaces/
```

## Adding a New Application

### 1. Choose or create a namespace folder

Applications are organized by namespace:
- `tools/` - Developer utilities
- `misc/` - Miscellaneous apps
- `arr-stack/` - Media acquisition
- `media/` - Media streaming

```bash
# Add to existing namespace
mkdir -p kubernetes/apps/base/tools/my-app

# Or create new namespace folder
mkdir -p kubernetes/apps/base/my-namespace/my-app
```

### 2. Add namespace (if new)

If creating a new namespace folder, add it to `infrastructure/namespaces/`:

```yaml
# kubernetes/infrastructure/namespaces/my-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    app.kubernetes.io/name: my-namespace
```

And reference it in `infrastructure/namespaces/kustomization.yaml`.

### 3. Create the service kustomization.yaml

```yaml
# kubernetes/apps/base/<namespace>/my-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - secret.yaml  # SOPS-encrypted
```

### 4. Add to namespace kustomization

```yaml
# kubernetes/apps/base/<namespace>/kustomization.yaml
resources:
  - my-app
```

### 5. Create your Kubernetes manifests

- `deployment.yaml` - Deployment with secret references
- `service.yaml` - Service definition
- `pvc.yaml` - PersistentVolumeClaim (optional)

### 6. Create and encrypt secrets

```bash
# Create plaintext secret (NEVER commit this!)
cat > /tmp/secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secret
type: Opaque
stringData:
  api-key: "actual-api-key"
  database-url: "postgres://user:pass@host:5432/db"
EOF

# Encrypt with SOPS
sops -e /tmp/secret.yaml > kubernetes/apps/base/my-app/secret.enc.yaml

# Delete plaintext immediately!
rm /tmp/secret.yaml
```

### 7. Commit and push

```bash
git add kubernetes/apps/base/<namespace>/my-app/
git commit -m "feat(apps): Add my-app to <namespace>"
git push
```

FluxCD will automatically:
1. Detect the change
2. Decrypt `secret.enc.yaml` using the `sops-age` key
3. Deploy the application

## SOPS Setup (One-Time)

Before FluxCD can decrypt secrets, create the Age key secret:

```bash
cat ~/.config/sops/age/keys.txt | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

## Referencing Secrets in Deployments

```yaml
# In deployment.yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: my-app-secret
        key: api-key
```

Or mount as volume:

```yaml
volumes:
  - name: secrets
    secret:
      secretName: my-app-secret
volumeMounts:
  - name: secrets
    mountPath: /etc/secrets
    readOnly: true
```

## Verifying Encryption

```bash
# View encrypted file (safe)
cat kubernetes/apps/base/my-app/secret.enc.yaml

# Decrypt and view (requires Age key)
sops -d kubernetes/apps/base/my-app/secret.enc.yaml

# Edit encrypted file in place
sops kubernetes/apps/base/my-app/secret.enc.yaml
```

## Troubleshooting

**FluxCD can't decrypt secrets:**
```bash
# Check if sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check FluxCD logs
kubectl logs -n flux-system deploy/kustomize-controller | grep -i sops
```

**Verify SOPS encryption works locally:**
```bash
# This should work if Age key is configured
sops -d kubernetes/apps/base/my-app/secret.enc.yaml
```
