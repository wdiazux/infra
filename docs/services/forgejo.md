# Forgejo Git Server

Self-hosted Git platform with CI/CD capabilities.

---

## Overview

Forgejo is deployed **automatically** via Terraform Helm release when `enable_forgejo = true` (default).

**What's Automatic:**
- Forgejo deployment with PostgreSQL
- Admin user creation
- Repository creation for FluxCD
- LoadBalancer services (HTTP and SSH)

**Configuration:** `terraform/talos/addons.tf`

---

## Service URLs

| Service | URL | Port |
|---------|-----|------|
| Web UI | http://10.10.2.16 | 80 |
| HTTP Clone | http://10.10.2.13:3000 | 3000 |
| SSH Clone | ssh://git@10.10.2.14:22 | 22 |

---

## Credentials

Admin credentials are in `secrets/git-creds.enc.yaml`:

```bash
# View credentials
sops -d secrets/git-creds.enc.yaml
```

---

## Git Clone URLs

```bash
# HTTP
git clone http://10.10.2.16/wdiaz/infra.git

# SSH
git clone git@10.10.2.14:wdiaz/infra.git
```

---

## FluxCD Integration

Forgejo serves as the Git source for FluxCD GitOps:

1. **Repository:** `infra` created automatically
2. **Webhook:** FluxCD webhook at http://10.10.2.15
3. **Token:** Generated for FluxCD authentication

### Verify FluxCD Connection

```bash
# Check GitRepository
flux get sources git -A

# Check reconciliation
flux get kustomizations -A

# Force sync
flux reconcile source git flux-system
```

---

## Adding SSH Key

1. Login to Forgejo UI
2. Go to Settings → SSH/GPG Keys
3. Add your public key

```bash
# Generate key if needed
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub
```

---

## Creating Repositories

### Via Web UI

1. Click "+" → "New Repository"
2. Configure name, visibility
3. Create

### Via API

```bash
# Get token from Forgejo UI: Settings → Applications → Generate Token
TOKEN="your-token"

curl -X POST "http://10.10.2.16/api/v1/user/repos" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-repo", "private": false}'
```

---

## Forgejo Actions (CI/CD)

### Enable Actions

Actions are enabled by default. Create `.forgejo/workflows/` in your repository.

### Example Workflow

```yaml
# .forgejo/workflows/build.yaml
name: Build
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: echo "Building..."
      - name: Test
        run: echo "Testing..."
```

### Runner Status

Check if runner is available:
```bash
# In Forgejo UI
# Site Administration → Actions → Runners
```

---

## Backup

Forgejo data is stored on Longhorn volumes and backed up via NFS.

### Manual Backup

```bash
# Export repository via API
curl -X GET "http://10.10.2.16/api/v1/repos/wdiaz/infra/archive/main.zip" \
  -H "Authorization: token $TOKEN" \
  -o infra-backup.zip
```

### Database Backup

PostgreSQL is backed up with Longhorn volume snapshots.

---

## Verification

```bash
# Check pods
kubectl get pods -n forgejo

# Check services
kubectl get svc -n forgejo

# Check PVCs
kubectl get pvc -n forgejo

# View logs
kubectl logs -n forgejo -l app.kubernetes.io/name=forgejo
```

---

## Troubleshooting

### Can't Access UI

```bash
# Check Forgejo pod
kubectl get pods -n forgejo -l app.kubernetes.io/name=forgejo

# Check service
kubectl get svc -n forgejo

# View logs
kubectl logs -n forgejo deployment/forgejo-forgejo -f
```

### SSH Connection Refused

```bash
# Verify SSH service
kubectl get svc forgejo-ssh -n forgejo

# Test SSH connection
ssh -v -p 22 git@10.10.2.14

# Check SSH keys in Forgejo UI
```

### FluxCD Can't Sync

```bash
# Check GitRepository status
kubectl get gitrepository -n flux-system -o yaml

# Check Forgejo token secret
kubectl get secret forgejo-flux-token -n flux-system

# Verify repository exists
curl http://10.10.2.16/api/v1/repos/wdiaz/infra
```

### PostgreSQL Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n forgejo -l app.kubernetes.io/name=postgresql

# View PostgreSQL logs
kubectl logs -n forgejo -l app.kubernetes.io/name=postgresql

# Check database connection
kubectl exec -it -n forgejo deploy/forgejo-forgejo -- \
  env | grep DATABASE
```

---

## Resources

- [Forgejo Documentation](https://forgejo.org/docs/)
- [Forgejo Actions](https://forgejo.org/docs/latest/user/actions/)
- [Forgejo API](https://forgejo.org/docs/latest/admin/command-line/)

---

**Last Updated:** 2026-01-15
