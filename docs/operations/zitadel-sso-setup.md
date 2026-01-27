# Zitadel SSO Setup

Centralized Single Sign-On (SSO) for all homelab services using Zitadel.

## Overview

The SSO implementation is **fully automated**. On fresh deployment:

1. Zitadel boots and creates a machine user with `IAM_OWNER` role
2. A Kubernetes Job automatically creates all OIDC applications
3. The Job creates secrets in target namespaces
4. The Job restarts pods to apply OIDC configuration

**No manual configuration required.**

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │           Zitadel (IdP)             │
                    │      auth.home-infra.net            │
                    └──────────────┬──────────────────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
    ┌──────▼──────┐         ┌──────▼──────┐         ┌──────▼──────┐
    │ Native OIDC │         │ Native OIDC │         │Forward Auth │
    │  (Secret)   │         │  (Secret)   │         │(oauth2-proxy)│
    └──────┬──────┘         └──────┬──────┘         └──────┬──────┘
           │                       │                       │
    ┌──────▼──────┐         ┌──────▼──────┐         ┌──────▼──────┐
    │  Grafana    │         │   Immich    │         │  arr-stack  │
    │  Forgejo    │         │ Open WebUI  │         │  Longhorn   │
    └─────────────┘         │ Paperless   │         │  Hubble     │
                            └─────────────┘         │VictoriaMetrics│
                                                    └─────────────┘
```

## Services

### Native OIDC (Built-in SSO Support)

| Service | Namespace | URL | Auth Method |
|---------|-----------|-----|-------------|
| Grafana | monitoring | grafana.home-infra.net | Client Secret |
| Forgejo | forgejo | git.home-infra.net | Client Secret |
| Immich | media | photos.reynoza.org | Client Secret |
| Open WebUI | ai | chat.home-infra.net | Client Secret |
| Paperless | management | paperless.home-infra.net | Client Secret |

### Forward Auth (via oauth2-proxy)

| Service | Namespace | URL |
|---------|-----------|-----|
| Radarr | arr-stack | radarr.home-infra.net |
| Sonarr | arr-stack | sonarr.home-infra.net |
| Prowlarr | arr-stack | prowlarr.home-infra.net |
| Bazarr | arr-stack | bazarr.home-infra.net |
| SABnzbd | arr-stack | sabnzbd.home-infra.net |
| qBittorrent | arr-stack | qbittorrent.home-infra.net |
| Longhorn | longhorn-system | longhorn.home-infra.net |
| Hubble | kube-system | hubble.home-infra.net |
| VictoriaMetrics | monitoring | metrics.home-infra.net |

## How It Works

### Automatic OIDC Setup

The automation uses two components:

1. **Initial Job** (`zitadel-oidc-setup-initial`) - Runs once on deployment, waits up to 10 minutes for Zitadel
2. **CronJob** (`zitadel-oidc-sync`) - Runs every 15 minutes for self-healing

Both use the same setup script that:

1. **Authenticates via JWT** - Uses machine key generated on first boot
2. **Creates/verifies OIDC Applications** - Via Zitadel Management API
3. **Creates/updates Kubernetes Secrets** - Only when values change
4. **Restarts Pods** - Only when secrets are modified

### Self-Healing Features

- **Zitadel DB reset**: CronJob recreates apps and secrets automatically
- **Auth method mismatch**: CronJob detects and recreates apps with correct auth method
- **Redirect URI changes**: CronJob updates OIDC config for existing apps on every sync
- **Deleted secrets**: CronJob recreates them within 15 minutes
- **New app deployment**: CronJob creates secrets when namespace appears
- **Idempotent**: Safe to run multiple times, no unnecessary restarts

### Machine User Authentication

Zitadel creates a machine user on first boot via environment variables:

```yaml
ZITADEL_FIRSTINSTANCE_ORG_MACHINE_MACHINE_USERNAME: "terraform-admin"
ZITADEL_FIRSTINSTANCE_ORG_MACHINE_MACHINEKEY_TYPE: "1"  # JSON/RSA
ZITADEL_FIRSTINSTANCE_MACHINEKEYPATH: "/machinekey/zitadel-admin-sa.json"
```

The machine user automatically gets `IAM_OWNER` role, allowing it to create OIDC applications.

### Secrets Created

| Secret Name | Namespace | Contents |
|-------------|-----------|----------|
| grafana-oidc-secrets | monitoring | client-id, client-secret |
| forgejo-oidc-secrets | forgejo | client-id, client-secret |
| immich-oidc-secrets | media | client-id, client-secret |
| open-webui-oidc-secrets | ai | client-id, client-secret |
| paperless-oidc-secrets | management | client-id, client-secret |
| oauth2-proxy-oidc-secrets | auth | client-id, client-secret |

## Upgrading from Job to CronJob

If upgrading from the previous one-time Job approach:

### 1. Delete Old Job

```bash
# Check if old job exists
kubectl get job zitadel-oidc-setup -n auth

