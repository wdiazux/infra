# Cilium Inline Manifest for Talos Bootstrap
#
# This file generates a Cilium manifest to be embedded in the Talos machine
# configuration as an inlineManifest. This solves the chicken-and-egg problem:
# CNI must be available before FluxCD can sync, but FluxCD would install CNI.
#
# By embedding Cilium in the Talos config, it's applied during bootstrap,
# making nodes Ready immediately. FluxCD can then take over management.
#
# Reference: https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/

# ============================================================================
# Cilium Helm Template (rendered locally, not installed)
# ============================================================================

data "helm_template" "cilium" {
  provider = helm.template # Use alias provider (no cluster connectivity needed)

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  # Kubernetes version for template rendering (must match cluster version)
  kube_version = var.kubernetes_version

  # Talos-specific Cilium configuration
  # This is the PRIMARY source for Cilium config (embedded in Talos bootstrap)
  values = [yamlencode({
    # Cluster configuration
    cluster = {
      name = var.cluster_name
      id   = 0
    }

    # CRITICAL: KubePrism for API server access (Talos requirement)
    k8sServiceHost = "localhost"
    k8sServicePort = 7445

    # IPAM configuration
    ipam = {
      mode = "kubernetes"
      operator = {
        clusterPoolIPv4PodCIDRList = ["10.244.0.0/16"]
      }
    }

    # kube-proxy replacement
    kubeProxyReplacement = true
    socketLB = {
      enabled = true
    }
    nodePort = {
      enabled = true
    }

    # L2 Load Balancing
    l2announcements = {
      enabled = true
    }
    externalIPs = {
      enabled = true
    }

    # BGP disabled for homelab
    bgpControlPlane = {
      enabled = false
    }

    # CNI configuration
    cni = {
      install   = true
      exclusive = true
    }

    # Networking
    tunnelProtocol = "vxlan"
    ipv4 = {
      enabled = true
    }
    ipv6 = {
      enabled = false
    }

    # eBPF configuration - CRITICAL for Talos
    bpf = {
      masquerade        = true
      hostLegacyRouting = true # Required for DNS compatibility
      tproxy            = true
    }
    bpfMapDynamicSizeRatio = 0.0025

    # Cgroup configuration - CRITICAL for Talos
    cgroup = {
      autoMount = {
        enabled = false
      }
      hostRoot = "/sys/fs/cgroup"
    }

    # Security
    encryption = {
      enabled = false
    }
    policyEnforcementMode = "default"

    # Operator
    operator = {
      enabled  = true
      replicas = 1
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }

    # Agent resources (optimized for single-node homelab)
    # Official: ~573MB max observed at 50k pods, ~438MB average
    resources = {
      limits = {
        cpu    = "2000m"
        memory = "1Gi"
      }
      requests = {
        cpu    = "100m"
        memory = "512Mi"
      }
    }

    # Hubble observability
    hubble = {
      enabled = true
      relay = {
        enabled  = true
        replicas = 1
      }
      ui = {
        enabled  = true
        replicas = 1
        service = {
          type = "LoadBalancer"
          annotations = {
            "io.cilium/lb-ipam-ips" = var.hubble_ui_ip
          }
        }
      }
    }

    # Prometheus metrics
    prometheus = {
      enabled = true
      serviceMonitor = {
        enabled = false
      }
    }

    # Bandwidth manager (BBR disabled for Talos compatibility)
    bandwidthManager = {
      enabled = true
      bbr     = false
    }
    enableServiceTopology = true

    # Security context - CRITICAL for Talos (drop SYS_MODULE)
    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN",
          "KILL",
          "NET_ADMIN",
          "NET_RAW",
          "IPC_LOCK",
          "SYS_ADMIN",
          "SYS_RESOURCE",
          "DAC_OVERRIDE",
          "FOWNER",
          "SETGID",
          "SETUID"
        ]
        cleanCiliumState = [
          "NET_ADMIN",
          "SYS_ADMIN",
          "SYS_RESOURCE"
        ]
      }
    }

    # Tolerations (allow on all nodes including control-plane)
    tolerations = [
      { operator = "Exists" }
    ]

    # Update strategy
    updateStrategy = {
      type = "RollingUpdate"
      rollingUpdate = {
        maxUnavailable = 1
      }
    }

    # Ingress Controller
    ingressController = {
      enabled          = true
      default          = true
      loadbalancerMode = "shared"
      service = {
        type = "LoadBalancer"
        annotations = {
          "io.cilium/lb-ipam-ips" = var.ingress_controller_ip
        }
      }
    }
  })]
}

# ============================================================================
# Cilium L2 Configuration (also embedded in inline manifest)
# ============================================================================

locals {
  # Cilium L2 IP Pool manifest
  cilium_l2_ippool = <<-EOF
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: homelab-pool
  namespace: kube-system
spec:
  blocks:
    # Services and applications pool (10.10.2.11-150)
    # Traditional VMs use 10.10.2.151-254
    - start: "${var.important_services_ip_start}"
      stop: "${var.important_services_ip_stop}"
  serviceSelector:
    matchLabels: {}
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: homelab-l2-policy
  namespace: kube-system
spec:
  loadBalancerIPs: true
  externalIPs: true
  interfaces:
    - ^eth[0-9]+
    - ^ens[0-9]+
  nodeSelector:
    matchLabels: {}
EOF

  # Talos Node Reader RBAC - allows nodes to list all nodes
  # Fixes KubernetesPullController warning in Talos
  talos_node_reader_rbac = <<-EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: talos-node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: talos-nodes-can-read-nodes
subjects:
  - kind: Group
    name: system:nodes
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: talos-node-reader
  apiGroup: rbac.authorization.k8s.io
EOF

  # Combined Cilium manifest (Helm output + L2 config + RBAC)
  cilium_inline_manifest = join("\n", [
    data.helm_template.cilium.manifest,
    local.cilium_l2_ippool,
    local.talos_node_reader_rbac
  ])
}
