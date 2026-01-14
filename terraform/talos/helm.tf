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
      set -e

      if ! command -v kubectl &>/dev/null; then
        echo "ERROR: kubectl not found. Install via nix-shell."
        exit 1
      fi

      echo "Waiting for Cilium to be ready (installed via inlineManifest)..."
      for i in $(seq 1 120); do
        # Check if cilium pods are running
        CILIUM_PHASE=$(kubectl --kubeconfig=${local.kubeconfig_path} get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        NODE_READY=$(kubectl --kubeconfig=${local.kubeconfig_path} get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

        if [ "$CILIUM_PHASE" = "Running" ] && [ "$NODE_READY" = "True" ]; then
          echo "Cilium is ready and node is Ready!"
          exit 0
        fi
        echo "Waiting for Cilium... ($i/120) [Cilium: $CILIUM_PHASE, Node Ready: $NODE_READY]"
        sleep 5
      done

      echo "ERROR: Timeout waiting for Cilium after 10 minutes."
      echo "Check Cilium pods: kubectl get pods -n kube-system -l k8s-app=cilium"
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
    kubernetes_namespace.longhorn,
    null_resource.label_node_for_longhorn
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