# Delete it (new CronJob will take over)
kubectl delete job zitadel-oidc-setup -n auth
```

### 2. Apply Updates

```bash
# Commit and push changes
git add -A && git commit -m "feat(auth): convert OIDC setup to self-healing CronJob"
git push

# Reconcile
flux reconcile kustomization apps --with-source
```

### 3. Verify New Resources

```bash
# Check CronJob and initial Job were created
kubectl get cronjob,job -n auth

# Expected output:
# NAME                                  SCHEDULE       SUSPEND   ACTIVE
# cronjob.batch/zitadel-oidc-sync      */15 * * * *   False     0
#
# NAME                                  COMPLETIONS   DURATION
# job.batch/zitadel-oidc-setup-initial 1/1           30s

# Watch initial job logs
kubectl logs -n auth job/zitadel-oidc-setup-initial -f
```

### 4. Verify Secrets

```bash
# All secrets should exist
kubectl get secrets -A | grep oidc-secrets

# Expected:
# auth         oauth2-proxy-oidc-secrets
# forgejo      forgejo-oidc-secrets
# management   paperless-oidc-secrets
# media        immich-oidc-secrets
# ai           open-webui-oidc-secrets
# monitoring   grafana-oidc-secrets
```

No data loss occurs - the CronJob script is idempotent and preserves existing OIDC apps and secrets.

---

## Fresh Deployment

On a fresh cluster deployment:

```bash
# 1. Deploy infrastructure (includes Zitadel)
flux reconcile kustomization infrastructure --with-source

# 2. Wait for Zitadel to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=zitadel -n auth --timeout=5m

# 3. Check OIDC setup job status
kubectl get cronjob,job -n auth
kubectl logs -n auth job/zitadel-oidc-setup-initial -f

# 4. Verify secrets were created
kubectl get secrets -A | grep oidc-secrets
```

The initial setup job automatically:
- Creates all OIDC applications in Zitadel
- Creates Kubernetes secrets in target namespaces
- Restarts all affected pods (including Forgejo StatefulSet)

The CronJob then maintains this state every 15 minutes.

## Verification

### Check Zitadel Health

```bash
curl -s https://auth.home-infra.net/.well-known/openid-configuration | jq .issuer
# Expected: "https://auth.home-infra.net"
```

### Check OIDC Setup

```bash
# Check initial setup job
kubectl logs -n auth job/zitadel-oidc-setup-initial

# Check CronJob status
kubectl get cronjob zitadel-oidc-sync -n auth

# Check latest CronJob run
kubectl logs -n auth -l app.kubernetes.io/name=zitadel-oidc-sync --tail=50
```

Expected output:
```
=== Zitadel OIDC Sync 2026-01-25T12:00:00+00:00 ===
Machine key file found.
Zitadel is ready.
Successfully authenticated.
Project ID: <uuid>
=== Syncing OIDC Applications ===
Processing: grafana
  App 'grafana' exists (ID: <uuid>)
  Secret 'grafana-oidc-secrets' in 'monitoring' is up-to-date
