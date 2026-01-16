# Outputs for Talos Kubernetes Cluster

# ============================================================================
# Cluster Information
# ============================================================================

output "cluster_name" {
  description = "Cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = local.cluster_endpoint
}

output "talos_version" {
  description = "Talos Linux version"
  value       = var.talos_version
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}

# ============================================================================
# Node Information
# ============================================================================

output "node_name" {
  description = "Talos node name"
  value       = proxmox_virtual_environment_vm.talos_node.name
}

output "node_ip" {
  description = "Talos node IP address"
  value       = var.node_ip
}

output "node_vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.talos_node.vm_id
}

# ============================================================================
# Configuration Files
# ============================================================================

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = var.generate_kubeconfig && var.auto_bootstrap ? local.kubeconfig_path : "Not generated"
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = local.talosconfig_path
}

# ============================================================================
# Sensitive Outputs
# ============================================================================

output "talos_client_configuration" {
  description = "Talos client configuration"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig content"
  value       = var.auto_bootstrap ? talos_cluster_kubeconfig.cluster[0].kubeconfig_raw : ""
  sensitive   = true
}

# ============================================================================
# GPU Information
# ============================================================================

output "gpu_enabled" {
  description = "GPU passthrough enabled"
  value       = var.enable_gpu_passthrough
}

# ============================================================================
# CNI and Storage Information
# ============================================================================

output "cilium_version" {
  description = "Cilium CNI version"
  value       = var.cilium_version
}

output "cilium_lb_pool" {
  description = "Cilium L2 LoadBalancer IP pool CIDR"
  value       = var.cilium_lb_pool_cidr
}

output "longhorn_version" {
  description = "Longhorn storage version"
  value       = var.longhorn_version
}

# ============================================================================
# Service URLs
# ============================================================================

output "hubble_ui_url" {
  description = "Cilium Hubble UI URL"
  value       = "http://${var.hubble_ui_ip}"
}

output "longhorn_ui_url" {
  description = "Longhorn storage management UI URL"
  value       = "http://${var.longhorn_ui_ip}"
}

output "forgejo_http_url" {
  description = "Forgejo Git server HTTP URL (port 80)"
  value       = var.enable_forgejo ? "http://${var.forgejo_ip}" : "Not enabled"
}

output "forgejo_ssh_url" {
  description = "Forgejo Git server SSH URL"
  value       = var.enable_forgejo ? "ssh://git@${var.forgejo_ssh_ip}:22" : "Not enabled"
}

output "fluxcd_webhook_url" {
  description = "FluxCD webhook receiver URL"
  value       = var.enable_fluxcd ? "http://${var.fluxcd_webhook_ip}" : "Not enabled"
}

# ============================================================================
# Access Instructions
# ============================================================================

output "access_instructions" {
  description = "How to access the cluster"
  value       = var.auto_bootstrap ? local.access_instructions : "Cluster not bootstrapped"
}

output "useful_commands" {
  description = "Useful commands"
  value       = var.auto_bootstrap ? local.useful_commands : ""
}
