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
    kubernetes_namespace.longhorn,
    null_resource.wait_for_cilium
  ]
}

# ============================================================================
# Longhorn Backup Secret (NFS Credentials)
# ============================================================================

# Create secret for Longhorn NFS backup authentication
resource "kubernetes_secret" "longhorn_backup" {
  count = var.auto_bootstrap && var.enable_longhorn_backups ? 1 : 0

  metadata {
    name      = "longhorn-backup-secret"
    namespace = kubernetes_namespace.longhorn[0].metadata[0].name
  }

  data = {
    NFS_USERNAME = data.sops_file.nas_backup_secrets[0].data["nfs_username"]
    NFS_PASSWORD = data.sops_file.nas_backup_secrets[0].data["nfs_password"]
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.longhorn
  ]
}

# ============================================================================
# Longhorn BackupTarget Configuration
# ============================================================================
# NOTE: In Longhorn 1.10+, backup targets are configured via BackupTarget CRD,
# not via defaultSettings.backupTarget in values.yaml.

resource "null_resource" "configure_longhorn_backup_target" {
  count = var.auto_bootstrap && var.enable_longhorn_backups ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Configuring Longhorn BackupTarget..."

      # Wait for BackupTarget CRD to be available
      for i in $(seq 1 30); do
        if kubectl --kubeconfig=${local.kubeconfig_path} get backuptarget default -n longhorn-system &>/dev/null; then
          echo "BackupTarget CRD is available"
          break
        fi
        echo "Waiting for BackupTarget CRD... ($i/30)"
        sleep 5
      done

      # Patch the default BackupTarget with NFS URL
      kubectl --kubeconfig=${local.kubeconfig_path} patch backuptarget default \
        -n longhorn-system \
        --type=merge \
        -p '{"spec":{"backupTargetURL":"${var.longhorn_backup_target}","pollInterval":"5m0s"}}'

      echo "Longhorn BackupTarget configured: ${var.longhorn_backup_target}"
    EOT
  }

  depends_on = [
    helm_release.longhorn,
    kubernetes_secret.longhorn_backup
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

# Create nvidia RuntimeClass and device plugin using kubectl
# Note: Using null_resource instead of kubernetes_manifest to avoid plan-time
# API validation which fails when the cluster doesn't exist yet.

resource "null_resource" "nvidia_gpu_setup" {
  count = var.enable_gpu_passthrough && var.auto_install_gpu_device_plugin && var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Installing NVIDIA GPU Support ==="

      # Create RuntimeClass
      echo "Creating nvidia RuntimeClass..."
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF

      # Create NVIDIA device plugin DaemonSet
      echo "Creating NVIDIA device plugin DaemonSet..."
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
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
      priorityClassName: system-node-critical
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: nvidia-device-plugin-ctr
          image: nvcr.io/nvidia/k8s-device-plugin:${var.nvidia_device_plugin_version}
          env:
            - name: DEVICE_DISCOVERY_STRATEGY
              value: nvml
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

      echo "=== NVIDIA GPU Support Installed ==="
    EOT
  }

  depends_on = [
    null_resource.wait_for_cilium
  ]
}

# ============================================================================
# cert-manager Namespace and Secrets
# ============================================================================
#
# Creates the cert-manager namespace and Cloudflare API token secret.
# cert-manager itself is deployed via FluxCD, but the namespace and secret
# must exist before FluxCD can deploy cert-manager with the ClusterIssuer.

# cert-manager namespace
resource "kubernetes_namespace" "cert_manager" {
  count = var.auto_bootstrap && var.enable_cert_manager ? 1 : 0

  metadata {
    name = "cert-manager"

    labels = {
      "app.kubernetes.io/name" = "cert-manager"
    }
  }

  depends_on = [
    null_resource.remove_control_plane_taint
  ]
}

# Cloudflare API Token Secret for cert-manager
# Used by ClusterIssuer for DNS-01 challenge (wildcard certificates)
resource "kubernetes_secret" "cloudflare_api_token" {
  count = var.auto_bootstrap && var.enable_cert_manager ? 1 : 0

  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.cert_manager[0].metadata[0].name
  }

  data = {
    "api-token" = data.sops_file.cloudflare_secrets[0].data["cloudflare_api_token"]
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.cert_manager
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
# 5. Create cert-manager namespace and Cloudflare secret
# 6. Cilium CNI ready (via inlineManifest) - node becomes Ready
# 7. Install Longhorn storage (via Helm)
# 8. Create nvidia RuntimeClass
# 9. Install NVIDIA device plugin DaemonSet
#
# Verification:
# - kubectl get nodes (should be Ready)
# - kubectl get pods -n kube-system -l k8s-app=cilium
# - kubectl get pods -n longhorn-system
# - kubectl get ciliumloadbalancerippools
# - kubectl get secret cloudflare-api-token -n cert-manager
#
# GPU Verification:
# - kubectl describe node | grep nvidia.com/gpu
# - kubectl run gpu-test --rm -it --restart=Never --image=nvidia/cuda:12.6.3-base-ubuntu24.04 \
#     --overrides='{"spec":{"runtimeClassName":"nvidia"}}' -- nvidia-smi