...
No secrets changed, skipping pod restarts.
=== OIDC Sync Complete ===
```

### Test SSO Login

1. Open https://grafana.home-infra.net
2. Click "Sign in with Zitadel"
3. Login with Zitadel credentials
4. Should redirect back to Grafana, logged in

### Test Forward Auth

```bash
# Without auth - should redirect to Zitadel
curl -I https://radarr.home-infra.net
# Expected: 302 redirect to auth.home-infra.net
```

## Troubleshooting

### OIDC Sync Not Working

```bash
# Check CronJob status
kubectl get cronjob zitadel-oidc-sync -n auth
kubectl get jobs -n auth -l app.kubernetes.io/name=zitadel-oidc-sync

# Check latest job logs
kubectl logs -n auth -l app.kubernetes.io/name=zitadel-oidc-sync --tail=100

# Check if machine key exists
kubectl exec -n auth deploy/zitadel -- ls -la /machinekey/

# Force manual sync
kubectl create job --from=cronjob/zitadel-oidc-sync zitadel-debug -n auth
kubectl logs -n auth job/zitadel-debug -f
```

### App Shows "Sign in with Zitadel" But Fails

1. Check secret exists:
   ```bash
   kubectl get secret grafana-oidc-secrets -n monitoring -o yaml
   ```

2. Check app logs for OIDC errors:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep -i oauth
   ```

3. Restart the app:
   ```bash
   kubectl rollout restart deployment grafana -n monitoring
   ```

### Zitadel Not Starting

```bash
# Check pod status
kubectl get pods -n auth -l app.kubernetes.io/name=zitadel

# Check logs
kubectl logs -n auth -l app.kubernetes.io/name=zitadel

# Common issues:
# - PostgreSQL not ready
# - Redis not ready
# - Masterkey secret missing
```

### Internal OIDC Token Validation Fails

Apps inside the cluster need to resolve `auth.home-infra.net` to the ClusterIP, not the external IP. CoreDNS rewrite handles this:

```bash
# Test from inside a pod
kubectl run -it --rm debug --image=alpine -- nslookup auth.home-infra.net
# Should resolve to 10.96.100.18 (ClusterIP)
```

## Re-running OIDC Setup

The CronJob automatically handles most recovery scenarios. For manual intervention:

### Force Immediate Sync

```bash
# Trigger CronJob manually
kubectl create job --from=cronjob/zitadel-oidc-sync zitadel-oidc-manual -n auth

# Watch progress
kubectl logs -n auth job/zitadel-oidc-manual -f
```

### After Zitadel DB Reset

The CronJob will automatically recreate apps and secrets within 15 minutes. To force immediate recovery:

```bash
# Delete existing secrets (CronJob will recreate them)
kubectl delete secret grafana-oidc-secrets -n monitoring
kubectl delete secret forgejo-oidc-secrets -n forgejo
kubectl delete secret immich-oidc-secrets -n media
kubectl delete secret open-webui-oidc-secrets -n ai
kubectl delete secret paperless-oidc-secrets -n management
kubectl delete secret oauth2-proxy-oidc-secrets -n auth

# Trigger immediate sync
kubectl create job --from=cronjob/zitadel-oidc-sync zitadel-oidc-recovery -n auth
```

### Re-run Initial Setup

```bash
# Delete and recreate initial job
kubectl delete job zitadel-oidc-setup-initial -n auth
flux reconcile kustomization apps --with-source
```

## Files Reference

