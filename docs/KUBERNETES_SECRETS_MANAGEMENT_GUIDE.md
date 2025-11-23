# Kubernetes Secrets Management Guide for Talos Linux

**Last Updated:** 2025-11-23
**Target Platform:** Talos Linux on Proxmox VE 9.0
**Kubernetes Version:** 1.31+
**GitOps Tool:** FluxCD

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Comparison Matrix](#comparison-matrix)
3. [Detailed Solution Analysis](#detailed-solution-analysis)
   - [SOPS with FluxCD](#1-sops-with-fluxcd)
   - [External Secrets Operator (ESO)](#2-external-secrets-operator-eso)
   - [Sealed Secrets (Bitnami)](#3-sealed-secrets-bitnami)
   - [Native Kubernetes Secrets with Encryption at Rest](#4-native-kubernetes-secrets-with-encryption-at-rest)
   - [HashiCorp Vault Integration](#5-hashicorp-vault-integration)
   - [SOPS Secrets Operator](#6-sops-secrets-operator)
4. [Top 3 Recommendations with Implementation](#top-3-recommendations-with-implementation)
5. [Homelab vs Enterprise Recommendations](#homelab-vs-enterprise-recommendations)
6. [Migration Strategies](#migration-strategies)
7. [References](#references)

---

## Executive Summary

This guide evaluates six secrets management approaches for Talos Linux Kubernetes clusters:

**🏆 Top 3 for Homelab:**
1. **SOPS with FluxCD** - Best overall for GitOps workflows
2. **Sealed Secrets** - Simplest GitOps-native solution
3. **Native K8s + Encryption at Rest** - Baseline security for non-GitOps workflows

**🏢 Top 3 for Enterprise:**
1. **External Secrets Operator (ESO)** - Best for multi-cloud/existing secret backends
2. **HashiCorp Vault** - Most comprehensive enterprise solution
3. **SOPS with FluxCD** - Best for pure GitOps shops

**✅ Recommended for This Project:**
- **Primary:** SOPS with FluxCD + Age encryption
- **Rationale:** Already using FluxCD, native integration, no additional infrastructure
- **Backup:** Talos disk encryption at rest for defense-in-depth

---

## Comparison Matrix

| Solution | Setup Complexity (1-10) | Security Level | GitOps Compatible | Operational Overhead | Best For | Infrastructure Required |
|----------|------------------------|----------------|-------------------|---------------------|----------|------------------------|
| **SOPS + FluxCD** | 3/10 | High | ✅ Excellent | Low | Homelab, GitOps workflows | None (FluxCD built-in) |
| **External Secrets Operator** | 6/10 | High | ✅ Good | Medium | Multi-cloud, existing backends | External secret backend |
| **Sealed Secrets** | 4/10 | High | ✅ Excellent | Low | Homelab, GitOps workflows | Kubernetes controller only |
| **Native K8s + Encryption** | 2/10 | Medium | ⚠️ Limited | Very Low | Baseline security | None (Talos built-in) |
| **HashiCorp Vault** | 8/10 | Very High | ⚠️ Moderate | High | Enterprise, compliance | Vault infrastructure |
| **SOPS Secrets Operator** | 5/10 | High | ✅ Good | Medium | Non-FluxCD GitOps | Kubernetes operator |

**Legend:**
- Setup Complexity: 1 (easiest) to 10 (most complex)
- Security Level: Low → Medium → High → Very High
- ✅ Excellent/Good | ⚠️ Moderate/Limited | ❌ Poor/Incompatible

---

## Detailed Solution Analysis

### 1. SOPS with FluxCD

**Overview:**
[Mozilla SOPS](https://github.com/getsops/sops) (Secrets OPerationS) encrypts values within YAML/JSON files while keeping structure readable. [FluxCD has native SOPS integration](https://fluxcd.io/flux/guides/mozilla-sops/), decrypting secrets automatically during reconciliation.

**How It Works:**
1. Encrypt secrets locally with `sops` CLI using Age/GPG/Cloud KMS
2. Commit encrypted YAML to Git (safe to store in public repos)
3. FluxCD automatically decrypts during reconciliation using cluster-stored private key
4. Secrets are created in Kubernetes without ever being stored unencrypted in Git

**Supported Encryption Methods:**
- **Age** (recommended): Modern, lightweight, simple key management
- **GPG/OpenPGP**: Traditional public key encryption
- **Cloud KMS**: AWS KMS, GCP KMS, Azure Key Vault

**Pros:**
- ✅ Native FluxCD integration (no additional operators)
- ✅ Secrets stored encrypted in Git (audit trail, version control)
- ✅ Simple key management with Age
- ✅ Multi-key support (team members, disaster recovery)
- ✅ Selective field encryption (can leave metadata readable)
- ✅ Low operational overhead

**Cons:**
- ❌ Requires manual key distribution to team members
- ❌ No automatic secret rotation from external sources
- ❌ Key management is your responsibility
- ❌ Secrets must be updated manually in Git (no dynamic sync)

**Setup Complexity:** 3/10
**Security Level:** High
**Operational Overhead:** Low

**Best For:**
- Homelab GitOps workflows
- Teams already using FluxCD
- Simple secret rotation requirements
- Full audit trail in Git desired

**Talos Integration:**
- No special Talos configuration required
- Works seamlessly with standard Talos Kubernetes

**Cost:** Free and open source

---

### 2. External Secrets Operator (ESO)

**Overview:**
[External Secrets Operator](https://external-secrets.io/) syncs secrets from external secret management systems (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, etc.) into Kubernetes. It continuously monitors external backends and auto-updates Kubernetes secrets.

**How It Works:**
1. Install ESO in Kubernetes cluster
2. Configure `SecretStore` or `ClusterSecretStore` pointing to external backend
3. Create `ExternalSecret` custom resources referencing external secrets
4. ESO automatically syncs and keeps secrets updated
5. Secrets are available as standard Kubernetes Secrets

**Supported Backends (50+):**
- Cloud: AWS Secrets Manager, Azure Key Vault, GCP Secret Manager
- Vaults: HashiCorp Vault, Bitwarden, 1Password, Keeper, Doppler
- Others: IBM Cloud Secrets, Akeyless, CyberArk, Pulumi ESC

**Pros:**
- ✅ Automatic secret rotation from external sources
- ✅ Single source of truth outside Kubernetes
- ✅ 50+ supported backends
- ✅ Multi-cluster secret sharing
- ✅ Secret templating and transformation
- ✅ No secrets stored in Git
- ✅ Enterprise & Pro versions available (free for ≤5 clusters)

**Cons:**
- ❌ Requires external secret backend infrastructure
- ❌ More complex architecture
- ❌ Additional SPOF (external backend availability)
- ❌ Secrets not version-controlled in Git
- ❌ Harder to audit secret changes

**Setup Complexity:** 6/10
**Security Level:** High
**Operational Overhead:** Medium

**Best For:**
- Multi-cloud environments
- Existing secret backend infrastructure
- Automatic secret rotation requirements
- Enterprise compliance needs
- Multiple Kubernetes clusters

**Talos Integration:**
- Standard Helm installation works on Talos
- No special Talos configuration needed

**Cost:**
- OSS: Free
- Pro: Free for ≤5 clusters
- Enterprise: Paid (custom pricing)

---

### 3. Sealed Secrets (Bitnami)

**Overview:**
[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) uses asymmetric encryption to create `SealedSecret` resources that can only be decrypted by the controller running in your cluster. Public key encryption allows safe storage in Git.

**How It Works:**
1. Install Sealed Secrets controller (generates RSA key pair)
2. Encrypt secrets with `kubeseal` CLI using cluster's public key
3. Store `SealedSecret` YAML in Git
4. Controller decrypts and creates standard Kubernetes Secrets
5. Only the cluster controller can decrypt (even if Git is compromised)

**Pros:**
- ✅ Simple architecture (controller + CLI)
- ✅ Excellent GitOps compatibility
- ✅ Secrets safe in public Git repos
- ✅ FluxCD and ArgoCD integration
- ✅ Automatic re-encryption support
- ✅ Namespace/cluster-wide scopes
- ✅ No external dependencies

**Cons:**
- ❌ Private key loss = all secrets lost (backup critical!)
- ❌ Manual secret rotation required
- ❌ No multi-cluster key sharing by design
- ❌ Re-encryption needed when moving clusters
- ❌ Key rotation is complex

**Setup Complexity:** 4/10
**Security Level:** High
**Operational Overhead:** Low

**Best For:**
- Homelab GitOps workflows
- Simple secret management needs
- ArgoCD users (FluxCD users prefer SOPS)
- No external secret backend available

**Talos Integration:**
- Standard Helm installation works on Talos
- No special Talos configuration needed
- Backup private key outside cluster (critical!)

**Cost:** Free and open source

---

### 4. Native Kubernetes Secrets with Encryption at Rest

**Overview:**
[Talos supports disk encryption](https://www.talos.dev/v1.11/talos-guides/configuration/disk-encryption/) using LUKS2 and [Kubernetes secrets encryption at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) using `aescbc` or `secretbox` (default for new clusters).

**Talos Encryption Methods:**
- **Static passphrase**: Encrypt with static key
- **Node UUID**: Derive key from node UUID
- **Network KMS**: External key management service
- **TPM**: Derive key from Trusted Platform Module

**Kubernetes Secret Encryption:**
- Talos v1.8+ uses `secretbox` by default for etcd secret encryption
- Configured via `aescbcEncryptionSecret` in machine config (base64-encoded 32 bytes)
- Both `aescbc` and `secretbox` can coexist (`secretbox` takes precedence)

**How It Works:**
1. Enable disk encryption in Talos machine config
2. Configure etcd encryption in Kubernetes
3. Secrets encrypted at rest in etcd
4. Decrypted transparently when accessed
5. No application changes required

**Pros:**
- ✅ Built into Talos/Kubernetes (no additional tools)
- ✅ Very simple to enable
- ✅ Defense-in-depth security layer
- ✅ Protects against physical disk theft
- ✅ TPM-anchored encryption available
- ✅ No operational overhead

**Cons:**
- ❌ No protection if cluster is compromised
- ❌ No GitOps workflow support
- ❌ No version control for secrets
- ❌ No audit trail
- ❌ Manual secret management via kubectl
- ❌ Not sufficient as sole secret strategy

**Setup Complexity:** 2/10
**Security Level:** Medium
**Operational Overhead:** Very Low

**Best For:**
- Baseline security layer (use with other solutions)
- Physical security requirements
- Compliance requirements (encryption at rest)
- Defense-in-depth strategy

**Talos Configuration Example:**
```yaml
machine:
  systemDiskEncryption:
    ephemeral:
      provider: luks2
      keys:
        - slot: 0
          tpm: {}
    state:
      provider: luks2
      keys:
        - slot: 0
          tpm: {}
```

**Cost:** Free (built-in)

---

### 5. HashiCorp Vault Integration

**Overview:**
[HashiCorp Vault](https://www.vaultproject.io/) is a comprehensive secrets management platform. Kubernetes integration via [Vault Secrets Store CSI Driver](https://developer.hashicorp.com/vault/docs/platform/k8s/csi/installation), [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector), or [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso).

**Integration Methods:**

| Method | Architecture | Complexity | When to Use |
|--------|--------------|------------|-------------|
| **CSI Driver** | Mounts secrets as volume | Medium | Pods need file-based secrets |
| **Agent Injector** | Sidecar container per pod | High | Legacy apps, advanced templating |
| **Secrets Operator** | Operator syncs to K8s Secrets | Medium | Standard K8s Secret consumption |

**How It Works (CSI Driver - Recommended):**
1. Install Vault CSI Provider (Helm chart)
2. Configure Vault Kubernetes auth method
3. Create Vault policies and roles
4. Mount secrets as CSI volume in pod spec
5. Secrets rendered before pod starts
6. Automatic lease renewal by Agent

**Pros:**
- ✅ Enterprise-grade secret management
- ✅ Dynamic secrets (database creds, etc.)
- ✅ Automatic secret rotation
- ✅ Detailed audit logging
- ✅ Fine-grained access control (policies)
- ✅ All secret engines supported
- ✅ Encryption as a Service
- ✅ PKI management
- ✅ Multi-cloud support

**Cons:**
- ❌ Significant operational overhead (Vault infrastructure)
- ❌ Complex setup and learning curve
- ❌ Requires HA Vault deployment for production
- ❌ Additional cost for enterprise features
- ❌ Network dependency (Vault availability)
- ❌ Overkill for simple use cases

**Setup Complexity:** 8/10
**Security Level:** Very High
**Operational Overhead:** High

**Best For:**
- Enterprise environments
- Compliance requirements (SOC2, PCI-DSS, etc.)
- Dynamic secret generation needs
- Multi-cloud deployments
- Large-scale Kubernetes fleets
- Organizations already using Vault

**Talos Integration:**
- Standard Helm installation works on Talos
- Configure Kubernetes auth in Vault
- No special Talos configuration needed

**Cost:**
- OSS: Free (community support only)
- Enterprise: Paid (starts ~$40k/year for small deployments)

---

### 6. SOPS Secrets Operator

**Overview:**
[SOPS Secrets Operator](https://github.com/isindir/sops-secrets-operator) is a standalone Kubernetes operator that decrypts SOPS-encrypted `SopsSecret` custom resources into standard Kubernetes Secrets. Alternative to FluxCD's built-in SOPS support.

**How It Works:**
1. Install SOPS Secrets Operator
2. Create `SopsSecret` CRs with SOPS-encrypted data
3. Operator decrypts and creates Kubernetes Secrets
4. Automatic secret rotation when `SopsSecret` changes
5. Secrets stored encrypted in Git

**Variants:**
- [isindir/sops-secrets-operator](https://github.com/isindir/sops-secrets-operator) - Original, most popular
- [peak-scale/sops-operator](https://github.com/peak-scale/sops-operator) - Newer, SopsProvider CRD concept

**Pros:**
- ✅ Works without FluxCD/ArgoCD
- ✅ GitOps compatible
- ✅ Automatic secret rotation
- ✅ Supports Age, GPG, Cloud KMS
- ✅ Can use multiple encryption keys
- ✅ Continuous monitoring for changes

**Cons:**
- ❌ Additional operator to maintain
- ❌ Redundant if using FluxCD (has native SOPS)
- ❌ Smaller community vs Sealed Secrets
- ❌ Manual key management required

**Setup Complexity:** 5/10
**Security Level:** High
**Operational Overhead:** Medium

**Best For:**
- Non-FluxCD GitOps workflows
- Organizations using SOPS but not FluxCD
- ArgoCD users wanting SOPS instead of Sealed Secrets
- Migration from manual SOPS to automated sync

**Talos Integration:**
- Standard Helm installation works on Talos
- No special Talos configuration needed

**Cost:** Free and open source

---

## Top 3 Recommendations with Implementation

### 🥇 #1: SOPS with FluxCD + Age Encryption

**Why This is #1:**
- Native FluxCD integration (already using FluxCD per CLAUDE.md)
- Zero additional infrastructure required
- Simple Age key management
- Perfect for homelab scale
- Full GitOps workflow with audit trail

#### Prerequisites

```bash
# Install SOPS (on local machine)
# macOS
brew install sops

# Linux
wget https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
sudo mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops
chmod +x /usr/local/bin/sops

# Install Age (on local machine)
# macOS
brew install age

# Linux
wget https://github.com/FiloSottile/age/releases/download/v1.2.1/age-v1.2.1-linux-amd64.tar.gz
tar xzf age-v1.2.1-linux-amd64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/
```

#### Step 1: Generate Age Key Pair

```bash
# Generate Age key pair
age-keygen -o age.agekey

# Output:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Store public key in environment variable (for convenience)
export SOPS_AGE_RECIPIENTS=age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# CRITICAL: Backup age.agekey securely!
# Store in password manager, encrypted USB, etc.
```

#### Step 2: Create SOPS Configuration

Create `.sops.yaml` in repository root:

```yaml
creation_rules:
  # Encrypt all files in clusters/*/secrets/ directory
  - path_regex: clusters/.*/secrets/.*\.yaml
    encrypted_regex: ^(data|stringData)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

  # Encrypt specific secret files anywhere
  - path_regex: .*secret.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

  # Multiple keys for team + disaster recovery
  - path_regex: clusters/production/.*
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p,
      age1backup_key_here_for_disaster_recovery
```

#### Step 3: Store Age Private Key in Kubernetes

```bash
# Create sops-age secret in flux-system namespace
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age.agekey

# Verify secret created
kubectl get secret sops-age -n flux-system
```

#### Step 4: Configure FluxCD Kustomization for Decryption

```yaml
# clusters/my-cluster/flux-system/kustomization.yaml
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
  # Enable SOPS decryption
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

#### Step 5: Create and Encrypt a Secret

```bash
# Create plain YAML secret
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: default
type: Opaque
stringData:
  username: admin
  password: SuperSecretPassword123!
  database: myapp
EOF

# Encrypt with SOPS (uses .sops.yaml config)
sops --encrypt secret.yaml > secret.enc.yaml

# Inspect encrypted file (structure readable, values encrypted)
cat secret.enc.yaml
```

**Encrypted Output Example:**
```yaml
apiVersion: v1
kind: Secret
metadata:
    name: database-credentials
    namespace: default
type: Opaque
stringData:
    username: ENC[AES256_GCM,data:Zm9v,iv:...,tag:...,type:str]
    password: ENC[AES256_GCM,data:YmFy,iv:...,tag:...,type:str]
    database: ENC[AES256_GCM,data:bXlhcHA=,iv:...,tag:...,type:str]
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
    lastmodified: "2025-11-23T10:30:00Z"
    mac: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
    pgp: []
    version: 3.9.0
```

#### Step 6: Edit Encrypted Secrets

```bash
# Edit encrypted file directly (SOPS decrypts in $EDITOR)
export SOPS_AGE_KEY_FILE=./age.agekey
sops secret.enc.yaml

# SOPS will:
# 1. Decrypt file
# 2. Open in $EDITOR
# 3. Re-encrypt on save
# 4. Update MAC and lastmodified
```

#### Step 7: Commit and Push

```bash
# Safe to commit encrypted files to Git
git add secret.enc.yaml .sops.yaml
git commit -m "Add database credentials (SOPS encrypted)"
git push

# FluxCD will:
# 1. Detect change in Git
# 2. Decrypt using sops-age secret
# 3. Create/update Kubernetes Secret
# 4. Reconcile in ~1-10 minutes (configurable)
```

#### Step 8: Verify FluxCD Reconciliation

```bash
# Check Kustomization status
kubectl get kustomization -n flux-system

# View Kustomization events
kubectl describe kustomization cluster-apps -n flux-system

# Verify secret was created
kubectl get secret database-credentials -n default

# View secret data (base64 decoded)
kubectl get secret database-credentials -n default -o jsonpath='{.data.password}' | base64 -d
```

#### Multi-Key Configuration (Team + Disaster Recovery)

```yaml
# .sops.yaml with multiple keys
creation_rules:
  - path_regex: .*secret.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1alice...,
      age1bob...,
      age1charlie...,
      age1disaster_recovery_key...
```

**Benefits:**
- Multiple team members can decrypt
- Disaster recovery key stored offline
- Any key can decrypt (SOPS tries all keys)
- Add/remove keys by re-encrypting files

---

### 🥈 #2: Sealed Secrets (Bitnami)

**Why This is #2:**
- Excellent for ArgoCD users
- Simple architecture (no FluxCD required)
- Good alternative to SOPS if not using FluxCD
- Slightly more complex key management than SOPS

#### Step 1: Install Sealed Secrets Controller

```bash
# Add Helm repo
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# Install controller (generates key pair automatically)
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set fullnameOverride=sealed-secrets-controller

# Verify installation
kubectl get pods -n kube-system | grep sealed-secrets
```

#### Step 2: Install kubeseal CLI

```bash
# macOS
brew install kubeseal

# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/kubeseal-0.27.1-linux-amd64.tar.gz
tar xzf kubeseal-0.27.1-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/
chmod +x /usr/local/bin/kubeseal
```

#### Step 3: Backup Private Key (CRITICAL!)

```bash
# Backup sealing key (CRITICAL - store securely!)
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-master-key.yaml

# Store this file in:
# - Password manager (1Password, Bitwarden, etc.)
# - Encrypted backup (SOPS, Age, GPG)
# - Offline secure location

# If this key is lost, ALL sealed secrets are unrecoverable!
```

#### Step 4: Create and Seal a Secret

```bash
# Create standard Kubernetes secret (DO NOT APPLY)
kubectl create secret generic database-credentials \
  --namespace=default \
  --from-literal=username=admin \
  --from-literal=password=SuperSecretPassword123! \
  --from-literal=database=myapp \
  --dry-run=client \
  -o yaml > secret.yaml

# Seal the secret (encrypt with cluster's public key)
kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  < secret.yaml > sealed-secret.yaml

# Inspect sealed secret
cat sealed-secret.yaml
```

**Sealed Secret Example:**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
  namespace: default
spec:
  encryptedData:
    username: AgA8...encrypted_base64...==
    password: AgBc...encrypted_base64...==
    database: AgCd...encrypted_base64...==
  template:
    metadata:
      name: database-credentials
      namespace: default
    type: Opaque
```

#### Step 5: Apply Sealed Secret

```bash
# Safe to commit and apply (only cluster controller can decrypt)
kubectl apply -f sealed-secret.yaml

# Verify SealedSecret created
kubectl get sealedsecrets -n default

# Verify controller decrypted to Secret
kubectl get secret database-credentials -n default

# View secret data
kubectl get secret database-credentials -n default -o jsonpath='{.data.password}' | base64 -d
```

#### Step 6: GitOps Workflow

```bash
# Safe to commit sealed-secret.yaml to Git
git add sealed-secret.yaml
git commit -m "Add database credentials (Sealed Secret)"
git push

# FluxCD/ArgoCD will:
# 1. Apply SealedSecret to cluster
# 2. Controller decrypts and creates Secret
# 3. Application can use standard Kubernetes Secret
```

#### Scope Options

```bash
# Namespace-scoped (default) - secret tied to specific namespace
kubeseal --scope namespace-wide < secret.yaml > sealed-secret.yaml

# Cluster-wide - can be renamed and moved between namespaces
kubeseal --scope cluster-wide < secret.yaml > sealed-secret.yaml

# Strict - tied to specific name and namespace (most secure)
kubeseal --scope strict < secret.yaml > sealed-secret.yaml
```

#### Key Rotation

```bash
# Generate new sealing key (old key still works)
kubectl -n kube-system create secret tls my-new-key \
  --cert=my-new-cert.pem \
  --key=my-new-key.pem \
  --labels=sealedsecrets.bitnami.com/sealed-secrets-key=active

# Controller will use newest key for sealing
# Old keys remain for decryption (backwards compatible)

# Re-seal all secrets with new key (optional)
kubeseal --re-encrypt < old-sealed-secret.yaml > new-sealed-secret.yaml
```

---

### 🥉 #3: Native Kubernetes Secrets + Talos Encryption at Rest

**Why This is #3:**
- Essential baseline security layer
- Use in combination with #1 or #2
- Defense-in-depth strategy
- Protects against physical attacks

#### Step 1: Enable Talos Disk Encryption

Create Talos machine config patch:

```yaml
# talos/patches/disk-encryption.yaml
machine:
  systemDiskEncryption:
    # Encrypt ephemeral partition (containers, logs)
    ephemeral:
      provider: luks2
      keys:
        - slot: 0
          # TPM-based encryption (recommended if hardware supports)
          tpm: {}

    # Encrypt state partition (machine config, certificates)
    state:
      provider: luks2
      keys:
        - slot: 0
          tpm: {}
```

**Alternative Key Methods:**

```yaml
# Static passphrase (manual unlock required)
keys:
  - slot: 0
    static:
      passphrase: "my-secure-passphrase-here"

# Node UUID (automatic unlock, tied to hardware)
keys:
  - slot: 0
    nodeID: {}

# Network KMS (enterprise)
keys:
  - slot: 0
    kms:
      endpoint: "https://kms.example.com:9000"
```

#### Step 2: Apply Machine Config Patch

```bash
# Apply during initial bootstrap
talosctl gen config \
  my-cluster https://10.0.0.10:6443 \
  --config-patch @talos/patches/disk-encryption.yaml

# Or apply to existing node (requires reboot and data loss!)
talosctl patch machineconfig \
  --nodes 10.0.0.10 \
  --patch @talos/patches/disk-encryption.yaml
```

#### Step 3: Enable Kubernetes Secrets Encryption at Rest

Talos v1.8+ uses `secretbox` by default, but you can configure explicitly:

```yaml
# talos/patches/secrets-encryption.yaml
cluster:
  # Optional: explicitly configure encryption secret
  # Talos generates this automatically if not specified
  aescbcEncryptionSecret: "base64_encoded_32_random_bytes_here"

  # Note: Talos v1.8+ uses secretbox by default
  # Both aescbc and secretbox can coexist
  # secretbox takes precedence for new writes
```

**Generate encryption secret:**

```bash
# Generate random 32 bytes, base64 encode
openssl rand -base64 32

# Output example: x8fFYhqX3p2kL9mN7vB4cD1eF6gH8iJ0kL1mN2oP3qR=
```

#### Step 4: Verify Encryption

```bash
# Check disk encryption status
talosctl get encryptionconfig

# Verify partitions are encrypted
talosctl read /proc/mounts | grep /dev/mapper

# Output should show dm-crypt devices:
# /dev/mapper/ephemeral on /var type xfs
# /dev/mapper/state on /system/state type xfs
```

#### Step 5: Create Secrets Normally

```bash
# Create secrets as usual (encrypted at rest automatically)
kubectl create secret generic my-secret \
  --from-literal=key1=value1 \
  --from-literal=key2=value2

# Secrets are:
# 1. Encrypted in etcd (secretbox)
# 2. Stored on encrypted disk (LUKS2)
# 3. Decrypted transparently when accessed
```

#### Step 6: Backup Encryption Keys

```bash
# CRITICAL: Backup Talos machine config (contains encryption config)
talosctl get machineconfig -o yaml > machine-config-backup.yaml

# Encrypt backup with SOPS
sops --encrypt machine-config-backup.yaml > machine-config-backup.enc.yaml

# Store encrypted backup in:
# - Git repository (if using SOPS)
# - Password manager
# - Offline secure location
```

#### Defense-in-Depth Strategy

**Layer 1: Talos Disk Encryption**
- Protects against: Physical disk theft, unauthorized access to storage

**Layer 2: Kubernetes Secrets Encryption at Rest**
- Protects against: etcd database compromise, direct database access

**Layer 3: SOPS/Sealed Secrets (GitOps Layer)**
- Protects against: Git repository compromise, unauthorized access to source code

**Layer 4: Application-Level Encryption**
- Protects against: Application compromise, memory dumps

**Recommendation:**
- **Minimum:** Layers 1 + 2 (Talos encryption + K8s encryption at rest)
- **Homelab:** Layers 1 + 2 + 3 (Add SOPS for GitOps)
- **Enterprise:** All 4 layers + HSM/Cloud KMS

---

## Homelab vs Enterprise Recommendations

### Homelab Recommendations

**🏆 Best Choice: SOPS with FluxCD + Age**

**Configuration:**
```yaml
# Recommended homelab stack
GitOps: FluxCD
Secrets: SOPS + Age encryption
Baseline: Talos disk encryption + K8s secrets encryption at rest
Backup: Age private key in password manager
```

**Why:**
- ✅ Zero additional infrastructure cost
- ✅ Simple Age key management (1-2 keys total)
- ✅ Native FluxCD integration
- ✅ Full GitOps workflow with audit trail
- ✅ Low operational overhead
- ✅ Easy disaster recovery (restore Age key + Git repo)

**Alternative for Non-FluxCD Users:**
- **Sealed Secrets** if using ArgoCD or manual kubectl workflows
- **SOPS Secrets Operator** if using SOPS without FluxCD

**Don't Use for Homelab:**
- ❌ HashiCorp Vault (overkill, high overhead)
- ❌ External Secrets Operator (unless already have external backend)
- ❌ Multiple secret management tools (pick one!)

---

### Enterprise Recommendations

**🏆 Best Choice: External Secrets Operator OR HashiCorp Vault**

**Decision Matrix:**

| Scenario | Recommended Solution | Rationale |
|----------|---------------------|-----------|
| Already use AWS/Azure/GCP | **External Secrets Operator** | Leverage existing cloud secret backends |
| Already use HashiCorp Vault | **Vault CSI Driver** | Maximize existing investment |
| Multi-cloud environment | **External Secrets Operator** | 50+ backend support |
| Compliance requirements (SOC2, PCI-DSS) | **HashiCorp Vault** | Enterprise audit logging, policies |
| Dynamic secrets needed | **HashiCorp Vault** | Database credential rotation, etc. |
| Pure GitOps shop | **SOPS with FluxCD** | Best developer experience |
| Multiple K8s clusters | **External Secrets Operator** | Centralized secret management |

**Enterprise Stack Example:**

```yaml
# Multi-layer enterprise configuration
Primary: External Secrets Operator (syncing from AWS Secrets Manager)
GitOps: FluxCD with SOPS (infrastructure secrets)
Baseline: Talos disk encryption (TPM-anchored) + K8s encryption at rest
Compliance: HashiCorp Vault (for audit logging, dynamic secrets)
Backup: Cloud KMS for disaster recovery
```

**Why Layered Approach:**
- **ESO/Vault:** Application secrets with rotation
- **SOPS:** Infrastructure/bootstrap secrets (ESO credentials, etc.)
- **Talos Encryption:** Physical security, compliance checkboxes
- **Cloud KMS:** Enterprise key management, disaster recovery

**Enterprise Best Practices:**
1. **Separation of Concerns:**
   - Infrastructure secrets: SOPS in Git
   - Application secrets: ESO/Vault with rotation
   - Bootstrap secrets: Talos machine config (encrypted)

2. **Key Management:**
   - Use Cloud KMS (AWS KMS, Azure Key Vault, GCP KMS)
   - HSM for highest security requirements
   - Regular key rotation (90 days)

3. **Disaster Recovery:**
   - Multi-region key backup
   - Offline recovery keys (printed, in safe)
   - Documented recovery procedures
   - Regular DR testing

4. **Compliance:**
   - Audit all secret access (Vault audit logs)
   - Encrypt all secrets in transit and at rest
   - Least privilege access (RBAC + Vault policies)
   - Secret rotation policies (30-90 days)

---

## Migration Strategies

### From Manual kubectl Secrets → SOPS

```bash
# Step 1: Export existing secrets
kubectl get secret my-secret -n default -o yaml > secret.yaml

# Step 2: Remove metadata Kubernetes adds
# Edit secret.yaml and remove:
# - metadata.resourceVersion
# - metadata.uid
# - metadata.creationTimestamp

# Step 3: Convert data to stringData (easier to read/edit)
# Change:
#   data:
#     key: dmFsdWU=  # base64
# To:
#   stringData:
#     key: value      # plaintext

# Step 4: Encrypt with SOPS
sops --encrypt secret.yaml > secret.enc.yaml

# Step 5: Delete original secret
kubectl delete secret my-secret -n default

# Step 6: Commit encrypted secret to Git
git add secret.enc.yaml
git commit -m "Migrate my-secret to SOPS"
git push

# FluxCD will recreate the secret from Git
```

### From Sealed Secrets → SOPS

```bash
# Step 1: Get decrypted secret from cluster
kubectl get secret my-secret -n default -o yaml > secret.yaml

# Step 2: Clean up metadata (same as above)

# Step 3: Encrypt with SOPS
sops --encrypt secret.yaml > secret.enc.yaml

# Step 4: Delete SealedSecret
kubectl delete sealedsecret my-secret -n default

# Step 5: Update Git repository
git rm sealed-secret.yaml
git add secret.enc.yaml
git commit -m "Migrate from Sealed Secrets to SOPS"
git push
```

### From SOPS → External Secrets Operator

```bash
# Step 1: Decrypt SOPS secret
sops --decrypt secret.enc.yaml > secret.yaml

# Step 2: Create secret in external backend (example: AWS Secrets Manager)
aws secretsmanager create-secret \
  --name my-app/database-credentials \
  --secret-string file://secret.yaml

# Step 3: Create ExternalSecret referencing AWS
cat > external-secret.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: database-credentials
  data:
    - secretKey: username
      remoteRef:
        key: my-app/database-credentials
        property: username
    - secretKey: password
      remoteRef:
        key: my-app/database-credentials
        property: password
EOF

# Step 4: Apply ExternalSecret
kubectl apply -f external-secret.yaml

# Step 5: Remove SOPS secret from Git
git rm secret.enc.yaml
git add external-secret.yaml
git commit -m "Migrate to External Secrets Operator"
git push
```

---

## References

### Official Documentation

**SOPS + FluxCD:**
- [FluxCD Mozilla SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [FluxCD Secrets Management](https://fluxcd.io/flux/security/secrets-management/)
- [Mozilla SOPS GitHub](https://github.com/getsops/sops)
- [Age Encryption](https://github.com/FiloSottile/age)

**Talos Linux:**
- [Talos Disk Encryption](https://www.talos.dev/v1.11/talos-guides/configuration/disk-encryption/)
- [Talos Security Best Practices](https://www.siderolabs.com/blog/security-in-kubernetes-infrastructure/)

**External Secrets Operator:**
- [External Secrets Operator Documentation](https://external-secrets.io/latest/introduction/overview/)
- [ESO GitHub](https://github.com/external-secrets/external-secrets)
- [ESO Red Hat OpenShift Integration](https://developers.redhat.com/articles/2025/11/11/introducing-external-secrets-operator-openshift)

**Sealed Secrets:**
- [Bitnami Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [FluxCD Sealed Secrets Guide](https://fluxcd.io/flux/guides/sealed-secrets/)

**HashiCorp Vault:**
- [Vault Kubernetes Integration](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Vault CSI Driver](https://developer.hashicorp.com/vault/docs/platform/k8s/csi/installation)
- [Vault Secrets Store CSI Provider](https://github.com/hashicorp/vault-csi-provider)

**SOPS Secrets Operator:**
- [isindir/sops-secrets-operator](https://github.com/isindir/sops-secrets-operator)
- [peak-scale/sops-operator](https://github.com/peak-scale/sops-operator)

### Tutorials and Guides (2024-2025)

**SOPS + FluxCD:**
- [GitOps on k3s with Flux v2 and SOPS/age (October 2025)](https://onidel.com/setup-gitops-k3s-flux/)
- [Encrypted GitOps Secrets with Flux and Age (2024)](https://major.io/p/encrypted-gitops-secrets-with-flux-and-age/)
- [Kubernetes GitOps with FluxCD Part 2 - SOPS (February 2025)](https://apurv.me/posts/kubernetes-gitops-with-fluxcd-part-2/)
- [Using SOPS Secrets with Age (February 2025)](https://www.federicoserinidev.com/blog/using_sops_secrets_with_age/)

**External Secrets Operator:**
- [ESO on Amazon EKS - Terraform Guide (October 2025)](https://medium.com/@bounouh.fedi/external-secrets-operator-eso-on-amazon-eks-a-practical-terraform-first-guide-1ed918bcdecc)
- [How to Setup ESO as a Service (Red Hat)](https://www.redhat.com/en/blog/how-to-setup-external-secrets-operator-eso-as-a-service)

**Sealed Secrets:**
- [Securing Kubernetes Secrets with Sealed Secrets (July 2024)](https://medium.com/@josephsims1/secure-your-kubernetes-cluster-e2ddc3a09eb0)
- [How to Encrypt Kubernetes Secrets Using Sealed Secrets (DigitalOcean, February 2024)](https://www.digitalocean.com/community/developer-center/how-to-encrypt-kubernetes-secrets-using-sealed-secrets-in-doks)

**HashiCorp Vault:**
- [Vault CSI Driver with Kubernetes Auth (IBM, October 2024)](https://community.ibm.com/community/user/blogs/ewan-chalmers/2024/10/04/kubernetes-auth)
- [Kubernetes Vault Integration Comparison (HashiCorp)](https://www.hashicorp.com/en/blog/kubernetes-vault-integration-via-sidecar-agent-injector-vs-csi-provider)

**Talos Linux:**
- [Talos on Proxmox with OpenTofu (August 2024)](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/)
- [Talos: Setting Up Secure Immutable Kubernetes (2024)](https://seehiong.github.io/archives/2024/talos-linux-setting-up-a-secure-immutable-kubernetes-cluster/)
- [Introduction to Talos, the Kubernetes OS (March 2024)](https://blog.yadutaf.fr/2024/03/14/introduction-to-talos-kubernetes-os/)

**Homelab Comparisons:**
- [List of Secrets Management Tools for Kubernetes (2025)](https://blog.techiescamp.com/secrets-management-tools/)
- [Top Secrets Management Tools for 2024 (GitGuardian)](https://blog.gitguardian.com/top-secrets-management-tools-for-2024/)
- [Homelab Secret Management with Azure Key Vault](https://mischavandenburg.com/zet/handling-secrets-kubernetes/)

---

## Conclusion

**For This Project (Talos Linux Homelab with FluxCD):**

**Recommended Implementation:**
```
Primary:   SOPS with FluxCD + Age encryption
Baseline:  Talos disk encryption (TPM) + Kubernetes secrets encryption at rest
Backup:    Age private key in password manager (1Password, Bitwarden, etc.)
```

**Implementation Priority:**
1. ✅ Enable Talos disk encryption (done during initial setup)
2. ✅ Verify Kubernetes secrets encryption at rest (Talos default)
3. ✅ Generate Age key pair and configure SOPS
4. ✅ Store Age private key in Kubernetes (sops-age secret)
5. ✅ Configure FluxCD Kustomization for SOPS decryption
6. ✅ Migrate existing secrets to SOPS-encrypted format
7. ✅ Backup Age private key securely (critical!)

**Next Steps:**
1. Review this guide with project stakeholders
2. Generate Age key pair for the cluster
3. Create `.sops.yaml` configuration in Git repository
4. Test SOPS workflow with non-critical secret
5. Document secret management procedures for team
6. Set up regular backup of Age private key

---

**Document Version:** 1.0
**Last Updated:** 2025-11-23
**Next Review:** 2025-12-23 (monthly review recommended)
