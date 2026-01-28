# Reflector

Kubernetes secret and ConfigMap synchronization across namespaces.

---

## Overview

Reflector automatically replicates Secrets and ConfigMaps across namespaces. This solves the "one TLS certificate per namespace" problem by syncing wildcard certificates from cert-manager to all application namespaces.

| Property | Value |
|----------|-------|
| Namespace | `kube-system` |
| Chart | `emberstack/reflector` |
| Version | `7.1.288` |

**Key Features:**

| Feature | Description |
|---------|-------------|
| Secret Sync | Replicate secrets across namespaces |
| ConfigMap Sync | Replicate ConfigMaps across namespaces |
| Annotation-based | Configuration via resource annotations |
| Auto-sync | Automatic updates when source changes |

---

## The Problem It Solves

cert-manager creates TLS certificates in its own namespace. Applications in other namespaces need access to these certificates but Kubernetes secrets are namespace-scoped.

**Without Reflector:**
```
cert-manager namespace          app namespace
┌─────────────────────┐         ┌─────────────────────┐
│  wildcard-tls       │    ✗    │  (no access)        │
│  Certificate        │────────▶│                     │
└─────────────────────┘         └─────────────────────┘
```

**With Reflector:**
```
cert-manager namespace          app namespace
┌─────────────────────┐         ┌─────────────────────┐
│  wildcard-tls       │    ✓    │  wildcard-tls       │
│  Certificate        │────────▶│  (synced copy)      │
│  + annotations      │         │                     │
└─────────────────────┘         └─────────────────────┘
```

---

## Configuration

### Source Secret Annotations

Add these annotations to the source secret to enable reflection:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wildcard-tls
  namespace: cert-manager
  annotations:
    # Allow reflection
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"

    # Namespaces allowed to receive reflections
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "ai,media,auth,forgejo"

    # Enable auto-reflection (create without manual trigger)
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"

    # Namespaces to auto-reflect to
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "ai,media,auth,forgejo"
type: kubernetes.io/tls
data:
  tls.crt: ...
  tls.key: ...
```

### Annotation Reference

| Annotation | Description |
|------------|-------------|
| `reflection-allowed` | Enable reflection for this resource (`true`/`false`) |
| `reflection-allowed-namespaces` | Comma-separated list of allowed target namespaces |
| `reflection-auto-enabled` | Automatically create reflections (`true`/`false`) |
| `reflection-auto-namespaces` | Comma-separated list of auto-reflection targets |

---

## Common Use Cases

### TLS Certificate Sync

Sync wildcard certificate from cert-manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-home-infra
  namespace: cert-manager
spec:
  secretName: wildcard-home-infra-tls
  secretTemplate:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "ai,media,auth,forgejo,monitoring"
      reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "ai,media,auth,forgejo,monitoring"
  # ... certificate spec
```

### Registry Credentials Sync

Sync image pull secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: default
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "ai,media,tools"
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ...
```

---

## Common Operations

### View Reflected Secrets

```bash
# List secrets with reflection annotations
kubectl get secrets -A -o json | jq -r '
  .items[] |
  select(.metadata.annotations["reflector.v1.k8s.emberstack.com/reflection-allowed"] == "true") |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Check if secret exists in target namespace
kubectl get secret wildcard-home-infra-tls -n ai
```

### Force Resync

```bash
# Restart Reflector to force resync
kubectl rollout restart deployment/reflector -n kube-system

# Or update source secret to trigger sync
kubectl annotate secret wildcard-home-infra-tls -n cert-manager \
  reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" --overwrite
```

### Add New Target Namespace

```bash
# Update allowed namespaces
kubectl annotate secret wildcard-home-infra-tls -n cert-manager \
  reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces="ai,media,auth,forgejo,new-ns" \
  reflector.v1.k8s.emberstack.com/reflection-auto-namespaces="ai,media,auth,forgejo,new-ns" \
  --overwrite
```

---

## Verification

```bash
# Check Reflector pod
kubectl get pods -n kube-system -l app.kubernetes.io/name=reflector

# View Reflector logs
kubectl logs -n kube-system deployment/reflector --tail=50

# Verify source secret has annotations
kubectl get secret wildcard-home-infra-tls -n cert-manager -o yaml | grep reflector

# Verify reflected secret exists
kubectl get secret wildcard-home-infra-tls -n ai
kubectl get secret wildcard-home-infra-tls -n media

# Compare source and reflected secret data
diff <(kubectl get secret wildcard-home-infra-tls -n cert-manager -o jsonpath='{.data}') \
     <(kubectl get secret wildcard-home-infra-tls -n ai -o jsonpath='{.data}')
```

---

## Troubleshooting

### Secret Not Reflected

```bash
# Check Reflector logs for errors
kubectl logs -n kube-system deployment/reflector --tail=100 | grep -i error

# Verify annotations are correct
kubectl get secret <name> -n <source-ns> -o yaml | grep reflector

# Check target namespace exists
kubectl get namespace <target-ns>

# Restart Reflector
kubectl rollout restart deployment/reflector -n kube-system
```

### Reflected Secret Out of Sync

```bash
# Check source secret update time
kubectl get secret <name> -n <source-ns> -o jsonpath='{.metadata.resourceVersion}'

# Check reflected secret update time
kubectl get secret <name> -n <target-ns> -o jsonpath='{.metadata.resourceVersion}'

# Force update by modifying source
kubectl annotate secret <name> -n <source-ns> updated=$(date +%s)
```

### Namespace Not in Allowed List

```bash
# Check current allowed namespaces
kubectl get secret <name> -n <source-ns> -o jsonpath='{.metadata.annotations.reflector\.v1\.k8s\.emberstack\.com/reflection-allowed-namespaces}'

# Add namespace to allowed list
kubectl annotate secret <name> -n <source-ns> \
  reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces="existing,new" --overwrite
```

---

## Resources

| Resource | Requests | Limits |
|----------|----------|--------|
| CPU | 10m | - |
| Memory | 64Mi | 128Mi |

---

## Security Considerations

- **Principle of Least Privilege**: Only list namespaces that need the secret
- **Sensitive Data**: Reflected secrets contain the same data as source
- **Audit**: Monitor Reflector logs for unexpected reflections
- **Namespace Deletion**: Deleting a namespace removes reflected secrets

---

## Documentation

- [Reflector GitHub](https://github.com/emberstack/kubernetes-reflector)
- [Helm Chart](https://github.com/emberstack/helm-charts/tree/main/charts/reflector)
- [cert-manager Integration](https://cert-manager.io/docs/tutorials/syncing-secrets-across-namespaces/)

---

**Last Updated:** 2026-01-28
