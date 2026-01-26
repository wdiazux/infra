# Zitadel OIDC/SSO Review Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Review and validate the current Zitadel SSO implementation. Remove or mark the optional `zitadel.tf` appropriately. Ensure forward auth configuration is correct.

**Architecture:** The infrastructure uses a dual-approach design: Kubernetes CronJob (active, self-healing) and Terraform (optional, disabled by default). Both are mutually exclusive via `enable_zitadel_oidc` variable.

**Tech Stack:** Zitadel, oauth2-proxy, Cilium Envoy, Terraform, Kubernetes

---

## Review Findings

### zitadel.tf Status

**Decision: KEEP but clarify documentation**

The file is NOT dead code. It is a documented, intentionally disabled alternative approach:
- `enable_zitadel_oidc` defaults to `false` in `variables-services.tf:186-189`
- The file header (lines 3-15) contains clear warnings about mutual exclusivity
- The documentation in `docs/operations/zitadel-sso-setup.md:354-363` explains when and how to use it
- The Terraform approach is useful for users who prefer declarative state management over CronJobs

**No conflict exists** because:
- The CronJob approach is active when `enable_zitadel_oidc = false` (default)
- The Terraform approach is active when `enable_zitadel_oidc = true`
- Both create the same OIDC applications and secrets
- The file warns: "Do not enable both - they will conflict!"

### OIDC Setup Job Status

**Status: COMPLETE AND CORRECT**

The CronJob implementation (`oidc-setup-job.yaml`) is comprehensive:
- ConfigMap with 285-line setup script
- JWT authentication with machine key
- Self-healing every 15 minutes
- Idempotent (safe for repeated runs)
- Smart pod restarts (only when secrets change)
- All 6 applications managed: Grafana, Forgejo, Immich, Open WebUI, Paperless, oauth2-proxy
- Proper RBAC: ServiceAccount + ClusterRole + ClusterRoleBinding
- PVC for machine key persistence

### Forward Auth Status

**Status: CORRECTLY CONFIGURED BUT DISABLED**

- `cilium-envoy-forward-auth.yaml` (91 lines) is present but commented out in `infrastructure/security/kustomization.yaml`
- oauth2-proxy is deployed and configured correctly
- The forward auth flow is: Cilium Envoy ext_authz -> oauth2-proxy -> Zitadel OIDC

### Issues Found

1. **Minor**: The `zitadel.tf` file should reference the correct documentation path
2. **Minor**: Forward auth disabled status should be documented in the SSO setup docs

---

### Task 1: Verify zitadel.tf Documentation References

**Files:**
- Read: `terraform/talos/zitadel.tf`
- Read: `docs/operations/zitadel-sso-setup.md`

**Step 1: Verify the zitadel.tf header accurately describes the alternative approach**

Read `zitadel.tf` and verify:
- [ ] Warning about mutual exclusivity is clear
- [ ] Instructions for enabling are accurate
- [ ] Secret file reference is correct (`secrets/zitadel-terraform.enc.yaml`)
- [ ] All 6 OIDC applications match the K8s Job approach

**Step 2: Verify SSO setup documentation**

Read `docs/operations/zitadel-sso-setup.md` and verify:
- [ ] Architecture diagram is accurate
- [ ] All 6 applications are listed
- [ ] CronJob schedule is documented (every 15 minutes)
- [ ] Machine user authentication flow is documented
- [ ] Upgrade path from old one-time Job is documented
- [ ] Terraform alternative is documented
- [ ] Forward auth status (disabled) is mentioned

**Step 3: No code changes expected unless documentation is inaccurate**

---

### Task 2: Verify Forward Auth Configuration

**Files:**
- Read: `kubernetes/infrastructure/security/cilium-envoy-forward-auth.yaml`
- Read: `kubernetes/infrastructure/security/kustomization.yaml`
- Read: `kubernetes/apps/base/auth/oauth2-proxy/helmrelease.yaml`

**Step 1: Verify CiliumEnvoyConfig**

Check that the forward auth configuration:
- [ ] Lists all protected services (arr-stack, infrastructure UIs)
- [ ] Points to oauth2-proxy on correct port (4180)
- [ ] Has correct auth path (`/oauth2/auth`)
- [ ] Passes correct headers (cookie, authorization, x-auth-request-*)
- [ ] Has failure_mode_allow set to false (deny on auth failure)

**Step 2: Verify oauth2-proxy configuration**

Check that:
- [ ] OIDC issuer URL matches Zitadel endpoint (`https://auth.home-infra.net`)
- [ ] Client credentials reference the auto-generated secret (`oauth2-proxy-oidc-secrets`)
- [ ] Cookie settings are correct (secure, lax, .home-infra.net domain)
- [ ] Upstream is `static://200` for ext_authz mode

**Step 3: Document forward auth status in SSO docs**

If not already documented, add a note to `docs/operations/zitadel-sso-setup.md` explaining that forward auth via Cilium Envoy ext_authz is configured but disabled by default, with instructions for enabling.

**Step 4: Commit if any documentation changes**

```bash
git add docs/operations/zitadel-sso-setup.md
git commit -m "docs: clarify forward auth status in Zitadel SSO documentation"
```

---

### Task 3: Verify All OIDC Applications Match Between Approaches

**Files:**
- Read: `terraform/talos/zitadel.tf` (Terraform approach)
- Read: `kubernetes/apps/base/auth/zitadel/oidc-setup-job.yaml` (K8s Job approach)

**Step 1: Compare application lists**

Both approaches must create identical OIDC applications:

| Application | Auth Method | Namespace | Secret Name |
|-------------|------------|-----------|-------------|
| Grafana | PKCE | monitoring | grafana-oidc-secrets |
| Forgejo | PKCE | forgejo | forgejo-oidc-secrets |
| Immich | Client Secret | media | immich-oidc-secrets |
| Open WebUI | Client Secret | ai | open-webui-oidc-secrets |
| Paperless | Client Secret | management | paperless-oidc-secrets |
| oauth2-proxy | Client Secret | auth | oauth2-proxy-oidc-secrets |

**Step 2: Verify redirect URIs match**

Check that both approaches use the same redirect URIs for each application.

**Step 3: Report any discrepancies**

If any applications or configurations differ between the two approaches, fix the discrepancy so they remain interchangeable.

---

## Validation Checklist

- [ ] `zitadel.tf` is correctly documented as optional alternative
- [ ] No conflict between K8s Job and Terraform approaches (mutual exclusivity confirmed)
- [ ] All 6 OIDC applications are identical in both approaches
- [ ] Forward auth configuration is correct
- [ ] Documentation accurately reflects current implementation
- [ ] Forward auth disabled status is documented
