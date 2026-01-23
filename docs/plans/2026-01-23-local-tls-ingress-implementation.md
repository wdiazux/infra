# Local TLS Ingress Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable local HTTPS access to services using wildcard certificates for all domains, with the same URLs working both locally (via ControlD) and externally (via Pangolin).

**Architecture:** Deploy cert-manager with Cloudflare DNS-01 challenge to obtain wildcard certificates for all 4 domains. Use Cilium's built-in Ingress Controller for TLS termination. Services remain on LoadBalancer IPs but Ingress provides HTTPS frontend with same domain names used by Pangolin.

**Tech Stack:** cert-manager, Cloudflare DNS-01, Cilium Ingress Controller, Let's Encrypt

---

## Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Local Access (via ControlD)                                        │
│  https://photos.reynoza.org    → Ingress (10.10.2.38) → Immich     │
│  https://music.home-infra.net  → Ingress (10.10.2.38) → Navidrome  │
│                                                                     │
│  Remote Access (via Cloudflare → Pangolin)                         │
│  https://photos.reynoza.org    → Pangolin VPS → Immich             │
│  https://music.home-infra.net  → Pangolin VPS → Navidrome          │
└─────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Cloudflare account with all 4 domains
- Cloudflare API token with DNS edit permissions
- SOPS/Age encryption configured

---

## Task 1: Create Cloudflare API Token

**Files:**
- Create: `secrets/cloudflare-api-token.enc.yaml`

**Step 1: Generate Cloudflare API Token**

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Configure:
   - Permissions: Zone → DNS → Edit
   - Zone Resources: Include → All zones (or select specific zones)
5. Create token and copy it

**Step 2: Create encrypted secret file**

```bash
cat > /tmp/cloudflare-api-token.yaml << 'EOF'
cloudflare_api_token: "YOUR_TOKEN_HERE"
EOF

sops -e /tmp/cloudflare-api-token.yaml > secrets/cloudflare-api-token.enc.yaml
rm /tmp/cloudflare-api-token.yaml
```

**Step 3: Verify encryption**

```bash
sops -d secrets/cloudflare-api-token.enc.yaml
```

Expected: Shows decrypted token

**Step 4: Commit**

```bash
git add secrets/cloudflare-api-token.enc.yaml
git commit -m "feat: add Cloudflare API token for cert-manager DNS-01"
```

---

## Task 2: Add cert-manager Namespace

**Files:**
- Modify: `kubernetes/infrastructure/namespaces/kustomization.yaml`
- Create: `kubernetes/infrastructure/namespaces/cert-manager.yaml`

**Step 1: Create namespace manifest**

Create `kubernetes/infrastructure/namespaces/cert-manager.yaml`:

```yaml
# cert-manager Namespace
#
# Namespace for certificate management components.
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    app.kubernetes.io/name: cert-manager
```

**Step 2: Add to kustomization**

Add to `kubernetes/infrastructure/namespaces/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - cert-manager.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/namespaces/cert-manager.yaml kubernetes/infrastructure/namespaces/kustomization.yaml
git commit -m "feat: add cert-manager namespace"
```

---

## Task 3: Add cert-manager HelmRepository

**Files:**
- Modify: `kubernetes/infrastructure/controllers/helm-repositories.yaml`

**Step 1: Add Jetstack Helm repository**

Add to `kubernetes/infrastructure/controllers/helm-repositories.yaml`:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: jetstack
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.jetstack.io
```

**Step 2: Commit**

```bash
git add kubernetes/infrastructure/controllers/helm-repositories.yaml
git commit -m "feat: add Jetstack Helm repository for cert-manager"
```

---

## Task 4: Create Cloudflare API Token Secret for Kubernetes

**Files:**
- Create: `kubernetes/infrastructure/configs/cloudflare-api-token-secret.yaml`
- Modify: `kubernetes/infrastructure/configs/kustomization.yaml`

**Step 1: Create secret manifest with SOPS**

Create `kubernetes/infrastructure/configs/cloudflare-api-token-secret.yaml`:

```yaml
# Cloudflare API Token Secret for cert-manager
#
# Used by cert-manager ClusterIssuer for DNS-01 challenge.
# Token must have Zone:DNS:Edit permissions.
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
type: Opaque
stringData:
  api-token: "${CLOUDFLARE_API_TOKEN}"
