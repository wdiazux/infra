# Terraform Outputs for Talos Linux Deployment
#
# Export useful information after deployment

# ============================================================================
# Cluster Information
# ============================================================================

output "cluster_name" {
  description = "Talos/Kubernetes cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = local.cluster_endpoint
}

output "talos_version" {
  description = "Talos Linux version deployed"
  value       = var.talos_version
}

output "kubernetes_version" {
  description = "Kubernetes version deployed"
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
  description = "Proxmox VM ID for the node"
  value       = proxmox_virtual_environment_vm.talos_node.vm_id
}

output "node_resources" {
  description = "Node hardware resources"
  value = {
    cpu_cores   = var.node_cpu_cores
    memory_mb   = var.node_memory
    disk_gb     = var.node_disk_size
    gpu_enabled = var.enable_gpu_passthrough
  }
}

# ============================================================================
# Configuration Files
# ============================================================================

output "kubeconfig_path" {
  description = "Path to generated kubeconfig file"
  value       = var.generate_kubeconfig && var.auto_bootstrap ? local.kubeconfig_path : "Not generated (set generate_kubeconfig=true and auto_bootstrap=true)"
}

output "talosconfig_path" {
  description = "Path to generated talosconfig file"
  value       = local.talosconfig_path
}

# ============================================================================
# Access Instructions
# ============================================================================

output "access_instructions" {
  description = "Instructions for accessing the cluster"
  value       = var.auto_bootstrap ? local.access_instructions_bootstrapped : "Cluster not bootstrapped yet. Set auto_bootstrap=true to bootstrap automatically."
}

# ============================================================================
# Sensitive Outputs (Hidden by Default)
# ============================================================================

output "talos_client_configuration" {
  description = "Talos client configuration (sensitive)"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (sensitive)"
  value       = var.auto_bootstrap ? talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.ca_certificate : "Not available"
  sensitive   = true
}

# ============================================================================
# GPU Information
# ============================================================================

output "gpu_passthrough_enabled" {
  description = "Whether NVIDIA GPU passthrough is enabled"
  value       = var.enable_gpu_passthrough
}

output "gpu_pci_id" {
  description = "PCI ID of passed-through GPU (if enabled)"
  value       = var.enable_gpu_passthrough ? var.gpu_pci_id : "N/A"
}

output "gpu_verification_command" {
  description = "Command to verify GPU passthrough in a pod"
  value       = var.enable_gpu_passthrough ? local.gpu_verification_instructions : "GPU passthrough not enabled"
}

# ============================================================================
# Storage Information
# ============================================================================

output "storage_configuration" {
  description = "Storage configuration summary"
  value = {
    local_disk      = "${var.node_disk_size}GB"
    primary_storage = "Longhorn v1.7.x (install via Helm - see kubernetes/longhorn/)"
    backup_target   = var.nfs_server != "" ? "NFS backup to ${var.nfs_server}:${var.nfs_path}" : "Not configured (optional)"
    storage_classes = [
      "longhorn (default, 1-replica for single node, expandable to 3-replica for HA)",
      "longhorn-retain (persistent data survives PVC deletion)",
      "longhorn-fast (performance optimized, SSD/NVMe selector)",
      "longhorn-backup (automated snapshots)",
      "longhorn-xfs (XFS filesystem support)"
    ]
    installation_notes = local.storage_installation_notes
  }
}

# ============================================================================
# Network Information
# ============================================================================

output "network_configuration" {
  description = "Network configuration summary"
  value = {
    ip_address  = var.node_ip
    gateway     = var.node_gateway
    netmask     = var.node_netmask
    dns_servers = var.dns_servers
    bridge      = var.network_bridge
    vlan        = var.network_vlan > 0 ? var.network_vlan : "none"
  }
}

# ============================================================================
# Post-Deployment Commands
# ============================================================================

output "useful_commands" {
  description = "Useful commands for managing the cluster"
  value       = var.auto_bootstrap ? local.useful_commands_bootstrapped : "Cluster not bootstrapped yet."
}

# ============================================================================
# Terraform State Information
# ============================================================================

output "terraform_workspace" {
  description = "Current Terraform workspace"
  value       = terraform.workspace
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}

# Notes:
# - Sensitive outputs are hidden by default (use terraform output -json to see all)
# - Kubeconfig and talosconfig files are saved locally in terraform/ directory
# - Export KUBECONFIG and TALOSCONFIG environment variables to use them
# - For production: Store kubeconfig securely (e.g., encrypted with SOPS)
# - GPU verification requires NVIDIA GPU Operator to be installed first
# - Storage configuration assumes NFS CSI driver will be installed
# - Network information matches the static IP configuration

# ============================================================================
# Traditional VMs Outputs (for_each pattern)
# ============================================================================
#
# Usage:
#   terraform output traditional_vms
#   terraform output -json traditional_vms | jq '.["ubuntu-dev"]'
#
# ============================================================================

output "traditional_vms" {
  description = "All deployed traditional VMs with their details"
  value = {
    for name, vm in module.traditional_vm : name => {
      vm_id          = vm.vm_id
      vm_name        = vm.vm_name
      ipv4_addresses = vm.ipv4_addresses
      os_type        = local.traditional_vms[name].os_type
      description    = local.traditional_vms[name].description
    }
  }
}

output "traditional_vm_count" {
  description = "Count of deployed traditional VMs by OS type"
  value       = local.vm_counts
}

output "traditional_vm_ips" {
  description = "Quick lookup of VM IPs (name => first IP)"
  value = {
    for name, vm in module.traditional_vm : name => (
      length(vm.ipv4_addresses) > 0 && length(vm.ipv4_addresses[0]) > 0
      ? vm.ipv4_addresses[0][0]
      : "pending"
    )
  }
}

# ============================================================================
# Summary Output
# ============================================================================

output "deployed_vms_summary" {
  description = "Summary of all deployed VMs (Talos + Traditional)"
  value = {
    # Talos Kubernetes node (always deployed)
    talos = {
      deployed    = true
      vm_id       = proxmox_virtual_environment_vm.talos_node.vm_id
      vm_name     = proxmox_virtual_environment_vm.talos_node.name
      ip          = var.node_ip
      gpu_enabled = var.enable_gpu_passthrough
    }

    # Traditional VMs (from for_each)
    traditional = {
      total_count = local.vm_counts.total
      vms = {
        for name, vm in module.traditional_vm : name => {
          vm_id   = vm.vm_id
          vm_name = vm.vm_name
          os_type = local.traditional_vms[name].os_type
        }
      }
    }
  }
}

# ============================================================================
# SSH Connection Helpers
# ============================================================================

output "ssh_commands" {
  description = "SSH commands to connect to each VM"
  sensitive   = true
  value = {
    for name, vm in module.traditional_vm : name => (
      local.traditional_vms[name].os_type != "windows"
      ? "ssh ${local.secrets.cloud_init_user}@${length(vm.ipv4_addresses) > 0 && length(vm.ipv4_addresses[0]) > 0 ? vm.ipv4_addresses[0][0] : "PENDING"}"
      : "# Windows: Use RDP to ${length(vm.ipv4_addresses) > 0 && length(vm.ipv4_addresses[0]) > 0 ? vm.ipv4_addresses[0][0] : "PENDING"}"
    )
  }
}
