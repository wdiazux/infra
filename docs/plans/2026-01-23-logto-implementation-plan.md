# Logto Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Casdoor SSO with Logto for better developer experience (modern UI, clean APIs, excellent documentation).

**Architecture:** Logto server + PostgreSQL deployed in auth namespace. Admin console on port 80, user auth on port 3001. Single LoadBalancer IP (10.10.2.18).

**Tech Stack:** Logto (OIDC/OAuth2), PostgreSQL 17, Kubernetes, FluxCD, SOPS, Cilium NetworkPolicies

---

## Phase 1: Remove Casdoor

### Task 1: Remove Casdoor NetworkPolicies

**Files:**
- Modify: `kubernetes/infrastructure/security/network-policies.yaml` (lines 1345-1481)

**Step 1: Delete Casdoor NetworkPolicy section**

Remove lines 1345-1481 (the entire auth namespace section including):
- `auth-default-deny-egress`
- `auth-casdoor-allow`
- `auth-casdoor-postgres-allow`
- `auth-casdoor-redis-allow`

**Step 2: Verify removal**

```bash
grep -n "casdoor" kubernetes/infrastructure/security/network-policies.yaml
```
Expected: No matches

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/security/network-policies.yaml
git commit -m "refactor(auth): remove Casdoor NetworkPolicies

Preparing for Logto migration. New policies will be added in next commit."
```

---

### Task 2: Remove Casdoor Image Automation

**Files:**
- Delete: `kubernetes/infrastructure/image-automation/policies/auth.yaml`

**Step 1: Delete the file**

```bash
rm kubernetes/infrastructure/image-automation/policies/auth.yaml
```

**Step 2: Verify deletion**

```bash
ls kubernetes/infrastructure/image-automation/policies/auth.yaml
```
Expected: No such file

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/image-automation/policies/auth.yaml
git commit -m "refactor(auth): remove Casdoor image automation policy"
```

---

### Task 3: Remove Casdoor Manifests

**Files:**
- Delete: `kubernetes/apps/base/auth/casdoor/` (entire directory)
- Modify: `kubernetes/apps/base/auth/kustomization.yaml`

**Step 1: Delete casdoor directory**

```bash
rm -rf kubernetes/apps/base/auth/casdoor
```

**Step 2: Update auth kustomization**

Replace contents of `kubernetes/apps/base/auth/kustomization.yaml` with:

```yaml
# Auth namespace - authentication and SSO services
#
# Services:
#   - Logto: SSO/IAM platform (10.10.2.18)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - logto
```

**Step 3: Verify directory removed**

