# Talos Linux SOPS Integration Report

**Report Date**: 2025-11-23
**Infrastructure Path**: /home/user/infra
**Talos Version**: v1.11.5
**Terraform Talos Provider**: v0.9.0

---

## Executive Summary

This report analyzes the current state of SOPS (Secrets OPerationS) integration for Talos Linux secrets management in the infrastructure. The analysis covers Talos machine secrets, Kubernetes secrets, current implementation gaps, and recommendations for alignment with community best practices.

### Key Findings

✅ **Strengths**:
- SOPS + Age infrastructure is set up with comprehensive documentation
- .sops.yaml configuration file exists
- secrets/ directory structure is in place
- Excellent documentation in secrets/README.md

⚠️ **Gaps Identified**:
- .sops.yaml has placeholder Age keys (not configured for production use)
- **CRITICAL**: kubeconfig and talosconfig files are NOT in .gitignore
- No talhelper integration (community-standard tool for Talos + SOPS)
- No FluxCD + SOPS setup for Kubernetes secrets management
- Current Terraform workflow differs from GitOps best practices

---

## 1. Current Talos Secrets Implementation

### 1.1 Terraform-Managed Secrets (Current Approach)

**Location**: `/home/user/infra/terraform/main.tf`

```hcl
# Generate Talos secrets (cluster CA, bootstrap token, etc.)
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}
```

**How it works**:
1. Terraform `siderolabs/talos` provider generates machine secrets automatically
2. Secrets are stored in Terraform state (local file: `terraform.tfstate`)
3. kubeconfig and talosconfig are written to local files with 0600 permissions
4. No SOPS encryption applied to these files

**Files Generated**:
- `terraform/kubeconfig` - Kubernetes cluster access credentials
- `terraform/talosconfig` - Talos API access credentials

**Security Concerns**:
```bash
# These files are NOT in .gitignore - SECURITY GAP!
$ grep -E "kubeconfig|talosconfig" .gitignore
# No matches found
```

**Terraform State Handling**:
- State file (`terraform.tfstate`) is in .gitignore ✅
- Contains ALL cluster secrets in plaintext
- Local state acceptable for solo homelab (per CLAUDE.md)

### 1.2 Sensitive Outputs Marking

**Location**: `/home/user/infra/terraform/outputs.tf`

```hcl
output "talos_client_configuration" {
  description = "Talos client configuration (sensitive)"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true  # ✅ Properly marked
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (sensitive)"
  value       = var.auto_bootstrap ? data.talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.ca_certificate : "Not available"
  sensitive   = true  # ✅ Properly marked
}
```

**Assessment**: Sensitive outputs are properly marked in Terraform ✅

---

## 2. SOPS Configuration Analysis

### 2.1 .sops.yaml Configuration

**Location**: `/home/user/infra/.sops.yaml`

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    age: >-
      YOUR_AGE_PUBLIC_KEY_HERE  # ⚠️ Placeholder - not configured

  - path_regex: .*\.enc\.yaml$
    age: >-
      YOUR_AGE_PUBLIC_KEY_HERE  # ⚠️ Placeholder - not configured
```

**Status**: ⚠️ **NOT PRODUCTION READY**

**Required Actions**:
1. Generate Age key pair: `age-keygen -o ~/.config/sops/age/keys.txt`
2. Extract public key: `age-keygen -y ~/.config/sops/age/keys.txt`
3. Replace `YOUR_AGE_PUBLIC_KEY_HERE` with actual Age public key
4. Set environment variable: `export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"`

### 2.2 Secrets Directory

**Location**: `/home/user/infra/secrets/`

**Contents**:
- `README.md` - Comprehensive SOPS documentation ✅
- `TEMPLATE-talos-secrets.yaml` - Template for Talos secrets
- `TEMPLATE-proxmox-creds.yaml` - Template for Proxmox credentials
- `TEMPLATE-nas-creds.yaml` - Template for NAS credentials
- `TEMPLATE-ansible-creds.yaml` - Template for Ansible credentials

**Actual encrypted files**: ❌ **NONE EXIST**

