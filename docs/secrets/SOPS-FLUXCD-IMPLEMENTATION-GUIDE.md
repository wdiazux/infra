# SOPS + FluxCD Implementation Guide

**Complete practical guide for secrets management in Talos Linux**

Last Updated: 2025-11-23
Talos: 1.12.1 | Kubernetes: 1.31.x | FluxCD: 2.4+ | SOPS: 3.9+ | Age: 1.2+

---

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Complete Working Example](#complete-working-example)
6. [Day-to-Day Workflow](#day-to-day-workflow)
7. [Advanced Use Cases](#advanced-use-cases)
8. [Production Deployments](#production-deployments)
9. [Team Collaboration](#team-collaboration)
10. [Disaster Recovery](#disaster-recovery)
11. [Best Practices](#best-practices)
12. [Troubleshooting](#troubleshooting)
13. [Quick Reference](#quick-reference)

---

## Introduction

**SOPS + FluxCD** provides GitOps-native secrets management with zero additional infrastructure. All secrets are encrypted in Git and automatically decrypted when deployed to Kubernetes.

### Why SOPS + FluxCD?

- ✅ **Zero infrastructure** - No Vault servers or external dependencies
- ✅ **GitOps native** - FluxCD decrypts automatically
- ✅ **Simple** - One key pair, straightforward workflow
- ✅ **Secure** - Age encryption, secrets never in plaintext in Git
- ✅ **Auditable** - All changes tracked in Git history

### Defense-in-Depth Security

1. **Talos disk encryption** - LUKS2 encryption at rest
2. **Kubernetes encryption** - Secrets encrypted in etcd
3. **SOPS encryption** - Secrets encrypted in Git

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Developer Workflow                                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Create secret.yaml (plaintext)                          │
│ 2. Encrypt: sops -e secret.yaml > secret.sops.yaml        │
│ 3. Commit encrypted file to Git                            │
│ 4. Push to Git repository                                  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ FluxCD Reconciliation Loop                                  │
├─────────────────────────────────────────────────────────────┤
│ 1. Detect changes in Git                                   │
│ 2. Pull encrypted secret.sops.yaml                         │
│ 3. Decrypt using Age key from flux-system/sops-age        │
│ 4. Apply decrypted secret to Kubernetes                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Application Pods                                            │
├─────────────────────────────────────────────────────────────┤
│ Use secrets as environment variables or mounted files      │
│ Secrets are already decrypted by FluxCD                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required

- ✅ Talos cluster deployed and accessible (`kubectl get nodes`)
- ✅ Git repository (GitHub, Forgejo, GitLab, etc.)
- ✅ Local machine with terminal access

### Tools to Install

```bash
# macOS
brew install age sops fluxcd/tap/flux

# Debian/Ubuntu
sudo apt install age
# SOPS (download latest from GitHub)
wget https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
sudo mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
# FluxCD
curl -s https://fluxcd.io/install.sh | sudo bash

# Arch Linux
sudo pacman -S age sops flux-bin

# Verify installation
age --version
sops --version
flux --version
```

---

## Installation

### Step 1: Generate Age Key Pair

```bash
# Generate new Age key (save output!)
age-keygen -o age.agekey

# Example output:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# View public key
age-keygen -y age.agekey

# CRITICAL: Backup this file to password manager!
# You'll need it for disaster recovery
```

### Step 2: Store Age Key in Kubernetes

```bash
# Create sops-age secret in flux-system namespace
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age.agekey

# Verify
kubectl -n flux-system get secret sops-age

# Output:
# NAME       TYPE     DATA   AGE
# sops-age   Opaque   1      5s
```

### Step 3: Bootstrap FluxCD

**Option A: GitHub**

```bash
# Set environment variables
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=flux-homelab

# Bootstrap FluxCD
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=${GITHUB_REPO} \
  --branch=main \
  --path=./clusters/homelab \
  --personal \
  --private=false
```

**Option B: Forgejo (Self-hosted)**

```bash
# Bootstrap with generic Git
flux bootstrap git \
  --url=https://git.yourdomain.com/username/flux-homelab \
  --branch=main \
  --path=./clusters/homelab \
  --username=<username> \
  --password=<token>
```

**Verify FluxCD is running:**

```bash
flux check

# Output:
# ✔ Kubernetes 1.31.x >=1.28.0-0
# ✔ prerequisites
# ✔ Flux 2.4.x installed
```

### Step 4: Create .sops.yaml in Git Repository

```bash
# Clone your flux repository
git clone <your-repo-url>
cd flux-homelab

# Create .sops.yaml (replace with YOUR public key)
cat > .sops.yaml <<EOF
creation_rules:
  # Encrypt all files in secrets/ directory
  - path_regex: clusters/homelab/secrets/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

  # Encrypt all .sops.yaml files
  - path_regex: .*\.sops\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
EOF

# Commit
git add .sops.yaml
git commit -m "Add SOPS configuration"
git push
```

### Step 5: Create Repository Structure

```bash
# Create directory structure
mkdir -p clusters/homelab/{secrets,apps,infrastructure}

# Create Kustomization with SOPS decryption
cat > clusters/homelab/apps/kustomization.yaml <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/homelab/apps
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  # Enable SOPS decryption
  decryption:
    provider: sops
    secretRef:
      name: sops-age
EOF

git add clusters/
git commit -m "Add directory structure"
git push
```

---

## Complete Working Example

### Example 1: Database Credentials

**Step 1: Create plaintext secret**

```bash
# Create secret file
cat > postgres-creds.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: database
type: Opaque
stringData:
  POSTGRES_USER: admin
  POSTGRES_PASSWORD: MySecureP@ssw0rd123
  POSTGRES_DB: myapp
EOF
```

**Step 2: Encrypt with SOPS**

```bash
# Encrypt (SOPS uses .sops.yaml config)
sops -e postgres-creds.yaml > clusters/homelab/secrets/postgres-creds.sops.yaml

# Delete plaintext file
rm postgres-creds.yaml

# View encrypted file
cat clusters/homelab/secrets/postgres-creds.sops.yaml
```

**Encrypted file will look like:**

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: postgres-credentials
    namespace: database
type: Opaque
stringData:
    POSTGRES_USER: ENC[AES256_GCM,data:YWRtaW4=,iv:xxx...]
    POSTGRES_PASSWORD: ENC[AES256_GCM,data:TXlTZWN1cmVQQHNzdzByZDEyMw==,iv:xxx...]
    POSTGRES_DB: ENC[AES256_GCM,data:bXlhcHA=,iv:xxx...]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age:
        - recipient: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "2025-11-23T12:00:00Z"
    mac: ENC[AES256_GCM,data:xxx...]
```

**Step 3: Commit and push**

```bash
git add clusters/homelab/secrets/postgres-creds.sops.yaml
git commit -m "Add postgres credentials (encrypted)"
git push
```

**Step 4: Verify deployment**

```bash
# FluxCD will automatically decrypt and apply
# Wait a moment, then check:

kubectl -n database get secret postgres-credentials

# Output:
# NAME                     TYPE     DATA   AGE
# postgres-credentials     Opaque   3      30s

# View secret (base64 encoded, not SOPS encrypted)
kubectl -n database get secret postgres-credentials -o yaml
```

### Example 2: Docker Registry Credentials

```bash
# Create docker registry secret
cat > docker-registry.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry
  namespace: flux-system
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "ghcr.io": {
          "username": "myuser",
          "password": "ghp_MyGitHubToken123",
          "email": "user@example.com"
        }
      }
    }
EOF

# Encrypt
sops -e docker-registry.yaml > clusters/homelab/secrets/docker-registry.sops.yaml

# Clean up and commit
rm docker-registry.yaml
git add clusters/homelab/secrets/docker-registry.sops.yaml
git commit -m "Add docker registry credentials"
git push
```

### Example 3: Using Secret in Deployment

```yaml
# clusters/homelab/apps/postgres/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        # FluxCD already decrypted the secret!
        envFrom:
          - secretRef:
              name: postgres-credentials
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-pvc
```

---

## Day-to-Day Workflow

### Creating New Secret

```bash
# 1. Create plaintext secret
vim my-secret.yaml

# 2. Encrypt with SOPS
sops -e my-secret.yaml > clusters/homelab/secrets/my-secret.sops.yaml

# 3. Delete plaintext file
rm my-secret.yaml

# 4. Commit encrypted file
git add clusters/homelab/secrets/my-secret.sops.yaml
git commit -m "Add new secret"
git push

# 5. FluxCD deploys automatically (wait ~10 seconds)
```

### Editing Existing Secret

```bash
# Edit encrypted file directly (SOPS decrypts in your editor)
sops clusters/homelab/secrets/postgres-creds.sops.yaml

# Make changes, save and exit
# SOPS re-encrypts automatically

# Commit changes
git add clusters/homelab/secrets/postgres-creds.sops.yaml
git commit -m "Update postgres password"
git push
```

### Viewing Secret (Decrypted)

```bash
# View decrypted content (doesn't modify file)
sops -d clusters/homelab/secrets/postgres-creds.sops.yaml
```

### Rotating Age Key

```bash
# 1. Generate new Age key
age-keygen -o age-new.agekey

# 2. Extract new public key
NEW_KEY=$(age-keygen -y age-new.agekey)

# 3. Update .sops.yaml with new public key
sed -i "s/age: age.*/age: ${NEW_KEY}/" .sops.yaml

# 4. Re-encrypt all secrets
find clusters/ -name "*.sops.yaml" -exec sops updatekeys {} \;

# 5. Update Kubernetes secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age-new.agekey \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. Commit changes
git add .
git commit -m "Rotate Age key"
git push
```

---

## Advanced Use Cases

### 1. Multi-Namespace Secret Sharing

**Problem:** You need to use the same secret in multiple namespaces.

**Solution A: Duplicate secrets (Recommended for homelab)**

```bash
# Create database credentials for multiple namespaces
for ns in app1 app2 app3; do
  cat > postgres-creds-${ns}.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: ${ns}
type: Opaque
stringData:
  POSTGRES_USER: app_user
  POSTGRES_PASSWORD: SecurePassword123
  POSTGRES_DB: mydb
EOF

  # Encrypt
  sops -e postgres-creds-${ns}.yaml > clusters/homelab/secrets/postgres-creds-${ns}.sops.yaml
  rm postgres-creds-${ns}.yaml
done

# Commit all
git add clusters/homelab/secrets/postgres-creds-*.sops.yaml
git commit -m "Add postgres credentials for multiple namespaces"
git push
```

**Solution B: Use Kubernetes native replication (Advanced)**

```yaml
# clusters/homelab/infrastructure/secret-reflector.yaml
# Requires: stakater/reloader or similar
apiVersion: v1
kind: Secret
metadata:
  name: shared-db-credentials
  namespace: flux-system
  annotations:
    replicator.v1.mittwald.de/replicate-to: "app1,app2,app3"
type: Opaque
stringData:
  POSTGRES_USER: app_user
  POSTGRES_PASSWORD: SecurePassword123
```

### 2. Secret Templates for Multiple Environments

**Use Case:** Different credentials for dev/staging/prod in same cluster.

```bash
# Directory structure
mkdir -p clusters/homelab/secrets/{dev,staging,prod}

# Create environment-specific secrets
cat > dev-db-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: dev
type: Opaque
stringData:
  POSTGRES_HOST: postgres-dev.default.svc.cluster.local
  POSTGRES_USER: dev_user
  POSTGRES_PASSWORD: DevPassword123
  POSTGRES_DB: dev_db
EOF

cat > prod-db-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: prod
type: Opaque
stringData:
  POSTGRES_HOST: postgres-prod.default.svc.cluster.local
  POSTGRES_USER: prod_user
  POSTGRES_PASSWORD: Pr0dP@ssw0rd!VerySecure
  POSTGRES_DB: prod_db
EOF

# Encrypt both
sops -e dev-db-secret.yaml > clusters/homelab/secrets/dev/database-creds.sops.yaml
sops -e prod-db-secret.yaml > clusters/homelab/secrets/prod/database-creds.sops.yaml

# Clean up
rm dev-db-secret.yaml prod-db-secret.yaml

# Commit
git add clusters/homelab/secrets/
git commit -m "Add environment-specific database credentials"
git push
```

### 3. Automated Secret Rotation Strategy

**Strategy 1: Time-based rotation with Git commits**

```bash
#!/bin/bash
# rotate-db-password.sh - Run monthly via cron or CI/CD

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Decrypt existing secret
sops -d clusters/homelab/secrets/postgres-creds.sops.yaml > /tmp/secret.yaml

# Update password in YAML
sed -i "s/POSTGRES_PASSWORD: .*/POSTGRES_PASSWORD: ${NEW_PASSWORD}/" /tmp/secret.yaml

# Re-encrypt
sops -e /tmp/secret.yaml > clusters/homelab/secrets/postgres-creds.sops.yaml

# Clean up
rm /tmp/secret.yaml

# Commit
git add clusters/homelab/secrets/postgres-creds.sops.yaml
git commit -m "Rotate postgres password (automated)"
git push

# Update actual database user (run this on database)
# psql -U postgres -c "ALTER USER app_user PASSWORD '${NEW_PASSWORD}';"
```

**Strategy 2: Event-based rotation (when breach detected)**

```bash
# Manual emergency rotation
INCIDENT_DATE=$(date +%Y%m%d)

# 1. Generate new credentials
NEW_USER="user_${INCIDENT_DATE}"
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. Create new secret
cat > new-creds.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: database
type: Opaque
stringData:
  POSTGRES_USER: ${NEW_USER}
  POSTGRES_PASSWORD: ${NEW_PASSWORD}
EOF

# 3. Encrypt and deploy
sops -e new-creds.yaml > clusters/homelab/secrets/postgres-creds.sops.yaml
rm new-creds.yaml
git add clusters/homelab/secrets/postgres-creds.sops.yaml
git commit -m "SECURITY: Emergency credential rotation - incident ${INCIDENT_DATE}"
git push

# 4. Verify new credentials deployed
kubectl -n database rollout restart deployment postgres

echo "Old credentials will be revoked after verification"
```

### 4. Integration with Longhorn Backup (NFS Credentials)

**Complete Longhorn backup target with SOPS-encrypted NFS credentials:**

```bash
# Create NFS mount credentials (if NAS requires auth)
cat > longhorn-nfs-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nfs-backup-credentials
  namespace: longhorn-system
type: Opaque
stringData:
  # NFS server details
  NFS_SERVER: "10.10.2.5"
  NFS_PATH: "/mnt/tank/backups/longhorn"
  # Optional: NFS mount options
  NFS_OPTIONS: "vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2"
EOF

# Encrypt
sops -e longhorn-nfs-secret.yaml > clusters/homelab/secrets/longhorn-nfs-secret.sops.yaml
rm longhorn-nfs-secret.yaml

# Create Longhorn backup target ConfigMap
cat > clusters/homelab/infrastructure/longhorn-backup-target.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-backup-target
  namespace: longhorn-system
data:
  # NFS backup target (credentials from secret)
  backup-target: "nfs://10.10.2.5:/mnt/tank/backups/longhorn"
  # S3 alternative (for reference)
  # backup-target: "s3://bucket-name@region/"
  # backup-target-credential-secret: "s3-credentials"
EOF

# Commit both
git add clusters/homelab/secrets/longhorn-nfs-secret.sops.yaml
git add clusters/homelab/infrastructure/longhorn-backup-target.yaml
git commit -m "Add Longhorn NFS backup configuration with encrypted credentials"
git push
```

### 5. API Tokens and Service Accounts

**GitHub/Forgejo API tokens for CI/CD:**

```bash
cat > git-api-tokens.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: git-api-tokens
  namespace: ci-cd
type: Opaque
stringData:
  # Forgejo API token for CI/CD pipelines
  FORGEJO_TOKEN: "fgt_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  FORGEJO_URL: "https://git.yourdomain.com"

  # GitHub token for mirroring (optional)
  GITHUB_TOKEN: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  GITHUB_USER: "your-username"
EOF

# Encrypt
sops -e git-api-tokens.yaml > clusters/homelab/secrets/git-api-tokens.sops.yaml
rm git-api-tokens.yaml

# Commit
git add clusters/homelab/secrets/git-api-tokens.sops.yaml
git commit -m "Add Git API tokens for CI/CD"
git push
```

**Use in CI/CD pipeline:**

```yaml
# clusters/homelab/apps/ci-cd/pipeline-runner.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forgejo-runner
  namespace: ci-cd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: forgejo-runner
  template:
    metadata:
      labels:
        app: forgejo-runner
    spec:
      containers:
      - name: runner
        image: code.forgejo.org/forgejo/runner:latest
        env:
        # Tokens decrypted by FluxCD
        - name: FORGEJO_TOKEN
          valueFrom:
            secretKeyRef:
              name: git-api-tokens
              key: FORGEJO_TOKEN
        - name: FORGEJO_INSTANCE_URL
          valueFrom:
            secretKeyRef:
              name: git-api-tokens
              key: FORGEJO_URL
```

### 6. TLS Certificates and Private Keys

**Self-signed or Let's Encrypt private keys:**

```bash
# Generate certificate (example with openssl)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=*.yourdomain.com/O=Homelab"

# Create TLS secret
cat > tls-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: wildcard-tls
  namespace: ingress-nginx
type: kubernetes.io/tls
stringData:
  tls.crt: |
$(cat tls.crt | sed 's/^/    /')
  tls.key: |
$(cat tls.key | sed 's/^/    /')
EOF

# Encrypt (CRITICAL - private key must be encrypted!)
sops -e tls-secret.yaml > clusters/homelab/secrets/wildcard-tls.sops.yaml

# Clean up plaintext files
rm tls.key tls.crt tls-secret.yaml

# Commit encrypted secret
git add clusters/homelab/secrets/wildcard-tls.sops.yaml
git commit -m "Add wildcard TLS certificate (encrypted)"
git push
```

---

## Production Deployments

### Complete Forgejo Deployment with SOPS Secrets

**Step 1: Create all required secrets**

```bash
# Forgejo admin credentials
cat > forgejo-admin.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-admin
  namespace: forgejo
type: Opaque
stringData:
  ADMIN_USERNAME: admin
  ADMIN_PASSWORD: AdminP@ssw0rd123!ChangeMe
  ADMIN_EMAIL: admin@yourdomain.com
EOF

# PostgreSQL database credentials
cat > forgejo-db.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-db-credentials
  namespace: forgejo
type: Opaque
stringData:
  POSTGRES_USER: forgejo
  POSTGRES_PASSWORD: ForgejoDbP@ss123!
  POSTGRES_DB: forgejo
  DATABASE_URL: "postgres://forgejo:ForgejoDbP@ss123!@postgres.forgejo.svc:5432/forgejo?sslmode=disable"
EOF

# Forgejo internal token and JWT secret
cat > forgejo-tokens.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-tokens
  namespace: forgejo
type: Opaque
stringData:
  INTERNAL_TOKEN: "$(openssl rand -base64 32)"
  JWT_SECRET: "$(openssl rand -base64 32)"
  SECRET_KEY: "$(openssl rand -base64 32)"
EOF

# Encrypt all
sops -e forgejo-admin.yaml > clusters/homelab/secrets/forgejo-admin.sops.yaml
sops -e forgejo-db.yaml > clusters/homelab/secrets/forgejo-db.sops.yaml
sops -e forgejo-tokens.yaml > clusters/homelab/secrets/forgejo-tokens.sops.yaml

# Clean up
rm forgejo-admin.yaml forgejo-db.yaml forgejo-tokens.yaml

# Commit
git add clusters/homelab/secrets/forgejo-*.sops.yaml
git commit -m "Add Forgejo deployment secrets (encrypted)"
git push
```

**Step 2: Deploy Forgejo using encrypted secrets**

```yaml
# clusters/homelab/apps/forgejo/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forgejo
  namespace: forgejo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: forgejo
  template:
    metadata:
      labels:
        app: forgejo
    spec:
      containers:
      - name: forgejo
        image: codeberg.org/forgejo/forgejo:9
        env:
        # Admin credentials (SOPS decrypted by FluxCD)
        - name: FORGEJO__security__INSTALL_LOCK
          value: "true"
        - name: FORGEJO__security__SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: forgejo-tokens
              key: SECRET_KEY
        - name: FORGEJO__security__INTERNAL_TOKEN
          valueFrom:
            secretKeyRef:
              name: forgejo-tokens
              key: INTERNAL_TOKEN
        - name: FORGEJO__oauth2__JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: forgejo-tokens
              key: JWT_SECRET
        # Database credentials
        - name: FORGEJO__database__DB_TYPE
          value: postgres
        - name: FORGEJO__database__HOST
          value: postgres.forgejo.svc:5432
        - name: FORGEJO__database__NAME
          valueFrom:
            secretKeyRef:
              name: forgejo-db-credentials
              key: POSTGRES_DB
        - name: FORGEJO__database__USER
          valueFrom:
            secretKeyRef:
              name: forgejo-db-credentials
              key: POSTGRES_USER
        - name: FORGEJO__database__PASSWD
          valueFrom:
            secretKeyRef:
              name: forgejo-db-credentials
              key: POSTGRES_PASSWORD
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 22
          name: ssh
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: forgejo-data
```

### Complete Monitoring Stack with SOPS Secrets

**Step 1: Create monitoring credentials**

```bash
# Grafana admin password
cat > grafana-admin.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: monitoring
type: Opaque
stringData:
  admin-user: admin
  admin-password: GrafanaAdminP@ss123!
EOF

# Alertmanager secrets (Slack webhook, email, etc.)
cat > alertmanager-config.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-secrets
  namespace: monitoring
type: Opaque
stringData:
  slack-webhook-url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  smtp-password: "YourEmailP@ssword"
  pagerduty-key: "your-pagerduty-integration-key"
EOF

# Prometheus remote write credentials (if using remote storage)
cat > prometheus-remote.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-remote-write
  namespace: monitoring
type: Opaque
stringData:
  username: prometheus
  password: RemoteWriteP@ss123!
  remote-write-url: "https://prometheus-remote.yourdomain.com/api/v1/write"
EOF

# Encrypt all
sops -e grafana-admin.yaml > clusters/homelab/secrets/grafana-admin.sops.yaml
sops -e alertmanager-config.yaml > clusters/homelab/secrets/alertmanager-config.sops.yaml
sops -e prometheus-remote.yaml > clusters/homelab/secrets/prometheus-remote.sops.yaml

# Clean up
rm grafana-admin.yaml alertmanager-config.yaml prometheus-remote.yaml

# Commit
git add clusters/homelab/secrets/{grafana,alertmanager,prometheus}-*.sops.yaml
git commit -m "Add monitoring stack secrets (encrypted)"
git push
```

**Step 2: kube-prometheus-stack Helm values with SOPS secrets**

```yaml
# clusters/homelab/infrastructure/monitoring/kube-prometheus-stack-values.yaml
grafana:
  adminUser: admin
  # Password from SOPS-encrypted secret
  admin:
    existingSecret: "grafana-admin"
    userKey: admin-user
    passwordKey: admin-password

  persistence:
    enabled: true
    size: 5Gi
    storageClassName: longhorn

alertmanager:
  config:
    global:
      # SMTP from encrypted secret
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alerts@yourdomain.com'
      smtp_auth_username: 'alerts@yourdomain.com'
      smtp_auth_password_file: /etc/alertmanager/secrets/smtp-password

    route:
      receiver: 'default'
      routes:
      - receiver: 'slack'
        matchers:
        - severity =~ "warning|critical"

    receivers:
    - name: 'default'
      email_configs:
      - to: 'admin@yourdomain.com'

    - name: 'slack'
      slack_configs:
      - api_url_file: /etc/alertmanager/secrets/slack-webhook-url
        channel: '#alerts'
        title: 'Homelab Alert'

  # Mount secrets
  alertmanagerSpec:
    secrets:
    - alertmanager-secrets

prometheus:
  prometheusSpec:
    # Remote write with credentials
    remoteWrite:
    - url: https://prometheus-remote.yourdomain.com/api/v1/write
      basicAuth:
        username:
          name: prometheus-remote-write
          key: username
        password:
          name: prometheus-remote-write
          key: password
```

---

## Team Collaboration

### Multi-Developer Workflow

**Scenario:** Multiple developers need to encrypt/decrypt secrets.

**Step 1: Share Age public key (team uses same key)**

```bash
# Team lead generates key once
age-keygen -o age.agekey

# Extract public key
age-keygen -y age.agekey > age-public.txt

# Share public key with team (commit to repo)
git add age-public.txt
git commit -m "Add Age public key for team"
git push

# Share PRIVATE key securely (never commit!)
# Options:
# 1. Password manager (1Password shared vault)
# 2. Secure file share (encrypted)
# 3. In-person USB transfer
```

**Step 2: Team members set up locally**

```bash
# Each developer receives age.agekey securely
# Store it locally
mkdir -p ~/.config/sops/age
cp age.agekey ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Set environment variable (add to ~/.bashrc or ~/.zshrc)
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Verify can decrypt
sops -d clusters/homelab/secrets/postgres-creds.sops.yaml
```

**Step 3: Collaborative secret editing**

```bash
# Developer A: Create new secret
sops clusters/homelab/secrets/new-api-key.sops.yaml
# ... edits in editor ...
git add clusters/homelab/secrets/new-api-key.sops.yaml
git commit -m "Add new API key"
git push

# Developer B: Update same secret (next day)
git pull
sops clusters/homelab/secrets/new-api-key.sops.yaml
# ... edits in editor ...
git add clusters/homelab/secrets/new-api-key.sops.yaml
git commit -m "Update API key expiration"
git push

# No conflicts - SOPS re-encrypts with same key
```

### Access Control: Multiple Age Keys (Advanced)

**Use Case:** Different teams need access to different secrets.

```yaml
# .sops.yaml with multiple keys
creation_rules:
  # DevOps team can decrypt all secrets
  - path_regex: clusters/homelab/secrets/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1devops1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
      age1devops2xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # Database team can only decrypt database secrets
  - path_regex: clusters/homelab/secrets/database/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1dbateam1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
      age1devops1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # App developers can only decrypt app secrets
  - path_regex: clusters/homelab/secrets/apps/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1appdev1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
      age1devops1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Result:** Each team can only decrypt secrets in their path.

---

## Disaster Recovery

### Complete Recovery Procedure

**Scenario:** Lost Age private key, need to recover encrypted secrets.

**Prevention (Critical!):**

```bash
# BEFORE disaster - backup Age private key to password manager
# 1. Store in 1Password/Bitwarden as secure note
# 2. Print on paper and store in safe
# 3. Encrypt and store on USB drive
# 4. Store in company key management system
```

**Recovery Steps:**

```bash
# Step 1: Retrieve Age private key from backup
# (from password manager, paper backup, etc.)

# Step 2: Restore key locally
mkdir -p ~/.config/sops/age
cat > ~/.config/sops/age/keys.txt <<EOF
# created: 2025-11-23T12:00:00Z
# public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
AGE-SECRET-KEY-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
EOF

chmod 600 ~/.config/sops/age/keys.txt
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Step 3: Verify can decrypt
git clone <your-repo>
cd flux-homelab
sops -d clusters/homelab/secrets/postgres-creds.sops.yaml

# If successful, you've recovered!

# Step 4: Recreate sops-age secret in Kubernetes
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=~/.config/sops/age/keys.txt

# Step 5: Force FluxCD reconciliation
flux reconcile kustomization apps --with-source
```

### Complete Cluster Rebuild with SOPS

**Scenario:** Rebuild Talos cluster from scratch, restore all secrets.

```bash
# Assuming you have:
# - Git repository with encrypted secrets
# - Age private key backup

# Step 1: Deploy fresh Talos cluster
# (following TALOS-DEPLOYMENT-GUIDE.md)

# Step 2: Install Age key in new cluster
kubectl create namespace flux-system
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=~/.config/sops/age/keys.txt

# Step 3: Bootstrap FluxCD (same repo)
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=flux-homelab \
  --branch=main \
  --path=./clusters/homelab

# Step 4: FluxCD automatically pulls and decrypts all secrets
# Wait for reconciliation
flux get kustomizations --watch

# Step 5: Verify all secrets deployed
kubectl get secrets --all-namespaces | grep -E "postgres|grafana|forgejo"

# RESULT: Complete infrastructure recovered from Git + one Age key!
```

### Emergency: Lost Age Key (No Backup)

**WARNING: This is catastrophic. All encrypted secrets are permanently lost.**

**Recovery procedure:**

```bash
# Step 1: Generate NEW Age key
age-keygen -o age-new.agekey
NEW_PUBLIC_KEY=$(age-keygen -y age-new.agekey)

# Step 2: Decrypt ALL secrets with OLD key (if you still have access)
# If not, you must recreate all secrets from scratch

# Step 3: Re-encrypt with NEW key
for file in $(find clusters/ -name "*.sops.yaml"); do
  # Decrypt with old key (while you still have it)
  sops -d "$file" > /tmp/plaintext.yaml

  # Delete old encrypted file
  rm "$file"

  # Encrypt with new key
  sops -e /tmp/plaintext.yaml > "$file"

  rm /tmp/plaintext.yaml
done

# Step 4: Update .sops.yaml
sed -i "s/age: age.*/age: ${NEW_PUBLIC_KEY}/" .sops.yaml

# Step 5: Commit and push
git add .
git commit -m "EMERGENCY: Re-encrypt all secrets with new Age key"
git push

# Step 6: Update Kubernetes secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age-new.agekey \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 7: Force reconciliation
flux reconcile kustomization apps --with-source

# Step 8: Backup new key properly this time!
```

---

## Best Practices

### 1. Secret Naming Conventions

```bash
# Good naming (descriptive and namespace-aware)
postgres-credentials          # Database credentials
grafana-admin-password        # Grafana admin
forgejo-db-credentials        # Forgejo database
slack-webhook-url             # Alertmanager Slack
tls-wildcard-cert             # TLS certificate

# Bad naming (ambiguous)
secret1
creds
password
my-secret
```

### 2. Secret Organization Strategies

**Strategy A: Namespace-based (Recommended for homelab)**

```
clusters/homelab/secrets/
├── database/
│   ├── postgres-creds.sops.yaml
│   └── mysql-creds.sops.yaml
├── monitoring/
│   ├── grafana-admin.sops.yaml
│   └── alertmanager-config.sops.yaml
├── forgejo/
│   ├── forgejo-admin.sops.yaml
│   ├── forgejo-db.sops.yaml
│   └── forgejo-tokens.sops.yaml
└── infrastructure/
    ├── longhorn-nfs.sops.yaml
    └── tls-certs.sops.yaml
```

**Strategy B: Application-based**

```
clusters/homelab/secrets/
├── apps/
│   ├── app1-secrets.sops.yaml
│   ├── app2-secrets.sops.yaml
│   └── app3-secrets.sops.yaml
└── infrastructure/
    └── shared-secrets.sops.yaml
```

### 3. When to Rotate Secrets

**Mandatory rotation:**
- ✅ Security breach or suspected compromise
- ✅ Employee/team member departure
- ✅ Age key potentially exposed
- ✅ Secret accidentally committed to Git (even if quickly removed)

**Recommended rotation:**
- ⚠️ Every 90 days (database passwords, API tokens)
- ⚠️ Every 365 days (TLS certificates, Age keys)
- ⚠️ After major infrastructure changes

**Low priority:**
- 📌 Internal service-to-service tokens (if network is trusted)
- 📌 Development/testing credentials

### 4. Performance Considerations

**SOPS decryption is fast, but:**

```yaml
# GOOD: Single Kustomization for all secrets
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/homelab/secrets
  decryption:
    provider: sops    # Decrypt once for entire directory
    secretRef:
      name: sops-age

# AVOID: Multiple Kustomizations for individual secrets
# (creates unnecessary decryption overhead)
```

**Optimization tips:**
- Keep encrypted secrets together in one directory
- Use single Kustomization with SOPS decryption
- Don't create Kustomization per secret file
- FluxCD caches decrypted secrets (efficient)

### 5. Security Hardening

```yaml
# .sops.yaml - Best practices
creation_rules:
  - path_regex: clusters/homelab/secrets/.*\.yaml$
    # Only encrypt sensitive fields (not metadata)
    encrypted_regex: ^(data|stringData)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
    # Optional: Encrypt file creation date
    # encrypted_suffix: _encrypted
```

**Additional hardening:**

```bash
# .gitignore - Prevent committing plaintext secrets
*.agekey
*.key
*.pem
*-plaintext.yaml
*.env.local

# Git hooks - Prevent committing secrets
# .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -E '\.(agekey|key|pem)$'; then
  echo "ERROR: Attempting to commit private key!"
  exit 1
fi
```

### 6. Documentation Standards

**Always document:**
- Secret name and namespace
- Purpose and which service uses it
- Rotation schedule
- Who has access (in team environments)
- How to recover if lost

**Example secret documentation:**

```yaml
# clusters/homelab/secrets/postgres-creds.sops.yaml
#
# Secret: postgres-credentials
# Namespace: database
# Purpose: PostgreSQL database credentials for all applications
# Used by: Forgejo, Grafana, custom applications
# Rotation: Every 90 days (automated via rotate-db-password.sh)
# Access: DevOps team (Age key in shared 1Password vault)
# Recovery: Age key backup in 1Password -> "Homelab Age Keys"
#
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: database
  labels:
    app: postgres
    managed-by: flux
type: Opaque
stringData:
  POSTGRES_USER: ENC[AES256_GCM,data:...]
  POSTGRES_PASSWORD: ENC[AES256_GCM,data:...]
  POSTGRES_DB: ENC[AES256_GCM,data:...]
sops:
  # ... SOPS metadata ...
```

---

## Troubleshooting

### Error: "Failed to decrypt: no key could decrypt the data"

**Cause:** Age key in Kubernetes doesn't match the key used to encrypt

**Solution:**

```bash
# Verify age key in cluster
kubectl -n flux-system get secret sops-age -o jsonpath='{.data.age\.agekey}' | base64 -d

# Should show your Age private key

# If wrong, recreate secret
kubectl delete secret sops-age -n flux-system
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age.agekey
```

### Error: "No SOPS metadata found"

**Cause:** File was not encrypted with SOPS

**Solution:**

```bash
# Re-encrypt the file
sops -e file.yaml > file.sops.yaml
```

### Secret Not Updating After Git Push

**Cause:** FluxCD hasn't reconciled yet

**Solution:**

```bash
# Force immediate reconciliation
flux reconcile source git flux-system
flux reconcile kustomization apps

# Check status
flux get kustomizations
```

### Check FluxCD Logs for SOPS Errors

```bash
# View kustomize-controller logs (handles SOPS decryption)
kubectl -n flux-system logs deployment/kustomize-controller --tail=50

# Look for "sops" or "decrypt" errors
```

---

## Quick Reference

### Common Commands

```bash
# Encrypt secret
sops -e secret.yaml > secret.sops.yaml

# Edit encrypted secret (decrypts in editor)
sops secret.sops.yaml

# Decrypt to view only
sops -d secret.sops.yaml

# Update encryption keys after key rotation
sops updatekeys secret.sops.yaml

# FluxCD force reconciliation
flux reconcile kustomization apps --with-source

# Check FluxCD status
flux get all

# Check specific kustomization
flux get kustomization apps
```

### File Locations

- **Age private key backup:** Password manager (1Password, Bitwarden)
- **Age K8s secret:** `flux-system/sops-age`
- **SOPS config:** `.sops.yaml` (Git repository root)
- **Encrypted secrets:** `clusters/homelab/secrets/*.sops.yaml`

### Security Checklist

- ✅ Age private key backed up in password manager
- ✅ `*.agekey` added to `.gitignore`
- ✅ No plaintext secrets in Git history
- ✅ `.sops.yaml` committed to repository
- ✅ FluxCD Kustomization has `decryption.provider: sops`
- ✅ All team members use same Age public key for encryption

### Git Repository Structure

```
flux-homelab/
├── .gitignore                          # Ignore *.agekey
├── .sops.yaml                          # SOPS configuration
├── clusters/
│   └── homelab/
│       ├── flux-system/                # FluxCD components
│       ├── infrastructure/             # Infrastructure
│       ├── apps/                       # Applications
│       │   └── kustomization.yaml      # With SOPS decryption enabled
│       └── secrets/                    # Encrypted secrets
│           ├── *.sops.yaml             # All encrypted
└── README.md
```

---

## Next Steps

After implementing SOPS + FluxCD:

1. **Migrate existing secrets** to SOPS encryption
2. **Deploy Longhorn** with encrypted NAS credentials
3. **Deploy monitoring stack** with encrypted configs
4. **Deploy Forgejo** with encrypted admin credentials
5. **Set up CI/CD** with encrypted Git tokens

### Related Documentation

- `KUBERNETES_SECRETS_MANAGEMENT_GUIDE.md` - Deep-dive comparison of all options
- `SECRETS_MANAGEMENT_QUICK_START.md` - Quick 5-minute setup
- `TALOS-GETTING-STARTED.md` - Initial Talos cluster setup
- `FLUXCD-SETUP-GUIDE.md` - Detailed FluxCD GitOps guide *(to be created)*

---

## Summary

✅ **SOPS + FluxCD provides:**
- Zero-infrastructure secrets management
- GitOps-native workflow
- Strong encryption (Age)
- Audit trail in Git
- Automatic secret rotation via Git commits

✅ **Core workflow:**
1. Encrypt: `sops -e secret.yaml > secret.sops.yaml`
2. Commit: `git add secret.sops.yaml && git commit && git push`
3. Deploy: FluxCD automatically decrypts and applies
4. Use: Applications reference secrets normally

✅ **Security:**
- Secrets never in plaintext in Git
- Age private key backed up securely
- Defense-in-depth: Talos disk encryption + K8s encryption + SOPS
- All changes auditable in Git history

**Your secrets are now production-ready and GitOps-managed!** 🔐