```

**Step 2: Add to kustomization with SOPS substitution**

The secret will be populated via FluxCD's SOPS decryption. We need to create a SOPS-encrypted secret that FluxCD will decrypt.

Actually, let's use a different approach - create the secret directly with SOPS encryption:

Create `kubernetes/infrastructure/configs/cloudflare-api-token-secret.sops.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
type: Opaque
stringData:
  api-token: YOUR_CLOUDFLARE_TOKEN_HERE
```

Then encrypt it:

```bash
sops -e kubernetes/infrastructure/configs/cloudflare-api-token-secret.yaml > kubernetes/infrastructure/configs/cloudflare-api-token-secret.sops.yaml
rm kubernetes/infrastructure/configs/cloudflare-api-token-secret.yaml
```

**Step 3: Update kustomization**

Add to `kubernetes/infrastructure/configs/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - cloudflare-api-token-secret.sops.yaml
```

**Step 4: Commit**

```bash
git add kubernetes/infrastructure/configs/cloudflare-api-token-secret.sops.yaml kubernetes/infrastructure/configs/kustomization.yaml
git commit -m "feat: add Cloudflare API token secret for cert-manager"
```

---

## Task 5: Deploy cert-manager HelmRelease

**Files:**
- Create: `kubernetes/infrastructure/controllers/cert-manager.yaml`
- Modify: `kubernetes/infrastructure/controllers/kustomization.yaml`

**Step 1: Create cert-manager HelmRelease**

Create `kubernetes/infrastructure/controllers/cert-manager.yaml`:

```yaml
# cert-manager HelmRelease
#
# Manages TLS certificates via Let's Encrypt with Cloudflare DNS-01 challenge.
# Enables wildcard certificates for all domains.
#
# Docs: https://cert-manager.io/docs/
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 30m
  timeout: 10m
  chart:
    spec:
      chart: cert-manager
      version: "1.17.2"
      sourceRef:
        kind: HelmRepository
        name: jetstack
        namespace: flux-system
      interval: 12h
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    cleanupOnFail: true
    remediation:
      retries: 3
  values:
    # Install CRDs
    crds:
      enabled: true
    # Resource limits (homelab-friendly)
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 128Mi
    # Webhook resources
    webhook:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 128Mi
    # CA Injector resources
    cainjector:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 128Mi
    # Prometheus metrics
    prometheus:
      enabled: true
      servicemonitor:
        enabled: false
```

**Step 2: Add to kustomization**

Add to `kubernetes/infrastructure/controllers/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - cert-manager.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/controllers/cert-manager.yaml kubernetes/infrastructure/controllers/kustomization.yaml
git commit -m "feat: add cert-manager HelmRelease"
```

---

## Task 6: Create ClusterIssuer for Let's Encrypt

**Files:**
- Create: `kubernetes/infrastructure/configs/cluster-issuers.yaml`
- Modify: `kubernetes/infrastructure/configs/kustomization.yaml`

**Step 1: Create ClusterIssuer manifest**

Create `kubernetes/infrastructure/configs/cluster-issuers.yaml`:

```yaml
# ClusterIssuers for Let's Encrypt
#
# Uses Cloudflare DNS-01 challenge for wildcard certificate support.
# Two issuers: staging (for testing) and production.
#
# Usage in Certificate:
#   issuerRef:
#     name: letsencrypt-production
#     kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # Staging server (use for testing to avoid rate limits)
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: wdiaz@reynoza.org
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    # Production server
    server: https://acme-v02.api.letsencrypt.org/directory
    email: wdiaz@reynoza.org
    privateKeySecretRef:
      name: letsencrypt-production-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

**Step 2: Add to kustomization**

Add to `kubernetes/infrastructure/configs/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - cluster-issuers.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/configs/cluster-issuers.yaml kubernetes/infrastructure/configs/kustomization.yaml
git commit -m "feat: add Let's Encrypt ClusterIssuers with Cloudflare DNS-01"
```