**Expected workflow** (per README.md):
```bash
# 1. Create plaintext file
cat > secrets/talos-secrets-plaintext.yaml << EOF
cluster_secret: "actual-secret-value"
bootstrap_token: "actual-token"
EOF

# 2. Encrypt with SOPS
sops -e secrets/talos-secrets-plaintext.yaml > secrets/talos-secrets.enc.yaml

# 3. Delete plaintext
rm secrets/talos-secrets-plaintext.yaml

# 4. Commit encrypted file
git add secrets/talos-secrets.enc.yaml
```

---

## 3. Talos Community Best Practices Research

### 3.1 Official Talos SOPS Support

**Finding**: Talos Linux does NOT have native built-in SOPS integration.

**Source**: Official Talos documentation (https://www.talos.dev/) does not document SOPS integration.

**Community Approach**: SOPS is used as a third-party tool to encrypt Talos configuration files for GitOps workflows.

### 3.2 Recommended Tool: talhelper

**What is talhelper?**
> "Like kustomize but for Talos manifest files with SOPS support natively"

**Official Documentation**: https://budimanjojo.github.io/talhelper/latest/

**Workflow**:
```bash
# 1. Generate secrets with talhelper
talhelper gensecret > talsecret.sops.yaml

# 2. Encrypt with SOPS
sops -e -i talsecret.sops.yaml

# 3. Commit to Git (encrypted)
git add talsecret.sops.yaml

# 4. talhelper can read and decrypt when needed
talhelper genconfig  # Automatically decrypts talsecret.sops.yaml
```

**Key Benefits**:
- Native SOPS integration
- GitOps-friendly workflow
- Separates secrets from machine configuration
- Version-controlled encrypted secrets

**Sources**:
- [Talhelper Documentation](https://budimanjojo.github.io/talhelper/latest/)
- [Setting up a Talos kubernetes cluster with talhelper](https://www.beyondwatts.com/posts/setting-up-a-talos-kubernetes-cluster-with-talhelper/)
- [Talos SOPS Discussion on GitHub](https://github.com/siderolabs/talos/discussions/10081)

### 3.3 Alternative: talosctl + SOPS Workflow

**Standard Community Pattern**:
```bash
# 1. Generate secrets with talosctl
talosctl gen secrets -o secrets.yaml

# 2. Encrypt with SOPS
sops -e secrets.yaml > secrets.enc.yaml

# 3. Delete plaintext
rm secrets.yaml

# 4. Use encrypted secrets with talosctl
talosctl gen config mycluster https://cluster:6443 \
  --with-secrets <(sops -d secrets.enc.yaml)

# 5. Apply as config patch
talosctl apply -f controlplane.yaml -p @<(sops -d secrets.enc.yaml)
```

**Sources**:
- [Separating secrets from your controlplane.yaml/worker.yaml file](https://github.com/siderolabs/talos/discussions/10081)
- [Kubernetes Homelab Series Part 1 - Talos Installation](https://blog.dalydays.com/post/kubernetes-homelab-series-part-1-talos-linux-proxmox/)
- [Bare-metal Kubernetes, Part I: Talos on Hetzner](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)

---

## 4. Kubernetes Secrets in Talos

### 4.1 FluxCD + SOPS Integration (Recommended)

**Industry Standard Pattern**: Talos + FluxCD + SOPS

**Architecture**:
```
┌─────────────────────────────────────────────────┐
│  Git Repository (GitHub/Forgejo)                │
│  ├── clusters/                                  │
│  │   └── homelab/                               │
│  │       ├── flux-system/                       │
│  │       └── apps/                              │
│  │           └── secrets.enc.yaml  ← SOPS       │
│  └── .sops.yaml  ← Age public key               │
└─────────────────────────────────────────────────┘
                    │
                    │ FluxCD syncs
                    ↓
┌─────────────────────────────────────────────────┐
│  Talos Kubernetes Cluster                       │
│  ├── flux-system namespace                      │
│  │   └── sops-age secret (private key)          │
│  └── FluxCD automatically decrypts secrets      │
└─────────────────────────────────────────────────┘
```

**How it works**:
1. Create Kubernetes secrets YAML
2. Encrypt with SOPS: `sops -e secret.yaml > secret.enc.yaml`
3. Commit encrypted secrets to Git
4. FluxCD detects and decrypts secrets automatically
5. Secrets are applied to cluster

**Bootstrap FluxCD with SOPS**:
```bash
# 1. Create Age key secret in cluster
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt

# 2. Bootstrap Flux
flux bootstrap github \
  --owner=wdiazux \
  --repository=infra \
  --path=clusters/homelab \
  --personal

# 3. Create encrypted secret
kubectl create secret generic my-secret \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml | \
  sops -e /dev/stdin > secret.enc.yaml
```

**Official Documentation**:
- [FluxCD SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Bare-metal Kubernetes, Part III: Encrypted GitOps with FluxCD](https://datavirke.dk/posts/bare-metal-kubernetes-part-3-encrypted-gitops-with-fluxcd/)
- [Secure Kubernetes Secrets with SOPS, GitOps & FluxCD](https://bash.ghost.io/secure-kubernetes-secrets-disaster-recovery-with-sops-gitops-fluxcd/)

### 4.2 Current State

**FluxCD Status**: ❌ **NOT INSTALLED**

**Recommendation**: Install FluxCD as documented in CLAUDE.md:
```yaml
# From terraform/outputs.tf:
Next steps:
- Install FluxCD: flux bootstrap github ...
```

---

## 5. Security Gap Analysis

### 5.1 CRITICAL: Missing .gitignore Entries

**Issue**: kubeconfig and talosconfig files are NOT excluded from Git.

**Risk**:
- Accidental commit would expose full cluster access
- Both files contain CA certificates, client certificates, and tokens
- Anyone with these files has complete cluster control

**Fix Required**:
```bash
# Add to .gitignore
echo "kubeconfig" >> .gitignore
echo "talosconfig" >> .gitignore
echo "terraform/kubeconfig" >> .gitignore
echo "terraform/talosconfig" >> .gitignore
```

### 5.2 Terraform State Security

**Current State**:
- Local state file (`terraform.tfstate`)
- Contains ALL secrets in plaintext
- ✅ Properly in .gitignore

**Risk Assessment**:
- **Solo homelab**: ✅ Acceptable (per CLAUDE.md guidelines)
- **Team environment**: ❌ Use remote backend with encryption

**Recommendation for Production**:
```hcl
# terraform/versions.tf
backend "s3" {
  bucket         = "terraform-state"
  key            = "talos/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true  # Encrypt state at rest
  dynamodb_table = "terraform-state-lock"
}
```

### 5.3 Age Key Management

**Current State**:
- .sops.yaml has placeholder keys
- No actual Age keys generated

**Action Required**:
1. Generate Age key pair
2. Store private key securely (password manager, hardware token)
3. Update .sops.yaml with public key
4. Document key rotation procedure

**Security Best Practices** (from secrets/README.md):

✅ **DO**:
- Store private keys in password manager (1Password, Bitwarden)
- Use hardware security tokens (YubiKey with age-plugin-yubikey)
- Rotate keys annually or when team members leave
- Back up private key securely

❌ **DON'T**:
- Never commit private keys to Git
- Don't share keys via insecure channels (email, Slack)
- Don't store in unencrypted cloud sync folders

---

## 6. Comparison: Current vs. Recommended Workflows

### 6.1 Current Workflow (Terraform-Managed)

```
┌─────────────────────────────────────────────────┐
│  Developer Local Machine                        │
├─────────────────────────────────────────────────┤
│  1. terraform apply                             │
│  2. Talos provider generates secrets            │
│  3. Secrets stored in terraform.tfstate         │
│  4. kubeconfig/talosconfig written to disk      │
│  5. Files NOT encrypted with SOPS               │
└─────────────────────────────────────────────────┘
```

**Pros**:
- ✅ Simple for solo operator
- ✅ Automated secret generation
- ✅ No manual SOPS encryption needed

**Cons**:
- ❌ Not GitOps-friendly
- ❌ Secrets not version-controlled
- ❌ No disaster recovery from Git
- ❌ Team collaboration difficult
- ❌ No audit trail for secret changes

### 6.2 Recommended Workflow (GitOps with SOPS)

**Option A: talhelper + SOPS + FluxCD**

```
┌─────────────────────────────────────────────────┐
│  Git Repository (Version Control)               │
├─────────────────────────────────────────────────┤
│  1. talhelper gensecret > talsecret.sops.yaml   │
│  2. sops -e -i talsecret.sops.yaml              │
│  3. git commit talsecret.sops.yaml (encrypted)  │
│  4. talhelper genconfig (auto-decrypts)         │
│  5. FluxCD syncs and decrypts K8s secrets       │
└─────────────────────────────────────────────────┘
```

**Pros**:
- ✅ Full GitOps workflow
- ✅ Secrets version-controlled (encrypted)
- ✅ Disaster recovery from Git
- ✅ Team collaboration enabled
- ✅ Audit trail for all changes
- ✅ Declarative infrastructure

**Cons**:
- ⚠️ More complex setup
- ⚠️ Requires learning talhelper
- ⚠️ Additional tooling (FluxCD)

**Option B: talosctl + SOPS (Simpler Alternative)**

```
┌─────────────────────────────────────────────────┐
│  Git Repository (Version Control)               │
├─────────────────────────────────────────────────┤
│  1. talosctl gen secrets -o secrets.yaml        │
│  2. sops -e secrets.yaml > secrets.enc.yaml     │
│  3. rm secrets.yaml (delete plaintext)          │
│  4. git commit secrets.enc.yaml (encrypted)     │
│  5. Use: talosctl ... --with-secrets <(sops -d) │
└─────────────────────────────────────────────────┘
```

**Pros**:
- ✅ Native talosctl workflow
- ✅ No additional tools (talhelper)
- ✅ Secrets in Git (encrypted)

**Cons**:
- ⚠️ Less automation than talhelper
- ⚠️ Manual SOPS decrypt on each use

---

## 7. Recommendations

### 7.1 Immediate Actions (Security Fixes)

**Priority: CRITICAL**

1. **Add kubeconfig/talosconfig to .gitignore**
   ```bash
   cat >> .gitignore << EOF

   # Talos and Kubernetes configuration files (contain secrets)
   kubeconfig
   talosconfig
   terraform/kubeconfig
   terraform/talosconfig
   EOF
   ```

2. **Configure SOPS with real Age keys**
   ```bash
   # Generate Age key pair
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt

   # Extract public key
   age-keygen -y ~/.config/sops/age/keys.txt

   # Update .sops.yaml with real public key
   # Replace YOUR_AGE_PUBLIC_KEY_HERE with actual key
   ```

3. **Verify no secrets are committed**
   ```bash
   # Check current Git status
   git status

   # If kubeconfig/talosconfig are staged:
   git rm --cached terraform/kubeconfig terraform/talosconfig
   ```

### 7.2 Short-Term Improvements (1-2 weeks)

**Priority: HIGH**

1. **Install FluxCD for GitOps**
   ```bash
   # Bootstrap FluxCD
   flux bootstrap github \
     --owner=wdiazux \
     --repository=infra \
     --path=clusters/homelab \
     --personal

   # Create SOPS Age secret
   kubectl create secret generic sops-age \
     --namespace=flux-system \
     --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
   ```

2. **Document current Terraform secrets workflow**
   - Create secrets/TERRAFORM-SECRETS-WORKFLOW.md
   - Document how secrets are generated
   - Document disaster recovery procedure
   - Document team onboarding (if applicable)

3. **Implement secret rotation procedure**
   - Document when to rotate Talos machine secrets
   - Document how to rotate Age keys
   - Test recovery from SOPS-encrypted secrets

### 7.3 Long-Term Enhancements (Future)

**Priority: MEDIUM**

1. **Evaluate talhelper for Talos GitOps**
   - Research talhelper benefits for your use case
   - Test in development environment
   - Compare with current Terraform workflow
   - Decide on migration path (if beneficial)

2. **Implement FluxCD + SOPS for all Kubernetes secrets**
   - Migrate manual `kubectl create secret` to encrypted YAML
   - Store all secrets in Git (encrypted with SOPS)
   - Use FluxCD Kustomization for automatic decryption

3. **Consider remote Terraform state (if scaling to team)**
   - Evaluate need for collaboration
   - Set up S3/GitLab backend with encryption
   - Implement state locking (DynamoDB/Consul)

4. **Hardware security key integration**
   - Evaluate YubiKey + age-plugin-yubikey
   - Implement for additional security layer
   - Document hardware key setup procedure

---

## 8. Migration Path: Current to GitOps

### 8.1 Phase 1: Add SOPS Support (No Breaking Changes)

**Goal**: Add SOPS encryption alongside current Terraform workflow

**Steps**:
1. Configure .sops.yaml with real Age keys ✅
2. Add .gitignore entries for kubeconfig/talosconfig ✅
3. Keep current Terraform workflow ✅
4. Start using SOPS for NEW secrets (Proxmox, NAS, Ansible)

**Impact**: Zero - additive only

### 8.2 Phase 2: Install FluxCD

**Goal**: Enable GitOps for Kubernetes secrets

**Steps**:
1. Install FluxCD via Helm (after Cilium)
2. Create SOPS Age secret in flux-system namespace
3. Test FluxCD + SOPS with sample secret
4. Migrate Kubernetes secrets to SOPS-encrypted YAML

**Impact**: Low - Kubernetes only, doesn't affect Talos

### 8.3 Phase 3: Evaluate Terraform vs. talhelper (Optional)

**Goal**: Decide on long-term Talos secrets strategy

**Decision Matrix**:

| Factor | Terraform (Current) | talhelper + SOPS |
|--------|---------------------|------------------|
| **Simplicity** | ✅ Simple | ⚠️ Learning curve |
| **GitOps** | ❌ Not GitOps | ✅ Full GitOps |
| **Disaster Recovery** | ⚠️ Local state | ✅ Git recovery |
| **Team Collaboration** | ⚠️ Limited | ✅ Excellent |
| **Audit Trail** | ❌ No | ✅ Git history |
| **Homelab Suitability** | ✅ Excellent | ✅ Good |
| **Enterprise Suitability** | ⚠️ Limited | ✅ Excellent |

**Recommendation**:
- **For solo homelab**: Current Terraform approach is acceptable
- **For learning GitOps**: Migrate to talhelper + SOPS
- **For team/enterprise**: Definitely use talhelper + SOPS

---

## 9. Documentation Gaps

### 9.1 Existing Documentation (Excellent)

✅ `/home/user/infra/secrets/README.md` - Comprehensive SOPS guide
✅ `/home/user/infra/CLAUDE.md` - References SOPS in multiple sections
✅ Secret templates in `/home/user/infra/secrets/TEMPLATE-*.yaml`

### 9.2 Missing Documentation

❌ **Talos-specific SOPS workflow**
- How to encrypt Talos machine configs
- talhelper integration guide
- Migration from Terraform to GitOps

❌ **FluxCD + SOPS setup guide**
- Step-by-step FluxCD installation
- SOPS Age secret creation
- First encrypted Kubernetes secret example

❌ **Disaster recovery procedures**
- How to recover cluster from Git (encrypted secrets)
- Secret rotation procedures
- Backup and restore of Age private keys

❌ **Team onboarding guide** (if applicable)
- How new team members get Age private key
- How to decrypt secrets for development
- Git workflow for encrypted secrets

### 9.3 Recommended New Documentation

**Create**: `docs/TALOS-SOPS-WORKFLOW.md`
- Current Terraform workflow
- Alternative talhelper workflow
- Comparison and migration guide

**Create**: `docs/FLUXCD-SOPS-SETUP.md`
- FluxCD installation on Talos
- SOPS Age secret setup
- First encrypted secret example
- Troubleshooting guide

**Update**: `CLAUDE.md` section on Talos secrets
- Add talhelper to recommended tools
- Document GitOps workflow option
- Add FluxCD + SOPS pattern

---

## 10. Security Compliance Checklist

### 10.1 SOPS Configuration

- [ ] Age key pair generated
- [ ] Private key stored securely (password manager)
- [ ] Public key configured in .sops.yaml
- [ ] SOPS_AGE_KEY_FILE environment variable set
- [ ] .sops.yaml committed to Git
- [ ] Private key NEVER committed to Git

### 10.2 Git Security

- [ ] kubeconfig in .gitignore
- [ ] talosconfig in .gitignore
- [ ] terraform.tfstate in .gitignore
- [ ] *.tfvars in .gitignore (for local overrides)
- [ ] All plaintext secrets in .gitignore
- [ ] Only .enc.yaml files committed

### 10.3 Terraform Security

- [ ] Sensitive variables marked `sensitive = true`
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] No secrets in terraform.tfvars (use env vars)
- [ ] State file encrypted (if using remote backend)
- [ ] State locking enabled (if multi-user)

### 10.4 Kubernetes Security

- [ ] FluxCD installed with SOPS support
- [ ] SOPS Age secret created in flux-system namespace
- [ ] Secret properly scoped (namespace-specific)
- [ ] RBAC configured for secret access
- [ ] All secrets encrypted with SOPS before commit

### 10.5 Operational Security

- [ ] Age key rotation procedure documented
- [ ] Disaster recovery tested
- [ ] Backup of Age private key (secure location)
- [ ] Team key sharing procedure (if applicable)
- [ ] Incident response plan for key compromise

---

## 11. Conclusion

### 11.1 Current State Assessment

**Overall Security Posture**: ⚠️ **MODERATE** with critical gaps

**Strengths**:
- ✅ Excellent SOPS documentation
- ✅ Proper Terraform sensitive output marking
- ✅ Comprehensive secret templates
- ✅ Good infrastructure foundation

**Critical Gaps**:
- ❌ kubeconfig/talosconfig not in .gitignore
- ❌ .sops.yaml has placeholder keys
- ❌ No FluxCD + SOPS for Kubernetes secrets
- ❌ No GitOps workflow for Talos secrets

**Risk Level**: **MEDIUM** - secrets properly generated but not properly protected from accidental Git commits

### 11.2 Path Forward

**Immediate** (Today):
1. Fix .gitignore
2. Configure .sops.yaml with real keys
3. Verify no secrets committed

**Short-term** (1-2 weeks):
1. Install FluxCD
2. Document current workflow
3. Test SOPS encryption for new secrets

**Long-term** (Future):
1. Evaluate talhelper
2. Migrate to full GitOps (if beneficial)
3. Implement hardware key security

### 11.3 Alignment with CLAUDE.md

**Current implementation follows CLAUDE.md guidelines**:
- ✅ SOPS + Age for secrets (infrastructure exists)
- ✅ Terraform for infrastructure (active)
- ✅ Talos for Kubernetes (deployed)
- ⚠️ FluxCD for GitOps (not yet installed)

**Gap from CLAUDE.md recommendations**:
- FluxCD listed as "chosen tool" but not deployed
- GitOps workflow mentioned but not implemented
- SOPS documented but not actively used

---

## 12. References and Sources

### Official Documentation

1. [Talos Linux Official Documentation](https://www.talos.dev/docs/latest/)
2. [SOPS Official Repository](https://github.com/getsops/sops)
3. [FluxCD SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
4. [Talhelper Documentation](https://budimanjojo.github.io/talhelper/latest/)

### Community Resources

5. [Setting up a Talos kubernetes cluster with talhelper](https://www.beyondwatts.com/posts/setting-up-a-talos-kubernetes-cluster-with-talhelper/)
6. [Kubernetes Homelab Series Part 1 - Talos Installation](https://blog.dalydays.com/post/kubernetes-homelab-series-part-1-talos-linux-proxmox/)
7. [Bare-metal Kubernetes, Part I: Talos on Hetzner](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)
8. [Bare-metal Kubernetes, Part III: Encrypted GitOps with FluxCD](https://datavirke.dk/posts/bare-metal-kubernetes-part-3-encrypted-gitops-with-fluxcd/)
9. [Secure Kubernetes Secrets with SOPS, GitOps & FluxCD](https://bash.ghost.io/secure-kubernetes-secrets-disaster-recovery-with-sops-gitops-fluxcd/)
10. [Separating secrets from your controlplane.yaml/worker.yaml file](https://github.com/siderolabs/talos/discussions/10081)

### Infrastructure-Specific

11. `/home/user/infra/secrets/README.md` - Project SOPS documentation
12. `/home/user/infra/CLAUDE.md` - Project AI assistant guide
13. `/home/user/infra/terraform/main.tf` - Current Talos secrets implementation
14. `/home/user/infra/.sops.yaml` - SOPS configuration

---

**Report Prepared By**: Claude Code (AI Assistant)
**Next Review Date**: After implementing immediate actions
**Action Required**: Review and implement recommendations in priority order
