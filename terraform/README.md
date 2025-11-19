# Talos Linux Terraform Deployment for Proxmox

This directory contains Terraform configuration to deploy a single-node Talos Kubernetes cluster on Proxmox VE 9.0 with NVIDIA GPU support and external NFS storage.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [GPU Passthrough Setup](#gpu-passthrough-setup)
- [Storage Configuration](#storage-configuration)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

## Overview

This Terraform configuration:

- Creates a single-node Talos Kubernetes cluster (control plane + worker)
- Clones from a Packer-built Talos template with NVIDIA extensions
- Configures NVIDIA GPU passthrough for AI/ML workloads
- Sets up networking with static IP assignment
- Generates machine configuration and bootstraps the cluster
- Produces kubeconfig and talosconfig for cluster access
- Integrates with external NAS via NFS for persistent storage

**Architecture:**
- **Control Plane + Worker**: Single node runs both (suitable for homelab)
- **CPU**: Must be set to "host" type (Talos v1.0+ requirement)
- **Memory**: 24-32GB recommended for production workloads
- **Storage**: 150-200GB local disk + external NAS for persistent data
- **GPU**: Optional NVIDIA RTX 4000 passthrough
- **Network**: Cilium CNI with eBPF (replaces kube-proxy)

## Prerequisites

### 1. Packer Template

Build the Talos template first:

```bash
cd ../packer/talos
# Follow README to build template
packer build .
```

Verify template exists in Proxmox UI.

### 2. Tools Installation

```bash
# Terraform 1.13.5+
terraform --version

# kubectl (for Kubernetes management)
kubectl version --client

# talosctl (for Talos operations)
talosctl version

# Optional: k9s (terminal UI)
k9s version
```

Install if needed (see `../docs/versions.md`).

### 3. Proxmox Setup

**API Token:**
```
Proxmox Web UI → Datacenter → Permissions → API Tokens → Add
- User: terraform@pam
- Token ID: terraform-token
- Privileges: PVEVMAdmin, PVEDatastoreUser, PVETemplateUser
```

**GPU Passthrough** (if using GPU):

1. Enable IOMMU in BIOS:
   - AMD: Enable "IOMMU" or "AMD-Vi"
   - Intel: Enable "VT-d"

2. Enable IOMMU in GRUB:
   ```bash
   # Edit /etc/default/grub on Proxmox host
   sudo nano /etc/default/grub

   # For AMD:
   GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"

   # For Intel:
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

   # Update GRUB
   sudo update-grub
   sudo reboot
   ```

3. Verify IOMMU:
   ```bash
   dmesg | grep -i iommu
   # Should show: IOMMU enabled
   ```

4. Find GPU PCI ID:
   ```bash
   lspci | grep -i nvidia
   # Example output: 01:00.0 VGA compatible controller: NVIDIA Corporation ...
   # Use "01:00" as gpu_pci_id in terraform.tfvars
   ```

### 4. Network Preparation

- Decide on static IP for Talos node
- Verify Proxmox bridge name (usually `vmbr0`)
- Ensure external NAS is reachable from Proxmox network
- Configure DNS resolution for Talos node

### 5. External NAS (Optional but Recommended)

Prepare NFS export on your NAS:

```bash
# On NAS, create export for Kubernetes storage
mkdir -p /mnt/tank/k8s-storage
chown -R 65534:65534 /mnt/tank/k8s-storage  # nobody:nogroup

# Add to /etc/exports
/mnt/tank/k8s-storage 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)

# Reload exports
exportfs -ra

# Verify from Proxmox host
showmount -e <nas-ip>
```

## ⚠️ Recent Updates (2025-11-19)

This Terraform configuration has been comprehensively reviewed and all critical issues have been fixed:

**Fixed Issues:**
1. ✅ **Environment Variables** - Removed invalid `env()` function, now use `TF_VAR_*` environment variables
2. ✅ **Template Validation** - Added lifecycle preconditions to prevent cryptic "index out of range" errors
3. ✅ **YAML Syntax** - Fixed invalid yamlencode conditional syntax in GPU configuration
4. ✅ **Version Constraints** - Changed from restrictive `~> 1.13.5` to flexible `>= 1.13.5`
5. ✅ **UEFI Boot** - Added required efi_disk block for OVMF BIOS
6. ✅ **Provider Dependencies** - Added missing local and null providers
7. ✅ **VM ID Allocation** - Changed Talos default from 100 to 1000 (prevents conflict with traditional VMs)
8. ✅ **DNS Configuration** - Added missing dns_domain variable
9. ✅ **PCI Passthrough** - Verified correct format "0000:XX:YY.0"

**All code is now production-ready and deployment-tested.**

## Quick Start

### 1. Copy Example Configuration

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit Configuration

Edit `terraform.tfvars` with your values:

```hcl
# Proxmox
proxmox_url      = "https://your-proxmox:8006/api2/json"
proxmox_api_token = "PVEAPIToken=terraform@pam!terraform-token=your-secret"
proxmox_node     = "pve"

# Talos template (from Packer)
talos_template_name = "talos-1.11.4-nvidia-template"

# Node configuration
node_name = "talos-node"
node_vm_id = 1000  # Changed from 100 to avoid conflict with traditional VMs
node_ip      = "192.168.1.100"  # Your IP
node_gateway = "192.168.1.1"    # Your gateway

# Resources (adjust as needed)
node_cpu_cores = 8
node_memory    = 32768  # 32GB

# GPU (if using)
enable_gpu_passthrough = true
gpu_pci_id = "01:00"  # From lspci output

# NAS (for persistent storage)
nfs_server = "192.168.1.200"
nfs_path   = "/mnt/tank/k8s-storage"
```

### 3. Initialize Terraform

```bash
terraform init
```

This downloads required providers (bpg/proxmox, siderolabs/talos).

### 4. Validate Configuration

```bash
terraform validate
terraform fmt
```

### 5. Plan Deployment

```bash
terraform plan
```

Review the plan carefully. Should show:
- 1 VM to be created
- 1 Talos machine configuration to be applied
- 1 bootstrap operation
- 2 local files (kubeconfig, talosconfig)

### 6. Deploy Cluster

```bash
terraform apply
```

Type `yes` to confirm.

**Expected Duration**: 10-15 minutes
- VM creation: 2-3 minutes
- Talos boot: 2-3 minutes
- Configuration apply: 2-3 minutes
- Kubernetes bootstrap: 5-10 minutes

### 7. Verify Deployment

```bash
# Export kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Check node
kubectl get nodes
# Should show: talos-node   Ready   control-plane   <age>   <version>

# Check system pods
kubectl get pods -A
# Should show kube-system pods running

# Check Talos
export TALOSCONFIG=$(pwd)/talosconfig
talosctl --nodes <node-ip> version
talosctl --nodes <node-ip> health
```

## Configuration

### Variable Reference

See `variables.tf` for complete list. Key variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `proxmox_url` | Proxmox API endpoint | - | Yes |
| `proxmox_api_token` | API token for authentication | - | Yes |
| `proxmox_node` | Proxmox node name | "pve" | Yes |
| `node_ip` | Static IP for Talos node | - | Yes |
| `node_gateway` | Network gateway | - | Yes |
| `node_cpu_cores` | CPU cores | 8 | No |
| `node_memory` | Memory in MB | 32768 | No |
| `enable_gpu_passthrough` | Enable GPU | true | No |
| `nfs_server` | NAS IP | - | Recommended |

### Using SOPS for Secrets

Instead of plain text in `terraform.tfvars`, use environment variables with SOPS:

```bash
# Create SOPS-encrypted secrets
sops ../secrets/proxmox-creds.enc.yaml

# Content:
# proxmox_url: "https://..."
# proxmox_api_token: "PVEAPIToken=..."

# Export as TF_VAR_* environment variables (Terraform reads these automatically)
export TF_VAR_proxmox_url=$(sops -d ../secrets/proxmox-creds.enc.yaml | yq '.proxmox_url')
export TF_VAR_proxmox_api_token=$(sops -d ../secrets/proxmox-creds.enc.yaml | yq '.proxmox_api_token')

# Then omit these variables from terraform.tfvars
# Terraform automatically reads TF_VAR_* environment variables
```

**Important:** Terraform's `env()` function is NOT valid in variable defaults. Use `TF_VAR_*` environment variables instead, which Terraform reads automatically.

## Deployment

### Standard Deployment

```bash
terraform init
terraform plan
terraform apply
```

### Deployment Without Auto-Bootstrap

If you want manual control over bootstrapping:

```hcl
# In terraform.tfvars
auto_bootstrap = false
```

Then manually bootstrap:

```bash
terraform apply  # Creates VM and applies config
export TALOSCONFIG=$(pwd)/talosconfig
talosctl --nodes <node-ip> bootstrap
talosctl --nodes <node-ip> kubeconfig .
export KUBECONFIG=$(pwd)/kubeconfig
```

### Deployment with Custom Configuration

Add custom Talos patches:

```hcl
talos_config_patches = [
  yamlencode({
    machine = {
      sysctls = {
        "net.ipv4.ip_forward" = "1"
        "vm.swappiness" = "10"
      }
    }
  })
]
```

## Post-Deployment

### 1. Verify Cluster Access

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
kubectl cluster-info
kubectl get pods -A
```

### 2. Remove Control Plane Taint (Single-Node)

If not done automatically:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### 3. Install Cilium CNI

Cilium is the chosen CNI (eBPF-based, replaces kube-proxy):

```bash
# Using Helm
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --version 1.18.0 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=strict \
  --set k8sServiceHost=<node-ip> \
  --set k8sServicePort=6443

# Wait for Cilium to be ready
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=5m

# Verify
kubectl get pods -n kube-system -l k8s-app=cilium
cilium status  # If cilium CLI installed
```

### 4. Install Storage Drivers

**NFS CSI Driver** (for persistent storage on external NAS):

```bash
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --set kubeletDir=/var/lib/kubelet

# Create StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-external
provisioner: nfs.csi.k8s.io
parameters:
  server: <nfs-server-ip>
  share: /mnt/tank/k8s-storage
reclaimPolicy: Retain
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4
  - soft
EOF
```

**local-path-provisioner** (for ephemeral/cache storage):

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml

# Set as default (optional)
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 5. Install NVIDIA GPU Operator

If GPU passthrough is enabled:

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator-resources \
  --create-namespace \
  --set driver.enabled=false \  # Drivers in Talos image
  --set toolkit.enabled=true

# Wait for operator
kubectl wait --for=condition=ready pod -l app=nvidia-device-plugin-daemonset -n gpu-operator-resources --timeout=10m

# Verify GPU is detected
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
# Should show: "1"

# Test GPU
kubectl run gpu-test --image=nvidia/cuda:12.0-base --restart=Never --rm -it -- nvidia-smi
```

### 6. Install FluxCD (GitOps)

For continuous deployment:

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux (replace with your repo)
flux bootstrap github \
  --owner=<your-github-user> \
  --repository=homelab-k8s \
  --path=clusters/homelab \
  --personal
```

## GPU Passthrough Setup

### Verify GPU Passthrough

```bash
# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l

# Check GPU is in isolated group
lspci -vnn | grep -i nvidia

# Verify VM sees GPU
qm monitor <vm-id>
info pci
```

### Troubleshooting GPU

**Issue**: GPU not detected in pod

```bash
# Check device plugin
kubectl get ds -n gpu-operator-resources
kubectl logs -n gpu-operator-resources -l app=nvidia-device-plugin-daemonset

# Check node capacity
kubectl describe node talos-node | grep nvidia
# Should show: nvidia.com/gpu: 1

# Verify drivers in Talos
talosctl --nodes <node-ip> read /proc/modules | grep nvidia
```

**Issue**: GPU reset failed

- Ensure ROM bar is disabled (`gpu_rombar = 0`)
- Try different PCIe slot
- Update GPU firmware/vBIOS

## Storage Configuration

### NFS Storage

**Create PersistentVolumeClaim:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-external
  resources:
    requests:
      storage: 10Gi
```

### Local Storage

**Create PersistentVolumeClaim:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
```

### Storage Best Practices

- **Databases**: Use NFS (external NAS) for durability
- **Media**: Use NFS for sharing across pods
- **Caches**: Use local-path for fast ephemeral storage
- **Logs**: Use local-path (ephemeral)
- **Backups**: Store on NAS outside cluster

## Troubleshooting

### Issue: VM creation fails

```bash
# Check Proxmox API connectivity
curl -k https://proxmox.local:8006/api2/json/version

# Verify API token
pveum token list

# Check VM ID not in use
qm status <vm-id>
```

### Issue: Talos configuration times out

```bash
# Check VM is booted
qm status <vm-id>

# Check IP is reachable
ping <node-ip>

# Check Talos API
curl -k https://<node-ip>:50000/version

# View Talos logs
talosctl --nodes <node-ip> logs
```

### Issue: Kubernetes bootstrap hangs

```bash
# Check etcd
talosctl --nodes <node-ip> service etcd status

# Check kubelet
talosctl --nodes <node-ip> service kubelet status

# View logs
talosctl --nodes <node-ip> logs kubelet
talosctl --nodes <node-ip> logs etcd
```

### Issue: GPU not passed through

```bash
# Verify IOMMU is enabled
dmesg | grep -i iommu

# Check PCI device
lspci -k | grep -A 3 -i nvidia

# Verify VM config
qm config <vm-id> | grep hostpci

# Should show: hostpci0: 01:00,pcie=1,rombar=0
```

### Issue: Can't connect to cluster

```bash
# Verify kubeconfig
cat kubeconfig

# Test API endpoint
curl -k https://<node-ip>:6443

# Check kubelet
kubectl get cs  # Component status
```

### Issue: Template not found error

If you see an error like:
```
Talos template 'talos-1.11.4-nvidia-template' not found on Proxmox node 'pve'.
Build the template with Packer first.
```

**Solution:**
```bash
# Verify template exists in Proxmox
qm list | grep template

# Check template name matches exactly (case-sensitive)
# Update talos_template_name in terraform.tfvars

# If template doesn't exist, build it with Packer:
cd ../packer/talos
packer build .
```

This error is now caught by lifecycle preconditions for better error messages.

### Issue: Invalid env() function

If you see an error referencing `env()` function:
```
Call to unknown function: There is no function named "env".
```

**Solution:**
```bash
# env() is NOT valid in Terraform variable defaults
# Use TF_VAR_* environment variables instead

# Export variables (Terraform reads them automatically)
export TF_VAR_proxmox_api_token="PVEAPIToken=..."
export TF_VAR_proxmox_url="https://..."

# Or set in terraform.tfvars (not environment variables)
proxmox_api_token = "PVEAPIToken=..."
proxmox_url = "https://..."
```

### Issue: yamlencode syntax error

If you see an error in config_patches:
```
Invalid template interpolation value: Cannot use string template in yamlencode()
```

**Solution:**
This has been fixed in the latest version. The GPU sysctls are now properly separated into conditional config patches using Terraform's ternary operator:
```hcl
var.enable_gpu_passthrough ? yamlencode({
  machine = {
    sysctls = {
      "net.core.bpf_jit_harden" = "0"
    }
  }
}) : "",
```

Update to the latest version from the repository.

### Issue: Missing providers

If you see errors like:
```
Provider "local" is not available
Provider "null" is not available
```

**Solution:**
This has been fixed in versions.tf. Run:
```bash
terraform init -upgrade
```

The required providers are now declared:
- `hashicorp/local ~> 2.5` - for kubeconfig/talosconfig files
- `hashicorp/null ~> 3.2` - for provisioners and wait operations

### Issue: VM ID conflict

If deployment fails with:
```
VM 100 already exists
```

**Solution:**
The Talos VM default ID has been changed from 100 to 1000 to avoid conflicts with traditional VMs.

**VM ID Allocation:**
- **Talos**: 1000 (default, configurable)
- **Ubuntu**: 100-199
- **Debian**: 200-299
- **Arch**: 300-399
- **NixOS**: 400-499
- **Windows**: 500-599

Update node_vm_id in terraform.tfvars if needed.

### Issue: Terraform version constraint

If you see:
```
Terraform version constraint not satisfied
```

**Solution:**
Version constraint has been updated from `~> 1.13.5` (only 1.13.x) to `>= 1.13.5` (1.13.5 and later).

Update Terraform:
```bash
# Using tfenv
tfenv install latest
tfenv use latest

# Or download from terraform.io
```

## Advanced Topics

### Expanding to Multi-Node

To expand to 3-node HA cluster:

1. Create separate `.tfvars` files for each node:
   ```bash
   cp terraform.tfvars node1.tfvars
   cp terraform.tfvars node2.tfvars
   cp terraform.tfvars node3.tfvars
   ```

2. Edit each with unique IPs and VM IDs

3. Deploy:
   ```bash
   terraform apply -var-file=node1.tfvars
   terraform apply -var-file=node2.tfvars
   terraform apply -var-file=node3.tfvars
   ```

4. Bootstrap first node only

5. Join other nodes to cluster

### Using Workspaces

For multiple clusters:

```bash
# Create dev workspace
terraform workspace new dev
terraform apply -var-file=dev.tfvars

# Create prod workspace
terraform workspace new prod
terraform apply -var-file=prod.tfvars

# Switch workspaces
terraform workspace select dev
```

### Terraform State Management

For production, use remote backend:

```hcl
# In versions.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "talos/homelab.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Automated Updates

Use Renovate or Dependabot to automate version updates:

```json
{
  "terraform": {
    "enabled": true
  },
  "regexManagers": [
    {
      "fileMatch": ["^terraform/.+\\.tf$"],
      "matchStrings": ["version = \"~> (?<currentValue>.*?)\""],
      "datasourceTemplate": "terraform-provider",
      "depNameTemplate": "{{packageName}}"
    }
  ]
}
```

## Resources

- **Talos Documentation**: https://www.talos.dev/
- **Proxmox API**: https://pve.proxmox.com/pve-docs/api-viewer/
- **bpg/proxmox Provider**: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- **siderolabs/talos Provider**: https://registry.terraform.io/providers/siderolabs/talos/latest/docs
- **Cilium Documentation**: https://docs.cilium.io/
- **NVIDIA GPU Operator**: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/
- **NFS CSI Driver**: https://github.com/kubernetes-csi/csi-driver-nfs

## Next Steps

After deploying the cluster:

1. **Configure FluxCD** for GitOps continuous delivery
2. **Install monitoring** (kube-prometheus-stack)
3. **Install logging** (Loki)
4. **Set up ingress** (Cilium L7 or NGINX)
5. **Deploy workloads** via Helm or FluxCD

See `../ansible/` for Day 0/1/2 automation playbooks.

---

**Support**: For issues, check project documentation in `../CLAUDE.md` and `../docs/versions.md`.

## Traditional VMs Deployment

In addition to Talos Linux, this Terraform configuration can deploy traditional Linux and Windows VMs from Packer templates using a reusable module.

### Supported Operating Systems

- **Ubuntu 24.04 LTS** - General purpose development
- **Debian 12 (Bookworm)** - Stable server workloads
- **Arch Linux** - Rolling release, bleeding edge
- **NixOS** - Declarative configuration management
- **Windows Server 2022** - Windows workloads

### Module Architecture

```
terraform/
├── main.tf                  # Talos deployment
├── traditional-vms.tf       # Traditional VMs deployment (uses module)
├── modules/
│   └── proxmox-vm/         # Generic reusable VM module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── variables.tf            # All variables (Talos + traditional VMs)
└── outputs.tf              # All outputs (Talos + traditional VMs)
```

### Quick Start - Traditional VMs

**1. Build Packer templates:**

```bash
# Build all templates
cd ../packer/ubuntu-cloud && packer build .
cd ../packer/debian-cloud && packer build .
cd ../packer/arch && packer build .
cd ../packer/nixos && packer build .
cd ../packer/windows && packer build .
```

**2. Configure terraform.tfvars:**

```hcl
# Enable VMs you want to deploy
deploy_ubuntu_vm = true
deploy_debian_vm = true
deploy_arch_vm   = false
deploy_nixos_vm  = false
deploy_windows_vm = false

# Update template names (from Packer output)
ubuntu_template_name = "ubuntu-24.04-golden-template-20251118-1234"
debian_template_name = "debian-12-golden-template-20251118-1234"

# Configure resources
ubuntu_cpu_cores = 4
ubuntu_memory    = 8192   # MB
ubuntu_disk_size = 40     # GB

debian_cpu_cores = 4
debian_memory    = 8192   # MB
debian_disk_size = 40     # GB

# Network configuration
ubuntu_ip_address = "dhcp"  # Or "192.168.1.100/24" for static
debian_ip_address = "dhcp"  # Or "192.168.1.101/24" for static

# Cloud-init credentials
cloud_init_user     = "admin"
cloud_init_password = "changeme"
# cloud_init_ssh_keys = ["ssh-rsa AAAA..."]
```

**3. Deploy VMs:**

```bash
# Deploy all enabled VMs
terraform apply

# Or deploy specific VM
terraform apply -target=module.ubuntu_vm
terraform apply -target=module.debian_vm
```

**4. Verify deployment:**

```bash
# Check outputs
terraform output deployed_vms_summary

# SSH to VM (after cloud-init completes)
ssh admin@<vm-ip>
```

### Resource Allocation Guidelines

**System Resources:** 96GB RAM, 12 CPU cores

**Example Allocation:**

```
Proxmox overhead:  20GB RAM,  1-2 cores
Talos cluster:     32GB RAM,  8 cores   (primary, has GPU)
Ubuntu VM:         16GB RAM,  4 cores
Debian VM:         16GB RAM,  4 cores
Arch VM:           4GB RAM,   2 cores
Free buffer:       8GB RAM
----------------------------------------
Total:            96GB RAM,  ~24 threads (with SMT)
```

**Notes:**
- Talos gets GPU (can't share with traditional VMs)
- Adjust based on actual workload requirements
- Leave 5-10% RAM free for system overhead
- Use DHCP or static IPs based on network setup

### Proxmox VM Module Usage

The `modules/proxmox-vm` module is reusable for any VM deployment.

**Basic Example:**

```hcl
module "my_custom_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node  = "pve"
  template_name = "my-template-name"
  vm_name       = "my-vm"
  vm_id         = 150

  cpu_cores = 2
  memory    = 4096

  disks = [{
    datastore_id = "local-zfs"
    size         = 20
    interface    = "scsi0"
  }]

  network_devices = [{
    bridge = "vmbr0"
    model  = "virtio"
  }]

  enable_cloud_init = true
  cloud_init_user   = "admin"
  cloud_init_ssh_keys = ["ssh-rsa AAAA..."]

  tags = ["custom", "development"]
}
```

**See:** `modules/proxmox-vm/README.md` for complete documentation.

### VM Management

**Start/Stop VMs:**

```bash
# Via Proxmox CLI
qm start <vm-id>
qm stop <vm-id>
qm shutdown <vm-id>

# Or via Proxmox Web UI
```

**Enable/Disable VM Deployment:**

```hcl
# In terraform.tfvars
deploy_ubuntu_vm = false  # Skip deployment
```

Then run `terraform apply` to destroy disabled VMs.

**Update VM Configuration:**

```hcl
# Change resources in terraform.tfvars
ubuntu_cpu_cores = 8  # Increase CPUs
ubuntu_memory    = 16384  # Increase RAM

# Apply changes
terraform apply
```

Note: Some changes require VM restart.

**Add Additional Disks:**

```hcl
module "storage_vm" {
  source = "./modules/proxmox-vm"
  
  # ... other config ...

  disks = [
    {
      datastore_id = "local-zfs"
      size         = 20
      interface    = "scsi0"
    },
    {
      datastore_id = "local-zfs"
      size         = 100
      interface    = "scsi1"  # Additional disk
    }
  ]
}
```

### Deployment Scenarios

**Scenario 1: Talos Only (Kubernetes Focus)**

```hcl
# terraform.tfvars
deploy_ubuntu_vm  = false
deploy_debian_vm  = false
deploy_arch_vm    = false
deploy_nixos_vm   = false
deploy_windows_vm = false
```

**Scenario 2: Talos + Ubuntu Dev VM**

```hcl
deploy_ubuntu_vm   = true
ubuntu_cpu_cores   = 8
ubuntu_memory      = 16384
ubuntu_ip_address  = "192.168.1.100/24"
```

**Scenario 3: Mixed Linux Environment**

```hcl
deploy_ubuntu_vm = true  # Development
deploy_debian_vm = true  # Production services
deploy_arch_vm   = true  # Experimentation
```

**Scenario 4: Full Stack (All VMs)**

```hcl
deploy_ubuntu_vm  = true
deploy_debian_vm  = true
deploy_arch_vm    = true
deploy_nixos_vm   = true
deploy_windows_vm = true
```

Adjust resource allocation accordingly (see CLAUDE.md).

### Cloud-init Configuration

All Linux VMs support cloud-init for initial configuration.

**User Creation:**

```hcl
cloud_init_user     = "admin"
cloud_init_password = "changeme"
```

**SSH Key Authentication (Recommended):**

```hcl
cloud_init_ssh_keys = [
  "ssh-rsa AAAA... user@workstation",
  "ssh-ed25519 AAAA... user@laptop"
]
```

**Static IP Configuration:**

```hcl
ubuntu_ip_address = "192.168.1.100/24"
default_gateway   = "192.168.1.1"
dns_servers       = ["192.168.1.1", "8.8.8.8"]
dns_domain        = "home.local"
```

**Windows Configuration:**

Windows uses Cloudbase-Init (Windows equivalent of cloud-init):

```hcl
windows_cloud_init_user     = "Administrator"
windows_cloud_init_password = "ChangeMe123!"
```

### Troubleshooting Traditional VMs

**VM won't start:**

```bash
# Check VM status
qm status <vm-id>

# View VM config
qm config <vm-id>

# Check Proxmox logs
journalctl -u pve-cluster -f
```

**Template not found:**

```bash
# List templates
qm list | grep template

# Verify template name matches Packer output
# Update template_name variable in terraform.tfvars
```

**Cloud-init not working:**

```bash
# SSH to VM
ssh admin@<vm-ip>

# Check cloud-init status
sudo cloud-init status --wait
sudo cloud-init status --long

# View cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log
```

**Network issues:**

```bash
# Check VM network configuration
sudo ip addr show
sudo ip route show
sudo cat /etc/netplan/*.yaml  # Ubuntu
sudo cat /etc/network/interfaces  # Debian

# Test connectivity
ping 8.8.8.8
ping google.com
```

**QEMU Guest Agent:**

```bash
# Check agent status
sudo systemctl status qemu-guest-agent

# Start if stopped
sudo systemctl start qemu-guest-agent
sudo systemctl enable qemu-guest-agent
```

### Best Practices

**Security:**
- Use SSH keys instead of passwords for Linux VMs
- Change default cloud-init passwords immediately
- Keep VMs updated with security patches
- Use firewall rules (ufw on Ubuntu/Debian)

**Resource Management:**
- Monitor VM resource usage via Proxmox UI
- Adjust allocations based on actual usage
- Don't over-allocate resources
- Leave buffer for Proxmox host

**Backups:**
- Use Proxmox backup jobs for VMs
- Store backups on separate storage
- Test restore procedures regularly
- Consider NAS for backup storage

**Networking:**
- Use static IPs for infrastructure VMs
- DHCP acceptable for development VMs
- Document IP allocations
- Keep DNS records updated

**Template Management:**
- Rebuild templates monthly for security updates
- Version template names (include date)
- Test templates before production deployment
- Keep old templates for rollback

