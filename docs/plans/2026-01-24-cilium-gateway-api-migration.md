# Cilium Gateway API Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate from Cilium Ingress Controller + nginx-ingress to Cilium Gateway API while keeping the current Ingress setup as a fallback.

**Architecture:** Deploy Gateway API resources alongside existing Ingress resources. Use a separate LoadBalancer IP for the new Gateway (10.10.2.19) to allow parallel testing. The original Ingress controller on 10.10.2.20 remains fully operational. Once validated, DNS can be switched to point to the Gateway IP.

**Tech Stack:** Cilium Gateway API (already enabled), HTTPRoute, GRPCRoute, ReferenceGrant, cert-manager (existing)

---

## Prerequisites

- Cilium 1.18.6 with Gateway API enabled (✅ already configured)
- Gateway API CRDs installed (✅ included in Cilium)
- cert-manager with wildcard certificates (✅ already configured)
- Reflector distributing TLS secrets to namespaces (✅ already configured)

## Architecture Decisions

### Why Migrate to Gateway API?

1. **HTTP/2 Support**: Cilium Gateway API supports `appProtocol: kubernetes.io/h2c` for gRPC backends (eliminates need for nginx-ingress for Zitadel)
2. **Standard API**: Gateway API is the Kubernetes standard, replacing Ingress
3. **More Expressive**: Better routing capabilities (header matching, traffic splitting)
4. **Simplified Stack**: Remove nginx-ingress dependency

### Parallel Deployment Strategy

**Phase 1: Testing (Tasks 1-8)**
| Component | IP | Status |
|-----------|-----|--------|
| Cilium Ingress | 10.10.2.20 | Active (fallback) |
| nginx-ingress (Zitadel) | 10.10.2.18 | Active (fallback) |
| Cilium Gateway | 10.10.2.19 | Testing |

**Phase 2: Production (Tasks 9-10)**
| Component | IP | Status |
|-----------|-----|--------|
| Cilium Ingress | 10.10.2.20 | Replaced by Gateway |
| nginx-ingress (Zitadel) | 10.10.2.18 | Active (pending cleanup) |
| Cilium Gateway | 10.10.2.20 | Production |

**Phase 3: Cleanup (Task 11)**
| Component | IP | Status |
|-----------|-----|--------|
| Cilium Gateway | 10.10.2.20 | Production (sole ingress) |
| All Ingress resources | - | Removed |
| nginx-ingress | - | Removed |

### Cross-Namespace Routing

Gateway API uses `ReferenceGrant` for cross-namespace access. We'll:
1. Deploy a single shared Gateway in `kube-system` namespace
2. Create `ReferenceGrant` in each app namespace allowing the Gateway to reference their Services
3. Create `HTTPRoute`/`GRPCRoute` in each app namespace (co-located with services)

---

## Task 1: Create Gateway Infrastructure

**Files:**
- Create: `kubernetes/infrastructure/gateway/gateway.yaml`
- Create: `kubernetes/infrastructure/gateway/kustomization.yaml`
- Modify: `kubernetes/infrastructure/controllers/kustomization.yaml`

**Step 1: Create the Gateway infrastructure directory and Gateway resource**

