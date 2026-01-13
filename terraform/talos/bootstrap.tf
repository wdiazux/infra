# Talos Cluster Bootstrap
#
# This file handles bootstrapping the Kubernetes cluster, generating
# kubeconfig, and waiting for the Kubernetes API to be ready.

# ============================================================================
# Cluster Bootstrap
# ============================================================================

# Bootstrap the Kubernetes cluster (only done once)
resource "talos_machine_bootstrap" "cluster" {
  count = var.auto_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.node_ip
  endpoint             = var.node_ip

  # Wait for node to be up with static IP before bootstrapping
  depends_on = [
    talos_machine_configuration_apply.node,
    null_resource.wait_for_static_ip
  ]
}

# ============================================================================
# Kubeconfig Generation
# ============================================================================

# Retrieve kubeconfig after bootstrap
# NOTE: Using resource instead of data source (data source deprecated in talos provider 0.10+)
resource "talos_cluster_kubeconfig" "cluster" {
  count = var.generate_kubeconfig && var.auto_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.node_ip
  endpoint             = var.node_ip

  depends_on = [
    talos_machine_bootstrap.cluster
  ]
}

# Save kubeconfig to file
resource "local_file" "kubeconfig" {
  count = var.generate_kubeconfig && var.auto_bootstrap ? 1 : 0

  content         = talos_cluster_kubeconfig.cluster[0].kubeconfig_raw
  filename        = local.kubeconfig_path
  file_permission = "0600"
}

# ============================================================================
# Kubernetes API Wait
# ============================================================================

# Wait for Kubernetes API to be ready
resource "null_resource" "wait_for_kubernetes" {
  count = var.auto_bootstrap && var.generate_kubeconfig ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Kubernetes API to be ready (timeout: ${var.kubernetes_wait_timeout}s)..."
      timeout ${var.kubernetes_wait_timeout} bash -c 'until kubectl --kubeconfig=${local.kubeconfig_path} get nodes &>/dev/null; do echo "Waiting..."; sleep 5; done'
      echo "Kubernetes API is ready!"
    EOT
  }

  depends_on = [
    local_file.kubeconfig,
    talos_machine_bootstrap.cluster
  ]
}
