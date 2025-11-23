# SOPS Integration Action Checklist

**Priority**: CRITICAL Security Fixes
**Estimated Time**: 30-60 minutes
**Date**: 2025-11-23

---

## ⚠️ CRITICAL: Immediate Actions (Do Today)

### 1. Fix .gitignore (5 minutes)

**Risk**: kubeconfig/talosconfig files could be accidentally committed, exposing full cluster access

```bash
# Navigate to repo root
cd /home/user/infra

# Add missing entries to .gitignore
cat >> .gitignore << 'EOF'

# Talos and Kubernetes configuration files (contain secrets)
kubeconfig
talosconfig
terraform/kubeconfig
terraform/talosconfig

# Age private keys (never commit these)
*.age
keys.txt
EOF

# Verify additions
tail -10 .gitignore
```

**Verify**: Check if files were accidentally staged
```bash
git status | grep -E "kubeconfig|talosconfig"
```

**If files are staged/committed**: Remove from Git history
```bash
# Remove from staging (if staged but not committed)
git rm --cached terraform/kubeconfig terraform/talosconfig

# If already committed, use git filter-branch or BFG Repo-Cleaner
# WARNING: This rewrites history - coordinate with team if applicable
```

### 2. Configure SOPS with Real Age Keys (10 minutes)

**Current State**: .sops.yaml has placeholder `YOUR_AGE_PUBLIC_KEY_HERE`

**Steps**:

```bash
# 1. Generate Age key pair
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# 2. Extract public key
PUBLIC_KEY=$(age-keygen -y ~/.config/sops/age/keys.txt)
echo "Your Age public key: $PUBLIC_KEY"

# 3. Update .sops.yaml
cd /home/user/infra
# Use sed to replace placeholder with actual key
sed -i "s|YOUR_AGE_PUBLIC_KEY_HERE|$PUBLIC_KEY|g" .sops.yaml

# 4. Verify .sops.yaml was updated
grep -A 1 "path_regex:" .sops.yaml

# 5. Set environment variable (add to ~/.bashrc or ~/.zshrc)
echo 'export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"' >> ~/.bashrc
source ~/.bashrc

# 6. Test SOPS
echo "test: secret" | sops -e /dev/stdin
```

**Backup Private Key**: Store in password manager (1Password, Bitwarden, etc.)
```bash
# Display private key for copying to password manager
cat ~/.config/sops/age/keys.txt
```

### 3. Verify No Secrets in Git (5 minutes)

```bash
cd /home/user/infra

# Check for any sensitive files in Git history
git log --all --full-history --source -- terraform/kubeconfig terraform/talosconfig

# Check current status
git status

# Check .gitignore is working
git check-ignore -v terraform/kubeconfig terraform/talosconfig
```

**Expected output**: Files should be ignored by .gitignore

---

## 📋 SHORT-TERM: Document and Test (1-2 weeks)

### 4. Test SOPS Encryption (15 minutes)

**Create and encrypt a test secret**:

```bash
cd /home/user/infra

# Create a test secret (plaintext)
cat > secrets/test-secret-plaintext.yaml << EOF
# Test secret
test_key: "test_value"
database_password: "super_secret_123"
EOF

# Encrypt with SOPS
sops -e secrets/test-secret-plaintext.yaml > secrets/test-secret.enc.yaml

# Delete plaintext
rm secrets/test-secret-plaintext.yaml

# Verify encryption worked
cat secrets/test-secret.enc.yaml
# Should show encrypted values (ENC[...])

# Decrypt to verify
sops -d secrets/test-secret.enc.yaml

# Commit encrypted file
git add secrets/test-secret.enc.yaml
git commit -m "test: Add SOPS test secret"
```

### 5. Create Proxmox Credentials Secret (10 minutes)

**Replace terraform.tfvars with SOPS-encrypted secrets**:

```bash
cd /home/user/infra

# 1. Create plaintext credentials file
cat > secrets/proxmox-creds-plaintext.yaml << EOF
proxmox_url: "https://proxmox.local:8006/api2/json"
proxmox_username: "root@pam"
proxmox_api_token: "YOUR_ACTUAL_TOKEN_HERE"
EOF

# 2. Encrypt with SOPS
sops -e secrets/proxmox-creds-plaintext.yaml > secrets/proxmox-creds.enc.yaml

# 3. Delete plaintext
rm secrets/proxmox-creds-plaintext.yaml

# 4. Commit encrypted file
git add secrets/proxmox-creds.enc.yaml
git commit -m "feat: Add encrypted Proxmox credentials"
```

**Update Terraform to use SOPS** (optional - for GitOps approach):

```bash
# Add SOPS provider to terraform/versions.tf
# (This is optional - current approach with env vars is fine for homelab)
```

### 6. Install FluxCD (30 minutes)

**After Cilium is installed**:

