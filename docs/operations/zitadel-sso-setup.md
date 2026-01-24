# Zitadel SSO Post-Deployment Setup

This guide covers the manual configuration steps after deploying the Zitadel SSO infrastructure.

## Prerequisites

Ensure the following are deployed and running:
```bash
kubectl get pods -n auth
# Expected: postgres-0, redis-*, zitadel-*, oauth2-proxy-*
```

## Phase 3: Initial Zitadel Setup

### 1. Access Zitadel Console

1. Open https://auth.home-infra.net
2. Login with initial admin credentials:
   - Username: `wdiaz`
   - Password: Retrieve from secret:
     ```bash
     sops -d kubernetes/apps/base/auth/zitadel/secret.enc.yaml | grep ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD
     ```

### 2. Initial Configuration

1. **Change Admin Password** (recommended)
2. **Create Organization**: `homelab`
3. **Create Project**: `infrastructure`

## Phase 4: Native OIDC Application Setup

### Grafana

1. In Zitadel Console:
   - Navigate to: Projects > infrastructure > Applications
   - Create Application:
     - Name: `grafana`
     - Type: Web
     - Authentication Method: PKCE
     - Redirect URIs: `https://grafana.home-infra.net/login/generic_oauth`
     - Post Logout URIs: `https://grafana.home-infra.net`
   - Copy Client ID

2. Update Grafana configuration:
   ```bash
   # Edit kubernetes/apps/base/monitoring/grafana/secret.enc.yaml
   # Add OIDC configuration to grafana.ini or environment variables
   ```

   Required Grafana settings:
   ```ini
   [auth.generic_oauth]
   enabled = true
   name = Zitadel
   allow_sign_up = true
   client_id = <CLIENT_ID>
   scopes = openid profile email
   auth_url = https://auth.home-infra.net/oauth/v2/authorize
   token_url = https://auth.home-infra.net/oauth/v2/token
   api_url = https://auth.home-infra.net/oidc/v1/userinfo
   ```

### Forgejo

1. In Zitadel Console:
   - Create Application:
     - Name: `forgejo`
     - Type: Web
     - Authentication Method: PKCE
     - Redirect URIs: `https://git.home-infra.net/user/oauth2/zitadel/callback`
   - Copy Client ID

2. In Forgejo Admin Panel:
   - Navigate to: Site Administration > Authentication Sources
   - Add OAuth2 provider with Zitadel settings

### Other Native OIDC Apps

| App | Redirect URI |
|-----|--------------|
| Open WebUI | `https://ai.home-infra.net/oauth/callback` |
| Immich | `https://photos.home-infra.net/auth/login` |
| Paperless-ngx | `https://docs.home-infra.net/accounts/oidc/zitadel/login/callback/` |
| n8n | `https://n8n.home-infra.net/rest/oauth2-credential/callback` |

## Phase 5: Forward Auth Setup (oauth2-proxy)

### 1. Create oauth2-proxy Application in Zitadel

1. In Zitadel Console:
   - Create Application:
     - Name: `oauth2-proxy`
     - Type: Web
     - Authentication Method: Basic (Client Secret)
     - Redirect URIs: `https://auth.home-infra.net/oauth2/callback`
   - Copy Client ID and Client Secret

2. Update oauth2-proxy secret:
   ```bash
   # Decrypt, edit, re-encrypt
   sops kubernetes/apps/base/auth/oauth2-proxy/secret.enc.yaml

   # Update:
   # - client-id: <ZITADEL_CLIENT_ID>
   # - client-secret: <ZITADEL_CLIENT_SECRET>
   ```

3. Commit and reconcile:
   ```bash
   git add -A && git commit -m "feat(auth): configure oauth2-proxy credentials"
   flux reconcile kustomization apps --with-source
   ```

### 2. Enable CiliumEnvoyConfig (Experimental)

The CiliumEnvoyConfig for forward auth is experimental. To enable:

1. Add to kustomization:
   ```bash
   # Edit kubernetes/infrastructure/security/kustomization.yaml
   # Add: - cilium-envoy-forward-auth.yaml
   ```

2. Test with a single app first (e.g., Radarr)

3. If issues occur, use Traefik fallback (see below)

### 3. Traefik Fallback (If CiliumEnvoyConfig Fails)

If CiliumEnvoyConfig proves unreliable:

1. Deploy Traefik alongside Cilium:
   ```yaml
   # kubernetes/infrastructure/controllers/traefik.yaml
   # Configure with ForwardAuth middleware
   ```

2. Create IngressRoutes for apps needing forward auth

3. Keep Cilium Ingress for all other apps

## Verification

### Test OIDC Flow
```bash
# Check Zitadel is accessible
curl -s https://auth.home-infra.net/.well-known/openid-configuration | jq .issuer

# Should return: "https://auth.home-infra.net"
```

### Test Internal Resolution
```bash
# From inside a pod
kubectl run -it --rm debug --image=alpine -- sh
nslookup auth.home-infra.net
# Should resolve to 10.96.100.18 (ClusterIP, not Ingress IP)
```

### Test Forward Auth
```bash
# Access protected app without auth (should redirect)
curl -I https://radarr.home-infra.net
# Should return 302 redirect to auth.home-infra.net
```

## Troubleshooting

### Zitadel Not Starting
```bash
kubectl logs -n auth -l app.kubernetes.io/name=zitadel
kubectl describe pod -n auth -l app.kubernetes.io/name=zitadel
```

### Database Connection Issues
```bash
kubectl logs -n auth postgres-0
kubectl exec -n auth postgres-0 -- pg_isready -U zitadel
```

### OIDC Token Validation Failing
- Check CoreDNS rewrite is working (internal pods should resolve auth.home-infra.net to ClusterIP)
- Verify NetworkPolicy allows egress to auth namespace

### oauth2-proxy Issues
```bash
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy
```

## References

- [Zitadel Documentation](https://zitadel.com/docs/)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Design Document](../plans/2026-01-24-zitadel-sso-design.md)