```yaml
# kubernetes/infrastructure/gateway/gateway.yaml
---
# Cilium Gateway API Gateway
#
# Central gateway for all HTTPS traffic. Uses shared LoadBalancer IP.
# Each app namespace creates HTTPRoutes that reference this Gateway.
#
# IP: 10.10.2.19 (new, parallel to existing ingress on 10.10.2.20)
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-gateway
  namespace: kube-system
  annotations:
    # Static IP for the Gateway LoadBalancer
    io.cilium/lb-ipam-ips: "10.10.2.19"
spec:
  gatewayClassName: cilium
  infrastructure:
    annotations:
      io.cilium/lb-ipam-ips: "10.10.2.19"
  listeners:
    # HTTP listener (redirects to HTTPS in production, but useful for testing)
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    # HTTPS listener for *.home-infra.net
    - name: https-home-infra
      protocol: HTTPS
      port: 443
      hostname: "*.home-infra.net"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-home-infra-net-tls
            namespace: cert-manager
      allowedRoutes:
        namespaces:
          from: All
    # HTTPS listener for home-infra.net (apex)
    - name: https-home-infra-apex
      protocol: HTTPS
      port: 443
      hostname: "home-infra.net"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-home-infra-net-tls
            namespace: cert-manager
      allowedRoutes:
        namespaces:
          from: All
    # HTTPS listener for *.reynoza.org (Immich)
    - name: https-reynoza
      protocol: HTTPS
      port: 443
      hostname: "*.reynoza.org"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-reynoza-org-tls
            namespace: cert-manager
      allowedRoutes:
        namespaces:
          from: All
---
# ReferenceGrant: Allow Gateway to reference TLS secrets in cert-manager namespace
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: gateway-cert-manager-secrets
  namespace: cert-manager
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: Gateway
      namespace: kube-system
  to:
    - group: ""
      kind: Secret
```

**Step 2: Create the kustomization file**

```yaml
# kubernetes/infrastructure/gateway/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kube-system
resources:
  - gateway.yaml
```

**Step 3: Run kustomize build to verify syntax**

Run: `kustomize build kubernetes/infrastructure/gateway/`
Expected: Valid YAML output with Gateway and ReferenceGrant

**Step 4: Add gateway to infrastructure controllers kustomization**

Modify `kubernetes/infrastructure/controllers/kustomization.yaml` to add:
```yaml
  - ../gateway
```

**Step 5: Commit**

```bash
git add kubernetes/infrastructure/gateway/
git add kubernetes/infrastructure/controllers/kustomization.yaml
git commit -m "feat(gateway): add Cilium Gateway API infrastructure

- Create shared Gateway in kube-system namespace
- Configure HTTPS listeners for home-infra.net and reynoza.org
- Add ReferenceGrant for cert-manager TLS secrets
- Use dedicated IP 10.10.2.19 (parallel to ingress on 10.10.2.20)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Create ReferenceGrant Template for App Namespaces

**Files:**
- Create: `kubernetes/apps/base/_templates/gateway-reference-grant.yaml` (reference)

**Step 1: Document the ReferenceGrant pattern**

Each namespace needs a ReferenceGrant to allow HTTPRoutes to reference their Services. Document the pattern:

```yaml
# Template: Add to each namespace that uses Gateway API routing
# File: kubernetes/apps/base/<category>/<app>/gateway-reference-grant.yaml
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: gateway-to-services
  namespace: <APP_NAMESPACE>
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: <APP_NAMESPACE>
  to:
    - group: ""
      kind: Service
```

Note: Since HTTPRoutes are co-located with Services (same namespace), ReferenceGrant for Service access is typically not needed. ReferenceGrant is only required for cross-namespace references.

**Step 2: Commit documentation**

```bash
git commit --allow-empty -m "docs(gateway): document ReferenceGrant pattern for app namespaces

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Migrate First App - Homepage (Pilot)

**Files:**
- Create: `kubernetes/apps/base/tools/homepage/httproute.yaml`
- Modify: `kubernetes/apps/base/tools/homepage/kustomization.yaml`

**Step 1: Create HTTPRoute for Homepage**

```yaml
# kubernetes/apps/base/tools/homepage/httproute.yaml
---
# Homepage HTTPRoute (Gateway API)
#
# Routes traffic from cilium-gateway to homepage service.
# Parallel deployment: existing Ingress on 10.10.2.20, Gateway on 10.10.2.19
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: homepage
  namespace: tools
  labels:
    app.kubernetes.io/name: homepage
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
  hostnames:
    - home.home-infra.net
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: homepage
          port: 80
```

**Step 2: Add HTTPRoute to kustomization**

Add to `kubernetes/apps/base/tools/homepage/kustomization.yaml`:
```yaml
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml      # Keep existing
  - httproute.yaml    # Add new
```

**Step 3: Test locally with kustomize**

Run: `kustomize build kubernetes/apps/base/tools/homepage/`
Expected: Output includes both Ingress and HTTPRoute resources

