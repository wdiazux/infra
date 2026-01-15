# Pre-Destroy Cleanup Resources
#
# These terraform_data resources run destroy-time provisioners to clean up
# Kubernetes resources before Terraform destroys them. This helps prevent
# stuck resources and failed destroy operations.
#
# Key Problems Solved:
# - Longhorn requires deleting-confirmation-flag=true before uninstall
# - FluxCD leaves finalizers on managed resources
# - Webhook configurations can block namespace deletion
# - Namespaces get stuck due to finalizers
#
# NOTE: terraform_data is used instead of null_resource because it's the
# recommended replacement in Terraform 1.4+ and handles triggers better.
#
# IMPORTANT: Destroy provisioners use self.triggers_replace.* to access
# values because normal variables aren't available during destroy.

# ============================================================================
# FluxCD Pre-Destroy Cleanup
# ============================================================================
# Suspends and removes FluxCD resources before Terraform tries to destroy them

resource "terraform_data" "fluxcd_pre_destroy" {
  count = var.enable_fluxcd ? 1 : 0

  # Store values needed during destroy (variables not available in destroy)
  triggers_replace = {
    kubeconfig = local.kubeconfig_path
  }

  # This runs BEFORE the resource is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "=== FluxCD Pre-Destroy Cleanup ==="

      KUBECONFIG="${self.triggers_replace.kubeconfig}"

      # Check if cluster is accessible
      if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1; then
        echo "Cluster not accessible, skipping FluxCD cleanup"
        exit 0
      fi

      # Suspend all reconciliations first
      echo "Suspending FluxCD reconciliation..."
      if command -v flux &>/dev/null; then
        flux suspend kustomization --all --kubeconfig="$KUBECONFIG" 2>/dev/null || true
        flux suspend source git --all --kubeconfig="$KUBECONFIG" 2>/dev/null || true
      fi

      # Delete FluxCD-managed resources
      echo "Deleting FluxCD resources..."
      kubectl --kubeconfig="$KUBECONFIG" delete kustomization --all -A --ignore-not-found 2>/dev/null || true
      kubectl --kubeconfig="$KUBECONFIG" delete helmrelease --all -A --ignore-not-found 2>/dev/null || true
      kubectl --kubeconfig="$KUBECONFIG" delete gitrepository --all -A --ignore-not-found 2>/dev/null || true

      # Uninstall FluxCD
      echo "Uninstalling FluxCD..."
      if command -v flux &>/dev/null; then
        flux uninstall --kubeconfig="$KUBECONFIG" --silent 2>/dev/null || true
      fi

      # Clean up flux-system namespace finalizers
      echo "Removing flux-system namespace finalizers..."
      kubectl --kubeconfig="$KUBECONFIG" patch namespace flux-system \
        -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

      echo "=== FluxCD Pre-Destroy Complete ==="
    EOT

    on_failure = continue
  }

  depends_on = [
    null_resource.wait_for_kubernetes
  ]
}

# ============================================================================
# Longhorn Pre-Destroy Cleanup
# ============================================================================
# Sets deleting-confirmation-flag and removes webhooks before Helm uninstall

