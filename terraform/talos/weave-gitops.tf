# Weave GitOps - FluxCD Web UI
#
# Provides a web dashboard for monitoring FluxCD:
# - Kustomization status and history
# - GitRepository sync status
# - HelmRelease status
# - Reconciliation errors
#
# Access: http://10.10.2.15 (or configured IP)
#
# Prerequisites:
# - FluxCD installed and running
#
# Note: Installed after FluxCD bootstrap to ensure controllers are ready.

# ============================================================================
# Weave GitOps Helm Release
# ============================================================================

resource "helm_release" "weave_gitops" {
  count = var.enable_fluxcd && var.enable_weave_gitops ? 1 : 0

  name             = "weave-gitops"
  repository       = "oci://ghcr.io/weaveworks/charts"
  chart            = "weave-gitops"
  version          = var.weave_gitops_version
  namespace        = "flux-system"
  create_namespace = false # flux-system already exists

  # Admin credentials
  set {
    name  = "adminUser.create"
    value = "true"
  }

  set {
    name  = "adminUser.username"
    value = var.weave_gitops_admin_user
  }

  set_sensitive {
    name  = "adminUser.passwordHash"
    value = local.git_secrets.weave_gitops_password_hash
  }

  # Service configuration
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.loadBalancerIP"
    value = var.weave_gitops_ip
  }

  # Resource limits (lightweight)
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  wait    = true
  timeout = 300

  depends_on = [
    null_resource.flux_verify
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Password hash generation:
#   echo -n 'your-password' | gitops get bcrypt-hash
#   Or: htpasswd -nbBC 10 "" 'your-password' | tr -d ':\n' | sed 's/$2y/$2a/'
#
# Access:
#   http://<weave_gitops_ip>:9001
#   Login with admin credentials
#
# Verification:
#   kubectl get pods -n flux-system -l app.kubernetes.io/name=weave-gitops
#   kubectl get svc -n flux-system weave-gitops
