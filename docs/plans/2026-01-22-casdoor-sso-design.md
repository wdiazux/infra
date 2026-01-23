# Casdoor SSO Service Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy Casdoor SSO/IAM platform with PostgreSQL and Redis in a dedicated auth namespace.

**Architecture:** New `auth` namespace with Casdoor server, PostgreSQL StatefulSet for persistence, Redis for session storage. LoadBalancer exposes service at 10.10.2.18. NetworkPolicies restrict traffic.

**Tech Stack:** Kubernetes manifests, Kustomize, SOPS encryption, Longhorn storage, Cilium NetworkPolicies

---

**Date:** 2026-01-22
**Status:** Approved
**Author:** Claude + wdiaz

## Overview

Deploy Casdoor as the SSO/IAM platform for the homelab, providing centralized authentication via OAuth 2.0, OIDC, SAML, and LDAP.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      auth namespace                          │
│                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Casdoor   │───▶│  PostgreSQL │    │    Redis    │     │
│  │   :8000     │    │    :5432    │    │    :6379    │     │
│  └──────┬──────┘    └─────────────┘    └─────────────┘     │
│         │                                                    │
│         │ LoadBalancer 10.10.2.18                           │
└─────────┼───────────────────────────────────────────────────┘
          │
          ▼
    auth.home-infra.net
    auth.home.arpa
```

## Components

| Component | Image | Port | Storage |
|-----------|-------|------|---------|
| Casdoor | `casbin/casdoor:v2.257.0` | 8000 | - |
| PostgreSQL | `postgres:16-alpine` | 5432 | 1Gi (Longhorn) |
| Redis | `redis:7-alpine` | 6379 | 256Mi (Longhorn) |

## Configuration

### Casdoor Environment Variables

| Variable | Value | Source |
|----------|-------|--------|
| `driverName` | `postgres` | literal |
| `dataSourceName` | `user=casdoor password=xxx host=casdoor-postgres port=5432 sslmode=disable dbname=casdoor` | secret |
| `dbName` | `casdoor` | literal |
| `redisEndpoint` | `casdoor-redis:6379` | literal |
| `origin` | `http://auth.${DOMAIN_PRIMARY}` | cluster-vars |
| `httpport` | `8000` | literal |
| `runmode` | `prod` | literal |
| `initDataFile` | `/init/init_data.json` | literal |

### Secrets (SOPS encrypted)

| Key | Purpose |
|-----|---------|
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `ADMIN_USER` | Initial admin username |
| `ADMIN_PASSWORD` | Initial admin password |

### Init Data

The `init_data.json` ConfigMap bootstraps Casdoor with:
- Built-in organization
- Admin user with configured credentials
- Default application for homelab

An init container substitutes secret values into `init_data.json` before Casdoor starts.

## Network

- **LoadBalancer IP:** 10.10.2.18
- **Primary domain:** auth.home-infra.net
- **Secondary domain:** auth.home.arpa

## NetworkPolicies

| Policy | Ingress | Egress |
|--------|---------|--------|
| `auth-default-deny-egress` | - | DNS only |
| `auth-casdoor-allow` | LoadBalancer:8000 | DNS, PostgreSQL:5432, Redis:6379, HTTPS:443 |
| `auth-casdoor-postgres-allow` | casdoor-server:5432 | DNS |
| `auth-casdoor-redis-allow` | casdoor-server:6379 | DNS |

HTTPS egress required for OAuth providers (GitHub, Google, etc.).

## File Structure

### Files to Create (10 files)

```
kubernetes/
├── infrastructure/
│   └── namespaces/
│       └── auth.yaml
│
└── apps/
    └── base/
        └── auth/
            ├── kustomization.yaml
            └── casdoor/
                ├── kustomization.yaml
                ├── secret.enc.yaml
                ├── init-data-configmap.yaml
                ├── postgres-statefulset.yaml
                ├── redis-deployment.yaml
                ├── server-deployment.yaml
                ├── services.yaml
                └── pvc.yaml
```

### Files to Modify (4 files)

| File | Change |
|------|--------|
| `kubernetes/infrastructure/namespaces/kustomization.yaml` | Add `auth.yaml` |
| `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml` | Add `IP_CASDOOR: "10.10.2.18"` |
| `kubernetes/infrastructure/security/network-policies.yaml` | Add auth namespace policies |
| `kubernetes/apps/production/kustomization.yaml` | Add `../base/auth/` |

