# Secrets Management Quick Start Guide

**Target:** Talos Linux on Proxmox with FluxCD
**Recommended Solution:** SOPS + FluxCD + Age
**Setup Time:** ~30 minutes

---

## Quick Decision Matrix

| If You Have... | Use This Solution |
|----------------|-------------------|
| FluxCD already installed | **SOPS with FluxCD** ⭐ (native integration) |
| ArgoCD instead of FluxCD | **Sealed Secrets** (better ArgoCD support) |
| AWS/Azure/GCP secrets backend | **External Secrets Operator** (sync from cloud) |
| Enterprise Vault deployment | **Vault CSI Driver** (leverage existing) |
| No GitOps tool yet | **SOPS Secrets Operator** or **Sealed Secrets** |

---

## 5-Minute SOPS Setup (For FluxCD Users)

### Prerequisites

```bash
# Install on your local machine
brew install sops age  # macOS
# OR
# Linux: Download from GitHub releases
```

### Setup Steps

```bash
# 1. Generate Age key (30 seconds)
age-keygen -o age.agekey
# Save the public key shown: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# 2. Create .sops.yaml in repo root (1 minute)
cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: .*secret.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
EOF

# 3. Store key in Kubernetes (1 minute)
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age.agekey

# 4. Configure FluxCD Kustomization (2 minutes)
cat > clusters/my-cluster/flux-system/kustomization.yaml <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-apps
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/my-cluster/apps
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
EOF

# 5. Test with a secret (2 minutes)
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
  namespace: default
stringData:
  password: "SuperSecret123!"
EOF

sops --encrypt secret.yaml > secret.enc.yaml
kubectl apply -f secret.enc.yaml  # Test locally

# 6. Commit and push
git add .sops.yaml secret.enc.yaml
git commit -m "Add SOPS secrets management"
git push

# Done! FluxCD will decrypt and apply automatically.
```

### Verification

```bash
# Check FluxCD reconciled the secret
kubectl get kustomization -n flux-system
kubectl get secret test-secret -n default

# View decrypted value
kubectl get secret test-secret -n default -o jsonpath='{.data.password}' | base64 -d
# Should output: SuperSecret123!
```

---

## Common Secret Operations

### Create New Secret

```bash
# Method 1: From literal values
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml > secret.yaml

# Method 2: From file
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
stringData:
  username: admin
  password: secret123
EOF

# Encrypt and commit
sops --encrypt secret.yaml > secret.enc.yaml
git add secret.enc.yaml
git commit -m "Add my-secret"
git push
```

### Edit Existing Secret

```bash
# SOPS opens decrypted version in $EDITOR
export SOPS_AGE_KEY_FILE=./age.agekey
sops secret.enc.yaml

# Make changes, save, exit
# SOPS automatically re-encrypts

# Commit changes
git add secret.enc.yaml
git commit -m "Update my-secret"
git push
```

### Rotate Secret

```bash
# Edit and change values
sops secret.enc.yaml

# Or regenerate from source
kubectl create secret generic my-secret \
  --from-literal=password=NewPassword456! \
  --dry-run=client -o yaml | \
  sops --encrypt /dev/stdin > secret.enc.yaml

# Commit
git add secret.enc.yaml
git commit -m "Rotate my-secret password"
git push
```

### Backup Age Key

```bash
# CRITICAL: Backup your Age private key!

# Option 1: Password manager (recommended)
# Store age.agekey file in 1Password, Bitwarden, etc.

# Option 2: Encrypted backup
sops --encrypt age.agekey > age.agekey.enc
# Store age.agekey.enc in Git or secure location

# Option 3: Multiple locations
cp age.agekey ~/Dropbox/backups/
cp age.agekey /mnt/encrypted-usb/
```

---

## Comparison Cheat Sheet

| Feature | SOPS + FluxCD | Sealed Secrets | ESO | Vault |
|---------|---------------|----------------|-----|-------|
| **Setup Time** | 5 min | 10 min | 30 min | 2+ hours |
| **Additional Infra** | None | Controller | Backend | Vault cluster |
| **GitOps Native** | ✅ | ✅ | ⚠️ | ⚠️ |
| **Auto Rotation** | ❌ | ❌ | ✅ | ✅ |
| **Multi-Cloud** | ✅ (via KMS) | ❌ | ✅ | ✅ |
| **Learning Curve** | Easy | Easy | Medium | Hard |
| **Homelab Friendly** | ✅✅✅ | ✅✅ | ⚠️ | ❌ |
| **Enterprise Ready** | ✅ | ✅ | ✅✅ | ✅✅✅ |

**Legend:**
- ✅✅✅ Excellent
- ✅✅ Very Good
- ✅ Good
- ⚠️ Acceptable
- ❌ Not Recommended

