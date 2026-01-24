# Zitadel NetworkPolicy and Ingress Configuration - Complete Solution

**Date**: 2026-01-24
**Status**: Complete

## Overview

This document describes the complete solution for deploying Zitadel SSO with proper NetworkPolicy and Ingress configuration in a Cilium-based Kubernetes cluster.

## Architecture

```
                     ┌─────────────────────────────────────────────────────┐
                     │              auth.home-infra.net                    │
                     │                  (10.10.2.18)                       │
                     └─────────────────────────────────────────────────────┘
                                           │
                                           ▼
                     ┌─────────────────────────────────────────────────────┐
                     │           nginx-ingress-controller                  │
                     │          (dedicated for Zitadel)                    │
                     └─────────────────────────────────────────────────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
         ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
         │  /ui/v2/login/*  │   │   /* (default)   │   │  gRPC APIs       │
         │                  │   │                  │   │  /zitadel.*      │
         └──────────────────┘   └──────────────────┘   └──────────────────┘
                    │                      │                      │
                    ▼                      ▼                      │
         ┌──────────────────┐   ┌──────────────────┐              │
         │  zitadel-login   │   │     zitadel      │◄─────────────┘
         │   (Next.js)      │   │   (gRPC/HTTP)    │
         │   port: 3000     │   │   port: 8080     │
         └──────────────────┘   └──────────────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
         ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
         │ zitadel-postgres │   │  zitadel-redis   │   │  Kubernetes API  │
         │   port: 5432     │   │   port: 6379     │   │   port: 6443     │
         └──────────────────┘   └──────────────────┘   └──────────────────┘
```

## Issues Solved

### 1. Zitadel Setup Job Failing (K8s API Access)

**Problem**: The `zitadel-setup` Helm pre-upgrade hook job couldn't reach the Kubernetes API server to create secrets.

**Error**:
```
couldn't get current server API group list: Get "https://10.96.0.1:443/api?timeout=32s": dial tcp 10.96.0.1:443: i/o timeout
```

**Root Cause**: Cilium with `bpf-lb-sock: true` performs socket-level load balancing. When a pod connects to the K8s API ClusterIP (`10.96.0.1:443`), Cilium translates it to the backend (`10.10.2.10:6443`) at the socket level, **before** NetworkPolicy evaluation. Standard Kubernetes NetworkPolicy with `ipBlock` rules never sees the original destination.

**Solution**: Use `CiliumNetworkPolicy` with `toEntities: kube-apiserver` instead of standard NetworkPolicy.

**File**: `kubernetes/infrastructure/security/cilium-network-policies.yaml`
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: auth-zitadel-kube-api-allow
  namespace: auth
spec:
  description: "Allow Zitadel setup job to access Kubernetes API for creating secrets"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: zitadel
  egress:
    - toEntities:
        - kube-apiserver
      toPorts:
        - ports:
            - port: "6443"
              protocol: TCP
```

### 2. oauth2-proxy CrashLoopBackOff

**Problem**: oauth2-proxy couldn't perform OIDC discovery and was stuck on startup.

**Error**:
```
Performing OIDC Discovery...
```

**Root Cause**: oauth2-proxy was configured with `oidc_issuer_url = "https://auth.home-infra.net"` (external URL), but the NetworkPolicy only allowed egress to the internal zitadel pod on port 8080.

**Solution**: Add HTTPS egress rule to the `auth-oauth2-proxy-allow` NetworkPolicy.

**File**: `kubernetes/infrastructure/security/network-policies.yaml`
```yaml
# In auth-oauth2-proxy-allow policy
egress:
  # ... existing DNS and internal Zitadel rules ...
  # Allow HTTPS for OIDC discovery (auth.home-infra.net via external DNS)
  - to:
      - namespaceSelector: {}
    ports:
      - protocol: TCP
        port: 443
```

### 3. DNS Routing (auth.home-infra.net → wrong IP)

**Problem**: DNS for `auth.home-infra.net` resolved to `10.10.2.20` (main Cilium ingress) instead of `10.10.2.18` (Zitadel's dedicated nginx-ingress).

**Root Cause**: The DNS generator script was designed before Zitadel had its own ingress controller. It routed all `*.home-infra.net` domains through the main ingress.

**Solution**: Add `OWN_INGRESS_SERVICES` configuration to the DNS generator for services with dedicated ingress controllers.

**File**: `scripts/generate-dns-config.py`
```python
# Services with their own ingress controller (bypass main INGRESS_IP)
OWN_INGRESS_SERVICES = {
    "ZITADEL",  # Has dedicated nginx-ingress for HTTP/2 gRPC support
}

