# cert-manager

Automated TLS certificate management with Let's Encrypt and Cloudflare DNS-01 challenge.

---

## Overview

| Component | Description |
|-----------|-------------|
| **cert-manager** | Kubernetes certificate controller |
| **ClusterIssuer** | Let's Encrypt ACME configuration |
| **DNS-01 Challenge** | Cloudflare API for wildcard certificates |
| **Reflector** | Syncs TLS secrets across namespaces |
| **Auto-Renewal** | 30 days before expiry |

### Why cert-manager?

1. **Wildcard certificates** - Single cert covers all subdomains (*.home-infra.net)
2. **Automatic renewal** - No manual intervention needed
3. **DNS-01 challenge** - Works behind NAT/firewall, no port 80 needed
4. **GitOps managed** - Certificates defined as Kubernetes resources

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Certificate Flow with Reflector                                    │
│                                                                     │
│  1. Certificate resource created in cert-manager namespace          │
│  2. cert-manager issues certificate via Let's Encrypt               │
│  3. TLS secret created with reflector annotations                   │
│  4. Reflector automatically copies secret to target namespaces      │
│  5. Ingress in each namespace uses the replicated secret            │
│  6. On renewal, reflector syncs the updated secret everywhere       │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Reflector?

**Problem:** Kubernetes Secrets are namespace-scoped, but we need the same TLS cert in many namespaces.

**Bad approach:** Create identical Certificate in each namespace → hits Let's Encrypt rate limits (5/week per domain set).

**Good approach:** ONE Certificate in cert-manager namespace → Reflector syncs the secret everywhere.

---

## Configuration

### ClusterIssuers

Two ClusterIssuers are configured:

| Issuer | Server | Use Case |
|--------|--------|----------|
| `letsencrypt-staging` | Staging | Testing (avoids rate limits) |
| `letsencrypt-production` | Production | Real certificates |

**Location:** `kubernetes/infrastructure/configs/cluster-issuers.yaml`

### Wildcard Certificates

**Source certificates** (in cert-manager namespace):

| Certificate | Domain | Synced To |
|-------------|--------|-----------|
| wildcard-home-infra-net | *.home-infra.net | All app namespaces |
| wildcard-reynoza-org | *.reynoza.org | media namespace |

**Location:** `kubernetes/infrastructure/configs/wildcard-certificates.yaml`

The TLS secrets are automatically synced by Reflector to:
- media, tools, monitoring, automation, ai, management
- arr-stack, backup, forgejo, auth, flux-system, printing

---

## Verification

### Check cert-manager Pods

```bash
kubectl get pods -n cert-manager
```

Expected: 3 pods running (cert-manager, cainjector, webhook)

### Check Reflector

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=reflector
```

Expected: 1 pod running

### Check ClusterIssuers

```bash
kubectl get clusterissuers
```

Expected: Both issuers show `Ready: True`

### Check Source Certificates

```bash
# Source certificates in cert-manager namespace
kubectl get certificates -n cert-manager
```

Expected: `Ready: True` for both wildcards

### Check Replicated Secrets

```bash
# Verify secrets exist in all app namespaces
kubectl get secrets -A | grep wildcard-home-infra-net-tls
```

Expected: Secret exists in cert-manager + all app namespaces

### Test HTTPS Access

```bash
# Test with curl (after DNS is configured)
curl -v https://music.home-infra.net

# Or test directly via Ingress IP
curl -v --resolve music.home-infra.net:443:10.10.2.20 https://music.home-infra.net
```

---

## Adding New Services

### Step 1: Check if TLS Secret Exists in Namespace

```bash
kubectl get secret wildcard-home-infra-net-tls -n <namespace>
```

If the secret doesn't exist, add the namespace to the reflector sync list in `wildcard-certificates.yaml`:

```yaml
secretTemplate:
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "...,<new-namespace>"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "...,<new-namespace>"
```

### Step 2: Create Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  namespace: <namespace>
  annotations:
    kubernetes.io/ingress.class: cilium
spec:
  tls:
    - hosts:
        - my-service.home-infra.net
      secretName: wildcard-home-infra-net-tls
  rules:
    - host: my-service.home-infra.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

### Step 3: Update DNS

Add entry to ControlD pointing to Ingress IP (10.10.2.20).

---

## Troubleshooting

### Certificate Stuck in "Pending"

```bash
# Check certificate status
kubectl describe certificate wildcard-home-infra-net -n cert-manager

# Check certificate request
kubectl get certificaterequest -n cert-manager

# Check ACME challenges
kubectl get challenges -A
```

### Secret Not Syncing to Namespace

```bash
# Check reflector logs
kubectl logs -n kube-system -l app.kubernetes.io/name=reflector

# Verify source secret has reflector annotations
kubectl get secret wildcard-home-infra-net-tls -n cert-manager -o yaml | grep reflector

# Check if namespace is in the allowed list
kubectl get secret wildcard-home-infra-net-tls -n cert-manager -o jsonpath='{.metadata.annotations}'
```

### DNS-01 Challenge Failing

```bash
# Check Cloudflare API token secret
kubectl get secret cloudflare-api-token -n cert-manager

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager -f

# Verify TXT record was created
dig TXT _acme-challenge.home-infra.net
```

### Ingress Not Using Certificate

```bash
# Check Ingress has correct secretName
kubectl get ingress <name> -n <namespace> -o yaml | grep -A5 tls

# Check secret exists in namespace
kubectl get secret wildcard-home-infra-net-tls -n <namespace>

# Check Cilium Ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium-envoy
```

---

## Rate Limits

Let's Encrypt has rate limits:

| Limit | Value | Period |
|-------|-------|--------|
| Certificates per exact domain set | 5 | Week |
| Failed validations | 5 | Hour |

**Our setup avoids rate limits by:**
- Using ONE source certificate per domain (not one per namespace)
- Reflector syncs the secret instead of issuing duplicate certs
- Using staging issuer for testing

---

## Secrets Management

### Cloudflare API Token

The Cloudflare API token is managed by Terraform:

- **Encrypted file:** `secrets/cloudflare-api-token.enc.yaml`
- **Kubernetes Secret:** Created by Terraform in cert-manager namespace
- **Required permissions:** Zone:DNS:Edit

To rotate the token:

1. Create new token in Cloudflare dashboard
2. Update `secrets/cloudflare-api-token.enc.yaml`
3. Run `terraform apply` in `terraform/talos/`

---

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Reflector](https://github.com/emberstack/kubernetes-reflector)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Cloudflare API Tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [Cilium Ingress Controller](https://docs.cilium.io/en/stable/network/servicemesh/ingress/)

---

**Last Updated:** 2026-01-23