---

## Troubleshooting

### SOPS: "Failed to get data key"

```bash
# Ensure SOPS_AGE_KEY_FILE is set
export SOPS_AGE_KEY_FILE=./age.agekey

# Or use --decrypt with specific key
sops --decrypt --age $(cat age.agekey | grep public) secret.enc.yaml
```

### FluxCD: "Decryption failed"

```bash
# Verify sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Kustomization has decryption config
kubectl get kustomization cluster-apps -n flux-system -o yaml | grep -A 3 decryption

# View FluxCD logs
kubectl logs -n flux-system deployment/kustomize-controller -f
```

### Sealed Secrets: "No private key found"

```bash
# Verify controller is running
kubectl get pods -n kube-system | grep sealed-secrets

# Check controller logs
kubectl logs -n kube-system deployment/sealed-secrets-controller

# Restore from backup if key was lost
kubectl apply -f sealed-secrets-master-key.yaml
kubectl rollout restart deployment/sealed-secrets-controller -n kube-system
```

### General: "Secret not appearing in cluster"

```bash
# Check FluxCD reconciliation
flux reconcile kustomization cluster-apps --with-source

# Force reconciliation
flux suspend kustomization cluster-apps
flux resume kustomization cluster-apps

# Check for errors
kubectl get kustomization -A
kubectl describe kustomization cluster-apps -n flux-system
```

---

## Security Best Practices

### DO ✅

- ✅ Backup Age/Sealed Secrets private keys securely
- ✅ Use TPM-based Talos disk encryption
- ✅ Enable Kubernetes secrets encryption at rest
- ✅ Rotate secrets regularly (90 days for sensitive data)
- ✅ Use separate Age keys for prod/dev environments
- ✅ Store `.sops.yaml` in Git (it's safe, only contains public keys)
- ✅ Use `encrypted_regex` to encrypt only sensitive fields
- ✅ Add disaster recovery key (offline backup)

### DON'T ❌

- ❌ Commit unencrypted secrets to Git (even private repos!)
- ❌ Share Age private keys via Slack/email
- ❌ Use the same Age key across multiple clusters
- ❌ Forget to backup private keys (unrecoverable data loss!)
- ❌ Store Age keys in Git (even encrypted repos)
- ❌ Use base64 encoding as "encryption" (it's not!)
- ❌ Skip Talos disk encryption (defense-in-depth!)
- ❌ Hard-code secrets in Dockerfile/code

---

## Migration Path

### Current: Manual kubectl Secrets

```bash
# Step 1: Export existing secrets
kubectl get secrets --all-namespaces -o yaml > all-secrets-backup.yaml

# Step 2: Filter sensitive secrets (exclude service account tokens)
# Edit all-secrets-backup.yaml manually

# Step 3: Encrypt each secret
for secret in secret1 secret2 secret3; do
  kubectl get secret $secret -o yaml > $secret.yaml
  sops --encrypt $secret.yaml > $secret.enc.yaml
  git add $secret.enc.yaml
done

# Step 4: Commit to Git
git commit -m "Migrate secrets to SOPS"
git push

# Step 5: Verify FluxCD recreates secrets
kubectl delete secret secret1 secret2 secret3
flux reconcile kustomization cluster-apps

# Step 6: Verify secrets exist
kubectl get secrets
```

### Future: External Secrets Operator (if needed)

```bash
# If you later need dynamic secrets from cloud providers:
# 1. Install ESO
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system --create-namespace

# 2. Configure SecretStore (e.g., AWS)
# 3. Create ExternalSecret CRDs
# 4. Keep SOPS for bootstrap/infrastructure secrets
```

---

## Next Steps

1. ✅ **Immediate:** Set up SOPS with FluxCD (30 minutes)
2. ✅ **Day 1:** Migrate existing secrets to SOPS (1 hour)
3. ✅ **Week 1:** Enable Talos disk encryption (if not already)
4. ✅ **Week 2:** Document secret management procedures for team
5. ✅ **Month 1:** Set up automated secret rotation policy
6. ⏳ **Future:** Evaluate ESO/Vault if requirements change

---

## Additional Resources

- **Full Guide:** See `KUBERNETES_SECRETS_MANAGEMENT_GUIDE.md` (comprehensive 40+ page guide)
- **SOPS Docs:** https://github.com/getsops/sops
- **FluxCD SOPS Guide:** https://fluxcd.io/flux/guides/mozilla-sops/
- **Age Encryption:** https://github.com/FiloSottile/age
- **Talos Security:** https://www.siderolabs.com/blog/security-in-kubernetes-infrastructure/

---

**Last Updated:** 2025-11-23
**Maintained By:** Infrastructure Team
**Review Cadence:** Monthly