```bash
# 1. Install flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# 2. Verify installation
flux --version

# 3. Bootstrap FluxCD (after cluster is running)
flux bootstrap github \
  --owner=wdiazux \
  --repository=infra \
  --path=clusters/homelab \
  --personal

# 4. Create SOPS Age secret for FluxCD
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt

# 5. Verify FluxCD is running
kubectl get pods -n flux-system

# 6. Test FluxCD + SOPS with sample secret
cat > test-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
  namespace: default
type: Opaque
stringData:
  password: "super_secret"
EOF

# Encrypt with SOPS
sops -e test-secret.yaml > test-secret.enc.yaml

# Apply via FluxCD
kubectl apply -f test-secret.enc.yaml

# Verify FluxCD decrypted it
kubectl get secret test-secret -o yaml
```

---

## 📚 DOCUMENTATION: Update Guides (1 week)

### 7. Create FluxCD + SOPS Setup Guide

**File**: `docs/FLUXCD-SOPS-SETUP.md`

**Contents**:
- FluxCD installation steps
- SOPS Age secret creation
- First encrypted Kubernetes secret example
- Troubleshooting guide

### 8. Create Talos SOPS Workflow Guide

**File**: `docs/TALOS-SOPS-WORKFLOW.md`

**Contents**:
- Current Terraform workflow documentation
- Alternative talhelper workflow
- Comparison and migration guide
- Decision matrix for choosing approach

### 9. Update CLAUDE.md

**Sections to update**:
- Add talhelper to "Talos Linux Recommended Tools"
- Document GitOps workflow option
- Add FluxCD + SOPS pattern details
- Update "Project-Specific Tool Decisions" with SOPS status

---

## 🔄 LONG-TERM: GitOps Migration (Optional, Future)

### 10. Evaluate talhelper (2-4 hours)

```bash
# Install talhelper
go install github.com/budimanjojo/talhelper/cmd/talhelper@latest

# Create talconfig.yaml
talhelper gensecret > talsecret.sops.yaml

# Encrypt with SOPS
sops -e -i talsecret.sops.yaml

# Test configuration generation
talhelper genconfig

# Compare with current Terraform approach
```

### 11. Migrate to Full GitOps (1-2 days)

**Only if beneficial for your use case**:

- [ ] Create Git repository structure for FluxCD
- [ ] Migrate all Kubernetes manifests to Git
- [ ] Set up HelmRelease resources for Cilium, Longhorn, etc.
- [ ] Configure FluxCD Kustomizations
- [ ] Test disaster recovery from Git
- [ ] Document new workflow

---

## ✅ Completion Checklist

### Critical Security (Must Complete)

- [ ] .gitignore updated with kubeconfig/talosconfig
- [ ] Age key pair generated
- [ ] Private key backed up to password manager
- [ ] .sops.yaml configured with real public key
- [ ] SOPS_AGE_KEY_FILE environment variable set
- [ ] Verified no secrets in Git history

### Short-Term (Should Complete)

- [ ] SOPS encryption tested with sample secret
- [ ] Proxmox credentials encrypted with SOPS
- [ ] FluxCD installed on Talos cluster
- [ ] SOPS Age secret created in flux-system namespace
- [ ] FluxCD + SOPS tested with sample Kubernetes secret

### Documentation (Should Complete)

- [ ] FluxCD + SOPS setup guide created
- [ ] Talos SOPS workflow guide created
- [ ] CLAUDE.md updated with SOPS status

### Long-Term (Optional)

- [ ] talhelper evaluated
- [ ] Decision made on GitOps migration
- [ ] Full GitOps implemented (if beneficial)

---

## 🚨 DANGER ZONE: What NOT to Do

❌ **NEVER**:
- Commit Age private keys to Git
- Share private keys via email/Slack
- Use SOPS without backing up private key
- Commit plaintext secrets (even temporarily)
- Push kubeconfig/talosconfig to Git

⚠️ **AVOID**:
- Rotating Age keys without backup
- Testing SOPS on production secrets first
- Skipping .gitignore updates
- Using weak Age key passphrases

---

## 📞 Support and Resources

**If you encounter issues**:

1. Check SOPS documentation: https://github.com/getsops/sops
2. Review secrets/README.md in this repo
3. Check official Talos docs: https://www.talos.dev/
4. Review FluxCD SOPS guide: https://fluxcd.io/flux/guides/mozilla-sops/

**Common errors and solutions**:

```bash
# Error: "no key could be found"
# Solution: Set SOPS_AGE_KEY_FILE environment variable

# Error: "MAC mismatch"
# Solution: File encrypted with different key - re-encrypt

# Error: "failed to decrypt sops data key"
# Solution: Your public key not in recipient list - update .sops.yaml and re-encrypt
```

---

**Created**: 2025-11-23
**Last Updated**: 2025-11-23
**Owner**: wdiazux
**Estimated Total Time**: 2-4 hours (critical + short-term)