```bash
ls kubernetes/apps/base/auth/
```
Expected: Only `kustomization.yaml` (logto directory doesn't exist yet)

**Step 4: Commit**

```bash
git add kubernetes/apps/base/auth/
git commit -m "refactor(auth): remove Casdoor deployment manifests

FluxCD will remove Casdoor resources on next reconciliation."
```

---

### Task 4: Update Cluster Variables

**Files:**
- Modify: `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`

**Step 1: Rename IP variable**

Change line 29:
```yaml
  IP_CASDOOR: "10.10.2.18"
```
to:
```yaml
  IP_LOGTO: "10.10.2.18"
```

**Step 2: Verify change**

```bash
grep "IP_LOGTO" kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
```
Expected: `IP_LOGTO: "10.10.2.18"`

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
git commit -m "refactor(auth): rename IP_CASDOOR to IP_LOGTO"
```

---

## Phase 2: Deploy Logto

### Task 5: Create Logto Secret

**Files:**
- Create: `kubernetes/apps/base/auth/logto/secret.enc.yaml`

**Step 1: Create logto directory**

```bash
mkdir -p kubernetes/apps/base/auth/logto
```

**Step 2: Create unencrypted secret file**

Create `kubernetes/apps/base/auth/logto/secret.yaml`:

```yaml
# Logto Secrets
#
# Contains PostgreSQL credentials.
apiVersion: v1
kind: Secret
metadata:
  name: logto-secrets
  namespace: auth
  labels:
    app.kubernetes.io/name: logto
    app.kubernetes.io/component: secrets
    app.kubernetes.io/part-of: logto
type: Opaque
stringData:
  POSTGRES_PASSWORD: "<generate-secure-password>"
```

**Step 3: Generate and insert password**

```bash
# Generate a secure password
openssl rand -base64 24
# Replace <generate-secure-password> with the generated password
```

**Step 4: Encrypt with SOPS**

```bash
sops -e kubernetes/apps/base/auth/logto/secret.yaml > kubernetes/apps/base/auth/logto/secret.enc.yaml
rm kubernetes/apps/base/auth/logto/secret.yaml
```

**Step 5: Verify encryption**

```bash
grep "ENC\[AES256" kubernetes/apps/base/auth/logto/secret.enc.yaml
```
Expected: Shows encrypted POSTGRES_PASSWORD

---

### Task 6: Create Logto PostgreSQL StatefulSet

**Files:**
- Create: `kubernetes/apps/base/auth/logto/postgres-statefulset.yaml`

**Step 1: Create the StatefulSet**

Create `kubernetes/apps/base/auth/logto/postgres-statefulset.yaml`:

```yaml
# Logto PostgreSQL StatefulSet
#
# PostgreSQL 17 database for Logto.
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: logto-postgres
  namespace: auth
  labels:
    app.kubernetes.io/name: logto-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: logto
spec:
  serviceName: logto-postgres
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: logto-postgres
  template:
    metadata:
      labels:
        app.kubernetes.io/name: logto-postgres
        app.kubernetes.io/component: database
        app.kubernetes.io/part-of: logto
    spec:
      securityContext:
        fsGroup: 999
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: postgres
          image: postgres:17-alpine
          ports:
            - name: postgres
              containerPort: 5432
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: POSTGRES_DB
              value: logto
            - name: POSTGRES_USER
              value: logto
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: logto-secrets
                  key: POSTGRES_PASSWORD
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - logto
                - -d
                - logto
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - logto
                - -d
                - logto
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              memory: 128Mi
            limits:
              memory: 512Mi
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: longhorn
        resources:
          requests:
            storage: 1Gi
```

**Step 2: Verify syntax**

```bash
kubectl apply --dry-run=client -f kubernetes/apps/base/auth/logto/postgres-statefulset.yaml
```
Expected: statefulset.apps/logto-postgres created (dry run)

---

### Task 7: Create Logto Server Deployment

**Files:**
- Create: `kubernetes/apps/base/auth/logto/server-deployment.yaml`

**Step 1: Create the Deployment**

Create `kubernetes/apps/base/auth/logto/server-deployment.yaml`:

```yaml
# Logto Server Deployment
#
# Main SSO/IAM application server.
# https://docs.logto.io/
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logto-server
  namespace: auth
  labels:
    app.kubernetes.io/name: logto-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: logto
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: logto-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: logto-server
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: logto
    spec:
      enableServiceLinks: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      initContainers:
        # Wait for PostgreSQL to be ready
        - name: wait-for-db
          image: postgres:17-alpine
          command:
            - sh
            - -c
            - |
              until pg_isready -h logto-postgres -p 5432 -U logto; do
                echo "Waiting for PostgreSQL..."
                sleep 2
              done
              echo "PostgreSQL is ready"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
      containers:
        - name: logto
          image: ghcr.io/logto-io/logto:1.27.0 # {"$imagepolicy": "flux-system:logto"}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          ports:
            - name: app
              containerPort: 3001
              protocol: TCP
            - name: admin
              containerPort: 3002
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: NODE_ENV
              value: "production"
            - name: TRUST_PROXY_HEADER
              value: "1"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: logto-secrets
                  key: POSTGRES_PASSWORD
            - name: DB_URL
              value: "postgres://logto:$(POSTGRES_PASSWORD)@logto-postgres:5432/logto"
            - name: ENDPOINT
              value: "http://auth.${DOMAIN_PRIMARY}:3001"
            - name: ADMIN_ENDPOINT
              value: "http://auth.${DOMAIN_PRIMARY}"
          startupProbe:
            httpGet:
              path: /api/status
              port: app
            failureThreshold: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /api/status
              port: app
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /api/status
              port: app
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              memory: 256Mi
              cpu: 100m
            limits:
              memory: 512Mi
```

**Step 2: Verify syntax**

```bash
kubectl apply --dry-run=client -f kubernetes/apps/base/auth/logto/server-deployment.yaml
```
Expected: deployment.apps/logto-server created (dry run)

---

### Task 8: Create Logto Services

**Files:**
- Create: `kubernetes/apps/base/auth/logto/services.yaml`

**Step 1: Create the Services**

Create `kubernetes/apps/base/auth/logto/services.yaml`:

```yaml
# Logto Services
---
# PostgreSQL Service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: logto-postgres
  namespace: auth
  labels:
    app.kubernetes.io/name: logto-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: logto
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: logto-postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
      protocol: TCP
---
# Logto Server Service (LoadBalancer)
apiVersion: v1
kind: Service
metadata:
  name: logto
  namespace: auth
  labels:
    app.kubernetes.io/name: logto-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: logto
  annotations:
    io.cilium/lb-ipam-ips: "${IP_LOGTO}"
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: logto-server
  ports:
    - name: admin
      port: 80
      targetPort: 3002
      protocol: TCP
    - name: app
      port: 3001
      targetPort: 3001
      protocol: TCP
```

**Step 2: Verify syntax**

```bash
kubectl apply --dry-run=client -f kubernetes/apps/base/auth/logto/services.yaml
```
Expected: service/logto-postgres created (dry run), service/logto created (dry run)

---

### Task 9: Create Logto Kustomization

**Files:**
- Create: `kubernetes/apps/base/auth/logto/kustomization.yaml`

**Step 1: Create the Kustomization**

Create `kubernetes/apps/base/auth/logto/kustomization.yaml`:

```yaml
# Logto Kustomization
#
# SSO/IAM platform with PostgreSQL.
# https://docs.logto.io/
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - secret.enc.yaml
  - postgres-statefulset.yaml
  - server-deployment.yaml
  - services.yaml
```

**Step 2: Verify kustomization builds**

```bash
kubectl kustomize kubernetes/apps/base/auth/logto/ | head -50
```
Expected: Combined YAML output without errors

---

### Task 10: Add Logto NetworkPolicies

**Files:**
- Modify: `kubernetes/infrastructure/security/network-policies.yaml`

**Step 1: Add Logto NetworkPolicies**

Add the following at the end of the file:

```yaml
# =============================================================================
# Auth Namespace - SSO/IAM (Logto)
# =============================================================================

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-default-deny-egress
  namespace: auth
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    # Allow DNS queries
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-logto-allow
  namespace: auth
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: logto-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from LoadBalancer (Cilium L2 - host network traffic)
    - ports:
        - protocol: TCP
          port: 3001
        - protocol: TCP
          port: 3002
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow PostgreSQL
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: logto-postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow HTTPS for social login providers (GitHub, Google, etc.)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-logto-postgres-allow
  namespace: auth
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: logto-postgres
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow connections from logto-server
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: logto-server
      ports:
        - protocol: TCP
          port: 5432
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

**Step 2: Verify syntax**

```bash
kubectl apply --dry-run=client -f kubernetes/infrastructure/security/network-policies.yaml
```
Expected: All NetworkPolicies created (dry run)

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/security/network-policies.yaml
git commit -m "feat(auth): add Logto NetworkPolicies"
```

---

### Task 11: Create Logto Image Automation

**Files:**
- Create: `kubernetes/infrastructure/image-automation/policies/auth.yaml`

**Step 1: Create the image policy**

Create `kubernetes/infrastructure/image-automation/policies/auth.yaml`:

```yaml
# Auth Namespace Image Policies
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: logto
  namespace: flux-system
spec:
  image: ghcr.io/logto-io/logto
  interval: 12h
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: logto
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: logto
  filterTags:
    # Match semver tags: 1.27.0, 1.28.0, etc.
    pattern: '^[0-9]+\.[0-9]+\.[0-9]+$'
  policy:
    semver:
      range: ">=1.0.0"
```

**Step 2: Verify syntax**

```bash
kubectl apply --dry-run=client -f kubernetes/infrastructure/image-automation/policies/auth.yaml
```
Expected: imagerepository.image.toolkit.fluxcd.io/logto created (dry run), imagepolicy.image.toolkit.fluxcd.io/logto created (dry run)

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/image-automation/policies/auth.yaml
git commit -m "feat(auth): add Logto image automation policy"
```

---

### Task 12: Commit All Logto Manifests

**Files:**
- All files in `kubernetes/apps/base/auth/logto/`
- `kubernetes/apps/base/auth/kustomization.yaml`

**Step 1: Stage all auth files**

```bash
git add kubernetes/apps/base/auth/
```

**Step 2: Commit**

```bash
git commit -m "feat(auth): deploy Logto SSO/IAM platform

Replaces Casdoor with Logto for better developer experience.

Components:
- Logto server (ghcr.io/logto-io/logto:1.27.0)
- PostgreSQL 17 for persistence
- LoadBalancer on 10.10.2.18 (port 80: admin, port 3001: auth)

OIDC endpoints:
- Discovery: http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration
- Admin console: http://auth.home-infra.net"
```

---

## Phase 3: Verify & Document

### Task 13: Push Changes and Verify Deployment

**Step 1: Push to remote**

```bash
git push
```

**Step 2: Watch FluxCD reconciliation**

```bash
flux reconcile kustomization flux-system --with-source
kubectl -n auth get pods -w
```
Expected: logto-postgres and logto-server pods running

**Step 3: Verify services**

```bash
kubectl -n auth get svc
```
Expected: logto service with EXTERNAL-IP 10.10.2.18

**Step 4: Test admin console**

```bash
curl -s http://10.10.2.18 | head -20
```
Expected: HTML response from Logto admin console

**Step 5: Test OIDC discovery**

```bash
curl -s http://10.10.2.18:3001/oidc/.well-known/openid-configuration | jq .
```
Expected: JSON with issuer, authorization_endpoint, token_endpoint, etc.

---

### Task 14: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update network table**

Change line 96:
```
| Casdoor | 10.10.2.18 | SSO/IAM |
```
to:
```
| Logto | 10.10.2.18 | SSO/IAM |
```

**Step 2: Update recent changes section**

Add entry:
```
- **2026-01-23**: Replaced Casdoor with Logto for SSO/IAM
```

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for Casdoor → Logto migration"
```

---

### Task 15: Create Logto Service Documentation

**Files:**
- Create: `docs/services/logto.md`

**Step 1: Create service doc**

Create `docs/services/logto.md`:

```markdown
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
kubectl -n auth exec -it deploy/logto-server -- sh -c 'pg_isready -h logto-postgres -U logto'
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
```

**Step 2: Commit**

```bash
git add docs/services/logto.md
git commit -m "docs: add Logto service documentation"
```

---

### Task 16: Update SSO Integration Plan

**Files:**
- Modify: `docs/plans/2026-01-23-sso-integration-plan.md`

**Step 1: Update title and references**

Change all "Casdoor" references to "Logto" and update OIDC endpoints:

- Old: `http://auth.home-infra.net/login/oauth/authorize`
- New: `http://auth.home-infra.net:3001/oidc/auth`

- Old: `http://auth.home-infra.net/api/login/oauth/access_token`
- New: `http://auth.home-infra.net:3001/oidc/token`

- Old: `http://auth.home-infra.net/.well-known/openid-configuration`
- New: `http://auth.home-infra.net:3001/oidc/.well-known/openid-configuration`

**Step 2: Remove Casdoor-specific workarounds**

Delete the "User Creation Issue" section (lines 29-56) as Logto has a working API.

**Step 3: Commit**

```bash
git add docs/plans/2026-01-23-sso-integration-plan.md
git commit -m "docs: update SSO integration plan for Logto endpoints"
```

---

### Task 17: Delete Casdoor Design Doc

**Files:**
- Delete: `docs/plans/2026-01-22-casdoor-sso-design.md`

**Step 1: Delete the file**

```bash
rm docs/plans/2026-01-22-casdoor-sso-design.md
```

**Step 2: Commit**

```bash
git add docs/plans/2026-01-22-casdoor-sso-design.md
git commit -m "docs: remove obsolete Casdoor design doc (superseded by Logto)"
```

---

### Task 18: Final Push and Verification

**Step 1: Push all changes**

```bash
git push
```

**Step 2: Final verification checklist**

- [ ] Admin console accessible at http://10.10.2.18
- [ ] OIDC discovery returns valid JSON at http://10.10.2.18:3001/oidc/.well-known/openid-configuration
- [ ] Can create first admin user in Logto console
- [ ] NetworkPolicies active: `kubectl -n auth get networkpolicies`
- [ ] No Casdoor resources remain: `kubectl -n auth get all | grep casdoor`

---

## Summary

Total tasks: 18
- Phase 1 (Remove Casdoor): Tasks 1-4
- Phase 2 (Deploy Logto): Tasks 5-12
- Phase 3 (Verify & Document): Tasks 13-18

After completion:
- Logto running at 10.10.2.18 (admin:80, auth:3001)
- All documentation updated
- Ready for service integrations (Grafana, Forgejo, etc.)
