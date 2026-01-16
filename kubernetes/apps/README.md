# Kubernetes Applications

This directory contains application deployments managed by FluxCD with SOPS-encrypted secrets.

## Directory Structure

```
apps/
├── base/                    # Base application definitions
│   └── <app-name>/
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── pvc.yaml              # Optional: persistent storage
│       ├── secret.yaml.template  # Template (DO NOT commit plaintext)
│       └── secret.enc.yaml       # SOPS-encrypted secret (safe to commit)
│
└── production/              # Production overlay
    └── kustomization.yaml   # References base apps

# Namespaces are defined in infrastructure/namespaces/ (not per-app)
```

## Adding a New Application

### 1. Create the app directory

```bash
mkdir -p kubernetes/apps/base/my-app
```

### 2. Add namespace (if new)

If your app needs a new namespace, add it to `infrastructure/namespaces/`:

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

### 3. Create the kustomization.yaml

```yaml
# kubernetes/apps/base/my-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-namespace  # Must exist in infrastructure/namespaces/

resources:
  - deployment.yaml
  - service.yaml
  - secret.enc.yaml  # Encrypted secret
```

### 4. Create your Kubernetes manifests

- `deployment.yaml` - Deployment with secret references
- `service.yaml` - Service definition
- `pvc.yaml` - PersistentVolumeClaim (optional)

### 5. Create and encrypt secrets

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

### 6. Add to production

```yaml
# kubernetes/apps/production/kustomization.yaml
resources:
  - ../base/my-app/
```

### 7. Commit and push

```bash
git add kubernetes/apps/base/my-app/
git commit -m "feat(apps): Add my-app deployment"
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