# Map ZITADEL variable to "auth" DNS name
NAME_MAPPINGS = {
    # ...
    "ZITADEL": "auth",
}
```

Then regenerate and sync:
```bash
python scripts/generate-dns-config.py
python scripts/controld/controld-dns.py sync
```

### 4. Login UI "Not Found" Error

**Problem**: Accessing `/ui/v2/login/login?authRequest=...` returned `{"code": 5, "message": "Not Found"}`.

**Root Cause**: The nginx-ingress routed all traffic to the Zitadel gRPC backend with `backend-protocol: GRPC`. But `/ui/v2/login` should route to the `zitadel-login` service (Next.js app) which uses HTTP.

**Solution**: Create a separate ingress for the login UI since nginx-ingress can't use different backend protocols for different paths in the same ingress.

**File**: `kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml`
```yaml
# Zitadel Login UI (hosted login v2) - HTTP backend
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zitadel-login-nginx
  namespace: auth
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - auth.home-infra.net
      secretName: wildcard-home-infra-net-tls
  rules:
    - host: auth.home-infra.net
      http:
        paths:
          - path: /ui/v2/login
            pathType: Prefix
            backend:
              service:
                name: zitadel-login
                port:
                  number: 3000
---
# Zitadel API and Console - gRPC backend
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zitadel-nginx
  namespace: auth
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - auth.home-infra.net
      secretName: wildcard-home-infra-net-tls
  rules:
    - host: auth.home-infra.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: zitadel
                port:
                  number: 8080
```

## Why Dedicated nginx-ingress for Zitadel?

Zitadel requires HTTP/2 for its v1 gRPC APIs. The main Cilium ingress uses HTTP/1.1 to backends, which breaks gRPC.

| Ingress | Backend Protocol | Purpose |
|---------|-----------------|---------|
| Cilium (10.10.2.20) | HTTP/1.1 | Most services |
| nginx for Zitadel (10.10.2.18) | HTTP/2 (gRPC) | Zitadel API + Console |
| nginx for Zitadel (10.10.2.18) | HTTP/1.1 | Zitadel Login UI |

## Files Modified

| File | Purpose |
|------|---------|
| `kubernetes/infrastructure/security/cilium-network-policies.yaml` | CiliumNetworkPolicy for K8s API access |
| `kubernetes/infrastructure/security/network-policies.yaml` | HTTPS egress for oauth2-proxy |
| `kubernetes/infrastructure/security/kustomization.yaml` | Include cilium-network-policies.yaml |
| `kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml` | Separate ingresses for login UI and API |
| `scripts/generate-dns-config.py` | Support for services with own ingress |
| `scripts/controld/domains.yaml` | Updated DNS routing |

## Commits

1. `78f7f59` - fix(auth): correct NetworkPolicy for K8s API and oauth2-proxy
2. `f9259dc` - fix(auth): use CiliumNetworkPolicy for K8s API access
3. `dcd563e` - docs(plans): mark zitadel NetworkPolicy fix as complete
4. `8283cb5` - fix(dns): route auth.home-infra.net to Zitadel's nginx-ingress
5. `4e3809e` - fix(auth): add separate ingress for zitadel-login hosted login UI

## Verification

```bash
# Check all pods are running
kubectl get pods -n auth
# NAME                                                      READY   STATUS
# nginx-ingress-ingress-nginx-controller-...                1/1     Running
# oauth2-proxy-...                                          1/1     Running
# zitadel-...                                               1/1     Running
# zitadel-login-...                                         1/1     Running
# zitadel-postgres-0                                        1/1     Running
# zitadel-redis-...                                         1/1     Running

# Check CiliumNetworkPolicy
kubectl get ciliumnetworkpolicies -n auth
# NAME                          AGE   VALID
# auth-zitadel-kube-api-allow   ...   True

# Check both ingresses exist
kubectl get ingress -n auth
# NAME                  CLASS   HOSTS                 ADDRESS      PORTS
# zitadel-login-nginx   nginx   auth.home-infra.net   10.10.2.18   80, 443
# zitadel-nginx         nginx   auth.home-infra.net   10.10.2.18   80, 443

# Test OIDC discovery
curl -sk https://auth.home-infra.net/.well-known/openid-configuration | jq .issuer
# "https://auth.home-infra.net"

# Test login UI routing
curl -sk https://auth.home-infra.net/ui/v2/login/login
# {"error":"No authRequest nor samlRequest provided"}  # Expected without auth flow
```

## Key Learnings

1. **Cilium socket-level LB**: With `bpf-lb-sock: true`, use `CiliumNetworkPolicy` with `toEntities` for K8s API access, not standard NetworkPolicy with `ipBlock`.

2. **nginx-ingress backend protocols**: Can't mix gRPC and HTTP backends in the same ingress. Create separate ingresses for different protocols.

3. **Services with own ingress**: Update DNS generator to handle services that bypass the main ingress controller.

## References

- [Cilium Network Policy - toEntities](https://docs.cilium.io/en/stable/security/policy/index.html)
- [GitHub Issue #20550 - Kubernetes network policy for api-server](https://github.com/cilium/cilium/issues/20550)
- [Zitadel Helm Chart](https://github.com/zitadel/zitadel-charts)
