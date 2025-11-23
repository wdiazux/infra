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
    cpu_cores = var.node_cpu_cores
    memory_mb = var.node_memory
    disk_gb   = var.node_disk_size
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
  value = var.auto_bootstrap ? <<-EOT
    Talos Kubernetes Cluster Deployed Successfully!

    Cluster Information:
    - Name: ${var.cluster_name}
    - Endpoint: ${local.cluster_endpoint}
    - Node IP: ${var.node_ip}

    Access the cluster:

    1. Export kubeconfig:
       export KUBECONFIG=${local.kubeconfig_path}

    2. Verify cluster:
       kubectl get nodes
       kubectl get pods -A

    3. Use talosctl (for Talos operations):
       export TALOSCONFIG=${local.talosconfig_path}
       talosctl --nodes ${var.node_ip} version
       talosctl --nodes ${var.node_ip} dashboard

    Next steps:
    - Install Cilium CNI: helm install cilium cilium/cilium --namespace kube-system -f ../kubernetes/cilium/cilium-values.yaml
    - Install Longhorn Storage: helm install longhorn longhorn/longhorn --namespace longhorn-system -f ../kubernetes/longhorn/longhorn-values.yaml
    - Install NVIDIA GPU Operator (if GPU enabled): helm install gpu-operator nvidia/gpu-operator --namespace gpu-operator
    - Install FluxCD: flux bootstrap github ...

    Documentation:
    - Talos: https://www.talos.dev/
    - Cilium: https://docs.cilium.io/
    - NVIDIA GPU Operator: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/

  EOT
  : "Cluster not bootstrapped yet. Set auto_bootstrap=true to bootstrap automatically."
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
  value       = var.auto_bootstrap ? data.talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.ca_certificate : "Not available"
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
  value = var.enable_gpu_passthrough ? <<-EOT
    # Create a test pod with GPU access:
    kubectl run gpu-test --image=nvidia/cuda:12.0-base --restart=Never --rm -it -- nvidia-smi

    # Or deploy NVIDIA device plugin and check:
    kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
  EOT
  : "GPU passthrough not enabled"
}

# ============================================================================
# Storage Information
# ============================================================================

output "storage_configuration" {
  description = "Storage configuration summary"
  value = {
    local_disk = "${var.node_disk_size}GB"
    primary_storage = "Longhorn v1.7.x (install via Helm - see kubernetes/longhorn/)"
    backup_target = var.nfs_server != "" ? "NFS backup to ${var.nfs_server}:${var.nfs_path}" : "Not configured (optional)"
    storage_classes = [
      "longhorn (default, 1-replica for single node, expandable to 3-replica for HA)",
      "longhorn-retain (persistent data survives PVC deletion)",
      "longhorn-fast (performance optimized, SSD/NVMe selector)",
      "longhorn-backup (automated snapshots)",
      "longhorn-xfs (XFS filesystem support)"
    ]
    installation_notes = <<-EOT
      CRITICAL: Longhorn requires system extensions in Talos image:
      - siderolabs/iscsi-tools (REQUIRED)
      - siderolabs/util-linux-tools (REQUIRED)
      Generate schematic at https://factory.talos.dev/
      See packer/talos/README.md for instructions
    EOT
  }
}

# ============================================================================
# Network Information
# ============================================================================

