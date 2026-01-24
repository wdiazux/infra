# Zitadel SSO Design

**Date**: 2026-01-24
**Status**: In Progress (Infrastructure deployed, post-deployment config pending)
**Author**: Claude + wdiaz

## Overview

Zitadel v4.x will serve as the central identity provider for the homelab, providing OIDC/OAuth2 authentication for applications with native support and header-based authentication via forward auth proxy for applications without native SSO.

## Background

### Previous Attempt (Logto)

Logto SSO was removed (commit 8ef2281) due to Cilium Ingress hairpin routing limitations. When internal pods accessed the external domain through Cilium Ingress, traffic was assigned the `reserved:ingress` identity, causing 403 Forbidden errors. This is a known Cilium issue documented in:

- [#28254](https://github.com/cilium/cilium/issues/28254) - Service hairpinning with Envoy
- [#27709](https://github.com/cilium/cilium/issues/27709) - IPv4 Service hairpin return-traffic denied
- [#24536](https://github.com/cilium/cilium/issues/24536) - Ingress traffic interactions with Policy enforcement

### Solution: CoreDNS Rewrite

Internal traffic bypasses Ingress entirely by configuring CoreDNS to resolve `auth.home-infra.net` to Zitadel's fixed ClusterIP. External traffic continues through Cilium Ingress normally.

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        External Traffic                              │
│                    (auth.home-infra.net:443)                        │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Cilium Ingress (10.10.2.20)                       │
│                    TLS Termination + Re-encrypt                      │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        ▼                                      ▼
┌───────────────────┐                ┌─────────────────────┐
│   Zitadel Core    │                │    Zitadel Login    │
│   (Port 8080)     │◄──────────────►│     (Port 3000)     │
│   HTTPS internal  │                │    HTTPS internal   │
└────────┬──────────┘                └─────────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌───────┐
│PostgreSQL│ │ Redis │
│ (5432) │ │(6379) │
└────────┘ └───────┘
```

### Internal Traffic Flow (CoreDNS Rewrite)

```
┌─────────────┐     CoreDNS resolves to      ┌─────────────┐
│   Grafana   │ ──────────────────────────► │   Zitadel   │
│   (pod)     │   ClusterIP 10.96.100.18    │   (pod)     │
└─────────────┘      (bypasses Ingress)      └─────────────┘
```

### Forward Auth Flow (Apps without native OIDC)

```
┌──────────────────────────────────────────────────────────────────┐
│                        Browser Request                            │
│                   (radarr.home-infra.net)                        │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Cilium Ingress + Envoy                         │
│                                                                   │
│  1. ext_authz filter calls oauth2-proxy                          │
│  2. If 401 → redirect to Zitadel login                           │
│  3. If 200 → forward request with user headers                   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Radarr    │    │   Sonarr    │    │   ComfyUI   │
│ (headers)   │    │ (headers)   │    │ (headers)   │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Configuration

### Core Settings

| Setting | Value |
|---------|-------|
| Domain | `auth.home-infra.net` |
| IP Address | `10.10.2.18` (LoadBalancer) |
| ClusterIP | `10.96.100.18` (fixed) |
| Namespace | `auth` |
| Zitadel Version | v4.x (latest) |
| Helm Chart | zitadel/zitadel v9.x |

### Zitadel Configuration

```yaml
ExternalDomain: auth.home-infra.net
ExternalPort: 443
ExternalSecure: true
TLS:
  Enabled: true  # Internal HTTPS
replicaCount: 1  # Single-node homelab
```

### Database (PostgreSQL)

| Setting | Value |
|---------|-------|
| Image | `postgres:17-alpine` |
| Database | `zitadel` |
| User | `zitadel` |
| Port | `5432` |
| Storage | `10Gi` (Longhorn PVC) |
| MaxOpenConns | `20` |
| MaxIdleConns | `10` |
| ConnMaxLifetime | `30m` |

### Cache (Redis)

| Setting | Value |
|---------|-------|
| Image | `redis:8-alpine` |
| Port | `6379` |
| Persistence | Disabled (cache only) |

### TLS Certificates

| Certificate | Issuer | DNS Names | Purpose |
|-------------|--------|-----------|---------|
| `zitadel-tls` | letsencrypt-prod | `auth.home-infra.net` | Cilium Ingress |
| `zitadel-internal-tls` | selfsigned-ca | `zitadel.auth.svc.cluster.local`, `auth.home-infra.net` | Zitadel pods |
| `zitadel-db-tls` | selfsigned-ca | `postgres.auth.svc.cluster.local` | PostgreSQL |

### CoreDNS Rewrite

```yaml
# In CoreDNS ConfigMap
hosts {
    10.96.100.18 auth.home-infra.net
    fallthrough
}
```

Using fixed ClusterIP (`10.96.100.18`) ensures the rewrite never needs updating.

## Application Integration

### Native OIDC Apps

| App | Client Type | Redirect URI | Scopes |
|-----|-------------|--------------|--------|
| Grafana | Web | `https://grafana.home-infra.net/login/generic_oauth` | `openid profile email` |
| Forgejo | Web | `https://git.home-infra.net/user/oauth2/zitadel/callback` | `openid profile email` |
| Open WebUI | Web | `https://ai.home-infra.net/oauth/callback` | `openid profile email` |
| Immich | Web | `https://photos.home-infra.net/auth/login` | `openid profile email` |
| Paperless-ngx | Web | `https://docs.home-infra.net/accounts/oidc/zitadel/login/callback/` | `openid profile email` |
| n8n | Web | `https://n8n.home-infra.net/rest/oauth2-credential/callback` | `openid profile email` |

### Header Auth Apps (via oauth2-proxy)

| App | Header Used | Auth Method |
|-----|-------------|-------------|
| Radarr | `X-Auth-Request-User` | Remote auth header |
| Sonarr | `X-Auth-Request-User` | Remote auth header |
| Prowlarr | `X-Auth-Request-User` | Remote auth header |
| Bazarr | `X-Auth-Request-User` | Remote auth header |
| SABnzbd | `X-Auth-Request-User` | Remote auth header |
| qBittorrent | `X-Auth-Request-User` | Remote auth header |
| ComfyUI | `X-Auth-Request-User` | Trusted header |
| IT-Tools | `X-Auth-Request-Email` | Display only |

### oauth2-proxy Configuration

```yaml
Provider: oidc
OIDC Issuer: https://auth.home-infra.net
Upstream: static://200
Cookie Secure: true
Set X-Auth-Request: true
Pass Access Token: true
```

### Forward Auth Strategy

**Primary**: CiliumEnvoyConfig with ext_authz filter

```yaml
apiVersion: cilium.io/v2
kind: CiliumEnvoyConfig
metadata:
  name: forward-auth
  namespace: auth
spec:
  services:
    - name: radarr
      namespace: media
    # ... other apps
  resources:
    - "@type": type.googleapis.com/envoy.config.listener.v3.Listener
      # ext_authz filter pointing to oauth2-proxy
```

**Fallback**: Traefik IngressRoute with ForwardAuth middleware (if CiliumEnvoyConfig proves unreliable)

## Network Policies

### Ingress Rules

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| `ingress` entity | Zitadel | 8080 | External HTTPS traffic |
| Any namespace pod | Zitadel (ClusterIP) | 8080 | Internal OIDC (via CoreDNS rewrite) |
| Zitadel | PostgreSQL | 5432 | Database |
| Zitadel | Redis | 6379 | Cache |
| oauth2-proxy | Zitadel | 8080 | Token validation |
| Cilium Envoy | oauth2-proxy | 4180 | Forward auth |

### Egress Rules

```yaml
# Zitadel needs external access for:
# - SMTP (email notifications)
# - External IdP federation (if configured)
egress:
  - toEntities:
      - world
    toPorts:
      - ports:
          - port: "443"
          - port: "587"  # SMTP
```

## Repository Structure

```
kubernetes/
├── apps/
│   └── base/
│       └── auth/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           ├── zitadel/
│           │   ├── kustomization.yaml
│           │   ├── helmrelease.yaml
│           │   ├── ingress.yaml
│           │   ├── certificate.yaml
│           │   └── secret.enc.yaml
│           ├── postgres/
│           │   ├── kustomization.yaml
│           │   ├── statefulset.yaml
│           │   ├── service.yaml
│           │   ├── certificate.yaml
│           │   └── secret.enc.yaml
│           ├── redis/
│           │   ├── kustomization.yaml
│           │   ├── deployment.yaml
│           │   ├── service.yaml
│           │   └── secret.enc.yaml
│           ├── oauth2-proxy/
│           │   ├── kustomization.yaml
│           │   ├── deployment.yaml
│           │   ├── service.yaml
│           │   └── secret.enc.yaml
│           └── network-policies.yaml
│
├── infrastructure/
│   ├── cluster-vars/
│   │   └── cluster-vars.yaml           # IP_ZITADEL: 10.10.2.18
│   ├── controllers/
│   │   └── coredns-custom.yaml         # auth.home-infra.net rewrite
│   └── security/
│       └── cilium-envoy-config.yaml    # ext_authz for forward auth
```

## Zitadel Organization Structure

```
Organization: homelab
├── Project: infrastructure
│   ├── App: grafana
│   ├── App: forgejo
│   └── App: oauth2-proxy
├── Project: media
│   └── App: immich
└── Users
    └── wdiaz (admin)
```

## Implementation Phases

### Phase 1: Core Infrastructure
1. Create `auth` namespace with labels
2. Deploy PostgreSQL StatefulSet with TLS
3. Deploy Redis with password auth
4. Create internal certificates (cert-manager)

### Phase 2: Zitadel Deployment
5. Add `IP_ZITADEL: 10.10.2.18` to cluster-vars
6. Deploy Zitadel via HelmRelease
7. Configure Ingress with Let's Encrypt TLS
8. Update CoreDNS with fixed ClusterIP rewrite
9. Apply NetworkPolicies

### Phase 3: Verify Core SSO
10. Access `https://auth.home-infra.net`
11. Login with initial admin credentials
12. Create organization and first project

### Phase 4: Native OIDC Integration
13. Create Zitadel applications for Grafana, Forgejo, etc.
14. Configure each app with OIDC settings
15. Test login flow for each app

### Phase 5: Forward Auth (CiliumEnvoyConfig)
16. Deploy oauth2-proxy
17. Create Zitadel application for oauth2-proxy
18. Apply CiliumEnvoyConfig with ext_authz
19. Test with one arr-stack app (e.g., Radarr)
20. If working, extend to remaining apps
21. If failing, implement Traefik fallback

## Environment Variables Reference

### Zitadel Core

| Variable | Description | Default |
|----------|-------------|---------|
| `ZITADEL_DATABASE_POSTGRES_HOST` | PostgreSQL host | `localhost` |
| `ZITADEL_DATABASE_POSTGRES_PORT` | PostgreSQL port | `5432` |
| `ZITADEL_DATABASE_POSTGRES_DATABASE` | Database name | `zitadel` |
| `ZITADEL_DATABASE_POSTGRES_USER_USERNAME` | Database user | - |
| `ZITADEL_DATABASE_POSTGRES_USER_PASSWORD` | Database password | - |
| `ZITADEL_DATABASE_POSTGRES_MAXOPENCONNS` | Max open connections | `10` |
| `ZITADEL_DATABASE_POSTGRES_MAXIDLECONNS` | Max idle connections | `5` |
| `ZITADEL_EXTERNALDOMAIN` | External domain | `localhost` |
| `ZITADEL_EXTERNALPORT` | External port | `8080` |
| `ZITADEL_EXTERNALSECURE` | HTTPS requirement | `true` |
| `ZITADEL_TLS_ENABLED` | Enable internal TLS | `true` |
| `ZITADEL_TLS_CERTPATH` | Certificate path | - |
| `ZITADEL_TLS_KEYPATH` | Key path | - |
| `ZITADEL_CACHES_REDIS_ENABLED` | Enable Redis cache | `false` |
| `ZITADEL_CACHES_REDIS_ADDR` | Redis address | `localhost:6379` |
| `ZITADEL_MASTERKEY` | 32-char encryption key | - |

### Helm Chart Values

Key values for `zitadel/zitadel` chart:

```yaml
replicaCount: 1
image:
  repository: ghcr.io/zitadel/zitadel
  tag: ""  # Uses appVersion

zitadel:
  masterkey: ""  # 32-character key
  configmapConfig:
    ExternalSecure: true
    ExternalDomain: auth.home-infra.net
    ExternalPort: 443
    TLS:
      Enabled: true
    Database:
      Postgres:
        Host: postgres.auth.svc.cluster.local
        Port: 5432
        Database: zitadel
        MaxOpenConns: 20
        MaxIdleConns: 10
    Caches:
      Connector:
        Redis:
          Enabled: true
          Addr: redis.auth.svc.cluster.local:6379

ingress:
  enabled: true
  className: cilium
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    ingress.cilium.io/backend-protocol: HTTPS
  hosts:
    - host: auth.home-infra.net
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: zitadel-tls
      hosts:
        - auth.home-infra.net

login:
  enabled: true
  ingress:
    enabled: true

service:
  type: ClusterIP
  port: 8080
  clusterIP: 10.96.100.18  # Fixed ClusterIP
```

## Security Considerations

1. **Secrets**: All sensitive data (masterkey, database credentials, Redis password, OAuth client secrets) encrypted with SOPS
2. **TLS**: End-to-end encryption - Let's Encrypt for external, self-signed CA for internal
3. **Network Policies**: Strict ingress/egress rules limiting access to required paths only
4. **Non-root**: All containers run as non-root user (UID 1000)
5. **Read-only filesystem**: Where supported by the application

## Fallback Plan

If CiliumEnvoyConfig with ext_authz proves unreliable for forward auth:

1. Deploy Traefik IngressController alongside Cilium
2. Create Traefik IngressRoutes only for apps needing forward auth
3. Use Traefik's ForwardAuth middleware pointing to oauth2-proxy
4. Keep Cilium Ingress for all other apps

## References

- [Zitadel Kubernetes Docs](https://zitadel.com/docs/self-hosting/deploy/kubernetes)
- [Zitadel Helm Charts](https://github.com/zitadel/zitadel-charts)
- [Zitadel v4 Release](https://zitadel.com/blog/announcing-the-general-availability-of-zitadel-v4)
- [Cilium Ingress Docs](https://docs.cilium.io/en/stable/network/servicemesh/ingress/)
- [Cilium ext_authz CFP #23797](https://github.com/cilium/cilium/issues/23797)
- [oauth2-proxy Docs](https://oauth2-proxy.github.io/oauth2-proxy/)
