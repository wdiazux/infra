# Local Variables for Talos Cluster
#
# Computed values used across multiple files

locals {
  # Cluster endpoint
  cluster_endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.node_ip}:6443"

  # Talos installer image (Factory format: SCHEMATIC_ID:VERSION)
  talos_installer_image = "${talos_image_factory_schematic.this.id}:${var.talos_version}"

  # DHCP IP for initial config apply
  talos_initial_ip = trimspace(data.local_file.talos_dhcp_ip.content)

  # File paths
  kubeconfig_path  = "${path.module}/kubeconfig"
  talosconfig_path = "${path.module}/talosconfig"

  # Output strings
  access_instructions = <<-EOT
    Talos Kubernetes Cluster Deployed!

    Cluster: ${var.cluster_name}
    Endpoint: ${local.cluster_endpoint}
    Node IP: ${var.node_ip}

    Access:
      export KUBECONFIG=${local.kubeconfig_path}
      export TALOSCONFIG=${local.talosconfig_path}
      kubectl get nodes
      talosctl dashboard
  EOT

  useful_commands = <<-EOT
    Talos:
      talosctl --nodes ${var.node_ip} dashboard
      talosctl --nodes ${var.node_ip} services
      talosctl --nodes ${var.node_ip} health

    Kubernetes:
      kubectl get nodes -o wide
      kubectl get pods -A
  EOT
}