**Step 4: Commit**

```bash
git add kubernetes/apps/base/tools/homepage/httproute.yaml
git add kubernetes/apps/base/tools/homepage/kustomization.yaml
git commit -m "feat(homepage): add Gateway API HTTPRoute (parallel to Ingress)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Test Gateway API with Homepage

**Step 1: Push changes and let FluxCD reconcile**

```bash
git push
```

**Step 2: Wait for reconciliation**

Run: `flux reconcile kustomization flux-system --with-source`

**Step 3: Verify Gateway is created**

Run: `kubectl get gateway -A`
Expected: `cilium-gateway` in `kube-system` with PROGRAMMED status

**Step 4: Verify HTTPRoute is accepted**

Run: `kubectl get httproute -A`
Expected: `homepage` in `tools` namespace with ACCEPTED status

**Step 5: Test connectivity via Gateway IP**

Run: `curl -k -H "Host: home.home-infra.net" https://10.10.2.19/`
Expected: Homepage HTML response

**Step 6: Document test results**

If successful, proceed to next task. If failed, debug with:
```bash
kubectl describe gateway cilium-gateway -n kube-system
kubectl describe httproute homepage -n tools
cilium status
```

---

## Task 5: Migrate Monitoring Apps (Grafana, VictoriaMetrics)

**Files:**
- Create: `kubernetes/apps/base/monitoring/grafana/httproute.yaml`
- Modify: `kubernetes/apps/base/monitoring/grafana/kustomization.yaml`
- Create: `kubernetes/apps/base/monitoring/victoriametrics/httproute.yaml`
- Modify: `kubernetes/apps/base/monitoring/victoriametrics/kustomization.yaml`

**Step 1: Create Grafana HTTPRoute**

```yaml
# kubernetes/apps/base/monitoring/grafana/httproute.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app.kubernetes.io/name: grafana
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
  hostnames:
    - grafana.home-infra.net
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: grafana
          port: 80
```

**Step 2: Create VictoriaMetrics HTTPRoute**

```yaml
# kubernetes/apps/base/monitoring/victoriametrics/httproute.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: victoriametrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: victoriametrics
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
  hostnames:
    - victoriametrics.home-infra.net
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: victoriametrics
          port: 80
```

**Step 3: Update kustomization files**

Add `httproute.yaml` to each app's kustomization.yaml resources list.

**Step 4: Test locally**

Run: `kustomize build kubernetes/apps/base/monitoring/grafana/`
Run: `kustomize build kubernetes/apps/base/monitoring/victoriametrics/`

**Step 5: Commit**

```bash
git add kubernetes/apps/base/monitoring/grafana/httproute.yaml
git add kubernetes/apps/base/monitoring/grafana/kustomization.yaml
git add kubernetes/apps/base/monitoring/victoriametrics/httproute.yaml
git add kubernetes/apps/base/monitoring/victoriametrics/kustomization.yaml
git commit -m "feat(monitoring): add Gateway API HTTPRoutes for Grafana and VictoriaMetrics

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Migrate Zitadel with GRPCRoute (Key Migration)

**Files:**
- Create: `kubernetes/apps/base/auth/zitadel/httproute.yaml`
- Create: `kubernetes/apps/base/auth/zitadel/grpcroute.yaml`
- Modify: `kubernetes/apps/base/auth/zitadel/service.yaml` (add appProtocol)
- Modify: `kubernetes/apps/base/auth/zitadel/kustomization.yaml`

**Step 1: Update Zitadel service to declare HTTP/2 protocol**

Modify `kubernetes/apps/base/auth/zitadel/service.yaml` to add appProtocol:
```yaml
spec:
  ports:
    - name: grpc
      port: 8080
      targetPort: 8080
      appProtocol: kubernetes.io/h2c  # Enable HTTP/2 for gRPC
