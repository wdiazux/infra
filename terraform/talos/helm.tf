# Helm Releases for Kubernetes Components
#
# Installs Longhorn storage after cluster bootstrap.
# NOTE: Cilium is now installed via Talos inlineManifest (see cilium-inline.tf)
# to solve the chicken-and-egg problem with FluxCD.

# ============================================================================
# Wait for Cilium to be Ready
# ============================================================================

# Wait for Cilium (installed via inlineManifest) to be ready
resource "null_resource" "wait_for_cilium" {
  count = var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Cilium to be ready (installed via inlineManifest)..."
      for i in $(seq 1 120); do
        # Check if cilium pods are running
        if kubectl --kubeconfig=${local.kubeconfig_path} get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
          # Also check if node is Ready
          if kubectl --kubeconfig=${local.kubeconfig_path} get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
            echo "Cilium is ready and node is Ready!"
            exit 0
          fi
        fi
        echo "Waiting for Cilium... ($i/120)"
        sleep 5
      done
      echo "Warning: Timeout waiting for Cilium"
      exit 1
    EOT
  }

  depends_on = [
    null_resource.wait_for_kubernetes
  ]
}

# ============================================================================
# Longhorn Storage
# ============================================================================

resource "helm_release" "longhorn" {
  count = var.auto_bootstrap ? 1 : 0

  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = var.longhorn_version
  namespace        = "longhorn-system"
  create_namespace = false # Already created by null_resource.configure_longhorn_namespace

  # Use values file from kubernetes/longhorn/
  values = [file("${path.module}/../../kubernetes/longhorn/longhorn-values.yaml")]

  # Wait for Longhorn to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    null_resource.wait_for_cilium,
    null_resource.configure_longhorn_namespace
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Installation order:
# 1. Talos bootstrap (includes Cilium via inlineManifest)
# 2. Kubernetes API ready (wait_for_kubernetes)
# 3. Cilium becomes Ready (wait_for_cilium)
# 4. Node becomes Ready
# 5. Longhorn storage installed (helm_release.longhorn)
# 6. FluxCD bootstrap (fluxcd.tf)
# 7. NVIDIA device plugin starts (addons.tf)
#
# Cilium:
# - Installed via Talos inlineManifest (cilium-inline.tf)
# - L2 IP pool and announcement policy included in inline manifest
# - FluxCD HelmRelease can take over management later
#
# Values files:
# - Longhorn: kubernetes/longhorn/longhorn-values.yaml
#
# Verification:
# - kubectl get pods -n kube-system -l k8s-app=cilium
# - kubectl get pods -n longhorn-system
# - kubectl get ciliumloadbalancerippools
# - kubectl get ciliuml2announcementpolicies
