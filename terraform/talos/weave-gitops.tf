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

  # Disable default service (we create our own with static IP)
  set {
    name  = "service.type"
    value = "ClusterIP"
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
# Weave GitOps LoadBalancer Service (Static IP)
# ============================================================================
# Cilium L2 LoadBalancer doesn't respect loadBalancerIP in Helm values,
# so we create a dedicated service with the correct IP.

resource "kubernetes_service" "weave_gitops_lb" {
  count = var.enable_fluxcd && var.enable_weave_gitops ? 1 : 0

  metadata {
    name      = "weave-gitops-lb"
    namespace = "flux-system"
    labels = {
      "app.kubernetes.io/name"       = "weave-gitops"
      "app.kubernetes.io/component"  = "loadbalancer"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    type             = "LoadBalancer"
    load_balancer_ip = var.weave_gitops_ip

    port {
      name        = "http"
      port        = 80
      target_port = 9001
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = "weave-gitops"
    }
  }

  depends_on = [
    helm_release.weave_gitops
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
#   http://10.10.2.16 (port 80)
#   Login with admin credentials
#
# Verification:
#   kubectl get pods -n flux-system -l app.kubernetes.io/name=weave-gitops
#   kubectl get svc -n flux-system weave-gitops-lb
