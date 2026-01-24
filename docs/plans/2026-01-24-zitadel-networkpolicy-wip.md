# Zitadel NetworkPolicy Fix - Work In Progress

**Date**: 2026-01-24
**Status**: Incomplete - K8s API access issue

## Completed

1. **nginx-ingress for HTTP/2 gRPC** - Zitadel v1 APIs now work
   - Files: `kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml`
   - LoadBalancer IP: 10.10.2.18

2. **NetworkPolicy fixes**:
   - `backup-minio-allow` - minio-init-bucket can reach MinIO (completed)
   - `auth-zitadel-login-allow` - zitadel-login can reach Zitadel API
   - `auth-zitadel-allow` - Added egress for setup job

3. **Working pods**:
   - zitadel: 1/1 Running
   - zitadel-login: 1/1 Running
   - zitadel-postgres: 1/1 Running
   - zitadel-redis: 1/1 Running
   - minio-init-bucket: Completed

## Outstanding Issue

The `zitadel-setup` Helm pre-upgrade hook job fails because containers (zitadel-machinekey, zitadel-machine-pat, zitadel-login-client-pat) cannot reach the Kubernetes API server.

**Error**:
```
couldn't get current server API group list: Get "https://10.96.0.1:443/api?timeout=32s": dial tcp 10.96.0.1:443: i/o timeout
```

**Current NetworkPolicy** (`auth-zitadel-allow`):
```yaml
egress:
  - ports:
    - port: 443
      protocol: TCP
    to:
    - ipBlock:
        cidr: 10.96.0.1/32
```

The ipBlock rule should allow access but doesn't work. Cilium may handle K8s API access differently.

## Next Steps

1. **Investigate Cilium K8s API access**:
   - Check if Cilium requires specific CiliumNetworkPolicy for K8s API
   - Test with `cilium connectivity test`

2. **Workarounds to try**:
   - Allow all egress temporarily for pods with `app.kubernetes.io/name: zitadel`
   - Use CiliumNetworkPolicy with toEntities: kube-apiserver
   - Skip Helm pre-upgrade hooks if Zitadel is already running

3. **Quick fix** (if needed):
   ```bash
   # Temporarily allow all egress for auth namespace
   kubectl delete networkpolicy auth-default-deny-egress -n auth

   # Retry HelmRelease
   kubectl delete job zitadel-setup -n auth
   flux reconcile helmrelease zitadel -n auth

   # Re-apply policies after success
   flux reconcile kustomization infrastructure-security
   ```

## Commits Made

- `60f7cb6` - nginx-ingress for Zitadel HTTP/2 gRPC support
- `fb9ef48` - minio init-bucket NetworkPolicy fix
- `ef0931a` - zitadel-login NetworkPolicy
- `451e70d` - K8s API egress for setup job
- `47e5f92` - Use ipBlock for K8s API

## Related Files

- `kubernetes/infrastructure/security/network-policies.yaml`
- `kubernetes/apps/base/auth/zitadel/kustomization.yaml`
- `kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml`
- `kubernetes/apps/base/auth/zitadel/networkpolicy-nginx.yaml`
- `kubernetes/infrastructure/controllers/coredns-custom.yaml`