resource "terraform_data" "longhorn_pre_destroy" {
  count = var.auto_bootstrap ? 1 : 0

  # Store values needed during destroy
  triggers_replace = {
    kubeconfig = local.kubeconfig_path
    namespace  = "longhorn-system"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "=== Longhorn Pre-Destroy Cleanup ==="

      KUBECONFIG="${self.triggers_replace.kubeconfig}"
      NAMESPACE="${self.triggers_replace.namespace}"

      # Check if cluster is accessible
      if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1; then
        echo "Cluster not accessible, skipping Longhorn cleanup"
        exit 0
      fi

      # Check if Longhorn namespace exists
      if ! kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
        echo "Longhorn namespace does not exist, skipping"
        exit 0
      fi

      # Set deleting-confirmation-flag (CRITICAL for Longhorn uninstall)
      echo "Setting Longhorn deleting-confirmation-flag..."
      kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" \
        patch settings.longhorn.io deleting-confirmation-flag \
        --type=merge -p '{"value": "true"}' 2>/dev/null || true

      # Delete webhook configurations (can block namespace deletion)
      echo "Deleting Longhorn webhook configurations..."
      kubectl --kubeconfig="$KUBECONFIG" delete validatingwebhookconfiguration \
        longhorn-webhook-validator --ignore-not-found 2>/dev/null || true
      kubectl --kubeconfig="$KUBECONFIG" delete mutatingwebhookconfiguration \
        longhorn-webhook-mutator --ignore-not-found 2>/dev/null || true

      # Scale down Longhorn to speed up deletion
      echo "Scaling down Longhorn deployments..."
      kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" \
        scale deployment --all --replicas=0 2>/dev/null || true

      # Delete any failed uninstall jobs (from previous attempts)
      echo "Cleaning up failed uninstall jobs..."
      kubectl --kubeconfig="$KUBECONFIG" delete jobs -n "$NAMESPACE" \
        -l app=longhorn-uninstall --ignore-not-found 2>/dev/null || true
      kubectl --kubeconfig="$KUBECONFIG" delete job longhorn-uninstall \
        -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

      # Remove finalizers from Longhorn CRDs if they exist
      echo "Removing Longhorn CRD finalizers..."
      for crd in $(kubectl --kubeconfig="$KUBECONFIG" get crd -o name 2>/dev/null | grep longhorn || true); do
        kubectl --kubeconfig="$KUBECONFIG" patch "$crd" \
          -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      done

      # Remove finalizers from namespace
      echo "Removing namespace finalizers..."
      kubectl --kubeconfig="$KUBECONFIG" patch namespace "$NAMESPACE" \
        -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

      echo "=== Longhorn Pre-Destroy Complete ==="
    EOT

    on_failure = continue
  }

  depends_on = [
    null_resource.wait_for_cilium
  ]
}

# ============================================================================
# Forgejo Pre-Destroy Cleanup
# ============================================================================
# Cleans up Forgejo namespace finalizers before deletion

resource "terraform_data" "forgejo_pre_destroy" {
  count = var.enable_forgejo ? 1 : 0

  triggers_replace = {
    kubeconfig = local.kubeconfig_path
    namespace  = "forgejo"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "=== Forgejo Pre-Destroy Cleanup ==="

      KUBECONFIG="${self.triggers_replace.kubeconfig}"
      NAMESPACE="${self.triggers_replace.namespace}"

      # Check if cluster is accessible
      if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1; then
        echo "Cluster not accessible, skipping Forgejo cleanup"
        exit 0
      fi

      # Check if namespace exists
      if ! kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
        echo "Forgejo namespace does not exist, skipping"
        exit 0
      fi

      # Remove finalizers from namespace
      echo "Removing Forgejo namespace finalizers..."
      kubectl --kubeconfig="$KUBECONFIG" patch namespace "$NAMESPACE" \
        -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

      echo "=== Forgejo Pre-Destroy Complete ==="
    EOT

    on_failure = continue
  }

  depends_on = [
    null_resource.wait_for_cilium
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Why terraform_data instead of null_resource?
# - terraform_data is the recommended replacement (Terraform 1.4+)
# - Better handling of triggers and lifecycle
# - Same provisioner support as null_resource
#
# Why on_failure = continue?
# - Destroy operations should not fail if cleanup fails
# - The cluster may already be partially destroyed
# - Better to proceed with Terraform destroy than to block
#
# Why use triggers_replace?
# - During destroy, normal variables are not accessible
# - triggers_replace stores values at creation time
# - Use self.triggers_replace.* in destroy provisioners
#
# Destroy Order:
# 1. terraform_data.fluxcd_pre_destroy (suspend/delete FluxCD)
# 2. terraform_data.longhorn_pre_destroy (set flag, remove webhooks)
# 3. terraform_data.forgejo_pre_destroy (remove finalizers)
# 4. helm_release.longhorn (Helm uninstall)
# 5. helm_release.forgejo (Helm uninstall)
# 6. kubernetes_namespace.* (namespace deletion)
# 7. proxmox_virtual_environment_vm.talos_node (VM deletion)
#
# Manual Fallback:
# If terraform destroy still fails, use ./destroy.sh which handles
# additional edge cases and removes stuck resources from state.