| File | Purpose |
|------|---------|
| `kubernetes/apps/base/auth/zitadel/helmrelease.yaml` | Zitadel deployment with machine user config |
| `kubernetes/apps/base/auth/zitadel/machinekey-pvc.yaml` | PVC for machine key storage |
| `kubernetes/apps/base/auth/zitadel/oidc-setup-job.yaml` | CronJob + Initial Job for OIDC sync |
| `kubernetes/apps/base/auth/oauth2-proxy/helmrelease.yaml` | Forward auth proxy |
| `kubernetes/infrastructure/security/cilium-envoy-forward-auth.yaml` | Forward auth routing (CiliumEnvoyConfig) |

## Service-Specific Notes

### Forgejo

Forgejo requires specific OIDC configuration:

- **Auth Method**: Must use `Client Secret` (BASIC), not PKCE. Forgejo's OAuth2 client does not support PKCE.
- **Session**: `SAME_SITE = lax` is required in `[session]` config. The default `strict` blocks cookies on cross-site redirects from Zitadel, causing login failures ([Forgejo #1205](https://codeberg.org/forgejo/forgejo/issues/1205)).
- **Username**: `USERNAME = email` in `[oauth2_client]` config extracts the part before `@` from the email. Without this, Zitadel returns the full email as the nickname claim, which contains `@` and fails user creation.
- **Redirect URI**: Case-sensitive. Forgejo generates the callback URL using the provider name as-is (e.g., `Zitadel` with capital Z → `/user/oauth2/Zitadel/callback`). The OIDC setup job must match this exactly.
- **Helm Chart**: When using `existingSecret`, do NOT set the `key` field in the `oauth` values. The chart uses `key` literally as the `--key` CLI argument. Omitting it makes the chart use the `${GITEA_OAUTH_KEY_0}` env var populated from the secret.

## Design Decisions

### Why CronJob Instead of Terraform?

| Approach | Pros | Cons |
|----------|------|------|
| **CronJob (current)** | Fully automated, self-healing, no external dependencies | Secrets not in Git |
| **Terraform** | Declarative, state-managed | Requires PAT token (chicken-and-egg problem) |

Zitadel generates client IDs and secrets - they cannot be pre-defined. This means:
- OIDC credentials cannot be stored in SOPS before deployment
- Dynamic secret generation is required regardless of approach

The CronJob approach was chosen because:
1. **Fully automated** - No manual steps on fresh deployment
2. **Self-healing** - Recovers from Zitadel DB resets, deleted secrets
3. **Simple** - No external secret stores needed (Vault, etc.)
4. **Works with SOPS** - Static secrets (passwords) stay in SOPS, dynamic secrets (OIDC) are managed by CronJob

### Why Both Initial Job and CronJob?

- **Initial Job**: Waits up to 10 minutes for Zitadel on fresh deploy (longer timeout, more retries)
- **CronJob**: Quick checks every 15 minutes (short timeout, graceful failure)

This separation ensures:
- Fresh deployments work reliably (Initial Job waits patiently)
- Ongoing operations are lightweight (CronJob exits quickly if Zitadel unavailable)

### Secret Management Strategy

```
Static Secrets (in SOPS):          Dynamic Secrets (CronJob-managed):
├── zitadel-secrets                ├── grafana-oidc-secrets
│   └── masterkey                  ├── forgejo-oidc-secrets
│   └── admin password             ├── immich-oidc-secrets
├── zitadel-postgres-secrets       ├── open-webui-oidc-secrets
├── oauth2-proxy cookie secret     ├── paperless-oidc-secrets
└── app API keys                   └── oauth2-proxy-oidc-secrets
```

## References

- [Zitadel Documentation](https://zitadel.com/docs/)
- [Zitadel Self-Hosting Guide](https://zitadel.com/docs/self-hosting/deploy/kubernetes)
- [Zitadel Terraform Provider](https://registry.terraform.io/providers/zitadel/zitadel/latest/docs)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [GitHub Issue #9932](https://github.com/zitadel/zitadel/issues/9932) - Static client ID/secret feature request
