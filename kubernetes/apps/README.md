# Kubernetes Applications

This directory contains application deployments managed by FluxCD with SOPS-encrypted secrets.

## Directory Structure

```
apps/
├── base/                    # Base application definitions
│   └── <app-name>/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── secret.yaml.template  # Template (DO NOT commit plaintext)
│       └── secret.enc.yaml       # SOPS-encrypted secret (safe to commit)
│
└── production/              # Production overlay
    └── kustomization.yaml   # References base apps
```

## Adding a New Application

### 1. Create the app directory

```bash
mkdir -p kubernetes/apps/base/my-app
```

### 2. Create the kustomization.yaml

```yaml
# kubernetes/apps/base/my-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - secret.enc.yaml  # Encrypted secret
```

### 3. Create your Kubernetes manifests

- `namespace.yaml` - Namespace definition
- `deployment.yaml` - Deployment with secret references
- `service.yaml` - Service definition

### 4. Create and encrypt secrets

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

### 5. Add to production

```yaml
# kubernetes/apps/production/kustomization.yaml
resources:
  - ../base/my-app/
```

### 6. Commit and push

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
