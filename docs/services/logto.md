# Logto - SSO/IAM Service

## Overview

Logto is an open-source identity and access management (IAM) solution providing OIDC/OAuth2 authentication for homelab services.

**Deployment:** Kubernetes (auth namespace)
**IP:** 10.10.2.18
**Ports:**
- 80: Admin Console
- 3001: User Authentication / OIDC

## Access

- **Admin Console:** http://auth.home-infra.net or http://10.10.2.18
- **OIDC Discovery:** http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration

## Environment Variables Reference

### Core Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode (production/development/test) | `undefined` |
| `PORT` | Main app port | `3001` |
| `ADMIN_PORT` | Admin console port | `3002` |
| `ENDPOINT` | Public URL for auth endpoints | `protocol://localhost:$PORT` |
| `ADMIN_ENDPOINT` | Public URL for admin console | `protocol://localhost:$ADMIN_PORT` |
| `TRUST_PROXY_HEADER` | Trust X-Forwarded headers (set to "1" behind LB) | `false` |

### Database

| Variable | Description |
|----------|-------------|
| `DB_URL` | PostgreSQL DSN (`postgres://user:pass@host:port/dbname`) |

### Security

| Variable | Description |
|----------|-------------|
| `ADMIN_DISABLE_LOCALHOST` | Disable localhost admin access ("1" to disable) |
| `HTTPS_CERT_PATH` | TLS certificate path (if terminating TLS at Logto) |
| `HTTPS_KEY_PATH` | TLS private key path |

## OIDC Endpoints

| Endpoint | URL |
|----------|-----|
| Discovery | `http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration` |
| Authorization | `http://auth.home-infra.net:3001/oidc/auth` |
| Token | `http://auth.home-infra.net:3001/oidc/token` |
| UserInfo | `http://auth.home-infra.net:3001/oidc/me` |
| JWKS | `http://auth.home-infra.net:3001/oidc/jwks` |
| End Session | `http://auth.home-infra.net:3001/oidc/session/end` |

## Default OIDC Scopes

- `openid` - Required for OIDC
- `profile` - User profile (name, picture, etc.)
- `email` - User email
- `offline_access` - Refresh tokens

## Admin Console Features

- **Applications** - OIDC/OAuth2 client management
- **Users** - User management and profiles
- **Roles** - RBAC with permissions
- **Organizations** - Multi-tenancy support
- **Sign-in Experience** - Branding and flow customization
- **Connectors** - Social login, SMS, email providers
- **Audit Logs** - Activity tracking

## Service Integration

To integrate a service with Logto SSO:

1. Open Admin Console (http://auth.home-infra.net)
2. Go to Applications → Create Application
3. Select "Traditional Web" for most services
4. Configure redirect URIs for the service
5. Copy Client ID and Client Secret
6. Configure the service with OIDC settings

## Kubernetes Resources

```
auth namespace:
├── logto-server (Deployment)
│   └── ghcr.io/logto-io/logto:1.27.0
├── logto-postgres (StatefulSet)
│   └── postgres:17-alpine
├── logto (Service - LoadBalancer)
│   └── 10.10.2.18:80,3001
└── logto-postgres (Service - ClusterIP)
```

## Troubleshooting

### Check pod status
```bash
kubectl -n auth get pods
kubectl -n auth logs deploy/logto-server
```

### Check database connectivity
```bash
kubectl -n auth exec -it sts/logto-postgres -- pg_isready -U logto
```

### Verify OIDC endpoints
```bash
curl http://10.10.2.18:3001/oidc/.well-known/openid-configuration | jq .
```

## References

- [Logto Documentation](https://docs.logto.io/)
- [Logto GitHub](https://github.com/logto-io/logto)
- [OIDC Integration Guide](https://docs.logto.io/integrate-logto/third-party-applications/)
- [Self-Hosting Guide](https://docs.logto.io/logto-oss/deployment-and-configuration/)
