# cert-manager

Automated TLS certificate management with Let's Encrypt and Cloudflare DNS-01 challenge.

---

## Overview

| Component | Description |
|-----------|-------------|
| **cert-manager** | Kubernetes certificate controller |
| **ClusterIssuer** | Let's Encrypt ACME configuration |
| **DNS-01 Challenge** | Cloudflare API for wildcard certificates |
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
│  Certificate Request Flow                                           │
│                                                                     │
│  1. Certificate resource created in namespace                       │
│  2. cert-manager detects new Certificate                           │
│  3. cert-manager creates ACME order with Let's Encrypt             │
│  4. Let's Encrypt requests DNS-01 challenge                        │
│  5. cert-manager creates TXT record via Cloudflare API             │
│  6. Let's Encrypt verifies TXT record                              │
│  7. Certificate issued and stored as Kubernetes Secret             │
│  8. Ingress uses Secret for TLS termination                        │
└─────────────────────────────────────────────────────────────────────┘
```

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

Certificates are created **per namespace** (Kubernetes Secrets are namespace-scoped).

| Namespace | Certificate | Domain |
|-----------|-------------|--------|
| media | wildcard-home-infra-net | *.home-infra.net |
| media | wildcard-reynoza-org | *.reynoza.org |
| tools | wildcard-home-infra-net | *.home-infra.net |
| monitoring | wildcard-home-infra-net | *.home-infra.net |
| automation | wildcard-home-infra-net | *.home-infra.net |
| ai | wildcard-home-infra-net | *.home-infra.net |
| management | wildcard-home-infra-net | *.home-infra.net |
| arr-stack | wildcard-home-infra-net | *.home-infra.net |
| backup | wildcard-home-infra-net | *.home-infra.net |
| forgejo | wildcard-home-infra-net | *.home-infra.net |
| auth | wildcard-home-infra-net | *.home-infra.net |
| flux-system | wildcard-home-infra-net | *.home-infra.net |
| printing | wildcard-home-infra-net | *.home-infra.net |

**Location:** `kubernetes/infrastructure/configs/wildcard-certificates.yaml`

---

## Verification

### Check cert-manager Pods

```bash
kubectl get pods -n cert-manager
```

Expected: 3 pods running (cert-manager, cainjector, webhook)

### Check ClusterIssuers

```bash
kubectl get clusterissuers
```

Expected: Both issuers show `Ready: True`

### Check Certificates

```bash
# List all certificates
kubectl get certificates -A

# Check specific certificate details
kubectl describe certificate wildcard-home-infra-net -n media
```

Expected: `Ready: True`, valid dates shown

### Check Certificate Secrets

```bash
# List TLS secrets
kubectl get secrets -A | grep tls

# Verify certificate content
kubectl get secret wildcard-home-infra-net-tls -n media -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | head -20
```

### Test HTTPS Access

```bash
# Test with curl (after DNS is configured)
curl -v https://music.home-infra.net

# Or test directly via Ingress IP
curl -v --resolve music.home-infra.net:443:10.10.2.20 https://music.home-infra.net
```

---

## Adding New Services

### Step 1: Check if Certificate Exists in Namespace

```bash
kubectl get certificates -n <namespace>
```

If no certificate exists, add one to `wildcard-certificates.yaml`:

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-home-infra-net
  namespace: <namespace>
spec:
  secretName: wildcard-home-infra-net-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.home-infra.net"
  dnsNames:
    - "home-infra.net"
    - "*.home-infra.net"
  renewBefore: 720h
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
kubectl describe certificate <name> -n <namespace>

# Check certificate request
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>

# Check ACME challenges
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
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

### Certificate Not Renewing

```bash
# Check renewal time
kubectl get certificates -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter,RENEWAL:.status.renewalTime'

# Force renewal (delete and recreate)
kubectl delete certificate <name> -n <namespace>
# Certificate will be recreated by FluxCD
```

### Ingress Not Using Certificate

```bash
# Check Ingress has correct secretName
kubectl get ingress <name> -n <namespace> -o yaml | grep -A5 tls

# Check secret exists in same namespace
kubectl get secret wildcard-home-infra-net-tls -n <namespace>

# Check Cilium Ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium-envoy
```

---

## Rate Limits

Let's Encrypt has rate limits:

| Limit | Value | Period |
|-------|-------|--------|
| Certificates per domain | 50 | Week |
| Failed validations | 5 | Hour |
| Duplicate certificates | 5 | Week |

**Best practices:**
- Use staging issuer for testing
- Wildcard certificates reduce certificate count
- Don't delete/recreate certificates unnecessarily

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
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Cloudflare API Tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [Cilium Ingress Controller](https://docs.cilium.io/en/stable/network/servicemesh/ingress/)

---

**Last Updated:** 2026-01-23
