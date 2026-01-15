# Secrets Management

SOPS + Age encryption for GitOps with FluxCD.

**Setup Time:** 10 minutes | **Solution:** SOPS + FluxCD + Age

---

## Quick Setup

### 1. Install Tools

```bash
# macOS
brew install sops age

# Linux (Ubuntu/Debian)
# SOPS
wget https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64
sudo mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops && sudo chmod +x /usr/local/bin/sops

# Age
wget https://dl.filippo.io/age/latest?for=linux/amd64 -O age.tar.gz
tar xf age.tar.gz && sudo mv age/age age/age-keygen /usr/local/bin/
```

### 2. Generate Age Key

```bash
# Create key directory
mkdir -p ~/.config/sops/age

# Generate key pair
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Get your public key (save this!)
age-keygen -y ~/.config/sops/age/keys.txt
# Output: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### 3. Configure Environment

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

### 4. Create .sops.yaml

In repository root:

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    age: >-
      age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

---

## FluxCD Integration

FluxCD automatically decrypts SOPS-encrypted secrets during reconciliation.

### How It Works

1. You push encrypted `*.enc.yaml` to Forgejo
2. FluxCD pulls the changes
3. FluxCD decrypts using the `sops-age` secret in cluster
4. Decrypted secret is applied to Kubernetes

### Verify Setup

```bash
# Check sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Kustomization has decryption configured
kubectl get kustomization flux-system -n flux-system -o yaml | grep -A3 decryption
```

Expected output:
```yaml
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

---

## Daily Operations

### Create New Secret

```bash
# Create plaintext (don't commit this!)
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
stringData:
  username: admin
  password: supersecret123
EOF

# Encrypt
sops -e secret.yaml > secret.enc.yaml

# Delete plaintext, commit encrypted
rm secret.yaml
git add secret.enc.yaml
git commit -m "Add my-secret"
git push
```

### Edit Existing Secret

```bash
# SOPS opens decrypted in $EDITOR, re-encrypts on save
sops secret.enc.yaml

# Commit changes
git add secret.enc.yaml
git commit -m "Update my-secret"
git push
```

### View Decrypted Secret

```bash
# Display to stdout (doesn't modify file)
sops -d secret.enc.yaml
```

### Rotate Secret Value

```bash
# Edit and change values
sops secret.enc.yaml

# Or regenerate entirely
kubectl create secret generic my-secret \
  --from-literal=password=NewPassword456! \
  --dry-run=client -o yaml | \
  sops --encrypt /dev/stdin > secret.enc.yaml

# Commit
git add secret.enc.yaml && git commit -m "Rotate my-secret" && git push
```

---

## Terraform Integration

Use the SOPS provider to read encrypted files:

```hcl
data "sops_file" "secrets" {
  source_file = "${path.module}/../../secrets/proxmox-creds.enc.yaml"
}

provider "proxmox" {
  endpoint = data.sops_file.secrets.data["proxmox_url"]
  api_token = "${data.sops_file.secrets.data["proxmox_token_id"]}=${data.sops_file.secrets.data["proxmox_token_secret"]}"
}
```

---

## File Naming Convention

| Pattern | Description | Commit? |
|---------|-------------|---------|
| `*.enc.yaml` | Encrypted secrets | Yes |
| `*-plaintext.yaml` | Unencrypted (temp) | NO |
| `*.age` | Private keys | NO |

---

## Secret Files in This Project

| File | Purpose |
|------|---------|
| `secrets/proxmox-creds.enc.yaml` | Proxmox API credentials |
| `secrets/nas-backup-creds.enc.yaml` | NFS backup auth (Longhorn) |
| `secrets/git-creds.enc.yaml` | Forgejo admin + FluxCD |
| `secrets/pangolin-creds.enc.yaml` | WireGuard tunnel credentials |

---

## Team Access (Multiple Keys)

Add multiple public keys to `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    age: >-
      age1user1publickey...,
      age1user2publickey...,
      age1user3publickey...
```

Re-encrypt all files:

```bash
find secrets/ -name "*.enc.yaml" -exec sops updatekeys {} \;
```

---

## Key Backup

**CRITICAL: Back up your Age private key!**

```bash
# Option 1: Password manager (recommended)
# Copy contents of ~/.config/sops/age/keys.txt to 1Password/Bitwarden

# Option 2: Encrypted backup
gpg -c ~/.config/sops/age/keys.txt
# Creates keys.txt.gpg - store securely

# Option 3: Print for physical safe
cat ~/.config/sops/age/keys.txt
# Write down and store offline
```

---

## Troubleshooting

### "no key could be found"

```bash
# Check environment variable
echo $SOPS_AGE_KEY_FILE
# Should be: /home/user/.config/sops/age/keys.txt

# Set if missing
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

### FluxCD "Decryption failed"

```bash
# Verify sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Kustomization config
kubectl get kustomization flux-system -n flux-system -o yaml | grep -A3 decryption

# View FluxCD logs
kubectl logs -n flux-system deployment/kustomize-controller -f
```

### "MAC mismatch"

File was encrypted with a different key. Either:
- Use the correct private key
- Re-encrypt with your public key (requires access to plaintext)

### "failed to decrypt sops data key"

Your public key is not in the recipient list. Ask someone to:
1. Add your public key to `.sops.yaml`
2. Run `sops updatekeys` on all encrypted files

---

## Security Best Practices

### DO

- Back up Age private key to password manager
- Use `chmod 600` on key files
- Commit encrypted files to Git
- Rotate keys annually or when team members leave
- Use separate keys for prod/dev

### DON'T

- Commit plaintext secrets (even to private repos)
- Share keys via Slack/email
- Store private keys in Git
- Use base64 as "encryption" (it's not!)
- Store keys in cloud sync folders unencrypted

---

## Resources

- [SOPS Documentation](https://github.com/getsops/sops)
- [Age Documentation](https://github.com/FiloSottile/age)
- [FluxCD SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [SOPS Terraform Provider](https://registry.terraform.io/providers/carlpett/sops/latest)

---

**Last Updated:** 2026-01-15