## Post-Deployment

1. Access `http://auth.home-infra.net`
2. Login with configured admin credentials
3. Configure DNS for `auth.home.arpa`
4. Change admin password if desired

## Future Integration

After Casdoor is running, create a separate plan for integrating:
- Grafana (native OIDC)
- Forgejo (OAuth2)
- n8n (OAuth2)
- Immich (OIDC)
- Home Assistant (OAuth2)

## References

- [Casdoor Documentation](https://casdoor.org/docs/)
- [Helm Chart](https://github.com/casdoor/casdoor-helm)
- [Docker Hub](https://hub.docker.com/r/casbin/casdoor)
- [Kubernetes OIDC Integration](https://casdoor.org/docs/integration/go/kubernetes/)

---

# Implementation Tasks

## Task 1: Infrastructure - Namespace and Cluster Variables

**Files:**
- Create: `kubernetes/infrastructure/namespaces/auth.yaml`
- Modify: `kubernetes/infrastructure/namespaces/kustomization.yaml`
- Modify: `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`

**Step 1: Create auth namespace**

Create `kubernetes/infrastructure/namespaces/auth.yaml`:

```yaml
# Auth Namespace
#
# Authentication and SSO services.
# Services: casdoor
apiVersion: v1
kind: Namespace
metadata:
  name: auth
  labels:
    app.kubernetes.io/name: auth
    purpose: authentication
```

**Step 2: Add namespace to kustomization**

Add `- auth.yaml` to `kubernetes/infrastructure/namespaces/kustomization.yaml` resources list.

**Step 3: Add IP_CASDOOR to cluster-vars**

Add to `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml` in the Infrastructure section:

```yaml
  # Service IPs - Auth
  IP_CASDOOR: "10.10.2.18"
```

**Step 4: Validate kustomize build**

Run: `kustomize build kubernetes/infrastructure/namespaces/`
Expected: Valid YAML output including auth namespace

**Step 5: Commit**

```bash
git add kubernetes/infrastructure/namespaces/ kubernetes/infrastructure/cluster-vars/
git commit -m "feat(auth): add auth namespace and IP_CASDOOR variable"
```

---

## Task 2: Create Casdoor Directory Structure

**Files:**
- Create: `kubernetes/apps/base/auth/kustomization.yaml`
- Create: `kubernetes/apps/base/auth/casdoor/kustomization.yaml`

**Step 1: Create auth namespace kustomization**

Create `kubernetes/apps/base/auth/kustomization.yaml`:

```yaml
# Auth namespace - authentication and SSO services
#
# Services:
#   - Casdoor: SSO/IAM platform (10.10.2.18)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - casdoor
```

**Step 2: Create casdoor kustomization**

Create `kubernetes/apps/base/auth/casdoor/kustomization.yaml`:

```yaml
# Casdoor Kustomization
#
# SSO/IAM platform with PostgreSQL and Redis.
# https://casdoor.org/
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - secret.enc.yaml
  - init-data-configmap.yaml
  - postgres-statefulset.yaml
  - redis-deployment.yaml
  - server-deployment.yaml
  - services.yaml
  - pvc.yaml
```

**Step 3: Create directories**

Run: `mkdir -p kubernetes/apps/base/auth/casdoor`

**Step 4: Commit structure**

```bash
git add kubernetes/apps/base/auth/
git commit -m "feat(auth): add casdoor directory structure"
```

---

## Task 3: PostgreSQL StatefulSet

**Files:**
- Create: `kubernetes/apps/base/auth/casdoor/postgres-statefulset.yaml`

**Step 1: Create PostgreSQL StatefulSet**

Create `kubernetes/apps/base/auth/casdoor/postgres-statefulset.yaml`:

```yaml
# Casdoor PostgreSQL StatefulSet
#
# PostgreSQL 16 database for Casdoor metadata.
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: casdoor-postgres
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: casdoor
spec:
  serviceName: casdoor-postgres
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: casdoor-postgres
  template:
    metadata:
      labels:
        app.kubernetes.io/name: casdoor-postgres
        app.kubernetes.io/component: database
        app.kubernetes.io/part-of: casdoor
    spec:
      securityContext:
        fsGroup: 999
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - name: postgres
              containerPort: 5432
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: POSTGRES_DB
              value: casdoor
            - name: POSTGRES_USER
              value: casdoor
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: casdoor-secrets
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
                - casdoor
                - -d
                - casdoor
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - casdoor
                - -d
                - casdoor
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

**Step 2: Commit**

```bash
git add kubernetes/apps/base/auth/casdoor/postgres-statefulset.yaml
git commit -m "feat(auth): add casdoor PostgreSQL statefulset"
```

---

## Task 4: Redis Deployment and PVC

**Files:**
- Create: `kubernetes/apps/base/auth/casdoor/redis-deployment.yaml`
- Create: `kubernetes/apps/base/auth/casdoor/pvc.yaml`

**Step 1: Create Redis PVC**

Create `kubernetes/apps/base/auth/casdoor/pvc.yaml`:

```yaml
# Casdoor Redis PVC
#
# Longhorn storage for Redis persistence.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: casdoor-redis
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: casdoor
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 256Mi
```

**Step 2: Create Redis Deployment**

Create `kubernetes/apps/base/auth/casdoor/redis-deployment.yaml`:

```yaml
# Casdoor Redis Deployment
#
# Redis 7 for session storage.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: casdoor-redis
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: casdoor
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: casdoor-redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: casdoor-redis
        app.kubernetes.io/component: cache
        app.kubernetes.io/part-of: casdoor
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: redis
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          image: redis:7-alpine
          ports:
            - name: redis
              containerPort: 6379
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
          volumeMounts:
            - name: data
              mountPath: /data
          livenessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              memory: 64Mi
            limits:
              memory: 256Mi
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: casdoor-redis
```

**Step 3: Commit**

```bash
git add kubernetes/apps/base/auth/casdoor/pvc.yaml kubernetes/apps/base/auth/casdoor/redis-deployment.yaml
git commit -m "feat(auth): add casdoor Redis deployment and PVC"
```

---

## Task 5: Services

**Files:**
- Create: `kubernetes/apps/base/auth/casdoor/services.yaml`

**Step 1: Create services**

Create `kubernetes/apps/base/auth/casdoor/services.yaml`:

```yaml
# Casdoor Services
---
# PostgreSQL Service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: casdoor-postgres
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-postgres
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: casdoor
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: casdoor-postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
      protocol: TCP
---
# Redis Service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: casdoor-redis
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: casdoor
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: casdoor-redis
  ports:
    - name: redis
      port: 6379
      targetPort: 6379
      protocol: TCP
---
# Casdoor Server Service (LoadBalancer)
apiVersion: v1
kind: Service
metadata:
  name: casdoor
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: casdoor
  annotations:
    io.cilium/lb-ipam-ips: "${IP_CASDOOR}"
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: casdoor-server
  ports:
    - name: http
      port: 80
      targetPort: 8000
      protocol: TCP
```

**Step 2: Commit**

```bash
git add kubernetes/apps/base/auth/casdoor/services.yaml
git commit -m "feat(auth): add casdoor services"
```

---

## Task 6: Init Data ConfigMap

**Files:**
- Create: `kubernetes/apps/base/auth/casdoor/init-data-configmap.yaml`

**Step 1: Create init data ConfigMap**

Create `kubernetes/apps/base/auth/casdoor/init-data-configmap.yaml`:

```yaml
# Casdoor Init Data ConfigMap
#
# Bootstrap configuration for Casdoor.
# Placeholders are substituted by init container.
apiVersion: v1
kind: ConfigMap
metadata:
  name: casdoor-init-data
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-server
    app.kubernetes.io/component: config
    app.kubernetes.io/part-of: casdoor
data:
  init_data.json: |
    {
      "organizations": [
        {
          "owner": "admin",
          "name": "built-in",
          "displayName": "Built-in Organization",
          "websiteUrl": "https://home-infra.net",
          "passwordType": "bcrypt",
          "passwordOptions": ["AtLeast6"],
          "countryCodes": ["US", "SV"],
          "defaultAvatar": "https://cdn.casbin.org/img/casbin.svg",
          "tags": [],
          "languages": ["en"],
          "initScore": 2000,
          "enableSoftDeletion": false,
          "isProfilePublic": false
        }
      ],
      "users": [
        {
          "owner": "built-in",
          "name": "ADMIN_USER_PLACEHOLDER",
          "type": "normal-user",
          "password": "ADMIN_PASSWORD_PLACEHOLDER",
          "displayName": "Admin",
          "email": "admin@home-infra.net",
          "isAdmin": true,
          "isForbidden": false,
          "isDeleted": false,
          "signupApplication": "app-built-in",
          "createdTime": "2026-01-22T00:00:00Z"
        }
      ],
      "applications": [
        {
          "owner": "built-in",
          "name": "app-built-in",
          "displayName": "Homelab SSO",
          "logo": "https://cdn.casbin.org/img/casbin.svg",
          "homepageUrl": "http://auth.home-infra.net",
          "organization": "built-in",
          "enablePassword": true,
          "enableSignUp": false,
          "clientId": "homelab-sso-client",
          "clientSecret": "homelab-sso-secret",
          "redirectUris": ["http://auth.home-infra.net/callback"],
          "expireInHours": 168
        }
      ]
    }
```

**Step 2: Commit**

```bash
git add kubernetes/apps/base/auth/casdoor/init-data-configmap.yaml
git commit -m "feat(auth): add casdoor init data configmap"
```

---

## Task 7: Secrets

**Files:**
- Create: `kubernetes/apps/base/auth/casdoor/secret.enc.yaml`

**Step 1: Create unencrypted secret template**

Create temporary file `kubernetes/apps/base/auth/casdoor/secret.yaml`:

```yaml
# Casdoor Secrets
#
# Contains PostgreSQL and admin credentials.
apiVersion: v1
kind: Secret
metadata:
  name: casdoor-secrets
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-server
    app.kubernetes.io/component: secrets
    app.kubernetes.io/part-of: casdoor
type: Opaque
stringData:
  POSTGRES_PASSWORD: "CHANGE_ME_POSTGRES_PASSWORD"
  ADMIN_USER: "admin"
  ADMIN_PASSWORD: "CHANGE_ME_ADMIN_PASSWORD"
```

**Step 2: Generate secure passwords**

Run:
```bash
# Generate passwords
POSTGRES_PW=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
ADMIN_PW=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
echo "POSTGRES_PASSWORD: $POSTGRES_PW"
echo "ADMIN_PASSWORD: $ADMIN_PW"
```

**Step 3: Update secret with generated passwords**

Edit `kubernetes/apps/base/auth/casdoor/secret.yaml` with the generated passwords.

**Step 4: Encrypt with SOPS**

Run:
```bash
sops -e kubernetes/apps/base/auth/casdoor/secret.yaml > kubernetes/apps/base/auth/casdoor/secret.enc.yaml
rm kubernetes/apps/base/auth/casdoor/secret.yaml
```

**Step 5: Commit**

```bash
git add kubernetes/apps/base/auth/casdoor/secret.enc.yaml
git commit -m "feat(auth): add casdoor encrypted secrets"
```

---

## Task 8: Casdoor Server Deployment

**Files:**
- Create: `kubernetes/apps/base/auth/casdoor/server-deployment.yaml`

**Step 1: Create server deployment**

Create `kubernetes/apps/base/auth/casdoor/server-deployment.yaml`:

```yaml
# Casdoor Server Deployment
#
# Main SSO/IAM application server.
# https://casdoor.org/
apiVersion: apps/v1
kind: Deployment
metadata:
  name: casdoor-server
  namespace: auth
  labels:
    app.kubernetes.io/name: casdoor-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: casdoor
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: casdoor-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: casdoor-server
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: casdoor
    spec:
      enableServiceLinks: false
      initContainers:
        # Wait for PostgreSQL to be ready
        - name: wait-for-db
          image: postgres:16-alpine
          command:
            - sh
            - -c
            - |
              until pg_isready -h casdoor-postgres -p 5432 -U casdoor; do
                echo "Waiting for PostgreSQL..."
                sleep 2
              done
              echo "PostgreSQL is ready"
        # Wait for Redis to be ready
        - name: wait-for-redis
          image: redis:7-alpine
          command:
            - sh
            - -c
            - |
              until redis-cli -h casdoor-redis ping; do
                echo "Waiting for Redis..."
                sleep 2
              done
              echo "Redis is ready"
        # Substitute secrets into init_data.json
        - name: prepare-init-data
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              cp /config/init_data.json /init/init_data.json
              sed -i "s/ADMIN_USER_PLACEHOLDER/$ADMIN_USER/g" /init/init_data.json
              sed -i "s/ADMIN_PASSWORD_PLACEHOLDER/$ADMIN_PASSWORD/g" /init/init_data.json
              echo "Init data prepared"
          env:
            - name: ADMIN_USER
              valueFrom:
                secretKeyRef:
                  name: casdoor-secrets
                  key: ADMIN_USER
            - name: ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: casdoor-secrets
                  key: ADMIN_PASSWORD
          volumeMounts:
            - name: init-config
              mountPath: /config
            - name: init-data
              mountPath: /init
      containers:
        - name: casdoor
          image: casbin/casdoor:v2.257.0
          ports:
            - name: http
              containerPort: 8000
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
            - name: RUNNING_IN_DOCKER
              value: "true"
            # Database configuration
            - name: driverName
              value: "postgres"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: casdoor-secrets
                  key: POSTGRES_PASSWORD
            - name: dataSourceName
              value: "user=casdoor password=$(POSTGRES_PASSWORD) host=casdoor-postgres port=5432 sslmode=disable dbname=casdoor"
            - name: dbName
              value: "casdoor"
            # Redis configuration
            - name: redisEndpoint
              value: "casdoor-redis:6379"
            # Server configuration
            - name: httpport
              value: "8000"
            - name: runmode
              value: "prod"
            - name: origin
              value: "http://auth.${DOMAIN_PRIMARY}"
            # Init data
            - name: initDataFile
              value: "/init/init_data.json"
          volumeMounts:
            - name: init-data
              mountPath: /init
          startupProbe:
            httpGet:
              path: /
              port: http
            failureThreshold: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              memory: 128Mi
            limits:
              memory: 512Mi
      volumes:
        - name: init-config
          configMap:
            name: casdoor-init-data
        - name: init-data
          emptyDir: {}
```

**Step 2: Commit**

```bash
git add kubernetes/apps/base/auth/casdoor/server-deployment.yaml
git commit -m "feat(auth): add casdoor server deployment"
```

---

## Task 9: NetworkPolicies

**Files:**
- Modify: `kubernetes/infrastructure/security/network-policies.yaml`

**Step 1: Add auth namespace NetworkPolicies**

Append to `kubernetes/infrastructure/security/network-policies.yaml`:

```yaml
---
# =============================================================================
# Auth Namespace - SSO/IAM (Casdoor)
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
  name: auth-casdoor-allow
  namespace: auth
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: casdoor-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from LoadBalancer (Cilium L2 - host network traffic)
    - ports:
        - protocol: TCP
          port: 8000
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
              app.kubernetes.io/name: casdoor-postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow Redis
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: casdoor-redis
      ports:
        - protocol: TCP
          port: 6379
    # Allow HTTPS for OAuth providers (GitHub, Google, etc.)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-casdoor-postgres-allow
  namespace: auth
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: casdoor-postgres
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow connections from casdoor-server
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: casdoor-server
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

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-casdoor-redis-allow
  namespace: auth
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: casdoor-redis
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow connections from casdoor-server
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: casdoor-server
      ports:
        - protocol: TCP
          port: 6379
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

**Step 2: Commit**

```bash
git add kubernetes/infrastructure/security/network-policies.yaml
git commit -m "feat(auth): add NetworkPolicies for auth namespace"
```

---

## Task 10: Production Kustomization

**Files:**
- Modify: `kubernetes/apps/production/kustomization.yaml`

**Step 1: Add auth to production**

Add `- ../base/auth/` to the resources list in `kubernetes/apps/production/kustomization.yaml`.

**Step 2: Validate complete build**

Run:
```bash
kustomize build kubernetes/apps/production/ | head -100
```

Expected: Valid YAML including auth namespace resources.

**Step 3: Commit**

```bash
git add kubernetes/apps/production/kustomization.yaml
git commit -m "feat(auth): enable casdoor in production"
```

---

## Task 11: Final Validation and Deploy

**Step 1: Validate all manifests**

Run:
```bash
kustomize build kubernetes/apps/base/auth/
```

Expected: Valid YAML with all Casdoor resources.

**Step 2: Push to git (triggers FluxCD)**

Run:
```bash
git push origin main
```

**Step 3: Monitor deployment**

Run:
```bash
export KUBECONFIG=terraform/talos/kubeconfig
kubectl get pods -n auth -w
```

Expected: All pods eventually reach Running state.

**Step 4: Verify service**

Run:
```bash
kubectl get svc -n auth
curl -s http://10.10.2.18 | head -20
```

Expected: Casdoor responds with HTML login page.

---

## Task 12: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add Casdoor to network table**

Add to the Network Configuration table in CLAUDE.md:

```markdown
| Casdoor | 10.10.2.18 | SSO/IAM |
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Casdoor to network table"
```