output "network_configuration" {
  description = "Network configuration summary"
  value = {
    ip_address = var.node_ip
    gateway    = var.node_gateway
    netmask    = var.node_netmask
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
  value = var.auto_bootstrap ? <<-EOT
    Talos Commands:
    - Get node status:     talosctl --nodes ${var.node_ip} version
    - Dashboard:           talosctl --nodes ${var.node_ip} dashboard
    - Logs:                talosctl --nodes ${var.node_ip} logs
    - Service status:      talosctl --nodes ${var.node_ip} services
    - Upgrade Talos:       talosctl --nodes ${var.node_ip} upgrade --image factory.talos.dev/...
    - Upgrade Kubernetes:  talosctl --nodes ${var.node_ip} upgrade-k8s --to ${var.kubernetes_version}

    Kubernetes Commands:
    - Get nodes:           kubectl get nodes -o wide
    - Get all pods:        kubectl get pods -A
    - Get system pods:     kubectl get pods -n kube-system
    - Describe node:       kubectl describe node ${var.node_name}
    - Check GPU:           kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
    - Port forward:        kubectl port-forward -n namespace pod/name 8080:80

    Troubleshooting:
    - Talos health:        talosctl --nodes ${var.node_ip} health
    - Talos containers:    talosctl --nodes ${var.node_ip} containers
    - Kubernetes events:   kubectl get events -A --sort-by='.lastTimestamp'
    - Node resources:      kubectl top node ${var.node_name}

  EOT
  : "Cluster not bootstrapped yet."
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
# Traditional VMs Outputs
# ============================================================================

# Ubuntu VM Outputs
# ----------------------------------------------------------------------------

output "ubuntu_vm_id" {
  description = "Ubuntu VM ID"
  value       = var.deploy_ubuntu_vm ? module.ubuntu_vm[0].vm_id : null
}

output "ubuntu_vm_name" {
  description = "Ubuntu VM name"
  value       = var.deploy_ubuntu_vm ? module.ubuntu_vm[0].vm_name : null
}

output "ubuntu_ip_addresses" {
  description = "Ubuntu VM IP addresses (requires QEMU agent)"
  value       = var.deploy_ubuntu_vm ? module.ubuntu_vm[0].ipv4_addresses : null
}

# Debian VM Outputs
# ----------------------------------------------------------------------------

output "debian_vm_id" {
  description = "Debian VM ID"
  value       = var.deploy_debian_vm ? module.debian_vm[0].vm_id : null
}

output "debian_vm_name" {
  description = "Debian VM name"
  value       = var.deploy_debian_vm ? module.debian_vm[0].vm_name : null
}

output "debian_ip_addresses" {
  description = "Debian VM IP addresses (requires QEMU agent)"
  value       = var.deploy_debian_vm ? module.debian_vm[0].ipv4_addresses : null
}

# Arch Linux VM Outputs
# ----------------------------------------------------------------------------

output "arch_vm_id" {
  description = "Arch Linux VM ID"
  value       = var.deploy_arch_vm ? module.arch_vm[0].vm_id : null
}

output "arch_vm_name" {
  description = "Arch Linux VM name"
  value       = var.deploy_arch_vm ? module.arch_vm[0].vm_name : null
}

output "arch_ip_addresses" {
  description = "Arch Linux VM IP addresses (requires QEMU agent)"
  value       = var.deploy_arch_vm ? module.arch_vm[0].ipv4_addresses : null
}

# NixOS VM Outputs
# ----------------------------------------------------------------------------

output "nixos_vm_id" {
  description = "NixOS VM ID"
  value       = var.deploy_nixos_vm ? module.nixos_vm[0].vm_id : null
}

output "nixos_vm_name" {
  description = "NixOS VM name"
  value       = var.deploy_nixos_vm ? module.nixos_vm[0].vm_name : null
}

output "nixos_ip_addresses" {
  description = "NixOS VM IP addresses (requires QEMU agent)"
  value       = var.deploy_nixos_vm ? module.nixos_vm[0].ipv4_addresses : null
}

# Windows Server VM Outputs
# ----------------------------------------------------------------------------

output "windows_vm_id" {
  description = "Windows Server VM ID"
  value       = var.deploy_windows_vm ? module.windows_vm[0].vm_id : null
}

output "windows_vm_name" {
  description = "Windows Server VM name"
  value       = var.deploy_windows_vm ? module.windows_vm[0].vm_name : null
}

output "windows_ip_addresses" {
  description = "Windows Server VM IP addresses (requires QEMU agent)"
  value       = var.deploy_windows_vm ? module.windows_vm[0].ipv4_addresses : null
}

# Summary Output
# ----------------------------------------------------------------------------

output "deployed_vms_summary" {
  description = "Summary of all deployed VMs"
  value = {
    talos = {
      deployed    = true
      vm_id      = proxmox_virtual_environment_vm.talos_node.vm_id
      vm_name    = proxmox_virtual_environment_vm.talos_node.name
      ip         = var.node_ip
      gpu_enabled = var.enable_gpu_passthrough
    }
    ubuntu = var.deploy_ubuntu_vm ? {
      deployed = true
      vm_id   = module.ubuntu_vm[0].vm_id
      vm_name = module.ubuntu_vm[0].vm_name
    } : { deployed = false }
    debian = var.deploy_debian_vm ? {
      deployed = true
      vm_id   = module.debian_vm[0].vm_id
      vm_name = module.debian_vm[0].vm_name
    } : { deployed = false }
    arch = var.deploy_arch_vm ? {
      deployed = true
      vm_id   = module.arch_vm[0].vm_id
      vm_name = module.arch_vm[0].vm_name
    } : { deployed = false }
    nixos = var.deploy_nixos_vm ? {
      deployed = true
      vm_id   = module.nixos_vm[0].vm_id
      vm_name = module.nixos_vm[0].vm_name
    } : { deployed = false }
    windows = var.deploy_windows_vm ? {
      deployed = true
      vm_id   = module.windows_vm[0].vm_id
      vm_name = module.windows_vm[0].vm_name
    } : { deployed = false }
  }
}
