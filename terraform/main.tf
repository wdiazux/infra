# Main Terraform Configuration for Talos Linux on Proxmox
#
# This file creates a single-node Talos Kubernetes cluster from a Packer template
# with optional NVIDIA GPU passthrough and external NFS storage

# ============================================================================
# Data Sources
# ============================================================================

# Look up the Talos template created by Packer
data "proxmox_virtual_environment_vms" "talos_template" {
  node_name = var.proxmox_node

  filter {
    name   = "name"
    values = [var.talos_template_name]
  }

  filter {
    name   = "template"
    values = [true]
  }
}

# Load SOPS-encrypted Proxmox credentials (optional)
# Uncomment if using SOPS for credential management
# data "sops_file" "proxmox_secrets" {
#   source_file = "${path.module}/../secrets/proxmox-creds.enc.yaml"
# }

# ============================================================================
# Talos Machine Secrets
# ============================================================================

# Generate Talos secrets (cluster CA, bootstrap token, etc.)
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# ============================================================================
# Talos Machine Configuration
# ============================================================================

# Generate machine configuration for single-node cluster (control plane + worker)
data "talos_machine_configuration" "node" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"  # Single node is both controlplane and worker
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  talos_version    = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Network configuration
  docs_enabled = false
  examples_enabled = false

  # Disable default CNI (we'll install Cilium)
  config_patches = concat([
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"  # Disable default Flannel
          }
          proxy = {
            disabled = true  # Disable kube-proxy (Cilium replaces it)
          }
        }
        discovery = {
          enabled = true
          registries = {
            kubernetes = {
              disabled = false
            }
          }
        }
      }
      machine = {
        network = {
          hostname = var.node_name
          interfaces = [
            {
              interface = "eth0"
              addresses = ["${var.node_ip}/${var.node_netmask}"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.node_gateway
                }
              ]
            }
          ]
          nameservers = var.dns_servers
        }
        time = {
          servers = var.ntp_servers
        }
        install = {
          disk = var.install_disk
          image = "factory.talos.dev/installer/${local.talos_installer_image}"
          bootloader = true
          wipe = false
        }
        kubelet = {
          nodeIP = {
            validSubnets = ["${var.node_ip}/${var.node_netmask}"]
          }
        }
      }
    }),
    # Enable KubePrism (local caching proxy for Kubernetes API)
    yamlencode({
      machine = {
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
      }
    }),
    # NVIDIA GPU sysctls (if GPU passthrough is enabled)
    var.enable_gpu_passthrough ? yamlencode({
      machine = {
        sysctls = {
          "net.core.bpf_jit_harden" = "0"
        }
      }
    }) : "",
    # Allow scheduling on control plane (required for single-node)
    var.allow_scheduling_on_control_plane ? yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }) : "",
  ], var.talos_config_patches)
}

# ============================================================================
# Proxmox Virtual Machine
# ============================================================================

