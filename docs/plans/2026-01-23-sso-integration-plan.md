# SSO Integration Plan - Logto with Homelab Services

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Logto SSO with all compatible homelab services for centralized authentication.

**Architecture:** Logto at auth.home-infra.net provides OIDC/OAuth2 authentication. Services connect either directly via OIDC or through reverse proxy header authentication.

**Tech Stack:** Logto (OIDC/OAuth2 provider), Kubernetes manifests, environment variables, SOPS secrets

---

**Date:** 2026-01-23
**Status:** In Progress
**Author:** Claude + wdiaz

---

## Service Authentication Matrix

Based on research, services are categorized by their authentication support:

### Tier 1: Native OIDC/OAuth2 Support (Direct Integration)

| Service | IP | Auth Method | Priority | Complexity |
|---------|-----|-------------|----------|------------|
| **Grafana** | 10.10.2.23 | Native OIDC (Generic OAuth) | High | Low |
| **Forgejo** | 10.10.2.13 | Native OAuth2/OIDC | High | Low |
| **Open WebUI** | 10.10.2.19 | Native OIDC | High | Low |
| **Immich** | 10.10.2.22 | Native OAuth2/OIDC | High | Low |
| **Paperless-ngx** | 10.10.2.36 | Native OIDC (django-allauth) | High | Medium |
| **MinIO** | 10.10.2.17 | Native OIDC | Medium | Medium |
| **n8n** | 10.10.2.26 | Native OIDC (Enterprise) or Community Patch | Medium | High |
| **Affine** | 10.10.2.33 | Native OIDC | Medium | Medium |
| **Wallos** | 10.10.2.34 | Native OIDC | Medium | Low |

### Tier 2: Reverse Proxy Header Authentication (Indirect Integration)

| Service | IP | Auth Method | Priority | Complexity |
|---------|-----|-------------|----------|------------|
| **Navidrome** | 10.10.2.31 | Reverse Proxy (`Remote-User` header) | Medium | Medium |
| **Home Assistant** | 10.10.2.25 | HACS OIDC Plugin or Header Auth | Low | High |

### Tier 3: No Native SSO Support (Requires Proxy Protection)

| Service | IP | Current Auth | Notes |
|---------|-----|--------------|-------|
| **Homepage** | 10.10.2.21 | None (by design) | Protect via reverse proxy |
| **Emby** | 10.10.2.30 | Internal + LDAP (Premiere) | No OIDC support |
| **Radarr** | 10.10.2.43 | Basic Auth / API Key | Use Authentik proxy pattern |
| **Sonarr** | 10.10.2.44 | Basic Auth / API Key | Use Authentik proxy pattern |
| **Prowlarr** | 10.10.2.42 | Basic Auth / API Key | Use Authentik proxy pattern |
| **Bazarr** | 10.10.2.45 | Basic Auth / API Key | Use Authentik proxy pattern |
| **SABnzbd** | 10.10.2.40 | API Key | Keep API key auth |
| **qBittorrent** | 10.10.2.41 | Basic Auth | Protect via reverse proxy |
| **ntfy** | 10.10.2.35 | Token-based | Keep token auth |
| **IT-Tools** | 10.10.2.32 | None (client-side only) | Protect via reverse proxy |
| **Copyparty** | 10.10.2.37 | Internal auth | Can use oauth2-proxy |
| **ComfyUI** | 10.10.2.28 | None | Protect via reverse proxy |
| **Obico** | 10.10.2.27 | Token-based | Keep token auth |
| **Attic** | 10.10.2.29 | JWT tokens | Keep token auth |
| **VictoriaMetrics** | 10.10.2.24 | vmauth (Enterprise OIDC) | Use basic auth or proxy |

### Tier 4: Internal/API-Only Services (No UI Auth Needed)

| Service | Notes |
|---------|-------|
| **Ollama** | API-only, accessed via Open WebUI |
| **PostgreSQL instances** | Internal database connections |
| **Redis instances** | Internal cache connections |

---

## Logto Configuration

### Prerequisites

Before integrating services, configure Logto:

1. **Change default admin password** - Login at http://10.10.2.18 with `admin/123`
2. **Create homelab organization** - Separate from built-in
3. **Create user account** - Your personal account in the new organization
4. **Configure OAuth2 applications** - One per service

### Application Template

For each service, create an OAuth2 application in Logto with:

```
Organization: homelab
Name: <service-name>
Display Name: <Service Display Name>
Homepage URL: http://<service>.home-infra.net
Redirect URIs: http://<service>.home-infra.net/callback (varies by service)
Grant Types: authorization_code
Response Types: code
Token Format: JWT
```

---

## Phase 1: High Priority OIDC Integrations

### Task 1: Configure Logto Base Setup

**Files:**
- Logto Web UI at http://10.10.2.18

**Step 1: Login and change admin password**
- Navigate to http://10.10.2.18
- Login with `admin/123`
- Go to Users → admin → Edit
- Change password to a secure value

**Step 2: Create homelab organization**
- Go to Organizations → Add
- Name: `homelab`
- Display Name: `Homelab`
- Website URL: `https://home-infra.net`
- Password Type: `bcrypt`

**Step 3: Create your user account**
- Go to Users → Add
- Organization: `homelab`
- Name: `wdiaz`
- Email: your email
- Is Admin: Yes

---

### Task 2: Grafana OIDC Integration

**Files:**
- Modify: `kubernetes/apps/base/monitoring/grafana/` deployment/configmap

**Logto Application Setup:**
- Name: `grafana`
- Redirect URI: `http://grafana.home-infra.net/login/generic_oauth`
- Scopes: `openid profile email`

**Grafana Configuration (environment variables):**

```yaml
env:
  - name: GF_AUTH_GENERIC_OAUTH_ENABLED
    value: "true"
  - name: GF_AUTH_GENERIC_OAUTH_NAME
    value: "Logto"
  - name: GF_AUTH_GENERIC_OAUTH_CLIENT_ID
    value: "grafana"
  - name: GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: grafana-oauth-secret
        key: client-secret
  - name: GF_AUTH_GENERIC_OAUTH_SCOPES
    value: "openid profile email"
  - name: GF_AUTH_GENERIC_OAUTH_AUTH_URL
    value: "http://auth.home-infra.net:3001/oidc/auth"
  - name: GF_AUTH_GENERIC_OAUTH_TOKEN_URL
    value: "http://auth.home-infra.net:3001/oidc/token"
  - name: GF_AUTH_GENERIC_OAUTH_API_URL
    value: "http://auth.home-infra.net:3001/oidc/me"
  - name: GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP
    value: "true"
  - name: GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH
    value: "contains(groups[*], 'admin') && 'Admin' || 'Viewer'"
```

