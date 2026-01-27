# Fix Zitadel OIDC Setup CronJob

**Status**: Completed (2026-01-27)

## Background

The OIDC setup CronJob had several issues since deployment:
1. Network policies blocked API access (fixed 2026-01-24)
2. JWT audience didn't match Zitadel's issuer (fixed 2026-01-24)
3. JWT bearer auth returns "Errors.Internal" (replaced with PAT 2026-01-24)
4. Sync job recreated ALL apps every 15 minutes due to Zitadel API not returning `authMethodType` (fixed 2026-01-27)

## Completed Tasks

### Task 1: CronJob works with PAT auth
- PAT authentication verified working from cluster
- CronJob runs every 15 minutes successfully

### Task 2: Initial Job removed
- Removed redundant initial Job (CronJob handles initial setup)
- Fixes "field is immutable" FluxCD error on updates

### Task 3: OIDC secrets verified
- All 6 OIDC secrets created and managed:
  - `grafana-oidc-secrets` (monitoring)
  - `forgejo-oidc-secrets` (forgejo)
  - `immich-oidc-secrets` (media)
  - `open-webui-oidc-secrets` (ai)
  - `paperless-oidc-secrets` (management)
  - `oauth2-proxy-oidc-secrets` (auth)

### Task 4: Sync job fix (2026-01-27)
- **Problem**: Zitadel API does not return `authMethodType` in responses (protobuf3 default value omission). The compare-and-recreate logic always detected a "mismatch" and deleted/recreated all apps every 15 minutes.
- **Fix**: Replaced compare-and-recreate with always-update-via-PUT. The sync job now uses `PUT /management/v1/projects/{id}/apps/{id}/oidc_config` to push the desired config idempotently, without credential rotation.

### Task 5: Auth method corrections (2026-01-27)
- All apps changed from PKCE to Client Secret (BASIC) auth method
- Immich uses `OIDC_APP_AUTH_METHOD_TYPE_POST` (`client_secret_post`) as required by its OAuth library
- All other apps use `OIDC_APP_AUTH_METHOD_TYPE_BASIC` (`client_secret_basic`)

### Task 6: Service-specific OIDC fixes (2026-01-27)
- **Paperless**: Fixed CSRF 403 (`PAPERLESS_URL` http→https), env var ordering for `$(VAR)` substitution, enabled social auto signup and email authentication for account linking, added `PAPERLESS_ADMIN_MAIL` to secrets
- **Immich**: Fixed auth method mismatch (BASIC→POST), changed `storageLabelClaim` from `preferred_username` to `email`
- **Forgejo**: Fixed redirect URI case mismatch, added `SAME_SITE=lax` for cross-site OAuth2, added `USERNAME=email`

## Key Files

| File | Purpose |
|------|---------|
| `kubernetes/apps/base/auth/zitadel/oidc-setup-job.yaml` | CronJob, ConfigMap, RBAC |
| `kubernetes/apps/base/management/paperless/server-deployment.yaml` | Paperless OIDC config |
| `kubernetes/apps/base/media/immich/server-deployment.yaml` | Immich OIDC config |
| `docs/operations/zitadel-sso-setup.md` | SSO setup documentation |

## Key Commands

```bash
# Force CronJob run
kubectl create job --from=cronjob/zitadel-oidc-sync test-oidc-sync -n auth

# Check CronJob logs
kubectl logs -n auth job/test-oidc-sync

# Check OIDC secrets
kubectl get secrets -A -l app.kubernetes.io/managed-by=zitadel-oidc-setup

# Test PAT manually
PAT=$(kubectl get secret iam-admin-pat -n auth -o jsonpath='{.data.pat}' | base64 -d)
curl -sk -H "Authorization: Bearer $PAT" "https://auth.home-infra.net/management/v1/orgs/me"

# Reconcile
flux reconcile kustomization apps --with-source
```
