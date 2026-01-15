# SOPS Management Skill

Manages encrypted secrets using SOPS + Age for this infrastructure project.

## Purpose

This skill ensures secrets are:
- Properly encrypted with SOPS + Age
- Never committed in plaintext
- Correctly configured in .sops.yaml
- Accessible to Packer and Terraform
- Following security best practices

## When to Use

Invoke this skill when:
- Adding new secrets to the repository
- Updating existing secrets
- Rotating encryption keys
- Debugging secret access issues
- Reviewing security configuration
- Before committing changes with secrets

## What This Skill Does

1. **Secret Encryption**
   - Verify .sops.yaml configuration
   - Check Age key file location (~/.config/sops/age/keys.txt)
   - Encrypt plaintext files with `sops -e`
   - Validate encrypted files can be decrypted
   - Check file extensions (.enc.yaml)

2. **Secret Access**
   - Show how to decrypt for viewing: `sops -d file.enc.yaml`
   - Show how to edit in place: `sops file.enc.yaml`
   - Show how to extract specific values: `sops -d --extract '["key"]' file.enc.yaml`
   - Verify environment variable setup for automation

3. **Integration Validation**
   - Check Packer can access secrets via env vars
   - Verify Terraform SOPS provider configuration
   - Ensure FluxCD can decrypt secrets in Kubernetes
   - Validate .envrc has SOPS_AGE_KEY_FILE set

4. **Security Checks**
   - Scan for plaintext secrets in files
   - Check .gitignore excludes plaintext secrets
   - Verify no secrets in git history
   - Ensure Age keys are not committed
   - Check file permissions on key files (600)

5. **Secret Organization**
   - Verify secrets/ directory structure
   - Check naming conventions (*-creds.enc.yaml)
   - Ensure TEMPLATE files don't have real values
   - Validate each secret has required fields

6. **Documentation**
   - Verify docs/operations/secrets.md is up to date
   - Check rotation procedures documented
   - Ensure backup procedures documented

## Current Project Secrets

Location: `/home/wdiaz/devland/infra/secrets/`

Files:
- `proxmox-creds.enc.yaml` - Proxmox API credentials and SSH keys
- `git-creds.enc.yaml` - Forgejo admin and FluxCD credentials
- `nas-backup-creds.enc.yaml` - NFS backup authentication
- `pangolin-creds.enc.yaml` - WireGuard tunnel credentials

Documentation: `docs/operations/secrets.md`

Keys Required:
- `proxmox_url`
- `proxmox_user`
- `proxmox_token_id`
- `proxmox_token_secret`
- `proxmox_node`
- `proxmox_storage_pool`
- `proxmox_iso_storage`
- `proxmox_tls_insecure`
- `ssh_public_key`

## Example Usage

```
User: "Can you help me add a new secret?"
Assistant: I'll use the sops-management skill to help you add a secret securely.

[Skill guides through adding, encrypting, and validating the secret]
```

```
User: "How do I rotate my Age encryption key?"
Assistant: I'll use the sops-management skill to guide you through key rotation.

[Skill provides step-by-step rotation process]
```

## Security Best Practices

- **Never commit plaintext secrets**
- **Age keys stored in ~/.config/sops/age/** (not in repo)
- **Encrypted files use .enc.yaml extension**
- **Templates use TEMPLATE- prefix**
- **Regular key rotation (annually)**
- **Backup Age keys securely** (encrypted password manager)
- **Use different keys for different environments** (if applicable)

## Common Commands

```bash
# Encrypt a new secret
sops -e secrets/new-secret.yaml > secrets/new-secret.enc.yaml

# Edit encrypted secret
sops secrets/proxmox-creds.enc.yaml

# View decrypted secret
sops -d secrets/proxmox-creds.enc.yaml

# Extract specific value
sops -d --extract '["ssh_public_key"]' secrets/proxmox-creds.enc.yaml

# Use in Packer
export SSH_PUBLIC_KEY=$(sops -d --extract '["ssh_public_key"]' secrets/proxmox-creds.enc.yaml)
packer build .

# Use in Terraform (via sops provider or env vars)
export TF_VAR_proxmox_token=$(sops -d --extract '["proxmox_token_secret"]' secrets/proxmox-creds.enc.yaml)
terraform apply
```

## Integration Points

- **Packer**: Environment variables exported before build
- **Terraform**: SOPS provider or TF_VAR_ environment variables
- **Ansible**: ansible-vault or SOPS vars files
- **FluxCD**: sops-secrets in Kubernetes
- **direnv**: .envrc loads secrets automatically

## Troubleshooting

Common issues:
1. **"failed to get data key"** - Age key not found or wrong path
2. **"MAC mismatch"** - File corrupted or wrong Age key
3. **"creation rule not found"** - .sops.yaml misconfigured
4. **Plaintext leaked** - Check git history, rotate immediately
