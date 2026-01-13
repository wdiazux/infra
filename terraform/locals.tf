# Shared Local Variables
#
# This file contains computed local values used across multiple Terraform files.

locals {
  # ============================================================================
  # Talos Configuration
  # ============================================================================

  # Cluster endpoint (use node IP if not specified)
  cluster_endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.node_ip}:6443"

  # Talos installer image
  # Official Factory format: SCHEMATIC_ID:VERSION or just VERSION for default
  # Example: "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.12.1"
  # See: https://www.talos.dev/v1.12/talos-guides/install/boot-assets/
  talos_installer_image = var.talos_schematic_id != "" ? "${var.talos_schematic_id}:${var.talos_version}" : "${var.talos_version}"

  # Use DHCP IP for initial config apply, then static IP for subsequent operations
  talos_initial_ip = trimspace(data.local_file.talos_dhcp_ip.content)

  # ============================================================================
  # File Paths
  # ============================================================================

  # Generate kubeconfig path
  kubeconfig_path = "${path.module}/kubeconfig"

  # Generate talosconfig path
  talosconfig_path = "${path.module}/talosconfig"

  # ============================================================================
  # Output Strings
  # ============================================================================

  # Access instructions (for output)
  access_instructions_bootstrapped = <<-EOT
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

  # GPU verification instructions (for output)
  gpu_verification_instructions = <<-EOT
    # Create a test pod with GPU access:
    kubectl run gpu-test --image=nvidia/cuda:12.0-base --restart=Never --rm -it -- nvidia-smi

    # Or deploy NVIDIA device plugin and check:
    kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
  EOT

  # Useful commands (for output)
  useful_commands_bootstrapped = <<-EOT
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

  # Storage installation notes (for output)
  storage_installation_notes = <<-EOT
    CRITICAL: Longhorn requires system extensions in Talos image:
    - siderolabs/iscsi-tools (REQUIRED)
    - siderolabs/util-linux-tools (REQUIRED)
    Generate schematic at https://factory.talos.dev/
    See packer/talos/README.md for instructions
  EOT
}
