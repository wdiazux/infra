# Zitadel

Single Sign-On (SSO) identity provider for the homelab.

---

## Overview

Zitadel provides OIDC-based authentication for all homelab services. It handles user management, OAuth2/OIDC flows, and integrates with applications via standard protocols.

| Property | Value |
|----------|-------|
| Namespace | `auth` |
| Chart | `zitadel/zitadel` |
| Version | `9.17.0` |
| URL | `https://auth.home-infra.net` |

**Key Features:**

| Feature | Description |
|---------|-------------|
| OIDC Provider | OpenID Connect for SSO |
| User Management | Self-service and admin user management |
| Machine Users | Service account authentication |
| Multi-tenant | Organization-based isolation |

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│  Gateway API    │────▶│  Zitadel        │
│  (10.10.2.20)   │     │  ClusterIP      │
│  Port 443       │     │  10.96.100.18   │
└─────────────────┘     └────────┬────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  PostgreSQL     │     │  Redis          │     │  CoreDNS        │
│  (auth ns)      │     │  (auth ns)      │     │  Rewrite        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Configuration

### External Access

| Setting | Value |
|---------|-------|
| External Domain | `auth.home-infra.net` |
| External Port | `443` |
| External Secure | `true` |
| TLS Termination | Gateway API (not Zitadel) |

### Database

| Setting | Value |
|---------|-------|
| Host | `zitadel-postgres.auth.svc.cluster.local` |
| Port | `5432` |
| Database | `zitadel` |
| User | `zitadel` |
| SSL Mode | `disable` (internal traffic) |

### Cache

| Setting | Value |
|---------|-------|
| Redis Host | `zitadel-redis.auth.svc.cluster.local:6379` |
| Purpose | Session caching, performance |

---

## First Instance Configuration

On initial deployment, Zitadel creates:

| Resource | Value |
|----------|-------|
| Organization | `HOMELAB` |
| Admin Username | `root@wdiaz.org` |
| Admin Email | `root@wdiaz.org` |
| Password | From `zitadel-secrets` secret |

---

## CoreDNS Hairpin Fix

Services inside the cluster need to reach Zitadel at `auth.home-infra.net`. To avoid hairpin routing issues, CoreDNS rewrites the domain to the fixed ClusterIP:

```yaml
# In CoreDNS ConfigMap
rewrite name auth.home-infra.net zitadel.auth.svc.cluster.local
```

The Zitadel service uses a fixed ClusterIP (`10.96.100.18`) to ensure stable internal routing.

---

## Integrated Applications

Zitadel provides OIDC authentication for:

| Application | Namespace | Integration |
|-------------|-----------|-------------|
| Open WebUI | ai | Native OIDC |
| Immich | media | Native OIDC (config file) |
| oauth2-proxy | auth | Forward auth for legacy apps |
| Forgejo | forgejo | Native OIDC |
| Grafana | monitoring | Native OIDC |

---

## OIDC Application Setup

### Create New Application

1. Login to `https://auth.home-infra.net`
2. Navigate to **Projects** > **Create Project** (or use existing)
3. **Add Application** > **Web** > **OIDC**
4. Configure:
   - **Redirect URIs**: `https://app.home-infra.net/callback`
   - **Post Logout URIs**: `https://app.home-infra.net`
   - **Grant Types**: Authorization Code
   - **Auth Method**: Client Secret Basic or Post

### Retrieve Credentials

```bash
# Client ID is shown in application settings
# Client Secret: Generate in application > Keys

# For automated credential management, use machine users
# with the iam-admin service account key
```

---

## Machine Users

Zitadel creates a machine user (`iam-admin`) for API access:

```bash
# The key is stored in Kubernetes secret
kubectl get secret iam-admin -n auth -o jsonpath='{.data.key}' | base64 -d
```

This is used by CronJobs that automatically create/rotate OIDC credentials for applications.

---

## Common Operations

### Access Admin Console

```bash
# Via Gateway API
open https://auth.home-infra.net

# Via port-forward (troubleshooting)
kubectl port-forward -n auth svc/zitadel 8080:8080
open http://localhost:8080
```

### View Logs

```bash
# Zitadel logs
kubectl logs -n auth deployment/zitadel --tail=100

# Init job logs (first deployment)
kubectl logs -n auth job/zitadel-init --tail=100
```

### Reset Admin Password

```bash
# Update the secret
kubectl create secret generic zitadel-secrets -n auth \
  --from-literal=masterkey=$(openssl rand -base64 32) \
  --from-literal=ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD='NewPassword123!' \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Zitadel
kubectl rollout restart deployment/zitadel -n auth
```

---

## Verification

```bash
# Check Zitadel pods
kubectl get pods -n auth -l app.kubernetes.io/name=zitadel

# Check service
kubectl get svc -n auth zitadel

# Test OIDC discovery
curl -s https://auth.home-infra.net/.well-known/openid-configuration | jq .

# Check database connectivity
kubectl exec -n auth deployment/zitadel -- \
  wget -qO- http://localhost:8080/debug/healthz
```

---

## Troubleshooting

### Login Redirects Fail

```bash
# Verify external domain configuration
kubectl get configmap -n auth zitadel -o yaml | grep -A5 ExternalDomain

# Check Gateway API route
kubectl get httproute -n auth -o wide

# Verify CoreDNS rewrite (for internal services)
kubectl get configmap -n kube-system coredns -o yaml | grep auth.home-infra.net
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n auth -l app=zitadel-postgres

# Test connection
kubectl exec -n auth deployment/zitadel -- \
  pg_isready -h zitadel-postgres -p 5432 -U zitadel
```

### Redis Connection Issues

```bash
# Check Redis pod
kubectl get pods -n auth -l app=zitadel-redis

# Test connection
kubectl exec -n auth deployment/zitadel -- \
  redis-cli -h zitadel-redis ping
```

---

## Resources

| Resource | Requests | Limits |
|----------|----------|--------|
| CPU | 50m | - |
| Memory | 128Mi | 512Mi |

---

## Secrets

| Secret | Keys | Purpose |
|--------|------|---------|
| `zitadel-secrets` | `masterkey`, `ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD` | Encryption and admin setup |
| `zitadel-postgres-secrets` | `POSTGRES_PASSWORD` | Database authentication |
| `zitadel-redis-secrets` | `REDIS_PASSWORD` | Cache authentication |
| `iam-admin` | `key` | Machine user for API access |

---

## Documentation

- [Zitadel Documentation](https://zitadel.com/docs/)
- [Self-hosting Guide](https://zitadel.com/docs/self-hosting/deploy/kubernetes)
- [OIDC Configuration](https://zitadel.com/docs/guides/integrate/login/oidc)
- [API Reference](https://zitadel.com/docs/apis/introduction)

---

**Last Updated:** 2026-01-28