---

## Task 7: Create Wildcard Certificates

**Files:**
- Create: `kubernetes/infrastructure/configs/wildcard-certificates.yaml`
- Modify: `kubernetes/infrastructure/configs/kustomization.yaml`

**Step 1: Create Certificate resources**

Create `kubernetes/infrastructure/configs/wildcard-certificates.yaml`:

```yaml
# Wildcard Certificates for all domains
#
# These certificates are requested from Let's Encrypt using DNS-01 challenge.
# cert-manager will automatically renew them before expiry.
#
# Certificates are stored in secrets in the cert-manager namespace.
# They can be referenced by Ingress resources in any namespace.
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-home-infra-net
  namespace: cert-manager
spec:
  secretName: wildcard-home-infra-net-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.home-infra.net"
  dnsNames:
    - "home-infra.net"
    - "*.home-infra.net"
  # Auto-renewal 30 days before expiry
  renewBefore: 720h
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-reynoza-org
  namespace: cert-manager
spec:
  secretName: wildcard-reynoza-org-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.reynoza.org"
  dnsNames:
    - "reynoza.org"
    - "*.reynoza.org"
  renewBefore: 720h
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-wdiaz-org
  namespace: cert-manager
spec:
  secretName: wildcard-wdiaz-org-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.wdiaz.org"
  dnsNames:
    - "wdiaz.org"
    - "*.wdiaz.org"
  renewBefore: 720h
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-unix-red
  namespace: cert-manager
spec:
  secretName: wildcard-unix-red-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.unix.red"
  dnsNames:
    - "unix.red"
    - "*.unix.red"
  renewBefore: 720h
```

**Step 2: Add to kustomization**

Add to `kubernetes/infrastructure/configs/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - wildcard-certificates.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/configs/wildcard-certificates.yaml kubernetes/infrastructure/configs/kustomization.yaml
git commit -m "feat: add wildcard certificates for all domains"
```

---

## Task 8: Enable Cilium Ingress Controller

**Files:**
- Modify: `kubernetes/infrastructure/controllers/cilium.yaml`
- Modify: `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`

**Step 1: Add Ingress IP to cluster-vars**

Add to `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`:

```yaml
data:
  # ... existing IPs ...

  # Service IPs - Ingress
  IP_INGRESS: "10.10.2.38"
```

**Step 2: Enable Cilium Ingress Controller**

Add to the `values` section in `kubernetes/infrastructure/controllers/cilium.yaml`:

```yaml
  values:
    # ... existing values ...

    # Ingress Controller
    ingressController:
      enabled: true
      default: true
      loadbalancerMode: shared
      service:
        type: LoadBalancer
        annotations:
          io.cilium/lb-ipam-ips: "${IP_INGRESS}"
```

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/controllers/cilium.yaml kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
git commit -m "feat: enable Cilium Ingress Controller with LoadBalancer IP"
```

---

## Task 9: Update Terraform Cilium Config (Bootstrap)

**Files:**
- Modify: `terraform/talos/cilium-inline.tf`
- Modify: `terraform/talos/variables.tf`

**Step 1: Add ingress variable**

Add to `terraform/talos/variables.tf`:

```hcl
variable "ingress_controller_ip" {
  description = "LoadBalancer IP for Cilium Ingress Controller"
  type        = string
  default     = "10.10.2.38"
}
```

**Step 2: Enable Ingress in Cilium inline config**

Add to the `values` in `terraform/talos/cilium-inline.tf` (inside the `yamlencode` block):

```hcl
    # Ingress Controller
    ingressController = {
      enabled          = true
      default          = true
      loadbalancerMode = "shared"
      service = {
        type = "LoadBalancer"
        annotations = {
          "io.cilium/lb-ipam-ips" = var.ingress_controller_ip
        }
      }
    }