**References:**
- [Grafana Generic OAuth docs](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/generic-oauth/)
- [Authelia Grafana Integration](https://www.authelia.com/integration/openid-connect/clients/grafana/)

---

### Task 3: Forgejo OIDC Integration

**Files:**
- Modify: Forgejo admin UI (Site Administration → Authentication Sources)

**Logto Application Setup:**
- Name: `forgejo`
- Redirect URI: `http://forgejo.home-infra.net/user/oauth2/logto/callback`
- Scopes: `openid profile email groups`

**Forgejo Configuration (via Admin UI):**
1. Login as admin to Forgejo
2. Go to Site Administration → Identity & Access → Authentication Sources
3. Add Authentication Source:
   - Authentication Type: `OAuth2`
   - Authentication Name: `logto`
   - OAuth2 Provider: `OpenID Connect`
   - Client ID: `forgejo`
   - Client Secret: (from Logto)
   - OpenID Connect Auto Discovery URL: `http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration`
   - Additional Scopes: `profile email groups`

**References:**
- [Forgejo OAuth2 Provider docs](https://forgejo.org/docs/next/user/oauth2-provider/)
- [Authelia Forgejo Integration](https://www.authelia.com/integration/openid-connect/clients/forgejo/)

---

### Task 4: Open WebUI OIDC Integration

**Files:**
- Modify: `kubernetes/apps/base/ai/open-webui/` deployment

**Logto Application Setup:**
- Name: `open-webui`
- Redirect URI: `http://openwebui.home-infra.net/oauth/oidc/callback`
- Scopes: `openid profile email`

**Open WebUI Configuration (environment variables):**

```yaml
env:
  - name: ENABLE_OAUTH_SIGNUP
    value: "true"
  - name: OAUTH_PROVIDER_NAME
    value: "Logto"
  - name: OPENID_PROVIDER_URL
    value: "http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration"
  - name: OAUTH_CLIENT_ID
    value: "open-webui"
  - name: OAUTH_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: openwebui-oauth-secret
        key: client-secret
  - name: OAUTH_SCOPES
    value: "openid profile email"
  - name: WEBUI_URL
    value: "http://openwebui.home-infra.net"
```

**References:**
- [Open WebUI SSO docs](https://docs.openwebui.com/features/auth/sso/)
- [Authelia Open WebUI Integration](https://www.authelia.com/integration/openid-connect/clients/open-webui/)

---

### Task 5: Immich OIDC Integration

**Files:**
- Immich Admin UI (Administration → Settings → OAuth Authentication)

**Logto Application Setup:**
- Name: `immich`
- Redirect URIs:
  - `app.immich:///oauth-callback` (mobile)
  - `http://immich.home-infra.net/auth/login`
  - `http://immich.home-infra.net/user-settings`
- Scopes: `openid profile email`

**Immich Configuration (via Admin UI):**
1. Login as admin to Immich
2. Go to Administration → Settings → OAuth Authentication
3. Enable OAuth
4. Configure:
   - Issuer URL: `http://auth.home-infra.net:3001/oidc`
   - Client ID: `immich`
   - Client Secret: (from Logto)
   - Scope: `openid profile email`
   - Signing Algorithm: `RS256`
   - Button Text: `Login with Logto`
   - Auto Register: `true`
   - Mobile Redirect URI Override: `true`

**References:**
- [Immich OAuth docs](https://docs.immich.app/administration/oauth/)
- [Authelia Immich Integration](https://www.authelia.com/integration/openid-connect/clients/immich/)

---

### Task 6: Paperless-ngx OIDC Integration

**Files:**
- Modify: `kubernetes/apps/base/management/paperless/` deployment

**Logto Application Setup:**
- Name: `paperless`
- Redirect URI: `http://paperless.home-infra.net/accounts/oidc/logto/login/callback/`
- Scopes: `openid profile email`

**Paperless-ngx Configuration (environment variables):**

```yaml
env:
  - name: PAPERLESS_APPS
    value: "allauth.socialaccount.providers.openid_connect"
  - name: PAPERLESS_SOCIALACCOUNT_PROVIDERS
    value: |
      {
        "openid_connect": {
          "APPS": [{
            "provider_id": "logto",
            "name": "Logto",
            "client_id": "paperless",
            "secret": "CLIENT_SECRET_HERE",
            "settings": {
              "server_url": "http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration"
            }
          }],
          "OAUTH_PKCE_ENABLED": true
        }
      }
```

**References:**
- [Paperless-ngx Configuration docs](https://docs.paperless-ngx.com/configuration/)
- [Authelia Paperless Integration](https://www.authelia.com/integration/openid-connect/clients/paperless/)

---

## Phase 2: Medium Priority Integrations

### Task 7: Wallos OIDC Integration

**Files:**
- Wallos Admin UI

**Logto Application Setup:**
- Name: `wallos`
- Redirect URI: `http://wallos.home-infra.net/callback`
- Scopes: `openid profile email`

**Wallos Configuration (via Admin UI):**
1. Login as admin to Wallos
2. Go to Admin → OIDC Settings
3. Enable OIDC/OAuth
4. Configure:
   - Provider Name: `Logto`
   - Client ID: `wallos`
   - Client Secret: (from Logto)
   - Auth URL: `http://auth.home-infra.net:3001/oidc/auth`
   - Token URL: `http://auth.home-infra.net:3001/oidc/token`
   - User Info URL: `http://auth.home-infra.net:3001/oidc/me`
   - Redirect URL: `http://wallos.home-infra.net/callback`

**References:**
- [Authelia Wallos Integration](https://www.authelia.com/integration/openid-connect/clients/wallos/)

---

### Task 8: Affine OIDC Integration

**Files:**
- Modify: `kubernetes/apps/base/tools/affine/` deployment

**Logto Application Setup:**
- Name: `affine`
- Redirect URI: `http://affine.home-infra.net/oauth/callback`
- Scopes: `openid profile email`

**Affine Configuration (environment variables):**

```yaml
env:
  - name: OAUTH_OIDC_ENABLED
    value: "true"
  - name: OAUTH_OIDC_ISSUER
    value: "http://auth.home-infra.net:3001/oidc"
  - name: OAUTH_OIDC_CLIENT_ID
    value: "affine"
  - name: OAUTH_OIDC_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: affine-oauth-secret
        key: client-secret
```

**References:**
- [Affine OAuth 2.0 docs](https://docs.affine.pro/self-host-affine/administer/oauth-2-0)

---

### Task 9: MinIO OIDC Integration

**Files:**
- Modify: `kubernetes/apps/base/backup/minio/` deployment

**Logto Application Setup:**
- Name: `minio`
- Redirect URI: `http://minio.home-infra.net/oauth_callback`
- Scopes: `openid profile email`

**MinIO Configuration (environment variables):**

```yaml
env:
  - name: MINIO_IDENTITY_OPENID_CONFIG_URL
    value: "http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration"
  - name: MINIO_IDENTITY_OPENID_CLIENT_ID
    value: "minio"
  - name: MINIO_IDENTITY_OPENID_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: minio-oauth-secret
        key: client-secret
  - name: MINIO_IDENTITY_OPENID_CLAIM_NAME
    value: "groups"
  - name: MINIO_IDENTITY_OPENID_SCOPES
    value: "openid,profile,email"
  - name: MINIO_IDENTITY_OPENID_REDIRECT_URI
    value: "http://minio.home-infra.net/oauth_callback"
```

**Note:** MinIO requires policies to be mapped to groups. Create policies in MinIO and matching groups in Logto.

**References:**
- [MinIO OIDC Configuration](https://min.io/docs/minio/linux/operations/external-iam/configure-openid-external-identity-management.html)
- [Logto OIDC Documentation](https://docs.logto.io/docs/references/openid-connect/)

---

### Task 10: Navidrome Header Auth Integration

**Files:**
- Modify: `kubernetes/apps/base/media/navidrome/` deployment

**Navidrome Configuration (environment variables):**

```yaml
env:
  - name: ND_REVERSEPROXYWHITELIST
    value: "10.244.0.0/16"  # Pod network CIDR
  - name: ND_REVERSEPROXYUSERHEADER
    value: "Remote-User"
```

**Note:** This requires an authentication proxy (like oauth2-proxy or Authelia outpost) in front of Navidrome that handles OIDC and passes the `Remote-User` header. Consider implementing this as a follow-up task.

**References:**
- [Navidrome External Auth docs](https://www.navidrome.org/docs/usage/integration/authentication/)

---

## Phase 3: Reverse Proxy Protected Services

For services without native OIDC support, consider one of these approaches:

### Option A: NetworkPolicy + Internal Access Only
Keep services on internal network only, no SSO needed.

### Option B: oauth2-proxy Sidecar
Deploy oauth2-proxy as a sidecar or separate deployment in front of services.

### Option C: Ingress Controller with Auth
If using an ingress controller (not currently deployed), configure forward auth.

**Recommended for homelab:** Keep Tier 3 services internal-only (Option A) and focus SSO efforts on Tier 1 services.

---

## Implementation Order

1. **Logto base setup** (Task 1) - Required first
2. **Grafana** (Task 2) - High value, monitoring access
3. **Forgejo** (Task 3) - High value, code repository
4. **Open WebUI** (Task 4) - High value, AI interface
5. **Immich** (Task 5) - High value, personal photos
6. **Paperless-ngx** (Task 6) - Medium value, documents
7. **Wallos** (Task 7) - Lower priority
8. **Affine** (Task 8) - Lower priority
9. **MinIO** (Task 9) - Lower priority (backup storage)
10. **Navidrome** (Task 10) - Lower priority, requires proxy setup

---

## Security Considerations

1. **HTTPS:** For production, all OAuth flows should use HTTPS. Current setup uses HTTP internally.
2. **Token Expiry:** Configure reasonable token expiry times in Logto (default 168 hours may be too long).
3. **Backup Access:** Keep local admin accounts as backup in case Logto is unavailable.
4. **Network Isolation:** Logto NetworkPolicies are already configured.

---

## Testing Checklist

For each integrated service:
- [ ] Can login via Logto SSO
- [ ] User info (name, email) populated correctly
- [ ] Logout works and redirects properly
- [ ] Local admin account still works (backup access)
- [ ] Mobile app works (if applicable)

---

## References

- [Logto Documentation](https://docs.logto.io/)
- [Logto OIDC Configuration](https://docs.logto.io/docs/references/openid-connect/)
- [Logto Application Setup](https://docs.logto.io/docs/recipes/integrate-logto/)
- [Authelia OpenID Connect Integrations](https://www.authelia.com/integration/openid-connect/clients/)
- [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy)