```

**Step 2: Create GRPCRoute for Zitadel API**

```yaml
# kubernetes/apps/base/auth/zitadel/grpcroute.yaml
---
# Zitadel GRPCRoute
#
# Routes gRPC traffic to Zitadel. Uses Gateway API native gRPC support
# instead of nginx-ingress with backend-protocol annotation.
---
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: zitadel-grpc
  namespace: auth
  labels:
    app.kubernetes.io/name: zitadel
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
  hostnames:
    - auth.home-infra.net
  rules:
    - backendRefs:
        - name: zitadel
          port: 8080
```

**Step 3: Create HTTPRoute for Zitadel Login UI**

```yaml
# kubernetes/apps/base/auth/zitadel/httproute.yaml
---
# Zitadel Login UI HTTPRoute
#
# Routes hosted login v2 UI traffic to zitadel-login service.
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: zitadel-login
  namespace: auth
  labels:
    app.kubernetes.io/name: zitadel-login
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
  hostnames:
    - auth.home-infra.net
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /ui/v2/login
      backendRefs:
        - name: zitadel-login
          port: 3000
```

**Step 4: Update kustomization**

Add to `kubernetes/apps/base/auth/zitadel/kustomization.yaml`:
```yaml
resources:
  - ...existing...
  - httproute.yaml
  - grpcroute.yaml
```

**Step 5: Test locally**

Run: `kustomize build kubernetes/apps/base/auth/zitadel/`

**Step 6: Commit**

```bash
git add kubernetes/apps/base/auth/zitadel/
git commit -m "feat(auth): add Gateway API routes for Zitadel (GRPCRoute + HTTPRoute)

- Add GRPCRoute for Zitadel gRPC API (replaces nginx-ingress)
- Add HTTPRoute for hosted login UI
- Update service with appProtocol for HTTP/2 support

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Migrate Remaining Apps by Category

This task migrates all remaining applications. Create HTTPRoutes following the same pattern.

### 7a: Tools Namespace

**Files to create:**
- `kubernetes/apps/base/tools/it-tools/httproute.yaml`
- `kubernetes/apps/base/tools/affine/httproute.yaml`
- `kubernetes/apps/base/tools/attic/httproute.yaml`
- `kubernetes/apps/base/tools/ntfy/httproute.yaml`
- `kubernetes/apps/base/tools/copyparty/httproute.yaml`

### 7b: Media Namespace

**Files to create:**
- `kubernetes/apps/base/media/immich/httproute.yaml` (uses reynoza.org domain)
- `kubernetes/apps/base/media/emby/httproute.yaml`
- `kubernetes/apps/base/media/navidrome/httproute.yaml`

### 7c: Automation Namespace

**Files to create:**
- `kubernetes/apps/base/automation/home-assistant/httproute.yaml`
- `kubernetes/apps/base/automation/n8n/httproute.yaml`

### 7d: AI Namespace

**Files to create:**
- `kubernetes/apps/base/ai/ollama/httproute.yaml`
- `kubernetes/apps/base/ai/open-webui/httproute.yaml`
- `kubernetes/apps/base/ai/comfyui/httproute.yaml`

### 7e: Management Namespace

**Files to create:**
- `kubernetes/apps/base/management/paperless-ngx/httproute.yaml`
- `kubernetes/apps/base/management/wallos/httproute.yaml`

### 7f: arr-stack Namespace

**Files to create:**
- `kubernetes/apps/base/arr-stack/radarr/httproute.yaml`
- `kubernetes/apps/base/arr-stack/sonarr/httproute.yaml`
- `kubernetes/apps/base/arr-stack/bazarr/httproute.yaml`
- `kubernetes/apps/base/arr-stack/prowlarr/httproute.yaml`
- `kubernetes/apps/base/arr-stack/sabnzbd/httproute.yaml`
- `kubernetes/apps/base/arr-stack/qbittorrent/httproute.yaml`

### 7g: Backup Namespace

**Files to create:**
- `kubernetes/apps/base/backup/minio/httproute.yaml`

### 7h: Forgejo Namespace

**Files to create:**
- `kubernetes/apps/base/forgejo/httproute.yaml`

### 7i: flux-system (Weave GitOps)

**Files to create:**
- `kubernetes/infrastructure/configs/weave-gitops-httproute.yaml`

