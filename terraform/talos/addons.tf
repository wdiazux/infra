# Talos Post-Bootstrap Addons
#
# This file handles post-bootstrap configuration including namespace setup,
# taint removal, and NVIDIA GPU device plugin installation.

# ============================================================================
# Control Plane Taint Removal
# ============================================================================

# Remove control-plane taint (allow scheduling on single node)
resource "null_resource" "remove_control_plane_taint" {
  count = var.allow_scheduling_on_control_plane && var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Removing control-plane taint to allow pod scheduling..."
      kubectl --kubeconfig=${local.kubeconfig_path} taint nodes --all node-role.kubernetes.io/control-plane- || true
      echo "Control-plane taint removed!"
    EOT
  }

  depends_on = [
    null_resource.wait_for_kubernetes
  ]
}

# ============================================================================
# Longhorn Namespace Configuration
# ============================================================================

# Configure Longhorn namespace with pod security
resource "null_resource" "configure_longhorn_namespace" {
  count = var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Configuring Longhorn namespace with pod security labels..."
      kubectl --kubeconfig=${local.kubeconfig_path} create namespace longhorn-system --dry-run=client -o yaml | kubectl --kubeconfig=${local.kubeconfig_path} apply -f -
      kubectl --kubeconfig=${local.kubeconfig_path} label namespace longhorn-system pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/audit=privileged pod-security.kubernetes.io/warn=privileged --overwrite || true
      echo "Longhorn namespace configured!"
    EOT
  }

  depends_on = [
    null_resource.remove_control_plane_taint
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

# Create nvidia RuntimeClass
resource "null_resource" "create_nvidia_runtimeclass" {
  count = var.enable_gpu_passthrough && var.auto_install_gpu_device_plugin && var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating nvidia RuntimeClass..."
      cat <<EOF | kubectl --kubeconfig=${local.kubeconfig_path} apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF
      echo "RuntimeClass created!"
    EOT
  }

  depends_on = [
    null_resource.configure_longhorn_namespace
  ]
}

# Install simple NVIDIA device plugin
resource "null_resource" "install_nvidia_device_plugin" {
  count = var.enable_gpu_passthrough && var.auto_install_gpu_device_plugin && var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing NVIDIA device plugin..."
      cat <<EOF | kubectl --kubeconfig=${local.kubeconfig_path} apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      runtimeClassName: nvidia
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      priorityClassName: system-node-critical
      containers:
        - image: nvcr.io/nvidia/k8s-device-plugin:v0.17.0
          name: nvidia-device-plugin-ctr
          env:
            - name: DEVICE_DISCOVERY_STRATEGY
              value: "nvml"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: device-plugin
              mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
EOF
      echo "NVIDIA device plugin installed!"
      echo "Verify with: kubectl get pods -n kube-system | grep nvidia"
    EOT
  }

  depends_on = [
    null_resource.create_nvidia_runtimeclass
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Post-bootstrap sequence:
# 1. Wait for Kubernetes API
# 2. Remove control-plane taint (single-node)
# 3. Create Longhorn namespace with privileged PSS
# 4. Create nvidia RuntimeClass
# 5. Install NVIDIA device plugin DaemonSet
#
# Manual steps after Terraform:
# - Install Cilium CNI: helm install cilium cilium/cilium -n kube-system -f ../../kubernetes/cilium/cilium-values.yaml
# - Install Longhorn: helm install longhorn longhorn/longhorn -n longhorn-system -f ../../kubernetes/longhorn/longhorn-values.yaml
# - Install FluxCD: flux bootstrap github ...
#
# GPU Verification:
# - kubectl describe node | grep nvidia.com/gpu
# - kubectl run gpu-test --rm -it --restart=Never --image=nvidia/cuda:12.6.3-base-ubuntu24.04 \
#     --overrides='{"spec":{"runtimeClassName":"nvidia"}}' -- nvidia-smi
