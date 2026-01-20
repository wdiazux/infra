# Talos Machine Configuration
#
# This file generates the Talos machine configuration for the single-node
# cluster including network, storage, and GPU settings.

# ============================================================================
# Machine Configuration
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
    # Base cluster configuration
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none" # Disable default Flannel
          }
        }
        proxy = {
          disabled = true # Disable kube-proxy (Cilium replaces it)
        }
        discovery = {
          enabled = true
          registries = {
            kubernetes = {
              disabled = false
            }
          }
        }
        # PodGC controller configuration
        # Automatically cleans up Failed/Succeeded pods when threshold exceeded
        # Default 12500 is too high for single-node homelab
        controllerManager = {
          extraArgs = {
            terminated-pod-gc-threshold = "50"
          }
        }
      }
      machine = {
        network = {
          # NOTE: hostname is intentionally NOT set here
          # Talos will derive hostname from the VM name or DHCP
          # Setting static hostname can conflict with maintenance mode config
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
        #    - iscsi_tcp: iSCSI for persistent volumes
        #    - configfs: iSCSI target configuration
        #
        # 3. KUBELET EXTRA MOUNTS (configured below in this machine config):
        #    - /var/lib/longhorn with rshared propagation
        #    - Allows volume mounts to propagate between host and containers
        #
        # Without ALL three components, Longhorn will fail to create volumes.
        # ═══════════════════════════════════════════════════════════════

        # Kernel modules for Longhorn and NVIDIA GPU
        # NOTE: iscsi_generic doesn't exist in Talos kernel - removed
        # iscsi_tcp is sufficient for Longhorn iSCSI functionality
        # NVIDIA GPU: All four modules required per official Talos docs
        # https://docs.siderolabs.com/talos/v1.9/configure-your-talos-cluster/hardware-and-drivers/nvidia-gpu-proprietary
        kernel = {
          modules = [
            { name = "nbd" },
            { name = "iscsi_tcp" },
            { name = "configfs" },
            { name = "nvidia" },
            { name = "nvidia_uvm" },
            { name = "nvidia_drm" },
            { name = "nvidia_modeset" }
          ]
        }
        kubelet = {
          nodeIP = {
            validSubnets = ["${var.node_ip}/${var.node_netmask}"]
          }
          # Graceful node shutdown configuration
          # Ensures pods terminate cleanly during reboot/shutdown
          # - 60s total grace period
          # - 30s for regular pods, 30s for critical pods (Longhorn, Cilium, etc.)
          extraConfig = {
            shutdownGracePeriod             = "60s"
            shutdownGracePeriodCriticalPods = "30s"
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
    # NOTE: These sysctls work together with the hostpci configuration
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

    # NVIDIA Container Runtime configuration
    # Sets nvidia as the default runtime for containerd
    # Required per: https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/hardware-and-drivers/nvidia-gpu-proprietary
    var.enable_gpu_passthrough ? yamlencode({
      machine = {
        files = [
          {
            content = <<-EOF
              [plugins]
                [plugins."io.containerd.cri.v1.runtime"]
                  [plugins."io.containerd.cri.v1.runtime".containerd]
                    default_runtime_name = "nvidia"
              EOF
            path    = "/etc/cri/conf.d/20-customization.part"
            op      = "create"
          }
        ]
      }
    }) : "",

    # ═══════════════════════════════════════════════════════════════
    # CILIUM CNI INLINE MANIFEST
    # ═══════════════════════════════════════════════════════════════
    # Cilium is embedded directly in the Talos machine config to solve
    # the chicken-and-egg problem: FluxCD needs CNI to work, but would
    # normally install CNI. By embedding Cilium here, it's applied during
    # Talos bootstrap, making nodes Ready immediately.
    #
    # FluxCD can later take over management via HelmRelease.
    # Reference: https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/
    # ═══════════════════════════════════════════════════════════════
    yamlencode({
      cluster = {
        inlineManifests = [
          {
            name     = "cilium"
            contents = local.cilium_inline_manifest
          }
        ]
      }
    }),

    # ═══════════════════════════════════════════════════════════════
    # PANGOLIN/NEWT WIREGUARD TUNNEL
    # ═══════════════════════════════════════════════════════════════
    # Newt is a WireGuard tunnel client that connects to Pangolin server
    # for secure remote access. Configured via ExtensionServiceConfig.
    # Requires: siderolabs/newt extension in Talos image schematic
    # ═══════════════════════════════════════════════════════════════
    var.enable_pangolin ? yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "newt"
      environment = [
        "PANGOLIN_ENDPOINT=${data.sops_file.pangolin_secrets[0].data["pangolin_url"]}",
        "NEWT_ID=${data.sops_file.pangolin_secrets[0].data["pangolin_user"]}",
        "NEWT_SECRET=${data.sops_file.pangolin_secrets[0].data["pangolin_token"]}"
      ]
    }) : "",
  ], var.talos_config_patches)
}