**Pattern for each HTTPRoute:**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
spec:
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
  hostnames:
    - <hostname>.home-infra.net  # or reynoza.org for Immich
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: <service-name>
          port: <port>
```

**Step: Commit all HTTPRoutes in batches by namespace**

```bash
git add kubernetes/apps/base/tools/*/httproute.yaml
git commit -m "feat(tools): add Gateway API HTTPRoutes for tools apps"

git add kubernetes/apps/base/media/*/httproute.yaml
git commit -m "feat(media): add Gateway API HTTPRoutes for media apps"

# Continue for each namespace...
```

---

## Task 8: Validate Full Migration

**Step 1: Push all changes**

```bash
git push
```

**Step 2: Reconcile FluxCD**

Run: `flux reconcile kustomization flux-system --with-source`

**Step 3: Check all HTTPRoutes**

Run: `kubectl get httproute -A`
Expected: All routes show ACCEPTED status

**Step 4: Check GRPCRoute**

Run: `kubectl get grpcroute -A`
Expected: zitadel-grpc shows ACCEPTED status

**Step 5: Test each app via Gateway IP**

Run test script:
```bash
for host in home grafana victoriametrics auth git; do
  echo "Testing ${host}.home-infra.net..."
  curl -sk -o /dev/null -w "%{http_code}" -H "Host: ${host}.home-infra.net" https://10.10.2.19/
  echo ""
done
```

**Step 6: Test Zitadel gRPC specifically**

Run: `grpcurl -insecure -servername auth.home-infra.net 10.10.2.19:443 list`
Expected: List of Zitadel gRPC services

---

## Task 9: Switch Gateway to Production IP (10.10.2.20)

Once all apps are validated via the test Gateway IP (10.10.2.19), switch to the production IP.

**Files:**
- Modify: `kubernetes/infrastructure/gateway/gateway.yaml`

**Step 1: Update Gateway IP from 10.10.2.19 to 10.10.2.20**

```yaml
# Change both annotation locations:
metadata:
  annotations:
    io.cilium/lb-ipam-ips: "10.10.2.20"  # Was 10.10.2.19
spec:
  infrastructure:
    annotations:
      io.cilium/lb-ipam-ips: "10.10.2.20"  # Was 10.10.2.19
```

**Step 2: Commit and push**

```bash
git add kubernetes/infrastructure/gateway/gateway.yaml
git commit -m "feat(gateway): switch Gateway to production IP 10.10.2.20

- Migration validated on test IP 10.10.2.19
- Now taking over from Cilium Ingress Controller

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push
```

**Step 3: Reconcile and verify**

Run: `flux reconcile kustomization flux-system --with-source`
Run: `kubectl get svc -n kube-system cilium-gateway-cilium-gateway`
Expected: EXTERNAL-IP shows 10.10.2.20

**Step 4: Verify all apps still work on new IP**

Run: `curl -sk -H "Host: home.home-infra.net" https://10.10.2.20/`

---

## Task 10: Update DNS/CoreDNS Configuration

**Files:**
- Modify: `kubernetes/infrastructure/controllers/coredns-custom.yaml`

**Step 1: Update CoreDNS to use Gateway IP**

Change internal resolution from nginx-ingress ClusterIP to Gateway:
```yaml
# Before: auth.home-infra.net -> nginx-ingress ClusterIP (10.109.133.199)
# After: auth.home-infra.net -> Gateway IP (10.10.2.20) or remove rewrite (use external DNS)
```

**Step 2: Update external DNS (if applicable)**

If using ControlD or Cloudflare for DNS, verify records point to 10.10.2.20.

**Step 3: Commit**

