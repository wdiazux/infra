# Secrets Management with SOPS + Age

This directory contains encrypted secrets for the infrastructure automation project. All sensitive data is encrypted using [SOPS](https://github.com/getsops/sops) with [Age](https://github.com/FiloSottile/age) encryption.

## Prerequisites

Install SOPS and Age on your system:

### Ubuntu/Debian
```bash
# Install SOPS
wget https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64
sudo mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops

# Install Age
wget https://dl.filippo.io/age/latest?for=linux/amd64 -O age.tar.gz
tar xf age.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/
rm -rf age age.tar.gz

# Verify installation
sops --version
age --version
```

### macOS
```bash
brew install sops age
```

### Verify Installation
```bash
sops --version  # Should show v3.11.0 or later
age --version   # Should show v1.1.1 or later
```

## First-Time Setup

### 1. Generate Age Key Pair

**IMPORTANT**: Do this on your secure local machine, not on shared systems.

```bash
# Create directory for Age keys
mkdir -p ~/.config/sops/age

# Generate a new Age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Set proper permissions (read-only for owner)
chmod 600 ~/.config/sops/age/keys.txt
```

The output will show your public key:
```
Public key: age1yl4td9av3g5j2z5w0cm7mqlcvx3u0p3r5jtqskhf7y8uevm8l8jqhs9xu7
```

### 2. Extract Your Public Key

```bash
# Display your public key
age-keygen -y ~/.config/sops/age/keys.txt
```

Copy this public key - you'll need it for the next step.

### 3. Update .sops.yaml Configuration

Edit `../.sops.yaml` in the repository root and replace `YOUR_AGE_PUBLIC_KEY_HERE` with your actual Age public key:

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    age: >-
      age1yl4td9av3g5j2z5w0cm7mqlcvx3u0p3r5jtqskhf7y8uevm8l8jqhs9xu7
```

### 4. Set Environment Variable

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

Then reload your shell:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Usage

### Encrypting a New Secret File

**Create a plaintext file first** (don't commit this):

```bash
cat > secrets/proxmox-creds-plaintext.yaml << EOF
proxmox_url: "https://proxmox.example.com:8006/api2/json"
proxmox_user: "terraform@pve"
proxmox_token_id: "terraform-token"
proxmox_token_secret: "your-secret-token-here"
EOF
```

**Encrypt it with SOPS:**

```bash
sops -e secrets/proxmox-creds-plaintext.yaml > secrets/proxmox-creds.enc.yaml
```

**Delete the plaintext file:**

```bash
rm secrets/proxmox-creds-plaintext.yaml
```

**Commit the encrypted file:**

```bash
git add secrets/proxmox-creds.enc.yaml
git commit -m "Add encrypted Proxmox credentials"
```

### Viewing Encrypted Files

```bash
# Decrypt and display to stdout (doesn't modify the file)
sops -d secrets/proxmox-creds.enc.yaml
```

### Editing Encrypted Files

SOPS opens the file in your default editor (decrypted), then re-encrypts on save:

```bash
sops secrets/proxmox-creds.enc.yaml
```

Changes are automatically encrypted when you save and close the editor.

### Using Encrypted Secrets in Terraform

Use the SOPS Terraform provider:

```hcl
data "sops_file" "secrets" {
  source_file = "${path.module}/../../secrets/proxmox-creds.enc.yaml"
}

provider "proxmox" {
  endpoint = data.sops_file.secrets.data["proxmox_url"]
  username = data.sops_file.secrets.data["proxmox_user"]
  api_token = "${data.sops_file.secrets.data["proxmox_token_id"]}=${data.sops_file.secrets.data["proxmox_token_secret"]}"
}
```

### Using Encrypted Secrets in Ansible

Use the community.sops collection:

```bash
# Install the collection
ansible-galaxy collection install community.sops
```

In your playbook:

```yaml
---
- name: Example playbook using SOPS
  hosts: localhost
  vars_files:
    - ../../secrets/ansible-vars.enc.yaml
  tasks:
    - name: Display decrypted variable
      debug:
        msg: "{{ secret_variable }}"
```

Or use the `sops` lookup plugin:

```yaml
---
- name: Example with lookup
  hosts: localhost
  tasks:
    - name: Load secrets
      set_fact:
        proxmox_password: "{{ lookup('community.sops.sops', '../../secrets/proxmox-creds.enc.yaml')['proxmox_password'] }}"
```

## Secret File Naming Convention

Use consistent naming for encrypted files:

- **Encrypted files**: `*.enc.yaml` (safe to commit)
- **Plaintext files**: `*-plaintext.yaml` (in .gitignore, never commit)

Examples:
- ✅ `proxmox-creds.enc.yaml` (encrypted, commit this)
- ❌ `proxmox-creds-plaintext.yaml` (plaintext, do NOT commit)
- ✅ `ansible-vault.enc.yaml` (encrypted, commit this)
- ❌ `secrets.yaml` (ambiguous naming, avoid)

## Team Access (Multiple Keys)

To allow multiple team members to decrypt secrets:

1. Each team member generates their own Age key pair
2. Collect all public keys
3. Update `.sops.yaml` with comma-separated public keys:

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    age: >-
      age1yl4td9av3g5j2z5w0cm7mqlcvx3u0p3r5jtqskhf7y8uevm8l8jqhs9xu7,
      age1ze3x5y2j5w0cm7mqlcvx3u0p3r5jtqskhf7y8uevm8l8jqhs9abc123,
      age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567
```

4. Re-encrypt all existing files with the new keys:

```bash
find secrets/ -name "*.enc.yaml" -exec sops updatekeys {} \;
```

## Key Rotation

To rotate encryption keys:

1. Generate a new Age key pair
2. Update `.sops.yaml` with the new public key
3. Re-encrypt all files:

```bash
find secrets/ -name "*.enc.yaml" -exec sops updatekeys --yes {} \;
```

4. Securely delete the old private key
5. Distribute new private key to authorized team members via secure channel

## Security Best Practices

### ✅ DO

- **Store private keys securely**:
  - Password manager (1Password, Bitwarden, etc.)
  - Hardware security token (YubiKey with age-plugin-yubikey)
  - Encrypted filesystem

- **Use proper file permissions**:
  ```bash
  chmod 600 ~/.config/sops/age/keys.txt
  ```

- **Commit encrypted files to Git**:
  - Files matching `.enc.yaml` are safe to commit
  - Encrypted secrets are useless without the private key

- **Rotate keys periodically**:
  - Annually or when team members leave
  - After any suspected key compromise

- **Back up your private key securely**:
  - Store in password manager
  - Print and store in physical safe (for disaster recovery)

### ❌ DON'T

- **Never commit plaintext secrets**:
  - Always encrypt before committing
  - Check with `git diff` before pushing

- **Never commit private keys**:
  - `.gitignore` includes `secrets/*.txt` and `*.age`
  - Private keys in Git = security incident

- **Don't share private keys via insecure channels**:
  - No email, Slack, Teams, etc.
  - Use secure key exchange methods only

- **Don't use weak storage**:
  - Not in cloud sync folders unencrypted (Dropbox, Google Drive, etc.)
  - Not in browser password managers (use dedicated password manager)

## Troubleshooting

### Error: "no key could be found"

**Problem**: SOPS can't find your Age private key.

**Solution**:
```bash
# Check environment variable
echo $SOPS_AGE_KEY_FILE

# Should output: /home/user/.config/sops/age/keys.txt
# If not, set it:
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

### Error: "MAC mismatch"

**Problem**: File was encrypted with a different key than you have.

**Solution**:
- Verify you're using the correct private key
- Contact the person who encrypted the file
- Re-encrypt the file with your public key (requires access to plaintext)

### Error: "failed to decrypt sops data key"

**Problem**: Your public key is not in the file's list of recipients.

**Solution**:
1. Get the plaintext version from someone who can decrypt it
2. Re-encrypt with your public key included
3. Or ask someone to run `sops updatekeys` after adding your public key to `.sops.yaml`

### File not encrypting automatically

**Problem**: SOPS doesn't encrypt the file when you edit it.

**Solution**:
- Check `.sops.yaml` path regex matches your file location
- Ensure Age public key is set in `.sops.yaml`
- Manually encrypt: `sops -e file.yaml > file.enc.yaml`

## Example Secret Files

### Proxmox Credentials

File: `secrets/proxmox-creds.enc.yaml`

```yaml
# Proxmox API credentials for Terraform
proxmox_url: "https://proxmox.example.com:8006/api2/json"
proxmox_user: "terraform@pve"
proxmox_token_id: "terraform-token"
proxmox_token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Talos Machine Configuration Secrets

File: `secrets/talos-secrets.enc.yaml`

```yaml
# Talos cluster secrets
cluster_name: "homelab-k8s"
cluster_secret: "base64-encoded-secret-here"
bootstrap_token: "token-value-here"
```

### Ansible Credentials

File: `secrets/ansible-creds.enc.yaml`

```yaml
# Ansible SSH and sudo credentials
ansible_user: "admin"
ansible_password: "secure-password-here"
ansible_become_password: "sudo-password-here"
```

### NAS Backup Credentials (Longhorn)

File: `secrets/nas-backup-creds.enc.yaml`

Used by Terraform to create the `longhorn-backup-secret` Kubernetes secret for NFS backup authentication.

```yaml
# NFS credentials for Longhorn backup target
nfs_username: "your-nas-username"
nfs_password: "your-nas-password"
```

### Git/Forgejo Credentials

File: `secrets/git-creds.enc.yaml`

Used by Terraform for Forgejo admin setup and FluxCD bootstrap.

```yaml
# Forgejo admin credentials
forgejo_admin_username: "admin"
forgejo_admin_password: "secure-password"
forgejo_admin_email: "admin@home-infra.net"

# Git settings (optional overrides)
git_hostname: "git.home-infra.net"
git_owner: "wdiaz"
git_repository: "infra"
```

## CI/CD Integration

For GitHub Actions or Forgejo Actions:

1. **Add Age private key as a secret** in your CI/CD platform:
   - Secret name: `SOPS_AGE_KEY`
   - Value: Contents of `~/.config/sops/age/keys.txt`

2. **Use in workflow**:

```yaml
name: Infrastructure CI/CD

on: [push, pull_request]

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup SOPS
        run: |
          curl -LO https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64
          sudo mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops
          sudo chmod +x /usr/local/bin/sops

      - name: Setup Age
        run: |
          curl -LO https://dl.filippo.io/age/latest?for=linux/amd64
          tar xf 'latest?for=linux%2Famd64'
          sudo mv age/age age/age-keygen /usr/local/bin/

      - name: Configure SOPS
        run: |
          mkdir -p ~/.config/sops/age
          echo "${{ secrets.SOPS_AGE_KEY }}" > ~/.config/sops/age/keys.txt
          chmod 600 ~/.config/sops/age/keys.txt
          echo "SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt" >> $GITHUB_ENV

      - name: Decrypt secrets and run Terraform
        run: |
          cd terraform
          terraform init
          terraform plan
```

## Resources

- **SOPS Documentation**: https://github.com/getsops/sops
- **Age Documentation**: https://github.com/FiloSottile/age
- **SOPS Terraform Provider**: https://registry.terraform.io/providers/carlpett/sops/latest
- **Ansible SOPS Collection**: https://galaxy.ansible.com/community/sops
- **FluxCD SOPS Guide**: https://fluxcd.io/flux/guides/mozilla-sops/

## Support

If you have issues with SOPS or Age:

1. Check this README for common solutions
2. Verify your Age key is properly configured
3. Ensure `.sops.yaml` has correct path patterns
4. Check the official documentation links above

---

**Remember**: The security of your infrastructure depends on keeping private keys secure. Never commit them to version control, and always use encrypted channels for sharing keys with team members.