```

**Step 3: Commit**

```bash
git add terraform/talos/cilium-inline.tf terraform/talos/variables.tf
git commit -m "feat: enable Cilium Ingress Controller in Terraform bootstrap"
```

---

## Task 10: Create Sample Ingress for Navidrome

**Files:**
- Create: `kubernetes/apps/base/media/navidrome/ingress.yaml`
- Modify: `kubernetes/apps/base/media/navidrome/kustomization.yaml`

**Step 1: Create Ingress manifest**

Create `kubernetes/apps/base/media/navidrome/ingress.yaml`:

```yaml
# Navidrome Ingress
#
# Provides HTTPS access via music.home-infra.net
# Uses wildcard certificate from cert-manager.
#
# Local access: ControlD resolves to Ingress IP (10.10.2.38)
# Remote access: Pangolin handles separately
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: navidrome
  namespace: media
  labels:
    app.kubernetes.io/name: navidrome
    app.kubernetes.io/part-of: media
  annotations:
    # Use Cilium Ingress Controller
    kubernetes.io/ingress.class: cilium
spec:
  tls:
    - hosts:
        - music.home-infra.net
      secretName: wildcard-home-infra-net-tls
  rules:
    - host: music.home-infra.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: navidrome
                port:
                  number: 80
```

**Step 2: Add to kustomization**

Add to `kubernetes/apps/base/media/navidrome/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - ingress.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/apps/base/media/navidrome/ingress.yaml kubernetes/apps/base/media/navidrome/kustomization.yaml
git commit -m "feat: add Ingress for Navidrome with TLS"
```

---

## Task 11: Create Sample Ingress for Immich

**Files:**
- Create: `kubernetes/apps/base/media/immich/ingress.yaml`
- Modify: `kubernetes/apps/base/media/immich/kustomization.yaml`

**Step 1: Create Ingress manifest**

Create `kubernetes/apps/base/media/immich/ingress.yaml`:

```yaml
# Immich Ingress
#
# Provides HTTPS access via photos.reynoza.org
# Uses wildcard certificate from cert-manager.
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: immich
  namespace: media
  labels:
    app.kubernetes.io/name: immich
    app.kubernetes.io/part-of: media
  annotations:
    kubernetes.io/ingress.class: cilium
    # Increase body size for photo uploads
    ingress.cilium.io/proxy-body-size: "0"
spec:
  tls:
    - hosts:
        - photos.reynoza.org
      secretName: wildcard-reynoza-org-tls
  rules:
    - host: photos.reynoza.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: immich
                port:
                  number: 80
```

**Step 2: Add to kustomization**

Add to `kubernetes/apps/base/media/immich/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - ingress.yaml
```

**Step 3: Commit**

```bash
git add kubernetes/apps/base/media/immich/ingress.yaml kubernetes/apps/base/media/immich/kustomization.yaml
git commit -m "feat: add Ingress for Immich with TLS"
```

---

## Task 12: Update ControlD DNS Entries

**Files:**
- Modify: `scripts/controld/domains.yaml` (or regenerate)

**Step 1: Update DNS entries to point to Ingress IP**

For services with Ingress, ControlD should resolve to the Ingress IP (10.10.2.38) instead of the service's LoadBalancer IP.

Update the DNS generation script or manually update `scripts/controld/domains.yaml`:

```yaml
domains:
  # Services with Ingress (point to Ingress IP for HTTPS)
  - name: music
    ip: 10.10.2.38
    suffixes: [home-infra.net]

  - name: photos
    ip: 10.10.2.38
    suffixes: [reynoza.org]

  # Services without Ingress (keep original LoadBalancer IPs)
  - name: grafana
    ip: 10.10.2.23
    # ... etc