```bash
git add kubernetes/infrastructure/controllers/coredns-custom.yaml
git commit -m "feat(dns): update CoreDNS to use Cilium Gateway

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 11: Clean Up Old Ingress Resources (Post-Validation)

**IMPORTANT:** Only proceed after full validation of Gateway API routing.

**Files to eventually remove:**
- All `ingress.yaml` files in app directories
- `kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml`
- `kubernetes/apps/base/auth/zitadel/networkpolicy-nginx.yaml`
- nginx-ingress Helm release (if deployed via FluxCD)

**Step 1: Create cleanup branch**

```bash
git checkout -b cleanup/remove-ingress-resources
```

**Step 2: Remove Ingress resources from kustomizations**

For each app, remove `ingress.yaml` from the resources list in kustomization.yaml.

**Step 3: Delete Ingress files**

```bash
find kubernetes/apps -name "ingress.yaml" -delete
```

**Step 4: Remove nginx-ingress for Zitadel**

```bash
rm kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml
rm kubernetes/apps/base/auth/zitadel/networkpolicy-nginx.yaml
```

**Step 5: Update Cilium config to disable Ingress controller (optional)**

In `terraform/talos/cilium-inline.tf`, set:
```terraform
ingressController = {
  enabled = false
}
```

**Step 6: Commit cleanup**

```bash
git add -A
git commit -m "refactor: remove legacy Ingress resources after Gateway API migration

- Remove all Ingress resources (replaced by HTTPRoute/GRPCRoute)
- Remove nginx-ingress for Zitadel (replaced by GRPCRoute)
- All traffic now routes through Cilium Gateway API

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Rollback Procedure

If Gateway API migration fails at any phase:

**During Phase 1 (Testing on 10.10.2.19):**
- No action needed - existing Ingress on 10.10.2.20 still works
- Delete Gateway resources if desired:
  ```bash
  kubectl delete gateway cilium-gateway -n kube-system
  kubectl delete httproute -A --all
  kubectl delete grpcroute -A --all
  ```

**During Phase 2 (After switching to 10.10.2.20):**
1. Revert Gateway IP back to 10.10.2.19:
   ```bash
   # Edit gateway.yaml to use 10.10.2.19
   git revert HEAD
   git push
   flux reconcile kustomization flux-system --with-source
   ```
2. Re-enable Cilium Ingress Controller if disabled

**Debug Gateway issues:**
```bash
kubectl describe gateway cilium-gateway -n kube-system
kubectl get events -n kube-system --field-selector involvedObject.name=cilium-gateway
kubectl get httproute -A -o wide
cilium status
```

---

## Verification Checklist

- [ ] Gateway created and PROGRAMMED
- [ ] All HTTPRoutes ACCEPTED
- [ ] GRPCRoute for Zitadel ACCEPTED
- [ ] Homepage accessible via Gateway IP
- [ ] Grafana accessible via Gateway IP
- [ ] Zitadel login UI works
- [ ] Zitadel gRPC API works (test with grpcurl)
- [ ] All arr-stack apps accessible
- [ ] Immich accessible (reynoza.org domain)
- [ ] CoreDNS updated for internal resolution
- [ ] External DNS updated (if applicable)

---

## Files Summary

### New Files
| Path | Purpose |
|------|---------|
| `kubernetes/infrastructure/gateway/gateway.yaml` | Shared Gateway + ReferenceGrant |
| `kubernetes/infrastructure/gateway/kustomization.yaml` | Gateway kustomization |
| `kubernetes/apps/base/*/httproute.yaml` | HTTPRoute per app (26 files) |
| `kubernetes/apps/base/auth/zitadel/grpcroute.yaml` | GRPCRoute for Zitadel |

### Modified Files
| Path | Change |
|------|--------|
| `kubernetes/infrastructure/controllers/kustomization.yaml` | Add gateway reference |
| `kubernetes/apps/base/*/kustomization.yaml` | Add httproute.yaml (26 files) |
| `kubernetes/apps/base/auth/zitadel/service.yaml` | Add appProtocol for HTTP/2 |
| `kubernetes/infrastructure/controllers/coredns-custom.yaml` | Update DNS resolution |

### Files to Remove (Post-Validation)
| Path | Reason |
|------|--------|
| `kubernetes/apps/base/*/ingress.yaml` | Replaced by HTTPRoute |
| `kubernetes/apps/base/auth/zitadel/nginx-ingress.yaml` | Replaced by GRPCRoute |
| `kubernetes/apps/base/auth/zitadel/networkpolicy-nginx.yaml` | No longer needed |
