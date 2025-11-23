# Talos Linux on Proxmox: Comprehensive Research Report

**Report Date:** November 23, 2025
**Talos Version Focus:** v1.11.4
**Kubernetes Version:** v1.31.x
**Research Scope:** Production deployment with GPU passthrough, Cilium, and Longhorn

---

## Executive Summary

This report provides comprehensive research on deploying Talos Linux v1.11.4 with Kubernetes v1.31 on Proxmox VE. It covers single-node cluster deployment with expansion paths to 3-node HA, NVIDIA GPU passthrough, Cilium v1.18 CNI, Longhorn v1.7.x storage, Terraform automation, and production best practices.

**Total Sources Reviewed:** 15+ high-quality sources
**Source Types:** Official documentation, 2024-2025 blog posts, GitHub repositories, community guides

---

## Table of Contents

1. [Official Talos Documentation](#1-official-talos-documentation)
2. [Talos on Proxmox Deployment](#2-talos-on-proxmox-deployment)
3. [Talos Factory and System Extensions](#3-talos-factory-and-system-extensions)
4. [Single-Node to HA Cluster Expansion](#4-single-node-to-ha-cluster-expansion)
5. [NVIDIA GPU Passthrough Configuration](#5-nvidia-gpu-passthrough-configuration)
6. [Cilium v1.18 CNI Integration](#6-cilium-v118-cni-integration)
7. [Longhorn v1.7.x Storage Integration](#7-longhorn-v17x-storage-integration)
8. [Terraform Integration](#8-terraform-integration)
9. [Ansible Automation](#9-ansible-automation)
10. [Production Best Practices](#10-production-best-practices)
11. [Common Issues and Troubleshooting](#11-common-issues-and-troubleshooting)
12. [Key Configuration Snippets](#12-key-configuration-snippets)

---

## 1. Official Talos Documentation

### 1.1 Talos on Proxmox Official Guide

**URL:** https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/
**Last Updated:** v1.11 (Current)

**Summary:**
The official Talos documentation for Proxmox deployment provides authoritative guidance on VM configuration, CPU requirements, and installation procedures.

**Key Points:**
- **CPU Type Requirement:** As of Talos v1.0+ (requires x86-64-v2 microarchitecture), the default Proxmox CPU type `kvm64` will NOT work on Proxmox versions prior to 8.0
- **Recommended CPU Configuration:** Set processor type to "host" for best compatibility (trade-off: cannot use live VM migration)
- **Alternative for older Proxmox:** Add CPU flags manually in `/etc/pve/qemu-server/<vmid>.conf`:
  ```
  args: -cpu kvm64,+cx16,+lahf_lm,+popcnt,+sse3,+ssse3,+sse4.1,+sse4.2
  ```
- **Memory Hot Plugging:** Talos does NOT support memory hot plugging. Enabling it will cause insufficient memory errors during installation
- **Image Type:** Use "nocloud" images (not "metal" images) for Proxmox, as metal images lack cloud-init support

**Version-Specific Details:**
- Talos v1.0+: Requires x86-64-v2 CPU features
- Proxmox 8.0+: Default CPU type works fine
- Proxmox <8.0: Requires CPU type "host" or manual CPU flags

---

### 1.2 Talos Image Factory

**URL:** https://www.talos.dev/v1.10/learn-more/image-factory/
**Terraform Resource:** https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic

**Summary:**
The Talos Image Factory generates customized boot assets with system extensions. It's the official way to create images with qemu-guest-agent, NVIDIA drivers, iSCSI tools, etc.

**Key Points:**
- **Factory URL:** https://factory.talos.dev/
- **Schematic Creation:** POST YAML configurations to `https://factory.talos.dev/schematics`
- **Schematic IDs:** Content-based hashing (same config = same ID)
- **Extension Versioning:** Factory automatically matches extension versions to Talos release
- **Usage:** `factory.talos.dev/installer/{schematic_id}:v1.11.4`

**Example Schematic YAML:**
```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
      - siderolabs/nonfree-kmod-nvidia-production
      - siderolabs/nvidia-container-toolkit-production
```

**API Usage:**
```bash
# Create schematic
curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics

# Returns schematic ID (e.g., abc123def456...)
# Use in installer: factory.talos.dev/installer/abc123def456:v1.11.4
```

**Version-Specific Details:**
- Extension versions automatically match Talos version
- NVIDIA LTS: 535.247.01
- NVIDIA Production: 570.140.08
- NVIDIA Container Toolkit: 1.17.8 (as of late 2024)

**Sources:**
- [Image Factory Documentation](https://www.talos.dev/v1.10/learn-more/image-factory/)
- [GitHub: siderolabs/image-factory](https://github.com/siderolabs/image-factory)
- [Customizing Talos with Extensions](https://a-cup-of.coffee/blog/talos-ext/)
- [System Extensions Changelog](https://github.com/siderolabs/extensions/blob/main/CHANGELOG.md)

---

### 1.3 KubePrism Configuration

**URL:** https://www.talos.dev/v1.10/kubernetes-guides/configuration/kubeprism/
**Blog Post:** https://www.siderolabs.com/blog/kubeprism-improving-kubernetes-workload-availability-by-preventing-kubernetes-api-endpoint-outages/

**Summary:**
KubePrism is a built-in localhost load balancer for the Kubernetes API server, enabled by default on port 7445 since Talos 1.6.

**Key Points:**
- **Default Port:** 7445 (localhost only)
- **Enabled by Default:** Talos 1.6+
- **Purpose:** Intelligent API server load balancing for high availability
- **Automatic Configuration:** Talos reconfigures kubelet, kube-scheduler, kube-controller-manager to use KubePrism
- **Endpoint Selection:** Prefers localhost API server on control plane nodes, filters unhealthy endpoints

**CNI Integration:**
When deploying Cilium or other CNIs that need API access:
```bash
--set k8sServiceHost=localhost \
--set k8sServicePort=7445
```

**Benefits:**
- Minimized latency for control plane components
- Automatic failover to healthy endpoints
- No external load balancer needed for internal communication

**Version-Specific Details:**
- Talos 1.6+: Enabled by default on port 7445
- Earlier versions: Must be manually enabled

**Sources:**
- [KubePrism Documentation](https://www.talos.dev/v1.10/kubernetes-guides/configuration/kubeprism/)
- [Deploying Cilium CNI](https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/)

---

## 2. Talos on Proxmox Deployment

### 2.1 TechDufus Guide (June 2025)

**URL:** https://techdufus.com/tech/2025/06/30/building-a-talos-kubernetes-homelab-on-proxmox-with-terraform.html

**Summary:**
Recent comprehensive guide for building Talos Kubernetes homelab on Proxmox using Terraform. Covers end-to-end deployment with practical examples.

**Key Points:**
- **Latest Versions:** Uses current Talos and Kubernetes versions
- **Terraform Approach:** Automates VM provisioning and cluster bootstrapping
- **Homelab Focus:** Optimized for single-node or small cluster deployments
- **Real-World Examples:** Includes actual configurations and troubleshooting

**Version-Specific Details:**
- Published June 2025 (very recent)
- Covers Kubernetes v1.31.x deployment
- Uses modern Terraform providers

---

### 2.2 Suraj Remanan Guide (August 2025)

**URL:** https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/

**Summary:**
Complete automation workflow using Packer for image building and Terraform for deployment, with integrated Cilium and Longhorn setup.

**Key Points:**
- **Packer Integration:** Build custom Talos images with extensions
- **Terraform Deployment:** Automated cluster provisioning
- **Cilium + Longhorn:** Pre-configured networking and storage
- **System Extensions:** Includes iscsi-tools, qemu-guest-agent, NVIDIA extensions

**Configuration Highlights:**
- Uses Talos Factory for custom image generation
- Packer validates images before deployment
- Terraform handles full cluster lifecycle

**Version-Specific Details:**
- Published August 2025 (most recent guide found)
- Covers latest best practices for Cilium and Longhorn integration

---

### 2.3 Stonegarden OpenTofu Guide (August 2024)

**URL:** https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/

**Summary:**
Deployment guide using OpenTofu (Terraform fork) with specific provider versions and configurations.

**Key Points:**
- **OpenTofu Compatible:** Works with both Terraform and OpenTofu
- **Provider Versions:** Uses talos 0.5.0, proxmox 0.61.1 (older versions)
- **Image Handling:** Notes that Proxmox requires .img or .iso extensions
- **Compression:** bpg/proxmox provider supports compression, but not xz format

**Configuration Notes:**
```hcl
# Proxmox provider configuration
provider "proxmox" {
  endpoint = var.proxmox_url
  insecure = true
  api_token = var.proxmox_api_token
}

# Talos provider configuration
provider "talos" {}
```

**Version-Specific Details:**
- Published August 2024
- Provider versions shown are older; latest are talos ~> 0.9.0, proxmox ~> 0.86.0

---

### 2.4 Additional Deployment Resources

**Virtualization Howto (January 2024):**
https://www.virtualizationhowto.com/2024/01/proxmox-kubernetes-install-with-talos-linux/

**JCharisTech Guide (October 2025):**
https://blog.jcharistech.com/2025/10/24/how-to-setup-talos-linux-kubernetes-os-on-proxmox/

**Xoid.net Guide (July 2024):**
https://xoid.net/2024/07/27/talos-terraform-proxmox.html

**Secsys Guide:**
https://secsys.pages.dev/posts/talos/

**Key Takeaways from Multiple Sources:**
- Consistent recommendation: Use "host" CPU type for Talos v1.0+
- QEMU guest agent highly recommended for Proxmox integration
- Most guides use Terraform for automation
- Kubernetes v1.31 confirmed working on latest Talos releases

---

## 3. Talos Factory and System Extensions

### 3.1 System Extensions Overview

**GitHub Repository:** https://github.com/siderolabs/extensions
**Changelog:** https://github.com/siderolabs/extensions/blob/main/CHANGELOG.md

**Summary:**
Official repository of Talos Linux system extensions. Extensions are container images with specific structure that add functionality to Talos.

**Required Extensions for This Project:**

**1. qemu-guest-agent**
- **Package:** `siderolabs/qemu-guest-agent`
- **Purpose:** Proxmox VM management and status reporting
- **Benefits:** Proper shutdown, network info display, IP address detection
- **Required:** Yes, for Proxmox integration

**2. iscsi-tools**
- **Package:** `siderolabs/iscsi-tools`
- **Purpose:** Enables iscsid daemon and iscsiadm for iSCSI persistent volumes
- **Required:** Yes, for Longhorn storage
- **Components:** iscsid daemon, iscsiadm CLI tool

**3. util-linux-tools**
- **Package:** `siderolabs/util-linux-tools`
- **Purpose:** Linux utilities including fstrim for volume trimming
- **Required:** Yes, for Longhorn storage
- **Components:** fstrim, blkid, lsblk, etc.

**4. nonfree-kmod-nvidia-production**
- **Package:** `siderolabs/nonfree-kmod-nvidia-production`
- **Purpose:** NVIDIA proprietary kernel modules (production branch)
- **Required:** For GPU passthrough
- **Current Version:** 570.140.08 (as of late 2024)
- **Alternative:** `nonfree-kmod-nvidia-lts` for LTS branch (535.247.01)

**5. nvidia-container-toolkit-production**
- **Package:** `siderolabs/nvidia-container-toolkit-production`
- **Purpose:** NVIDIA container runtime for GPU workloads in Kubernetes
- **Required:** For GPU passthrough
- **Current Version:** 1.17.8
- **Alternative:** `nvidia-container-toolkit-lts` for LTS branch

**Important Notes:**
- Extension versions MUST match between nonfree-kmod-nvidia and nvidia-container-toolkit
- Image Factory automatically handles version matching
- Extensions are bound to specific Talos releases
- Update extensions when upgrading Talos versions

---

### 3.2 Creating Custom Images with Extensions

**Installation Guide (HackMD):**
https://hackmd.io/@QI-AN/Install-Longhorn-on-Talos-Kubernetes

**Summary:**
Step-by-step process for creating custom Talos images with extensions using Image Factory.

**Process:**

**Step 1: Create Schematic YAML**
```yaml
# longhorn-schematic.yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
      - siderolabs/qemu-guest-agent
```

**Step 2: POST to Image Factory**
```bash
curl -X POST --data-binary @longhorn-schematic.yaml https://factory.talos.dev/schematics
```

**Response Example:**
```json
{
  "id": "abc123def456..."
}
```

**Step 3: Use Schematic in Installation**
```bash
# Download installer
wget https://factory.talos.dev/installer/abc123def456:v1.11.4

# Or use directly in Proxmox VM configuration
```

**Step 4: Upgrade Existing Nodes**
```bash
talosctl upgrade \
  --preserve \
  --nodes 192.168.1.100 \
  --image factory.talos.dev/installer/abc123def456:v1.11.4
```

**Step 5: Verify Extensions**
```bash
talosctl get extensions --nodes 192.168.1.100
```

**Expected Output:**
```
NODE             NAMESPACE   TYPE              ID              VERSION
192.168.1.100    runtime     ExtensionStatus   iscsi-tools     v1.11.4
192.168.1.100    runtime     ExtensionStatus   qemu-guest-agent v1.11.4
192.168.1.100    runtime     ExtensionStatus   util-linux-tools v1.11.4
```

---

### 3.3 Terraform Resource for Schematics

**Terraform Registry:** https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic

**Summary:**
The siderolabs/talos provider includes a resource for managing Image Factory schematics in Terraform.

**Example Configuration:**
```hcl
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools",
          "siderolabs/nonfree-kmod-nvidia-production",
          "siderolabs/nvidia-container-toolkit-production"
        ]
      }
    }
  })
}

# Use schematic ID in machine configuration
resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ip

  # Use custom image with extensions
  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:v1.11.4"
        }
      }
    })
  ]
}
```

---

## 4. Single-Node to HA Cluster Expansion

### 4.1 Official Scaling Guide

**URL:** https://www.talos.dev/v1.11/talos-guides/howto/scaling-up/

**Summary:**
Official documentation for adding nodes to an existing Talos cluster, including expansion from single-node to HA.

**Key Points:**
- **Preserve Original Configs:** Must keep controlplane.yaml and worker.yaml from initial deployment
- **No Re-Bootstrap:** Only the first control plane node is bootstrapped; additional nodes join existing cluster
- **Same Procedure:** Adding nodes uses same process as initial cluster creation
- **HA Considerations:** Odd number of control plane nodes preferred (1, 3, 5)

**Process:**

**Step 1: Prepare New Node**
- Boot new VM with Talos ISO
- Obtain IP address
- Ensure network connectivity to existing cluster

**Step 2: Apply Configuration**
```bash
# For additional control plane nodes
talosctl apply-config \
  --insecure \
  --nodes 192.168.1.101 \
  --file controlplane.yaml

# For worker nodes
talosctl apply-config \
  --insecure \
  --nodes 192.168.1.102 \
  --file worker.yaml
```

**Note:** The `--insecure` flag is necessary because PKI has not yet been made available to the new node.

**Step 3: Verify Node Joined**
```bash
talosctl get members --nodes 192.168.1.100
kubectl get nodes
```

**Step 4: Update Load Balancer/VIP (for HA)**
```bash
# If using external load balancer, add new control plane nodes
# Or configure VIP for control plane endpoint
```

---

### 4.2 HA Considerations

**GitHub Discussion:** https://github.com/siderolabs/talos/discussions/6554

**Summary:**
Community discussion about upgrading single-node clusters with important considerations.

**Key Points:**
- **Even vs Odd Nodes:** Control planes with even number of nodes are LESS highly available than odd numbers
- **Latency Trade-off:** More nodes = higher latency when interacting with Kubernetes API
- **etcd Quorum:** 3-node cluster tolerates 1 failure; 5-node tolerates 2 failures
- **Recommended Sizes:**
  - Small/Homelab: 1 node (learning) or 3 nodes (HA)
  - Medium: 3 nodes
  - Large: 5 nodes
  - Avoid: 2, 4, or 6 nodes

**Expansion Best Practices:**
1. Start with 1 node for development/testing
2. Expand to 3 nodes for production HA
3. Only go to 5 nodes if you need to tolerate 2 simultaneous failures
4. Always use odd numbers for control plane
5. Set up load balancer or VIP before adding 2nd control plane node

---

### 4.3 Single-Node Configuration Specific

**Blog Post:** https://replicator.medium.com/talos-linux-single-node-on-hetzner-robot-servers-8ea8708c2f8f
**GitHub Gist:** https://gist.github.com/cyrenity/67469dce33cf4eb4483486637c06d7be

**Summary:**
Guides specifically focused on single-node Talos deployments with later expansion.

**Key Configuration for Single-Node:**

**Remove Control Plane Taint:**
```bash
# After cluster bootstrap, allow workloads on control plane
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**Machine Config Considerations:**
```yaml
# Single-node specific settings
cluster:
  allowSchedulingOnControlPlanes: true

machine:
  kubelet:
    extraArgs:
      # Allow pods on control plane
      register-with-taints: ""
```

**Storage Considerations:**
- **Longhorn:** Configure single-replica mode
- **etcd:** Single-node etcd (no HA)
- **Backups:** CRITICAL for single-node (no redundancy)

---

## 5. NVIDIA GPU Passthrough Configuration

### 5.1 Official NVIDIA GPU Guide

**URL (Proprietary Drivers):** https://www.talos.dev/v1.11/talos-guides/configuration/nvidia-gpu-proprietary/
**URL (OSS Drivers):** https://www.talos.dev/v1.8/talos-guides/configuration/nvidia-gpu/

**Summary:**
Official Talos documentation for enabling NVIDIA GPU support using either proprietary or open-source drivers.

**Key Points:**
- **EULA Requirement:** Enabling NVIDIA GPU support is bound by NVIDIA EULA
- **Driver Matching:** Extension versions must match between kernel modules and container toolkit
- **Version Compatibility:** Extensions are bound to specific Talos releases
- **Proprietary Recommended:** For RTX 4000, use proprietary drivers

**Required System Extensions:**
```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/nonfree-kmod-nvidia-production
      - siderolabs/nvidia-container-toolkit-production
```

**Machine Configuration Patch:**
```yaml
machine:
  kernel:
    modules:
      - name: nvidia
      - name: nvidia_uvm
      - name: nvidia_drm
      - name: nvidia_modeset
  sysctls:
    net.core.bpf_jit_harden: 1
```

**Verification:**
```bash
# Check loaded modules
talosctl -n <node-ip> get extensions

# Verify NVIDIA modules
talosctl -n <node-ip> read /proc/modules | grep nvidia
```

---

### 5.2 Duck's Blog: Proxmox to Talos GPU Passthrough (March 2025)

**URL:** https://blog.duckdefense.cc/kubernetes-gpu-passthrough/

**Summary:**
Comprehensive guide for passing NVIDIA GPU from Proxmox host, through TalosOS VM, to Kubernetes pods.

**Key Points:**
- **Complete Workflow:** Covers Proxmox host setup, Talos VM config, and Kubernetes integration
- **Real RTX Card:** Uses actual NVIDIA RTX card (similar to RTX 4000)
- **Production Ready:** Includes monitoring and troubleshooting

**Proxmox Host Configuration:**

**1. Enable IOMMU in BIOS**
```bash
# For AMD processors
# Add to /etc/default/grub:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"

# For Intel processors
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# Update grub
update-grub
reboot
```

**2. Blacklist NVIDIA Drivers on Host**
```bash
# /etc/modprobe.d/blacklist-nvidia.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_uvm
blacklist nvidia_modeset
```

**3. Bind GPU to VFIO**
```bash
# Find GPU PCI address
lspci | grep -i nvidia

# Add to /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:XXXX,10de:YYYY

# Update initramfs
update-initramfs -u
```

**Talos VM Configuration:**
```yaml
# In Proxmox VM settings
hostpci0: 01:00.0,pcie=1,x-vga=1
cpu: host
```

**Talos Machine Config:**
```yaml
machine:
  kernel:
    modules:
      - name: nvidia
      - name: nvidia_uvm
      - name: nvidia_drm
      - name: nvidia_modeset
  install:
    image: factory.talos.dev/installer/<schematic-id>:v1.11.4
```

**Kubernetes GPU Operator:**
```bash
# Install NVIDIA GPU Operator
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update

helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true
```

**Verification:**
```bash
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Should show:
# "nvidia.com/gpu": "1"
```

---

### 5.3 Additional GPU Resources

**GitHub: GPU Passthrough Scripts**
https://github.com/kubebn/talos-qemu-gpu-passthrough

**DEV Community Guide**
https://dev.to/bnovickovs/running-talos-linux-with-gpu-passthrough-on-qemu-1ec6

**RTX 4090 Example (Medium)**
https://rahulvinodsharma.medium.com/homelab-setting-up-4090-graphic-card-to-talos-linux-0e8d5129b0b2

**Key Takeaways:**
- RTX 4000 uses same process as RTX 4090/3090
- Proprietary drivers recommended for Ada Lovelace architecture
- GPU can only be assigned to ONE VM at a time
- Talos requires system extensions, cannot load modules from Kubernetes

---

## 6. Cilium v1.18 CNI Integration

### 6.1 Official Cilium Deployment Guide

**URL:** https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/
**Cilium Docs:** https://docs.cilium.io/

**Summary:**
Official Talos guide for deploying Cilium CNI with six different installation methods.

**Key Points:**
- **Version:** Cilium v1.18.0+ recommended
- **CNI Mode:** Set to "none" when generating Talos machine config
- **Disable Components:** Disable Flannel and kube-proxy (Cilium replaces them)
- **SYS_MODULE Capability:** Must be dropped (Talos doesn't allow loading kernel modules from K8s)
- **KubePrism Integration:** Use localhost:7445 for API server access

**Machine Configuration:**
```yaml
cluster:
  network:
    cni:
      name: none  # Disable built-in CNI
  proxy:
    disabled: true  # Disable kube-proxy (Cilium replaces it)
```

**Installation Method 1: Helm (Recommended)**

```bash
# Talos will appear to hang on phase 18/19 - this is EXPECTED
# "retrying error: node not ready" message will appear
# Install Cilium during this 10-minute window

helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --version 1.18.0 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445
```

**Critical Settings Explained:**
- `ipam.mode=kubernetes`: Use Kubernetes native IPAM
- `kubeProxyReplacement=true`: Replace kube-proxy with Cilium
- `securityContext.capabilities.ciliumAgent`: Drop SYS_MODULE (Talos requirement)
- `cgroup.autoMount.enabled=false`: Use Talos-provided cgroup mounts
- `k8sServiceHost/Port`: Point to KubePrism endpoint

**Installation Method 2: Inline Manifest**

```yaml
# In controlplane machine config only
cluster:
  inlineManifests:
    - name: cilium
      contents: |
        # Helm template output here
```

**Note:** Only add inline manifest to control plane nodes, and ensure ALL control plane nodes have identical configuration.

---

### 6.2 Cilium L2 Announcements for LoadBalancer

**URL:** https://docs.cilium.io/en/stable/network/l2-announcements/
**Lab Guide:** https://isovalent.com/labs/cilium-lb-ipam-l2-announcements/
**Talos-Specific:** https://blog.devgenius.io/servicelb-with-cilium-on-talos-linux-8a290d524cb7

**Summary:**
Cilium L2 Announcements enable LoadBalancer services on bare-metal/homelab without external load balancers.

**Key Points:**
- **Purpose:** Makes services visible on LAN via ARP/NDP responses
- **Use Case:** On-premises deployments without BGP routing
- **Requirements:** Cilium 1.14+, L2 announcements enabled

**Configuration:**

**1. Enable in Helm Values:**
```bash
helm install cilium cilium/cilium \
  --set l2announcements.enabled=true \
  --set externalIPs.enabled=true \
  --set kubeProxyReplacement=true \
  --set devices='{eth0}' \
  # ... other settings
```

**2. Create IP Pool:**
```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: blue-pool
spec:
  blocks:
    - cidr: "192.168.1.240/28"  # Adjust to your network
```

**3. Create L2 Announcement Policy:**
```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: default-policy
spec:
  serviceSelector:
    matchLabels: {}  # Match all services
  nodeSelector:
    matchLabels: {}  # All nodes can announce
  interfaces:
    - eth0
  externalIPs: true
  loadBalancerIPs: true
```

**4. Create LoadBalancer Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: test-lb
spec:
  type: LoadBalancer
  # loadBalancerClass: io.cilium/l2-announcer  # Optional, defaults to this
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: test
```

**Verification:**
```bash
kubectl get svc test-lb
# Should show EXTERNAL-IP from pool range

# Test from LAN
curl http://192.168.1.241
```

---

### 6.3 Cilium with Talos-Specific Configurations

**Medium: Having Fun with Cilium BGP on Talos**
https://medium.com/@rob.de.graaf88/having-fun-with-cilium-bgp-talos-and-unifi-cloud-gateway-ultra-111ffb39757e

**Summary:**
Advanced Cilium configurations including BGP for homelab setups.

**Key Points:**
- BGP alternative to L2 announcements
- Integration with UniFi networking
- Multi-protocol support

---

## 7. Longhorn v1.7.x Storage Integration

### 7.1 Official Longhorn Talos Support

**URL:** https://longhorn.io/docs/1.10.0/advanced-resources/os-distro-specific/talos-linux-support/
**SUSE Docs:** https://documentation.suse.com/cloudnative/storage/latest/en/installation-setup/os-distro/talos-linux.html

**Summary:**
Official Longhorn documentation for Talos Linux integration with required system extensions and configurations.

**Key Requirements:**

**1. System Extensions:**
```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
```

**2. Machine Configuration:**
```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
  kernel:
    modules:
      - name: nbd
      - name: iscsi_tcp
      - name: iscsi_generic
      - name: configfs
```

**3. Namespace Configuration:**
```yaml
# Talos has default PSP preventing privileged pods
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

---

### 7.2 Longhorn Installation on Talos

**Guide 1:** https://hackmd.io/@QI-AN/Install-Longhorn-on-Talos-Kubernetes
**Guide 2:** https://phin3has.blog/posts/talos-longhorn/
**Guide 3:** https://joshrnoll.com/installing-longhorn-on-talos-with-helm/
**Guide 4:** https://calebcoffie.com/part-3-adding-longhorn-for-persistent-storage-on-our-talos-powered-kubernetes-cluster/

**Summary:**
Multiple community guides for installing Longhorn on Talos with various approaches.

**Complete Installation Process:**

**Step 1: Create Schematic with Extensions**
```yaml
# extensions.yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
```

```bash
curl -X POST --data-binary @extensions.yaml https://factory.talos.dev/schematics
# Returns: {"id": "abc123..."}
```

**Step 2: Upgrade Talos Nodes**
```bash
talosctl upgrade \
  --preserve \
  --nodes 192.168.1.100,192.168.1.101,192.168.1.102 \
  --image factory.talos.dev/installer/abc123:v1.11.4
```

**Step 3: Verify Extensions**
```bash
talosctl get extensions --nodes 192.168.1.100
```

**Step 4: Apply Machine Config Patch**
```yaml
# longhorn-patch.yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
  kernel:
    modules:
      - name: nbd
      - name: iscsi_tcp
      - name: iscsi_generic
      - name: configfs
```

```bash
talosctl patch mc \
  --nodes 192.168.1.100 \
  --patch @longhorn-patch.yaml
```

**Step 5: Install Longhorn via Helm**
```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update

helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn"
```

**Step 6: Configure for Single-Node (if applicable)**
```bash
# Set default replica count to 1 for single-node
kubectl -n longhorn-system edit settings.longhorn.io default-replica-count

# Change from 3 to 1
```

**Or via Helm:**
```bash
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set defaultSettings.defaultReplicaCount=1
```

---

### 7.3 Longhorn Replica Configuration

**Discussion:** https://github.com/longhorn/longhorn/discussions/9686
**Documentation:** https://longhorn.io/docs/1.10.1/concepts/

**Summary:**
Longhorn replica management and single-node to HA migration.

**Key Points:**

**Single-Node Configuration:**
- Default: 3 replicas
- Single-node: Must set to 1 replica
- Without adjustment: Volumes fail to create (insufficient nodes)
- Setting: `defaultSettings.defaultReplicaCount=1`

**Storage Class Configuration:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-single
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fromBackup: ""
```

**Migration to 3-Node HA:**

**1. Add Two More Nodes:**
```bash
# Deploy two additional Talos nodes with same Longhorn config
talosctl apply-config --nodes 192.168.1.101 --file controlplane.yaml
talosctl apply-config --nodes 192.168.1.102 --file worker.yaml
```

**2. Update Replica Count:**
```bash
# Option 1: Update global default
kubectl -n longhorn-system edit settings.longhorn.io default-replica-count
# Change from 1 to 3

# Option 2: Per-volume
kubectl -n longhorn-system edit volume pvc-xxxxx
# Change numberOfReplicas from 1 to 3
```

**3. Longhorn Automatically Rebalances:**
- Longhorn creates additional replicas
- Distributes across all 3 nodes
- Maintains data during migration

**Best Practices:**
- Minimum 3 nodes recommended for HA
- Use odd number of replicas (1, 3, 5)
- Monitor replication status during migration
- Test failover after adding replicas

---

### 7.4 Longhorn Backup to External NAS

**Key Configuration:**
```yaml
# In Longhorn UI or via YAML
apiVersion: longhorn.io/v1beta1
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: nfs://192.168.1.10:/mnt/storage/longhorn-backups
  credentialSecret: ""
```

---

## 8. Terraform Integration

### 8.1 Terraform Providers

**siderolabs/talos Provider:**
https://registry.terraform.io/providers/siderolabs/talos/latest

**Current Version:** ~> 0.9.0 (as of late 2024)

**Key Resources:**
- `talos_machine_secrets`: Generate cluster secrets
- `talos_machine_configuration`: Generate machine configs
- `talos_machine_configuration_apply`: Apply configs to nodes
- `talos_cluster_kubeconfig`: Retrieve kubeconfig
- `talos_machine_bootstrap`: Bootstrap etcd
- `talos_image_factory_schematic`: Manage Image Factory schematics

**bpg/proxmox Provider:**
https://registry.terraform.io/providers/bpg/proxmox/latest

**Current Version:** ~> 0.86.0 (as of late 2024)

**Key Resources:**
- `proxmox_virtual_environment_vm`: Create/manage VMs
- `proxmox_virtual_environment_file`: Upload ISOs/images
- `proxmox_virtual_environment_download_file`: Download files to Proxmox

---

### 8.2 Community Terraform Modules

**bbtechsys/talos/proxmox Module:**
https://registry.terraform.io/modules/bbtechsys/talos/proxmox/latest
**GitHub:** https://github.com/bbtechsys/terraform-proxmox-talos

**Summary:**
Community-maintained Terraform module for deploying Talos on Proxmox.

**Features:**
- Automated cluster deployment
- Multi-node support
- Cilium integration
- Configurable resources

**Usage Example:**
```hcl
module "talos_cluster" {
  source  = "bbtechsys/talos/proxmox"
  version = "~> 1.0"

  cluster_name = "homelab"

  proxmox_host = "proxmox.example.com"
  proxmox_node = "pve"

  controlplane_count = 1
  worker_count       = 0

  controlplane_memory = 24576  # 24GB
  controlplane_cores  = 8

  talos_version = "v1.11.4"
  kubernetes_version = "v1.31.2"
}
```

---

### 8.3 Reference Terraform Implementations

**rgl/terraform-proxmox-talos:**
https://github.com/rgl/terraform-proxmox-talos

**Summary:**
Example Talos Linux Kubernetes cluster in Proxmox using Terraform.

**Key Features:**
- Complete working example
- Well-documented
- Includes network configuration
- Shows best practices

**pascalinthecloud/terraform-proxmox-talos-cluster:**
https://github.com/pascalinthecloud/terraform-proxmox-talos-cluster

**Summary:**
Another reference implementation with different approach.

---

### 8.4 Example Terraform Configuration

**Complete Example:**
```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_url
  insecure = true
  api_token = var.proxmox_api_token
}

provider "talos" {}

# Create Image Factory schematic
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools"
        ]
      }
    }
  })
}

# Generate cluster secrets
resource "talos_machine_secrets" "this" {}

# Generate machine configurations
data "talos_machine_configuration" "controlplane" {
  cluster_name     = "homelab"
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.controlplane_ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
      machine = {
        install = {
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:v1.11.4"
        }
        kubelet = {
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
    })
  ]
}

# Create Proxmox VM
resource "proxmox_virtual_environment_vm" "controlplane" {
  name      = "talos-cp-01"
  node_name = "pve"

  cpu {
    cores = 8
    type  = "host"  # Required for Talos v1.0+
  }

  memory {
    dedicated = 24576  # 24GB
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 200
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"  # Linux kernel
  }

  agent {
    enabled = true  # qemu-guest-agent
  }

  # GPU passthrough (optional)
  # hostpci {
  #   device  = "hostpci0"
  #   id      = "0000:01:00"
  #   pcie    = true
  #   rombar  = true
  #   xvga    = false
  # }
}

# Apply machine configuration
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = proxmox_virtual_environment_vm.controlplane.ipv4_addresses[1][0]

  depends_on = [
    proxmox_virtual_environment_vm.controlplane
  ]
}

# Bootstrap cluster
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = proxmox_virtual_environment_vm.controlplane.ipv4_addresses[1][0]

  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

# Retrieve kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = proxmox_virtual_environment_vm.controlplane.ipv4_addresses[1][0]

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
```

---

## 9. Ansible Automation

### 9.1 mgrzybek/talos-ansible-playbooks

**GitHub:** https://github.com/mgrzybek/talos-ansible-playbooks
**License:** GPL-3.0

**Summary:**
Comprehensive Ansible playbooks for managing Talos Linux lifecycle with Day-0, Day-1, and Day-2 operations.

**Project Structure:**
- **Day-0:** Set prerequisites to deploy a cluster
- **Day-1:** Deploy the cluster
- **Day-2:** Add nodes, upgrade, or destroy resources

**Technology Stack:**
- Talos Linux
- Cilium (networking)
- Rook-Ceph (storage) - alternative to Longhorn

**Key Features:**
- Complete cluster lifecycle management
- Tinkerbell integration for bare-metal provisioning
- Infrastructure-as-code approach
- Active development (117 commits, 2024 updates)

**Community:**
- 68 stars, 15 forks on GitHub
- Active maintenance

---

### 9.2 sergelogvinov/ansible-role-talos-boot

**Ansible Galaxy:** https://galaxy.ansible.com/ui/standalone/roles/sergelogvinov/talos-boot/
**GitHub:** https://github.com/sergelogvinov/ansible-role-talos-boot

**Summary:**
Ansible role for bootstrapping Talos on cloud servers and bare metal without IPMI/PXE.

**Key Features:**
- Works in environments without DHCP, PXE, or IPMI
- Gathers network information from existing OS
- Creates Talos configuration patch files
- Downloads Talos kernel and initrd
- Uses kexec for booting Talos

**Use Cases:**
- Cloud server provisioning
- Bare metal without PXE
- Environments with existing OS

**Process:**
1. Gather network information from current OS
2. Generate Talos configuration patches
3. Download Talos kernel/initrd
4. Add GRUB boot entries or use kexec
5. Reboot into Talos

---

### 9.3 Ansible Integration Strategies

**Strategy 1: Pre-Deployment (Day-0)**
```yaml
---
- name: Prepare Proxmox host for Talos
  hosts: proxmox
  tasks:
    - name: Enable IOMMU for GPU passthrough
      lineinfile:
        path: /etc/default/grub
        regexp: '^GRUB_CMDLINE_LINUX_DEFAULT='
        line: 'GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"'
      notify: update-grub

    - name: Blacklist NVIDIA drivers on host
      copy:
        dest: /etc/modprobe.d/blacklist-nvidia.conf
        content: |
          blacklist nouveau
          blacklist nvidia
          blacklist nvidia_drm
      notify: update-initramfs
```

**Strategy 2: Deployment (Day-1)**
```yaml
---
- name: Deploy Talos cluster
  hosts: localhost
  vars:
    talos_version: "v1.11.4"
    cluster_name: "homelab"
  tasks:
    - name: Generate Talos secrets
      command: >
        talosctl gen secrets -o secrets.yaml

    - name: Generate machine configs
      command: >
        talosctl gen config {{ cluster_name }}
        https://{{ controlplane_ip }}:6443
        --with-secrets secrets.yaml
        --config-patch @cilium-patch.yaml
```

**Strategy 3: Operations (Day-2)**
```yaml
---
- name: Upgrade Talos cluster
  hosts: talos_nodes
  tasks:
    - name: Upgrade Talos
      command: >
        talosctl upgrade
        --nodes {{ inventory_hostname }}
        --image factory.talos.dev/installer/{{ schematic_id }}:{{ talos_version }}
        --preserve
```

---

## 10. Production Best Practices

### 10.1 Disaster Recovery and Backups

**Official Guide:** https://www.talos.dev/v1.10/advanced/disaster-recovery/
**etcd Maintenance:** https://www.talos.dev/v1.9/advanced/etcd-maintenance/
**talos-backup Tool:** https://github.com/siderolabs/talos-backup

**Summary:**
Critical procedures for production Talos deployments including etcd backup and disaster recovery.

**etcd Backup Procedures:**

**Method 1: Consistent Snapshot (Recommended)**
```bash
# Create consistent snapshot
talosctl -n 192.168.1.100 etcd snapshot db.snapshot

# Download snapshot
talosctl -n 192.168.1.100 cp /var/lib/etcd/member/snap/db.snapshot ./backup-$(date +%Y%m%d).snapshot
```

**Method 2: Direct Database Copy (Emergency)**
```bash
# If snapshot command fails, copy database directly
talosctl -n 192.168.1.100 cp /var/lib/etcd/member/snap/db ./emergency-backup.db

# WARNING: May not be fully consistent if etcd is running
```

**Automated Backup with talos-backup:**
```yaml
# Deploy as CronJob in cluster
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: talos-backup
          containers:
          - name: backup
            image: ghcr.io/siderolabs/talos-backup:latest
            env:
            - name: S3_BUCKET
              value: "s3://my-backups/talos-etcd"
            - name: S3_REGION
              value: "us-east-1"
```

**Machine Configuration Backup:**
```bash
# Backup machine configs (required for node recovery)
talosctl -n 192.168.1.100 get machineconfig -o yaml > controlplane-config-backup.yaml

# Store securely - contains cluster secrets!
```

**Critical Backup Considerations:**
- **Single-Node Clusters:** Regular backups ESSENTIAL (no redundancy)
- **Security:** etcd contains secrets (passwords, API keys) - encrypt backups
- **Frequency:** Daily minimum for production; hourly for critical workloads
- **Storage:** Off-cluster location (S3, NFS, external NAS)
- **Testing:** Regularly test restore procedures

---

### 10.2 Cluster Health and Monitoring

**Key Metrics to Monitor:**

**etcd Health:**
```bash
# Check etcd members
talosctl -n 192.168.1.100 etcd members

# Check etcd status
talosctl -n 192.168.1.100 etcd status

# etcd alarm list
talosctl -n 192.168.1.100 etcd alarm list
```

**Node Health:**
```bash
# Service status
talosctl -n 192.168.1.100 services

# System information
talosctl -n 192.168.1.100 get members

# Logs
talosctl -n 192.168.1.100 logs kubelet
```

**Kubernetes Metrics:**
```bash
# Node status
kubectl get nodes -o wide

# Pod health
kubectl get pods --all-namespaces

# Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

---

### 10.3 Security Best Practices

**1. Machine Configuration Security:**
- Store machine configs securely (contain cluster secrets)
- Use SOPS or similar for encrypting configs in Git
- Rotate secrets regularly
- Limit access to Talos API

**2. Network Security:**
```yaml
# Enable network policies with Cilium
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
spec:
  endpointSelector: {}
  ingress:
  - {}
  egress:
  - {}
```

**3. RBAC Configuration:**
```yaml
# Minimal ServiceAccount for talos-backup
apiVersion: v1
kind: ServiceAccount
metadata:
  name: talos-backup
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: talos-backup
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: talos-backup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: talos-backup
subjects:
- kind: ServiceAccount
  name: talos-backup
  namespace: kube-system
```

**4. Talos API Access:**
```yaml
# Enable Kubernetes access to Talos API (for backup pods)
machine:
  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:etcd:backup
      allowedKubernetesNamespaces:
        - kube-system
```

---

### 10.4 Upgrade Procedures

**Talos Upgrade:**
```bash
# Check current version
talosctl -n 192.168.1.100 version

# Upgrade Talos (rolling upgrade for multi-node)
talosctl -n 192.168.1.100 upgrade \
  --image factory.talos.dev/installer/$(schematic_id):v1.11.5 \
  --preserve

# For multi-node: upgrade one node at a time
# Control plane first, then workers
```

**Kubernetes Upgrade:**
```bash
# Upgrade Kubernetes version
talosctl -n 192.168.1.100 upgrade-k8s --to 1.31.3
```

**Best Practices:**
- Always backup before upgrades
- Test in dev environment first
- Upgrade Talos before Kubernetes
- Read release notes for breaking changes
- Monitor cluster during upgrade

---

### 10.5 Production Checklist

**Pre-Deployment:**
- [ ] etcd backup strategy configured
- [ ] Machine configs backed up securely
- [ ] Monitoring and alerting set up
- [ ] Network policies defined
- [ ] RBAC configured
- [ ] GPU passthrough tested (if applicable)
- [ ] Storage replica count appropriate for node count
- [ ] Load balancer/VIP configured (for HA)

**Post-Deployment:**
- [ ] Verify all nodes healthy
- [ ] Test etcd backup and restore
- [ ] Validate Cilium connectivity
- [ ] Verify Longhorn storage provisioning
- [ ] Test GPU workload scheduling (if applicable)
- [ ] Document runbooks for common operations
- [ ] Set up automated backups
- [ ] Configure log aggregation

**Ongoing Operations:**
- [ ] Regular etcd backups (automated)
- [ ] Monitor cluster health metrics
- [ ] Review security advisories
- [ ] Test disaster recovery procedures
- [ ] Plan upgrade windows
- [ ] Capacity planning and resource monitoring

---

## 11. Common Issues and Troubleshooting

### 11.1 Boot and Installation Issues

**Issue 1: Boot Loop on First Boot**
**GitHub Issue:** https://github.com/siderolabs/talos/issues/9852

**Problem:**
Machines throw "error running phase 6 in initialize sequence: task 1/1: failed, unexpected EOF" and enter boot loop.

**Solutions:**
- Use "nocloud" image type instead of "metal" image
- Ensure Proxmox CPU type is set to "host" (not kvm64) for Talos v1.0+
- Verify disk configuration (default is /dev/sda, may need /dev/vda)

---

**Issue 2: Inconsistent First Boot**
**GitHub Discussion:** https://github.com/siderolabs/talos/discussions/9291

**Problem:**
Unable to configure Talos in Proxmox VM - network or initialization issues.

**Solutions:**
- Check network bridge configuration in Proxmox
- Verify DHCP is available if using DHCP
- For static IP, ensure machine config has correct network settings
- Check Proxmox firewall rules

---

**Issue 3: Memory Hot Plugging Enabled**
**From Official Docs**

**Problem:**
Talos unable to see all available memory, insufficient memory errors during installation.

**Solution:**
- Disable memory hot plugging in Proxmox VM settings
- Talos does NOT support memory hot plugging

---

### 11.2 Networking Issues

**Issue 4: Node Stuck on "retrying error: node not ready"**
**From Cilium Deployment Guide**

**Problem:**
After bootstrap, node appears stuck on phase 18/19 with "retrying error: node not ready".

**This is EXPECTED behavior:**
- Nodes are only marked ready once CNI is up
- You have ~10 minutes to install Cilium before node reboots
- Install Cilium during this window using Helm or inline manifest

**Solution:**
```bash
# Install Cilium during the 10-minute window
helm install cilium cilium/cilium --version 1.18.0 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  # ... other settings
```

---

**Issue 5: IPv6-Only Network Problems**
**GitHub Discussion:** https://github.com/siderolabs/talos/discussions/9392

**Problem:**
Trouble setting up Talos on IPv6-only network.

**Solutions:**
- Ensure machine config has correct IPv6 settings
- Configure Cilium for IPv6
- Check router advertisement configuration

---

**Issue 6: Cloudflare Time Server Resolution Failure**
**From GitHub Issues**

**Problem:**
Network resolution failures for time.cloudflare.com despite VM connectivity.

**Solutions:**
```yaml
# Use different NTP servers in machine config
machine:
  time:
    servers:
      - time.google.com
      - pool.ntp.org
```

---

### 11.3 Storage and GPU Issues

**Issue 7: iSCSI Extension Not Working**
**GitHub Issue:** https://github.com/siderolabs/talos/issues/9134

**Problem:**
iSCSI system extension reported as uninstalled by applications (Longhorn).

**Solutions:**
- Verify extensions installed: `talosctl get extensions`
- Check schematic includes both iscsi-tools AND util-linux-tools
- Verify kernel modules loaded: `talosctl read /proc/modules | grep iscsi`
- Ensure kubelet extraMounts configured with rshared propagation

---

**Issue 8: NVIDIA GPU Not Detected in Kubernetes**
**GitHub Issue:** https://github.com/siderolabs/talos/issues/9149

**Problem:**
NVIDIA GPU OSS or proprietary driver install not working on KVM guest.

**Solutions:**
- Verify GPU passed through in Proxmox (check VM hardware settings)
- Confirm NVIDIA system extensions installed
- Check kernel modules loaded: `talosctl read /proc/modules | grep nvidia`
- Verify machine config has kernel modules section
- Install NVIDIA GPU Operator in Kubernetes
- Check GPU Operator pod status

**Debug Commands:**
```bash
# Check extensions
talosctl -n <node> get extensions

# Check kernel modules
talosctl -n <node> read /proc/modules | grep nvidia

# Check GPU visibility
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Check GPU Operator
kubectl get pods -n gpu-operator
```

---

**Issue 9: Longhorn Volumes Fail to Create**
**From Longhorn Documentation**

**Problem:**
Volumes fail to create with "insufficient nodes" error on single-node cluster.

**Solution:**
```bash
# Set default replica count to 1 for single-node
kubectl -n longhorn-system edit settings.longhorn.io default-replica-count

# Or install with Helm:
helm install longhorn longhorn/longhorn \
  --set defaultSettings.defaultReplicaCount=1
```

---

### 11.4 Disk and Filesystem Issues

**Issue 10: Wrong Disk Device Path**
**From Multiple Sources**

**Problem:**
Talos config defaults to /dev/sda but virtual disk mounted as /dev/vda.

**Solution:**
```yaml
# Machine config patch
machine:
  install:
    disk: /dev/vda  # Change from default /dev/sda
```

---

**Issue 11: Secure Boot Enrollment Failure**
**Forum Discussion:** https://forum.proxmox.com/threads/enroll-custom-secureboot-keys.151443/

**Problem:**
"Failed to write PK secure boot variable: Security Violation" when enrolling secure boot keys.

**Solutions:**
- Disable secure boot for Talos (not required)
- Or follow Proxmox secure boot enrollment procedures
- Most homelab deployments don't need secure boot

---

### 11.5 Cluster Operations Issues

**Issue 12: KubePrism Not Running After Update**
**GitHub Issue:** https://github.com/siderolabs/talos/issues/10598

**Problem:**
KubePrism not running on some nodes after talos/kube-apiserver update.

**Solutions:**
```bash
# Check KubePrism status
talosctl -n <node> services

# Restart node if needed
talosctl -n <node> reboot
```

---

**Issue 13: L2 Announcements responses_sent=0**
**GitHub Discussion:** https://github.com/cilium/cilium/discussions/36829

**Problem:**
Cilium L2 Announcements configured but not sending ARP responses.

**Solutions:**
- Verify CiliumL2AnnouncementPolicy created
- Check CiliumLoadBalancerIPPool configured
- Ensure `devices` parameter set correctly in Cilium
- Verify service has `loadBalancerClass: io.cilium/l2-announcer`

---

## 12. Key Configuration Snippets

### 12.1 Complete Machine Configuration for Single-Node with GPU

```yaml
version: v1alpha1
debug: false
persist: true

machine:
  type: controlplane

  # Installation
  install:
    disk: /dev/sda
    image: factory.talos.dev/installer/<schematic-id>:v1.11.4
    wipe: false

  # CPU and resources
  # Note: Set in Proxmox to "host" type

  # Kubelet configuration
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.31.2
    extraArgs:
      rotate-server-certificates: true
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw

  # Kernel modules for GPU and storage
  kernel:
    modules:
      # NVIDIA GPU
      - name: nvidia
      - name: nvidia_uvm
      - name: nvidia_drm
      - name: nvidia_modeset
      # Longhorn storage
      - name: nbd
      - name: iscsi_tcp
      - name: iscsi_generic
      - name: configfs

  # Network configuration
  network:
    hostname: talos-cp-01
    interfaces:
      - interface: eth0
        dhcp: true
        # Or static:
        # addresses:
        #   - 192.168.1.100/24
        # routes:
        #   - network: 0.0.0.0/0
        #     gateway: 192.168.1.1
    nameservers:
      - 1.1.1.1
      - 8.8.8.8

  # Time configuration
  time:
    servers:
      - time.cloudflare.com
      - time.google.com

  # Features
  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:etcd:backup
      allowedKubernetesNamespaces:
        - kube-system

cluster:
  # Cluster identification
  id: <generated-cluster-id>
  secret: <generated-cluster-secret>
  clusterName: homelab

  # Control plane endpoint
  controlPlane:
    endpoint: https://192.168.1.100:6443

  # Networking
  network:
    cni:
      name: none  # Using Cilium
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12

  # Disable kube-proxy (Cilium replaces it)
  proxy:
    disabled: true

  # Allow scheduling on control plane (single-node)
  allowSchedulingOnControlPlanes: true

  # Discovery
  discovery:
    enabled: true
    registries:
      kubernetes:
        disabled: false
      service:
        disabled: false

  # etcd
  etcd:
    subnet: 10.96.0.0/12
```

---

### 12.2 Cilium Helm Values for Talos

```yaml
# cilium-values.yaml
# For Cilium v1.18.0+

# Basic configuration
kubeProxyReplacement: true
k8sServiceHost: localhost
k8sServicePort: 7445

# IPAM
ipam:
  mode: kubernetes

# cgroup configuration for Talos
cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup

# Security context - drop SYS_MODULE for Talos
securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_ADMIN
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE

# L2 Announcements for LoadBalancer
l2announcements:
  enabled: true

# External IPs
externalIPs:
  enabled: true

# Devices for L2 announcements
devices:
  - eth0

# Hubble observability (optional)
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# Operator
operator:
  replicas: 1  # Single node

# Resources (adjust for your cluster)
resources:
  limits:
    cpu: 4000m
    memory: 4Gi
  requests:
    cpu: 100m
    memory: 512Mi
```

**Installation:**
```bash
helm install cilium cilium/cilium \
  --version 1.18.0 \
  --namespace kube-system \
  --values cilium-values.yaml
```

---

### 12.3 Longhorn Helm Values for Single-Node

```yaml
# longhorn-values.yaml
# For Longhorn v1.7.x

# Default settings
defaultSettings:
  # Single-node: 1 replica
  defaultReplicaCount: 1

  # Talos-specific data path
  defaultDataPath: /var/lib/longhorn

  # Backup target (external NAS)
  backupTarget: nfs://192.168.1.10:/mnt/storage/longhorn-backups

  # Storage settings
  storageMinimalAvailablePercentage: 10
  storageOverProvisioningPercentage: 200

  # Upgrade settings
  guaranteedInstanceManagerCPU: 12

  # Auto-salvage
  autoSalvage: true

  # Replica soft anti-affinity (single node = disabled)
  replicaSoftAntiAffinity: false

# Persistence
persistence:
  defaultClass: true
  defaultClassReplicaCount: 1

# Ingress (optional)
ingress:
  enabled: true
  host: longhorn.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod

# Resources
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Installation:**
```bash
# Add Helm repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Install
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --values longhorn-values.yaml
```

---

### 12.4 Storage Classes for Longhorn

```yaml
---
# Standard storage class (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"

---
# Retain storage class (for important data)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-retain
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fsType: "ext4"

---
# Fast storage class (for performance)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-fast
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "30"
  fsType: "ext4"
  dataLocality: "best-effort"
```

---

### 12.5 GPU Test Workload

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: Never
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command:
      - nvidia-smi
    resources:
      limits:
        nvidia.com/gpu: 1
```

**Run test:**
```bash
kubectl apply -f gpu-test.yaml
kubectl logs gpu-test

# Should show GPU information
```

---

## 13. Summary and Recommendations

### 13.1 Key Takeaways

**1. Proxmox Configuration:**
- CPU type MUST be "host" for Talos v1.0+
- Disable memory hot plugging
- Use "nocloud" images, not "metal" images
- qemu-guest-agent highly recommended

**2. System Extensions:**
- Use Talos Factory for custom images
- Required: qemu-guest-agent, iscsi-tools, util-linux-tools
- GPU: nonfree-kmod-nvidia-production + nvidia-container-toolkit-production
- Extension versions must match Talos version

**3. Single-Node to HA:**
- Start with 1 node, expand to 3 nodes
- Use odd number of control plane nodes
- Preserve original controlplane.yaml and worker.yaml
- Remove control plane taint for single-node
- Set Longhorn replicas to 1 for single-node, 3 for HA

**4. Cilium Configuration:**
- Set CNI to "none" in machine config
- Disable kube-proxy
- Drop SYS_MODULE capability
- Use KubePrism (localhost:7445) for API access
- L2 announcements for LoadBalancer services

**5. Longhorn Storage:**
- Requires iscsi-tools and util-linux-tools extensions
- Configure kubelet extraMounts with rshared propagation
- Set defaultDataPath to /var/lib/longhorn
- Single-node: 1 replica; HA: 3 replicas
- Configure backup to external NAS

**6. GPU Passthrough:**
- Proxmox host: Enable IOMMU, blacklist NVIDIA drivers
- Talos: Use proprietary NVIDIA extensions
- Machine config: Load nvidia kernel modules
- Kubernetes: Install NVIDIA GPU Operator
- ONE GPU per VM limitation (no vGPU on consumer cards)

**7. Production Best Practices:**
- Regular etcd backups (CRITICAL for single-node)
- Monitor cluster health
- Test disaster recovery procedures
- Secure machine configs (contain secrets)
- Document runbooks

---

### 13.2 Recommended Workflow

**Phase 1: Preparation**
1. Configure Proxmox host (IOMMU if using GPU)
2. Create Talos Factory schematic with extensions
3. Prepare Terraform configuration
4. Plan network configuration (static IPs, load balancer)

**Phase 2: Initial Deployment**
1. Deploy single-node cluster with Terraform
2. Bootstrap cluster with talosctl
3. Install Cilium CNI (during 10-minute window)
4. Verify cluster health
5. Remove control plane taint

**Phase 3: Storage and Services**
1. Install Longhorn (single-replica mode)
2. Create storage classes
3. Test volume provisioning
4. Configure backup to external NAS
5. Deploy initial workloads

**Phase 4: GPU Setup (if applicable)**
1. Verify GPU passthrough in Proxmox
2. Confirm NVIDIA extensions loaded
3. Install NVIDIA GPU Operator
4. Test GPU workload
5. Monitor GPU utilization

**Phase 5: Production Readiness**
1. Configure automated etcd backups
2. Set up monitoring and alerting
3. Test disaster recovery
4. Document procedures
5. Plan for expansion to HA

**Phase 6: Scale to HA (when ready)**
1. Add 2 more nodes (for 3-node cluster)
2. Update Longhorn replica count to 3
3. Configure load balancer/VIP
4. Test failover scenarios
5. Update backup procedures

---

### 13.3 Critical Documentation Links

**Must-Read Official Docs:**
1. [Talos on Proxmox](https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/)
2. [Talos Image Factory](https://www.talos.dev/v1.10/learn-more/image-factory/)
3. [Scaling Up Talos Cluster](https://www.talos.dev/v1.11/talos-guides/howto/scaling-up/)
4. [NVIDIA GPU Configuration](https://www.talos.dev/v1.11/talos-guides/configuration/nvidia-gpu-proprietary/)
5. [Deploying Cilium CNI](https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/)
6. [Longhorn Talos Support](https://longhorn.io/docs/1.10.0/advanced-resources/os-distro-specific/talos-linux-support/)
7. [Disaster Recovery](https://www.talos.dev/v1.10/advanced/disaster-recovery/)
8. [KubePrism](https://www.talos.dev/v1.10/kubernetes-guides/configuration/kubeprism/)

**Recommended Community Guides:**
1. [TechDufus: Talos on Proxmox with Terraform](https://techdufus.com/tech/2025/06/30/building-a-talos-kubernetes-homelab-on-proxmox-with-terraform.html)
2. [Suraj Remanan: Automating Talos with Packer and Terraform](https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/)
3. [Duck's Blog: GPU Passthrough to Talos](https://blog.duckdefense.cc/kubernetes-gpu-passthrough/)

**Terraform Providers:**
1. [siderolabs/talos Provider](https://registry.terraform.io/providers/siderolabs/talos/latest)
2. [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)

**GitHub Repositories:**
1. [mgrzybek/talos-ansible-playbooks](https://github.com/mgrzybek/talos-ansible-playbooks)
2. [siderolabs/extensions](https://github.com/siderolabs/extensions)
3. [rgl/terraform-proxmox-talos](https://github.com/rgl/terraform-proxmox-talos)

---

## 14. Version Matrix

| Component | Recommended Version | Notes |
|-----------|-------------------|-------|
| Talos Linux | v1.11.4 | Latest stable as of Nov 2024 |
| Kubernetes | v1.31.2 | Supported by Talos v1.11 |
| Cilium | v1.18.0+ | Current stable CNI |
| Longhorn | v1.7.x | Latest storage manager |
| Proxmox VE | 8.0+ | Earlier requires CPU type workaround |
| Terraform | 1.5+ | Latest stable |
| siderolabs/talos provider | ~> 0.9.0 | Published 3 months ago |
| bpg/proxmox provider | ~> 0.86.0 | Latest as of Oct 2024 |
| NVIDIA Driver (Production) | 570.140.08 | As of late 2024 |
| NVIDIA Driver (LTS) | 535.247.01 | Long-term support |
| NVIDIA Container Toolkit | 1.17.8 | Latest as of late 2024 |

---

## 15. Sources Reference

This research report synthesized information from the following sources:

**Official Documentation (8 sources):**
1. https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/
2. https://www.talos.dev/v1.10/learn-more/image-factory/
3. https://www.talos.dev/v1.11/talos-guides/howto/scaling-up/
4. https://www.talos.dev/v1.11/talos-guides/configuration/nvidia-gpu-proprietary/
5. https://www.talos.dev/v1.10/kubernetes-guides/network/deploying-cilium/
6. https://www.talos.dev/v1.10/kubernetes-guides/configuration/kubeprism/
7. https://longhorn.io/docs/1.10.0/advanced-resources/os-distro-specific/talos-linux-support/
8. https://docs.cilium.io/en/stable/network/l2-announcements/

**Blog Posts (10 sources):**
1. https://techdufus.com/tech/2025/06/30/building-a-talos-kubernetes-homelab-on-proxmox-with-terraform.html
2. https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/
3. https://blog.duckdefense.cc/kubernetes-gpu-passthrough/
4. https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/
5. https://a-cup-of.coffee/blog/talos-ext/
6. https://hackmd.io/@QI-AN/Install-Longhorn-on-Talos-Kubernetes
7. https://joshrnoll.com/installing-longhorn-on-talos-with-helm/
8. https://phin3has.blog/posts/talos-longhorn/
9. https://blog.devgenius.io/servicelb-with-cilium-on-talos-linux-8a290d524cb7
10. https://rahulvinodsharma.medium.com/homelab-setting-up-4090-graphic-card-to-talos-linux-0e8d5129b0b2

**GitHub Repositories (7 sources):**
1. https://github.com/siderolabs/extensions
2. https://github.com/siderolabs/image-factory
3. https://github.com/mgrzybek/talos-ansible-playbooks
4. https://github.com/sergelogvinov/ansible-role-talos-boot
5. https://github.com/rgl/terraform-proxmox-talos
6. https://github.com/bbtechsys/terraform-proxmox-talos
7. https://github.com/siderolabs/talos-backup

**Terraform Registry (3 sources):**
1. https://registry.terraform.io/providers/siderolabs/talos/latest
2. https://registry.terraform.io/providers/bpg/proxmox/latest
3. https://registry.terraform.io/modules/bbtechsys/talos/proxmox/latest

**Community Discussions (5+ GitHub issues/discussions)**

**Total High-Quality Sources:** 30+ URLs reviewed and synthesized

---

**Report End**

*This research report provides a comprehensive foundation for deploying Talos Linux on Proxmox with production-ready configurations for GPU passthrough, Cilium networking, and Longhorn storage.*
