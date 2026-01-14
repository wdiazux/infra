# Talos Post-Bootstrap Addons
#
# This file handles post-bootstrap configuration including namespace setup,
# taint removal, and NVIDIA GPU device plugin installation.
#
# IMPROVEMENTS:
# - Uses kubernetes_namespace instead of kubectl for namespace creation
# - Uses kubernetes_manifest for RuntimeClass and DaemonSet
# - Keeps null_resource only where kubectl is truly needed (taint removal, node labeling)

# ============================================================================
# Control Plane Taint Removal
# ============================================================================

# Remove control-plane taint (allow scheduling on single node)
# NOTE: Using null_resource because kubernetes provider doesn't support
# removing taints from all nodes in one operation
resource "null_resource" "remove_control_plane_taint" {
  count = var.allow_scheduling_on_control_plane && var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      if ! command -v kubectl &>/dev/null; then
        echo "ERROR: kubectl not found. Install via nix-shell."
        exit 1
      fi

      echo "Removing control-plane taint to allow pod scheduling..."
      kubectl --kubeconfig=${local.kubeconfig_path} taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
      echo "Control-plane taint removed (or was not present)."
    EOT
  }

  depends_on = [
    null_resource.wait_for_kubernetes
  ]
}

# ============================================================================
# Longhorn Namespace Configuration
# ============================================================================

# Create Longhorn namespace with pod security labels
resource "kubernetes_namespace" "longhorn" {
  count = var.auto_bootstrap ? 1 : 0

  metadata {
    name = "longhorn-system"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }

  depends_on = [
    null_resource.remove_control_plane_taint
  ]
}

# Label node for Longhorn default disk creation
# NOTE: Using null_resource because we need to dynamically get node name
resource "null_resource" "label_node_for_longhorn" {
  count = var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      if ! command -v kubectl &>/dev/null; then
        echo "ERROR: kubectl not found. Install via nix-shell."
        exit 1
      fi

      echo "Labeling node for Longhorn default disk creation..."
      NODE_NAME=$(kubectl --kubeconfig=${local.kubeconfig_path} get nodes -o jsonpath='{.items[0].metadata.name}')
      if [ -z "$NODE_NAME" ]; then
        echo "ERROR: Could not get node name"
        exit 1
      fi
      kubectl --kubeconfig=${local.kubeconfig_path} label node "$NODE_NAME" node.longhorn.io/create-default-disk=true --overwrite
      echo "Node '$NODE_NAME' labeled for Longhorn."
    EOT
  }

  depends_on = [
    kubernetes_namespace.longhorn
  ]
}

# ============================================================================
# NVIDIA GPU Setup (Simple Device Plugin)
# ============================================================================
#
# NOTE: We use the simple NVIDIA device plugin instead of the GPU Operator.
# The GPU Operator conflicts with Talos's immutable design because it tries
# to install drivers and toolkit, which are already provided by Talos extensions:
#   - nonfree-kmod-nvidia-production (driver)
#   - nvidia-container-toolkit-production (container runtime)
#
# The simple device plugin just advertises GPUs to Kubernetes.

# Create nvidia RuntimeClass using kubernetes_manifest
resource "kubernetes_manifest" "nvidia_runtimeclass" {
  count = var.enable_gpu_passthrough && var.auto_install_gpu_device_plugin && var.auto_bootstrap ? 1 : 0

  manifest = {
    apiVersion = "node.k8s.io/v1"
    kind       = "RuntimeClass"
    metadata = {
      name = "nvidia"
    }
    handler = "nvidia"
  }

  depends_on = [
    null_resource.wait_for_cilium
  ]
}

# Install simple NVIDIA device plugin using kubernetes_manifest
resource "kubernetes_manifest" "nvidia_device_plugin" {
  count = var.enable_gpu_passthrough && var.auto_install_gpu_device_plugin && var.auto_bootstrap ? 1 : 0

  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "nvidia-device-plugin-daemonset"
      namespace = "kube-system"
    }
    spec = {
      selector = {
        matchLabels = {
          name = "nvidia-device-plugin-ds"
        }
      }
      updateStrategy = {
        type = "RollingUpdate"
      }
      template = {
        metadata = {
          labels = {
            name = "nvidia-device-plugin-ds"
          }
        }
        spec = {
          runtimeClassName  = "nvidia"
          priorityClassName = "system-node-critical"
          tolerations = [
            {
              key      = "nvidia.com/gpu"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          containers = [
            {
              name  = "nvidia-device-plugin-ctr"
              image = "nvcr.io/nvidia/k8s-device-plugin:v0.18.1"
              env = [
                {
                  name  = "DEVICE_DISCOVERY_STRATEGY"
                  value = "nvml"
                }
              ]
              securityContext = {
                allowPrivilegeEscalation = false
                capabilities = {
                  drop = ["ALL"]
                }
              }
              volumeMounts = [
                {
                  name      = "device-plugin"
                  mountPath = "/var/lib/kubelet/device-plugins"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "device-plugin"
              hostPath = {
                path = "/var/lib/kubelet/device-plugins"
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.nvidia_runtimeclass
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Post-bootstrap sequence (automated):
# 1. Wait for Kubernetes API
# 2. Remove control-plane taint (single-node)
# 3. Create Longhorn namespace with privileged PSS
# 4. Label node for Longhorn disk creation
# 5. Cilium CNI ready (via inlineManifest) - node becomes Ready
# 6. Install Longhorn storage (via Helm)
# 7. Create nvidia RuntimeClass
# 8. Install NVIDIA device plugin DaemonSet
#
# Verification:
# - kubectl get nodes (should be Ready)
# - kubectl get pods -n kube-system -l k8s-app=cilium
# - kubectl get pods -n longhorn-system
# - kubectl get ciliumloadbalancerippools
#
# GPU Verification:
# - kubectl describe node | grep nvidia.com/gpu
# - kubectl run gpu-test --rm -it --restart=Never --image=nvidia/cuda:12.6.3-base-ubuntu24.04 \
#     --overrides='{"spec":{"runtimeClassName":"nvidia"}}' -- nvidia-smi