# Create Talos VM by cloning the template
resource "proxmox_virtual_environment_vm" "talos_node" {
  name        = var.node_name
  description = var.description
  tags        = var.tags

  node_name = var.proxmox_node
  vm_id     = var.node_vm_id

  # Clone from Packer template
  clone {
    vm_id = data.proxmox_virtual_environment_vms.talos_template.vms[0].vm_id
    full  = true  # Full clone (not linked)
  }

  # CPU configuration
  cpu {
    type    = var.node_cpu_type  # Must be 'host'
    cores   = var.node_cpu_cores
    sockets = var.node_cpu_sockets
  }

  # Memory configuration
  memory {
    dedicated = var.node_memory
  }

  # Disk configuration
  disk {
    datastore_id = var.node_disk_storage
    size         = var.node_disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  # Network configuration
  network_device {
    bridge  = var.network_bridge
    model   = var.network_model
    vlan_id = var.network_vlan > 0 ? var.network_vlan : null
  }

  # QEMU Guest Agent
  agent {
    enabled = var.enable_qemu_agent
    trim    = true
    type    = "virtio"
  }

  # GPU Passthrough (if enabled)
  dynamic "hostpci" {
    for_each = var.enable_gpu_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      id      = "0000:${var.gpu_pci_id}.0"  # Full PCI format required: 0000:XX:YY.0
      pcie    = var.gpu_pcie
      rombar  = var.gpu_rombar  # Boolean: true enables ROM bar, false disables
      mapping = null
    }
  }

  # BIOS/EFI configuration
  bios = "ovmf"

  efi_disk {
    datastore_id      = var.node_disk_storage
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # Boot order
  boot_order = ["scsi0"]

  # Machine type
  machine = "q35"

  # On boot behavior
  on_boot = true

  # SCSI hardware
  scsi_hardware = "virtio-scsi-single"

  # Startup/shutdown order
  startup {
    order      = 1
    up_delay   = 30
    down_delay = 30
  }

  # Lifecycle
  lifecycle {
    precondition {
      condition     = length(data.proxmox_virtual_environment_vms.talos_template.vms) > 0
      error_message = "Talos template '${var.talos_template_name}' not found on Proxmox node '${var.proxmox_node}'. Build the template with Packer first."
    }

    ignore_changes = [
      # Ignore changes to template-derived attributes
      clone,
    ]
  }

  # Depends on template existence
  depends_on = [
    data.proxmox_virtual_environment_vms.talos_template
  ]
}

# ============================================================================
# Talos Configuration Application
# ============================================================================

# Apply Talos machine configuration to the node
resource "talos_machine_configuration_apply" "node" {
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.node.machine_configuration
  node                        = var.node_ip
  endpoint                    = var.node_ip

  # Apply configuration after VM is created
  depends_on = [
    proxmox_virtual_environment_vm.talos_node
  ]

  # Wait for API to be available
  timeouts {
    create = "10m"
    update = "10m"
  }
}

# ============================================================================
# Cluster Bootstrap
# ============================================================================

# Bootstrap the Kubernetes cluster (only done once)
resource "talos_machine_bootstrap" "cluster" {
  count = var.auto_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.node_ip
  endpoint             = var.node_ip

  depends_on = [
    talos_machine_configuration_apply.node
  ]

  timeouts {
    create = "15m"
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Cluster endpoint (use node IP if not specified)
  cluster_endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.node_ip}:6443"

  # Talos installer image (matches schematic from Packer)
  talos_installer_image = "${var.talos_version}/metal-amd64"

  # Generate kubeconfig path
  kubeconfig_path = "${path.module}/kubeconfig"

  # Generate talosconfig path
  talosconfig_path = "${path.module}/talosconfig"
}

# ============================================================================
# Kubeconfig and Talosconfig
# ============================================================================

# Retrieve kubeconfig after bootstrap
data "talos_cluster_kubeconfig" "cluster" {
  count = var.generate_kubeconfig && var.auto_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.node_ip
  endpoint             = var.node_ip

  depends_on = [
    talos_machine_bootstrap.cluster
  ]

  timeouts {
    read = "5m"
  }
}

# Save kubeconfig to file
resource "local_file" "kubeconfig" {
  count = var.generate_kubeconfig && var.auto_bootstrap ? 1 : 0

  content         = data.talos_cluster_kubeconfig.cluster[0].kubeconfig_raw
  filename        = local.kubeconfig_path
  file_permission = "0600"
}

# Save talosconfig to file
resource "local_file" "talosconfig" {
  content = talos_machine_secrets.cluster.talos_config
  filename        = local.talosconfig_path
  file_permission = "0600"
}

# ============================================================================
# Wait for Kubernetes API
# ============================================================================

# Wait for Kubernetes API to be ready
resource "null_resource" "wait_for_kubernetes" {
  count = var.auto_bootstrap ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Kubernetes API to be ready..."
      timeout 300 bash -c 'until kubectl --kubeconfig=${local.kubeconfig_path} get nodes &>/dev/null; do echo "Waiting..."; sleep 5; done'
      echo "Kubernetes API is ready!"
    EOT
  }

  depends_on = [
    local_file.kubeconfig
  ]
}

# ============================================================================
# Post-Bootstrap Configuration
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

# Notes:
# - This configuration creates a SINGLE-NODE cluster (control plane + worker)
# - GPU passthrough requires IOMMU enabled in BIOS and GRUB
# - Default CNI (Flannel) is disabled - install Cilium separately
# - Kube-proxy is disabled - Cilium replaces it
# - KubePrism is enabled for local API caching
# - Control plane taint is removed to allow pod scheduling
# - Kubeconfig and talosconfig are saved to terraform/ directory
# - Persistent storage should use NFS CSI driver (external NAS)
# - Ephemeral storage uses local-path-provisioner
# - NVIDIA GPU Operator should be installed after Cilium deployment
# - For production: Use remote state backend and separate environments
