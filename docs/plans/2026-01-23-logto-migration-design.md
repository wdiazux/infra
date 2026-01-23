# Logto Migration Design - Replace Casdoor with Logto

**Date:** 2026-01-23
**Status:** Approved
**Author:** Claude + wdiaz

---

## Overview

Replace Casdoor SSO/IAM with Logto for better developer experience (modern UI, clean APIs, excellent documentation).

**Why Logto over Casdoor:**
- Modern React-based admin console
- Well-designed REST APIs with predictable behavior
- Comprehensive documentation with integration guides
- No Redis dependency (simpler architecture)

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   auth namespace                     │
│                                                      │
│  ┌──────────────────┐      ┌──────────────────────┐ │
│  │  logto-server    │      │  logto-postgres      │ │
│  │  (Deployment)    │─────▶│  (StatefulSet)       │ │
│  │                  │      │                      │ │
│  │  Port 3001: Auth │      │  Port 5432           │ │
│  │  Port 3002: Admin│      │  1Gi Longhorn PVC    │ │
│  └────────┬─────────┘      └──────────────────────┘ │
│           │                                          │
│  ┌────────▼─────────┐                               │
│  │  logto (Service) │                               │
│  │  LoadBalancer    │                               │
│  │  10.10.2.18      │                               │
│  │                  │                               │
│  │  :80   → 3002    │  Admin Console                │
│  │  :3001 → 3001    │  User Auth / OIDC             │
│  └──────────────────┘                               │
└─────────────────────────────────────────────────────┘
```

**OIDC Endpoints:**
- Discovery: `http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration`
- Authorization: `http://auth.home-infra.net:3001/oidc/auth`
- Token: `http://auth.home-infra.net:3001/oidc/token`
- UserInfo: `http://auth.home-infra.net:3001/oidc/me`
- JWKS: `http://auth.home-infra.net:3001/oidc/jwks`

---

## Files to Remove (Casdoor Cleanup)

**Delete entirely:**
```
kubernetes/apps/base/auth/casdoor/
├── kustomization.yaml
├── secret.enc.yaml
├── init-data-configmap.yaml
├── postgres-statefulset.yaml
├── redis-deployment.yaml
├── server-deployment.yaml
├── services.yaml
└── pvc.yaml

kubernetes/infrastructure/image-automation/policies/auth.yaml
```

**Modify:**
```
kubernetes/apps/base/auth/kustomization.yaml
kubernetes/infrastructure/security/network-policies.yaml
kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
```

---

## Files to Create (Logto Deployment)

**New directory:**
```
kubernetes/apps/base/auth/logto/
├── kustomization.yaml
├── secret.enc.yaml
├── postgres-statefulset.yaml
├── server-deployment.yaml
├── services.yaml
└── pvc.yaml
```

**Image automation:**
```
kubernetes/infrastructure/image-automation/policies/auth.yaml
```

---

## Logto Server Configuration

**Environment Variables:**
```yaml
env:
  - name: NODE_ENV
    value: "production"
  - name: TRUST_PROXY_HEADER
    value: "1"
  - name: DB_URL
    value: "postgres://logto:$(POSTGRES_PASSWORD)@logto-postgres:5432/logto"
  - name: ENDPOINT
    value: "http://auth.home-infra.net:3001"
  - name: ADMIN_ENDPOINT
    value: "http://auth.home-infra.net"
```

**Container Resources:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
```

---

## NetworkPolicies

**1. auth-default-deny-egress** (unchanged)
- Default deny all egress in auth namespace
- Exception: DNS to kube-system

**2. auth-logto-allow** (new)
```yaml
Ingress:
  - Port 3001 TCP (auth endpoint) from any
  - Port 3002 TCP (admin console) from any

Egress:
  - Port 53 UDP (DNS)
  - Port 5432 TCP to logto-postgres
  - Port 443 TCP external (social login providers)
```

**3. auth-logto-postgres-allow** (new)
```yaml
Ingress:
  - Port 5432 TCP from logto-server only

Egress:
  - Port 53 UDP (DNS only)
```

**Removed:** `auth-casdoor-allow`, `auth-casdoor-postgres-allow`, `auth-casdoor-redis-allow`

---

## Documentation Updates

| File | Action |
|------|--------|
| `CLAUDE.md` | Update network table: Casdoor → Logto |
| `docs/services/logto.md` | Create new service documentation |
| `docs/plans/2026-01-23-sso-integration-plan.md` | Update endpoints for Logto |
| `docs/plans/2026-01-22-casdoor-sso-design.md` | Delete (superseded) |
| `cluster-vars.yaml` | Rename IP_CASDOOR → IP_LOGTO |

---

## Implementation Order

### Phase 1: Remove Casdoor
1. Delete Casdoor NetworkPolicies from `network-policies.yaml`
2. Delete `kubernetes/apps/base/auth/casdoor/` directory
3. Update `kubernetes/apps/base/auth/kustomization.yaml` (remove casdoor)
4. Delete Casdoor image automation policy
5. Commit and push (FluxCD removes resources)

### Phase 2: Deploy Logto
1. Create `kubernetes/apps/base/auth/logto/` directory
2. Create PostgreSQL StatefulSet + PVC
3. Create Logto server Deployment
4. Create LoadBalancer Service (80 → 3002, 3001 → 3001)
5. Create SOPS-encrypted secret
6. Update `kubernetes/apps/base/auth/kustomization.yaml` (add logto)
7. Add Logto NetworkPolicies
8. Create Logto image automation policy
9. Update cluster-vars (IP_CASDOOR → IP_LOGTO)
10. Commit and push (FluxCD deploys)

### Phase 3: Verify & Document
1. Verify admin console at `http://10.10.2.18`
2. Verify OIDC discovery at `http://10.10.2.18:3001/oidc/.well-known/openid-configuration`
3. Create initial admin user
4. Update CLAUDE.md
5. Create docs/services/logto.md
6. Update SSO integration plan
7. Delete Casdoor design doc

---

## Logto Environment Variables Reference

**Core Configuration:**
| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode | `undefined` |
| `PORT` | Main app port | `3001` |
| `ADMIN_PORT` | Admin console port | `3002` |
| `ENDPOINT` | Public URL for auth | `protocol://localhost:$PORT` |
| `ADMIN_ENDPOINT` | Public URL for admin | `protocol://localhost:$ADMIN_PORT` |
| `TRUST_PROXY_HEADER` | Trust X-Forwarded headers | `false` |

**Database:**
| Variable | Description |
|----------|-------------|
| `DB_URL` | PostgreSQL DSN (`postgres://user:pass@host:port/dbname`) |

**Security:**
| Variable | Description |
|----------|-------------|
| `ADMIN_DISABLE_LOCALHOST` | Disable localhost admin access |
| `HTTPS_CERT_PATH` | TLS certificate path |
| `HTTPS_KEY_PATH` | TLS private key path |

**Default OIDC Scopes:** `openid`, `profile`, `email`, `offline_access`

---

## Admin Console Features

- **Applications** - OIDC/OAuth2 client management
- **Users** - User management and profiles
- **Roles** - RBAC with permissions
- **Organizations** - Multi-tenancy support
- **Sign-in Experience** - Branding and flow customization
- **Connectors** - Social login, SMS, email providers
- **Audit Logs** - Activity tracking

---

## References

- [Logto Documentation](https://docs.logto.io/)
- [Logto GitHub](https://github.com/logto-io/logto)
- [Logto OIDC Configuration](https://docs.logto.io/integrate-logto/third-party-applications/)
- [Logto Self-Hosting](https://docs.logto.io/logto-oss/deployment-and-configuration/)
