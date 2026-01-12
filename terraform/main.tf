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

# SOPS-encrypted credentials are loaded in sops.tf
# Access via: local.secrets.proxmox_url, local.secrets.ssh_public_key, etc.

# ============================================================================
# Talos Machine Secrets
# ============================================================================

# Generate Talos secrets (cluster CA, bootstrap token, etc.)
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# Generate client configuration for talosctl
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [var.node_ip]
  nodes                = [var.node_ip]
}

# ============================================================================
# Talos Machine Configuration
# ============================================================================

# Generate machine configuration for single-node cluster (control plane + worker)
data "talos_machine_configuration" "node" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane" # Single node is both controlplane and worker
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Disable default CNI (we'll install Cilium)
  config_patches = concat([
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none" # Disable default Flannel
          }
          proxy = {
            disabled = true # Disable kube-proxy (Cilium replaces it)
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
          servers  = var.ntp_servers
          timezone = "America/El_Salvador"
        }
        install = {
          disk       = var.install_disk
          image      = "factory.talos.dev/installer/${local.talos_installer_image}"
          bootloader = true
          wipe       = false
        }

        # ═══════════════════════════════════════════════════════════════
        # LONGHORN STORAGE REQUIREMENTS
        # ═══════════════════════════════════════════════════════════════
        # Longhorn is the primary storage manager for this infrastructure.
        # It requires THREE components configured across different layers:
        #
        # 1. SYSTEM EXTENSIONS (configured in Packer template):
        #    - siderolabs/iscsi-tools (provides iscsid daemon and iscsiadm)
        #    - siderolabs/util-linux-tools (provides fstrim, nsenter, etc.)
        #    These MUST be included in the Talos Factory schematic when
        #    building the image with Packer. See packer/talos/README.md
        #
        # 2. KERNEL MODULES (configured below in this machine config):
        #    - nbd: Network Block Device for Longhorn volume access
        #    - iscsi_tcp, iscsi_generic: iSCSI for persistent volumes
        #    - configfs: iSCSI target configuration
        #
        # 3. KUBELET EXTRA MOUNTS (configured below in this machine config):
        #    - /var/lib/longhorn with rshared propagation
        #    - Allows volume mounts to propagate between host and containers
        #
        # Without ALL three components, Longhorn will fail to create volumes.
        # ═══════════════════════════════════════════════════════════════

        # Longhorn requirements: kernel modules
        kernel = {
          modules = [
            { name = "nbd" },
            { name = "iscsi_tcp" },
            { name = "iscsi_generic" },
            { name = "configfs" }
          ]
        }
        kubelet = {
          nodeIP = {
            validSubnets = ["${var.node_ip}/${var.node_netmask}"]
          }
          # Longhorn requirements: extra mount for volume attachment
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
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
    # NOTE: These sysctls work together with the hostpci configuration below
    # to enable GPU passthrough for AI/ML workloads
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
    full  = true # Full clone (not linked)
  }

  # CPU configuration
  cpu {
    type    = var.node_cpu_type # Must be 'host'
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
  # NOTE: This works together with the NVIDIA GPU sysctls in machine config above
  # to enable GPU passthrough for AI/ML workloads
  #
  # CRITICAL AUTHENTICATION REQUIREMENT:
  # The 'id' parameter is NOT compatible with API token authentication.
  # You MUST use ONE of the following methods:
  #
  # METHOD 1 (RECOMMENDED): Use 'mapping' parameter with resource mapping
  #   1. Create GPU resource mapping in Proxmox UI:
  #      Datacenter → Resource Mappings → Add → PCI Device
  #      Name: "gpu" (or your choice)
  #      Path: 0000:XX:YY.0 (your GPU PCI ID)
  #   2. Uncomment 'mapping = var.gpu_mapping' below
  #   3. Comment out or remove 'id' parameter
  #   4. Set gpu_mapping variable to "gpu" (or your mapping name)
  #
  # METHOD 2: Use password authentication instead of API token
  #   1. In versions.tf, uncomment password auth and comment out api_token
  #   2. Keep 'id' parameter as-is below
  #
  # See: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#hostpci
  #
  dynamic "hostpci" {
    for_each = var.enable_gpu_passthrough ? [1] : []
    content {
      device = "hostpci0"
      # Choose ONE of the following (see comments above):
      # id      = "0000:${var.gpu_pci_id}.0"  # METHOD 2: Requires password auth
      mapping = var.gpu_mapping # METHOD 1: Works with API token (RECOMMENDED)
      pcie    = var.gpu_pcie
      rombar  = var.gpu_rombar # Boolean: true enables ROM bar, false disables
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
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Cluster endpoint (use node IP if not specified)
  cluster_endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.node_ip}:6443"

  # Talos installer image
  # Official Factory format: SCHEMATIC_ID:VERSION or just VERSION for default
  # Example: "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.12.1"
  # See: https://www.talos.dev/v1.12/talos-guides/install/boot-assets/
  talos_installer_image = var.talos_schematic_id != "" ? "${var.talos_schematic_id}:${var.talos_version}" : "${var.talos_version}"

  # Generate kubeconfig path
  kubeconfig_path = "${path.module}/kubeconfig"

  # Generate talosconfig path
  talosconfig_path = "${path.module}/talosconfig"

  # Multiline output strings (defined here to avoid heredoc-in-ternary issues)
  access_instructions_bootstrapped = <<-EOT
    Talos Kubernetes Cluster Deployed Successfully!

    Cluster Information:
    - Name: ${var.cluster_name}
    - Endpoint: local.cluster_endpoint
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

  gpu_verification_instructions = <<-EOT
    # Create a test pod with GPU access:
    kubectl run gpu-test --image=nvidia/cuda:12.0-base --restart=Never --rm -it -- nvidia-smi

    # Or deploy NVIDIA device plugin and check:
    kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
  EOT

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

  storage_installation_notes = <<-EOT
    CRITICAL: Longhorn requires system extensions in Talos image:
    - siderolabs/iscsi-tools (REQUIRED)
    - siderolabs/util-linux-tools (REQUIRED)
    Generate schematic at https://factory.talos.dev/
    See packer/talos/README.md for instructions
  EOT
}

# ============================================================================
# Kubeconfig and Talosconfig
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

# Save talosconfig to file
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.cluster.talos_config
  filename        = local.talosconfig_path
  file_permission = "0600"
}

# ============================================================================
# Wait for Kubernetes API
# ============================================================================

# Wait for Kubernetes API to be ready
resource "null_resource" "wait_for_kubernetes" {
  count = var.auto_bootstrap && var.generate_kubeconfig ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Kubernetes API to be ready..."
      timeout 300 bash -c 'until kubectl --kubeconfig=${local.kubeconfig_path} get nodes &>/dev/null; do echo "Waiting..."; sleep 5; done'
      echo "Kubernetes API is ready!"
    EOT
  }

  depends_on = [
    local_file.kubeconfig,
    talos_machine_bootstrap.cluster
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

# Notes:
# - This configuration creates a SINGLE-NODE cluster (control plane + worker)
# - GPU passthrough requires IOMMU enabled in BIOS and GRUB
# - Default CNI (Flannel) is disabled - install Cilium separately
# - Kube-proxy is disabled - Cilium replaces it
# - KubePrism is enabled for local API caching
# - Control plane taint is removed to allow pod scheduling
# - Kubeconfig and talosconfig are saved to terraform/ directory
# - PRIMARY STORAGE: Longhorn (installed after cluster bootstrap)
#   - Requires system extensions: iscsi-tools, util-linux-tools (via Talos Factory)
#   - Kernel modules: nbd, iscsi_tcp, iscsi_generic, configfs (configured above)
#   - Kubelet extra mounts: /var/lib/longhorn with rshared propagation (configured above)
# - BACKUP STORAGE: External NAS via NFS for Longhorn backups
# - NVIDIA GPU Operator should be installed after Cilium and Longhorn
# - For production: Use remote state backend and separate environments