```

**Step 2: Sync to ControlD**

```bash
./scripts/controld/controld-dns.py sync --dry-run
./scripts/controld/controld-dns.py sync
```

**Step 3: Commit**

```bash
git add scripts/controld/domains.yaml
git commit -m "feat: update ControlD DNS to route HTTPS services through Ingress"
```

---

## Task 13: Update Documentation

**Files:**
- Modify: `docs/reference/network.md`
- Create: `docs/services/cert-manager.md`
- Modify: `CLAUDE.md`

**Step 1: Update network.md**

Add Ingress IP to the network reference and update the domain resolution section.

**Step 2: Create cert-manager documentation**

Create `docs/services/cert-manager.md` with:
- Overview of cert-manager
- ClusterIssuer configuration
- Wildcard certificates
- Auto-renewal verification commands
- Troubleshooting

**Step 3: Update CLAUDE.md**

Add cert-manager to the Technology Stack table and update IP allocations.

**Step 4: Commit**

```bash
git add docs/reference/network.md docs/services/cert-manager.md CLAUDE.md
git commit -m "docs: add cert-manager documentation and update network reference"
```

---

## Task 14: Deploy and Verify

### IP Changes (IMPORTANT)

This implementation includes IP reassignments:

| Service | Old IP | New IP |
|---------|--------|--------|
| Ingress | N/A | 10.10.2.20 |
| Ollama | 10.10.2.20 | 10.10.2.50 |
| Open WebUI | 10.10.2.19 | 10.10.2.51 |
| ComfyUI | 10.10.2.28 | 10.10.2.52 |

### Deployment Order

**Step 1: Apply Terraform changes (creates namespace + secret)**

```bash
cd terraform/talos
terraform plan -out=tfplan
terraform apply tfplan
```

**Step 2: Apply cluster-vars first (AI services get new IPs)**

```bash
flux reconcile kustomization infrastructure-cluster-vars --with-source
```

**Step 3: Reconcile AI services (they move to new IPs)**

```bash
flux reconcile kustomization apps --with-source
# Wait for AI services to get new IPs
kubectl get svc -n ai
```

Expected: Ollama=10.10.2.50, Open WebUI=10.10.2.51, ComfyUI=10.10.2.52

**Step 4: Deploy cert-manager and Ingress**

```bash
flux reconcile kustomization infrastructure-controllers --with-source
flux reconcile kustomization infrastructure-configs --with-source
```

**Step 5: Verify cert-manager deployment**

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuers
```

Expected: All pods Running, ClusterIssuers Ready

**Step 6: Verify certificate issuance**

```bash
kubectl get certificates -A
kubectl describe certificate wildcard-home-infra-net -n media
```

Expected: Certificates show "Ready: True"

**Step 7: Verify Cilium Ingress**

```bash
kubectl get svc -n kube-system | grep cilium-ingress
kubectl get ingress -A
```

Expected: Ingress controller has IP 10.10.2.20, Ingresses show ADDRESS

**Step 8: Test local HTTPS access**

```bash
# Test via Ingress IP directly
curl -v --resolve music.home-infra.net:443:10.10.2.20 https://music.home-infra.net
curl -v --resolve photos.reynoza.org:443:10.10.2.20 https://photos.reynoza.org

# After DNS is updated
curl -v https://music.home-infra.net
curl -v https://photos.reynoza.org
```

Expected: Valid TLS certificate, 200 OK response

---

## Verification Checklist

- [ ] Cloudflare API token created and encrypted
- [ ] Terraform applied (cert-manager namespace + secret)
- [ ] AI services moved to new IPs (50-52)
- [ ] cert-manager pods running
- [ ] ClusterIssuers ready (staging and production)
- [ ] Wildcard certificates issued in all namespaces
- [ ] Cilium Ingress Controller running on 10.10.2.20
- [ ] Ingress resources created for all 25 services
- [ ] ControlD DNS updated to point to Ingress IP
- [ ] Local HTTPS access working
- [ ] Certificate auto-renewal configured (check with `kubectl describe certificate`)

---

## Rollback Plan

If issues occur:

1. **Disable Ingress resources**: Delete individual Ingress manifests
2. **Revert ControlD DNS**: Point back to original LoadBalancer IPs
3. **Disable Cilium Ingress**: Set `ingressController.enabled: false`
4. **Remove cert-manager**: Delete HelmRelease and namespace

Services will continue working via direct LoadBalancer IP access (HTTP).

---

## Future Enhancements

- Add Ingress resources for more services
- Configure Ingress annotations for rate limiting, authentication
- Set up certificate expiry alerts in Grafana
- Consider Gateway API (Cilium native) as Ingress replacement

---

**Last Updated:** 2026-01-23
