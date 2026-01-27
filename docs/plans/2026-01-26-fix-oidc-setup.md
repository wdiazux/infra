# Fix Zitadel OIDC Setup CronJob

## Background

The OIDC setup CronJob was never actually working since deployment. It was silently failing because:
1. Network policies blocked API access (fixed this session)
2. JWT audience didn't match Zitadel's issuer (fixed this session)
3. JWT bearer auth returns "Errors.Internal" (replaced with PAT this session)

The PAT approach was verified working manually but the initial Job still fails. The CronJob hasn't run with the new code yet.

## Current State

- **HelmRelease**: Fixed and healthy (v22, chart 9.17.0)
- **NetworkPolicies**: Added for `zitadel-oidc-setup` and `zitadel-oidc-sync` pods
- **CiliumNetworkPolicy**: Added for K8s API access
- **ConfigMap**: Updated with PAT auth, Host header, no openssl dependency
- **Initial Job**: Failing (BackoffLimitExceeded) - needs investigation
- **CronJob**: Next run should use updated ConfigMap (PAT approach)

## Verified Working

PAT authentication works from the cluster:
```bash
PAT=$(kubectl get secret iam-admin-pat -n auth -o jsonpath='{.data.pat}' | base64 -d)
curl -sk -H "Authorization: Bearer $PAT" "https://auth.home-infra.net/management/v1/orgs/me"
# Returns: {"org":{"name":"ZITADEL","state":"ORG_STATE_ACTIVE",...}}
```

## Plan

### Task 1: Verify CronJob works with PAT auth

1. Force a CronJob run: `kubectl create job --from=cronjob/zitadel-oidc-sync test-oidc-sync -n auth`
2. Check logs: `kubectl logs -n auth job/test-oidc-sync`
3. Expected: "PAT secret found", "Zitadel is ready", "Successfully authenticated", OIDC apps synced
4. If it fails, check:
   - Is apk install working? Look for errors in logs
   - Is the Host header being sent? Check for "Instance not found"
   - Is the PAT valid? Check for auth errors

### Task 2: Fix or remove the initial Job

The initial Job (`zitadel-oidc-setup-initial`) keeps failing. Options:

**Option A (Recommended): Remove the initial Job entirely**
- The CronJob runs every 15 minutes and handles initial setup
- The initial Job is redundant since the CronJob does the same thing
- Remove the `Job` resource from `oidc-setup-job.yaml`
- This also fixes the "field is immutable" FluxCD error on updates

**Option B: Fix the initial Job**
- The inline script may be failing at `apk add` or `kubectl`
- Change `restartPolicy: OnFailure` to `restartPolicy: Never` to see actual errors
- Add error logging to the inline script

### Task 3: Verify OIDC secrets are created/updated

After a successful CronJob run:
```bash
# Check OIDC secrets exist
kubectl get secrets -A -l app.kubernetes.io/managed-by=zitadel-oidc-setup
# Expected: grafana-oidc-secrets, forgejo-oidc-secrets, immich-oidc-secrets,
# open-webui-oidc-secrets, paperless-oidc-secrets, oauth2-proxy-oidc-secrets
```

### Task 4: Clean up debug commits

Squash the multiple fix commits into clean ones:
```bash
git rebase -i HEAD~6  # Squash debug commits into meaningful ones
git push forgejo main --force-with-lease
```

### Task 5: Verify apps kustomization is Ready

```bash
flux reconcile kustomization apps --with-source
kubectl get kustomization -n flux-system apps
# Expected: Ready: True
```

## Key Files

| File | Purpose |
|------|---------|
| `kubernetes/apps/base/auth/zitadel/helmrelease.yaml` | Zitadel Helm config |
| `kubernetes/apps/base/auth/zitadel/oidc-setup-job.yaml` | CronJob, ConfigMap, RBAC |
| `kubernetes/infrastructure/security/network-policies.yaml` | NetworkPolicies |
| `kubernetes/infrastructure/security/cilium-network-policies.yaml` | CiliumNetworkPolicies |

## Key Commands

```bash
# Force CronJob run
kubectl create job --from=cronjob/zitadel-oidc-sync test-oidc-sync -n auth

# Check CronJob logs
kubectl logs -n auth job/test-oidc-sync

# Delete stuck initial job
kubectl delete job zitadel-oidc-setup-initial -n auth

# Test PAT manually
PAT=$(kubectl get secret iam-admin-pat -n auth -o jsonpath='{.data.pat}' | base64 -d)
curl -sk -H "Authorization: Bearer $PAT" "https://auth.home-infra.net/management/v1/orgs/me"

# Check network policies
kubectl get networkpolicy -n auth
kubectl get ciliumnetworkpolicy -n auth

# Reset HelmRelease
flux suspend helmrelease zitadel -n auth && flux resume helmrelease zitadel -n auth

# Reconcile
flux reconcile kustomization apps --with-source
```
