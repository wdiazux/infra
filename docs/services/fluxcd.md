# FluxCD GitOps

Continuous delivery and GitOps automation.

---

## Overview

FluxCD is bootstrapped **automatically** via Terraform when `enable_fluxcd = true` (default).

**What's Automatic:**
- FluxCD installation
- Git source configuration (Forgejo)
- SOPS Age secret for decryption
- Initial Kustomization

**Configuration:** `terraform/talos/fluxcd.tf`

---

## How It Works

```
Push to Forgejo → FluxCD detects changes → Reconciles cluster state
         ↓
   Encrypted secrets (SOPS) → FluxCD decrypts → Applies to cluster
```

---

## Repository Structure

```
kubernetes/clusters/homelab/
├── flux-system/         # FluxCD components
├── infrastructure/      # Cluster services
│   ├── sources/         # Helm repositories
│   ├── monitoring/      # Prometheus, Grafana
│   └── storage/         # Additional storage classes
└── apps/                # Your applications
    ├── app1/
    └── app2/
```

---

## Common Commands

```bash
# Check all FluxCD resources
flux get all -A

# Check Git source
flux get sources git -A

# Check Kustomizations
flux get kustomizations -A

# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# Suspend/resume
flux suspend kustomization apps
flux resume kustomization apps

# View logs
kubectl logs -n flux-system deployment/source-controller -f
kubectl logs -n flux-system deployment/kustomize-controller -f
```

---

## Adding Applications

### 1. Create Application Manifests

```yaml
# kubernetes/clusters/homelab/apps/myapp/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
# kubernetes/clusters/homelab/apps/myapp/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: nginx:latest
```

### 2. Create Kustomization

```yaml
# kubernetes/clusters/homelab/apps/myapp/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
```

### 3. Push to Forgejo

```bash
git add kubernetes/clusters/homelab/apps/myapp/
git commit -m "Add myapp"
git push origin main
```

FluxCD will automatically detect and deploy.

---

## Secrets with SOPS

### Create Encrypted Secret

```bash
# Create plaintext
kubectl create secret generic myapp-secret \
  --from-literal=api-key=secret123 \
  --dry-run=client -o yaml > secret.yaml

# Encrypt
sops -e secret.yaml > secret.enc.yaml
rm secret.yaml

# Commit encrypted file
git add secret.enc.yaml
git commit -m "Add myapp secret"
git push
```

### Reference in Kustomization

FluxCD automatically decrypts `*.enc.yaml` files using the `sops-age` secret.

---

## Helm Releases

### Add Helm Repository

```yaml
# kubernetes/clusters/homelab/infrastructure/sources/helm-repos.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.bitnami.com/bitnami
```

### Create HelmRelease

```yaml
# kubernetes/clusters/homelab/apps/redis/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: redis
  namespace: redis
spec:
  interval: 30m
  chart:
    spec:
      chart: redis
      version: ">=18.0.0 <19.0.0"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
  values:
    architecture: standalone
    auth:
      password: "changeme"  # Use SOPS encrypted secret instead
```

---

## Webhook (Optional)

FluxCD webhook receiver at **http://10.10.2.15** for push notifications.

### Configure in Forgejo

1. Go to Repository Settings → Webhooks
2. Add webhook:
   - URL: `http://10.10.2.15/hook/<receiver-name>`
   - Content-Type: `application/json`
   - Events: Push

---

## Verification

```bash
# Check FluxCD pods
kubectl get pods -n flux-system

# Check GitRepository
kubectl get gitrepository -n flux-system

# Check all Kustomizations
kubectl get kustomization -n flux-system

# View reconciliation events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

---

## Troubleshooting

### GitRepository Not Ready

```bash
# Check status
kubectl get gitrepository flux-system -n flux-system -o yaml

# Common issues:
# - Authentication failed: Check token secret
# - Connection refused: Check Forgejo is running
# - Not found: Verify repository exists

# View source-controller logs
kubectl logs -n flux-system deployment/source-controller -f
```

### Kustomization Failed

```bash
# Check status
kubectl get kustomization -n flux-system -o yaml

# Common issues:
# - SOPS decryption failed: Check sops-age secret
# - Invalid YAML: Validate manifests locally
# - Dependencies not ready: Check dependsOn resources

# View kustomize-controller logs
kubectl logs -n flux-system deployment/kustomize-controller -f
```

### SOPS Decryption Failed

```bash
# Verify sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Kustomization has decryption configured
kubectl get kustomization flux-system -n flux-system -o yaml | grep -A3 decryption

# Verify Age key matches
sops -d your-secret.enc.yaml  # Test locally
```

### Force Full Reconciliation

```bash
# Suspend and resume
flux suspend kustomization --all -n flux-system
flux resume kustomization --all -n flux-system

# Or delete and recreate source
flux reconcile source git flux-system --with-source
```

---

## Best Practices

1. **Structure repositories** with clear separation (infra vs apps)
2. **Use Kustomizations** for organization
3. **Encrypt all secrets** with SOPS
4. **Pin chart versions** in HelmReleases
5. **Use dependsOn** for ordering
6. **Monitor reconciliation** with `flux get all`

---

## Resources

- [FluxCD Documentation](https://fluxcd.io/)
- [FluxCD SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Flux CLI Reference](https://fluxcd.io/flux/cmd/)

---

**Last Updated:** 2026-01-15
