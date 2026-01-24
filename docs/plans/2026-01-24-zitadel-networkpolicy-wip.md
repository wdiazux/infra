# Zitadel NetworkPolicy Fix - Completed

**Date**: 2026-01-24
**Status**: Complete

## Problem

The `zitadel-setup` Helm pre-upgrade hook job failed because containers couldn't reach the Kubernetes API server.

**Error**:
```
couldn't get current server API group list: Get "https://10.96.0.1:443/api?timeout=32s": dial tcp 10.96.0.1:443: i/o timeout
```

## Root Cause

Standard Kubernetes NetworkPolicy with `ipBlock: 10.96.0.1/32` or `namespaceSelector: {} port: 6443` doesn't work with Cilium's socket-level load balancing (`bpf-lb-sock: true`).

When a pod connects to the K8s API ClusterIP (`10.96.0.1:443`), Cilium translates it to the backend (`10.10.2.10:6443`) at the socket level, **before** NetworkPolicy evaluation. The NetworkPolicy never sees the original destination.

## Solution

Use `CiliumNetworkPolicy` with `toEntities: kube-apiserver` instead of standard NetworkPolicy. CiliumNetworkPolicy correctly identifies the API server regardless of IP translation.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: auth-zitadel-kube-api-allow
  namespace: auth
spec:
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

## Additional Fix

`oauth2-proxy` was also failing because it needed HTTPS egress for OIDC discovery to `auth.home-infra.net` (external URL). Added HTTPS egress rule to `auth-oauth2-proxy-allow` NetworkPolicy.

## Commits

- `78f7f59` - fix(auth): correct NetworkPolicy for K8s API and oauth2-proxy (initial attempt)
- `f9259dc` - fix(auth): use CiliumNetworkPolicy for K8s API access (final fix)

## Files Modified

- `kubernetes/infrastructure/security/cilium-network-policies.yaml` (new)
- `kubernetes/infrastructure/security/network-policies.yaml`
- `kubernetes/infrastructure/security/kustomization.yaml`

## Verification

```bash
# CiliumNetworkPolicy is valid
kubectl get ciliumnetworkpolicies -n auth
# NAME                          AGE   VALID
# auth-zitadel-kube-api-allow   5s    True

# zitadel-setup job completed
kubectl get jobs -n auth
# NAME            STATUS     COMPLETIONS
# zitadel-setup   Complete   1/1

# All pods running
kubectl get pods -n auth
# oauth2-proxy   1/1   Running
# zitadel        1/1   Running
```

## References

- [Cilium Network Policy documentation](https://docs.cilium.io/en/stable/security/policy/index.html)
- [GitHub Issue #20550 - Kubernetes network policy for api-server](https://github.com/cilium/cilium/issues/20550)
