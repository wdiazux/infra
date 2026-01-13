# Talos Post-Bootstrap Addons
#
# This file handles post-bootstrap configuration including namespace setup,
# taint removal, and optional GPU operator installation.

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
      echo "Longhorn namespace configured! Install Longhorn via Helm: helm install longhorn longhorn/longhorn --namespace longhorn-system --values ../kubernetes/longhorn/longhorn-values.yaml"
    EOT
  }

  depends_on = [
    null_resource.remove_control_plane_taint
  ]
}

# ============================================================================
# NVIDIA GPU Operator (Optional)
# ============================================================================

# Install NVIDIA GPU Operator (when GPU passthrough is enabled)
resource "null_resource" "install_gpu_operator" {
  count = var.enable_gpu_passthrough && var.auto_install_gpu_operator && var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing NVIDIA GPU Operator..."

      # Add NVIDIA Helm repo
      helm repo add nvidia https://helm.ngc.nvidia.com/nvidia 2>/dev/null || true
      helm repo update

      # Create namespace
      kubectl --kubeconfig=${local.kubeconfig_path} create namespace gpu-operator --dry-run=client -o yaml | kubectl --kubeconfig=${local.kubeconfig_path} apply -f -

      # Label namespace for privileged pods
      kubectl --kubeconfig=${local.kubeconfig_path} label namespace gpu-operator pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/audit=privileged pod-security.kubernetes.io/warn=privileged --overwrite || true

      # Install GPU Operator
      # Note: Driver is provided by Talos system extension (nonfree-kmod-nvidia)
      # so we disable driver installation and only install the toolkit/device-plugin
      helm install gpu-operator nvidia/gpu-operator \
        --namespace gpu-operator \
        --kubeconfig=${local.kubeconfig_path} \
        --set driver.enabled=false \
        --set toolkit.enabled=true \
        --set devicePlugin.enabled=true \
        --set dcgmExporter.enabled=false \
        --set migManager.enabled=false \
        --set nodeStatusExporter.enabled=false \
        --set gfd.enabled=true \
        --wait --timeout 5m

      echo "NVIDIA GPU Operator installed!"
      echo "Verify with: kubectl get pods -n gpu-operator"
    EOT
  }

  depends_on = [
    null_resource.configure_longhorn_namespace
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
# 4. (Optional) Install GPU Operator
#
# Manual steps after Terraform:
# - Install Cilium CNI: helm install cilium cilium/cilium -n kube-system -f ../kubernetes/cilium/cilium-values.yaml
# - Install Longhorn: helm install longhorn longhorn/longhorn -n longhorn-system -f ../kubernetes/longhorn/longhorn-values.yaml
# - Install FluxCD: flux bootstrap github ...
