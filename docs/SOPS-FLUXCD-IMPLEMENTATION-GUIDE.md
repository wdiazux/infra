# SOPS + FluxCD Implementation Guide

**Complete practical guide for secrets management in Talos Linux**

Last Updated: 2025-11-23
Talos: 1.11.5 | Kubernetes: 1.31.x | FluxCD: 2.4+ | SOPS: 3.9+ | Age: 1.2+

---

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Complete Working Example](#complete-working-example)
6. [Day-to-Day Workflow](#day-to-day-workflow)
7. [Troubleshooting](#troubleshooting)
8. [Quick Reference](#quick-reference)

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
