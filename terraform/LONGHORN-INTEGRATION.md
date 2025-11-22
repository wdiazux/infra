# Longhorn Integration with Terraform

This document explains how Longhorn storage manager is integrated into the Terraform configuration for Talos Linux on Proxmox.

## Overview

Longhorn is configured as the **primary storage manager** for almost all services in the Talos Kubernetes cluster. The Terraform configuration automatically includes all necessary Talos machine config patches for Longhorn to function properly.

## Automatic Configuration

The following Longhorn requirements are **automatically configured** in `main.tf`:

###  1. Kernel Modules

```hcl
machine = {
  kernel = {
    modules = [
      { name = "nbd" }
      { name = "iscsi_tcp" }
      { name = "iscsi_generic" }
      { name = "configfs" }
    ]
  }
}
```

These kernel modules enable iSCSI and network block device support required by Longhorn.

### 2. Kubelet Extra Mounts

```hcl
kubelet = {
  extraMounts = [
    {
      destination = "/var/lib/longhorn"
      type = "bind"
      source = "/var/lib/longhorn"
      options = ["bind", "rshared", "rw"]
    }
  ]
}
```

The `rshared` propagation mode ensures volume mounts work correctly between the host and containers.

## Required Manual Configuration

### Step 1: Generate Talos Factory Schematic ID

**CRITICAL**: You must use a custom Talos image with Longhorn system extensions.

1. Visit **[Talos Factory](https://factory.talos.dev/)**

2. Select your Talos version (e.g., v1.11.4)

3. **Add required extensions**:
   - ✅ `siderolabs/iscsi-tools` (required)
   - ✅ `siderolabs/util-linux-tools` (required)
   - ✅ `siderolabs/qemu-guest-agent` (recommended for Proxmox)

4. **Add optional GPU extensions** (if using NVIDIA GPU):
   - `nonfree-kmod-nvidia-production`
   - `nvidia-container-toolkit-production`

5. Click **"Generate"** and copy the schematic ID

6. **Set the schematic ID** in `terraform.tfvars`:
   ```hcl
   talos_schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
   ```

### Step 2: Configure terraform.tfvars

Copy the example file and update it:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set:
# - talos_schematic_id (from Step 1)
# - node_ip, node_gateway, node_netmask
# - nfs_server and nfs_path (for Longhorn backups)
# - gpu_pci_id (if using GPU)
```

### Step 3: Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (review changes)
terraform plan

# Apply configuration
terraform apply
```

### Step 4: Install Longhorn

After Terraform completes successfully:

```bash
# 1. Verify cluster is ready
kubectl --kubeconfig=./kubeconfig get nodes

# 2. Create Longhorn namespace with pod security labels
kubectl create namespace longhorn-system
kubectl label namespace longhorn-system pod-security.kubernetes.io/enforce=privileged

# 3. Add Longhorn Helm repository
helm repo add longhorn https://charts.longhorn.io
helm repo update

# 4. Install Longhorn with custom values
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values ../kubernetes/longhorn/longhorn-values.yaml

# 5. Apply storage classes
kubectl apply -f ../kubernetes/storage-classes/longhorn-storage-classes.yaml

# 6. Verify installation
kubectl get pods -n longhorn-system
kubectl get storageclass
```

## Configuration Files

| File | Purpose |
|------|---------|
| `main.tf` | Automatically includes Longhorn kernel modules and kubelet mounts |
| `variables.tf` | Defines `talos_schematic_id` variable for Factory image |
| `terraform.tfvars.example` | Example configuration with Longhorn setup |
| `../kubernetes/longhorn/longhorn-values.yaml` | Helm values for Longhorn installation |
| `../kubernetes/longhorn/INSTALLATION.md` | Comprehensive Longhorn installation guide |
| `../kubernetes/storage-classes/longhorn-storage-classes.yaml` | Storage class definitions |

## How It Works

```
┌─────────────────────────────────────────────────┐
│  1. Terraform Deployment                        │
├─────────────────────────────────────────────────┤
│  • Creates Proxmox VM from Packer template      │
│  • Uses Talos Factory image (with extensions)   │
│  • Applies machine config with Longhorn patches │
│  • Bootstraps Kubernetes cluster                │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  2. Talos Node Configuration                    │
├─────────────────────────────────────────────────┤
│  • iscsi-tools extension loaded                 │
│  • util-linux-tools extension loaded            │
│  • Kernel modules: nbd, iscsi_tcp, etc.         │
│  • Kubelet extra mount: /var/lib/longhorn       │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  3. Longhorn Installation (Helm)                │
├─────────────────────────────────────────────────┤
│  • Longhorn manager pods deployed               │
│  • CSI driver installed                         │
│  • Default storage class created                │
│  • Single-replica mode (expandable to 3)        │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  4. Application Deployment                      │
├─────────────────────────────────────────────────┤
│  • PVCs automatically provisioned by Longhorn   │
│  • Volumes created on local cluster storage     │
│  • Backups stored on external NAS (optional)    │
└─────────────────────────────────────────────────┘
```

## Storage Architecture

### Primary Storage: Longhorn
- **Purpose**: All persistent volumes for databases, applications, user data
- **Location**: Local cluster storage (ZFS on Proxmox VM disk)
- **Features**: Snapshots, cloning, resize, web UI
- **Configuration**: Single-replica for single node (expandable to 3-replica HA)

### Backup Storage: External NAS (Optional but Recommended)
- **Purpose**: Off-cluster backups for disaster recovery
- **Location**: External NAS via NFS
- **Configuration**: Set in Longhorn UI or Helm values
- **Path**: Configured via `nfs_server` and `nfs_path` in terraform.tfvars

## Troubleshooting

### Issue: Pods Stuck in "Pending" with Volume Mount Errors

**Symptoms:**
- Pods with Longhorn PVCs stuck in Pending
- Events show: "Failed to mount volume"

**Solution:**
1. Verify schematic ID includes `iscsi-tools` and `util-linux-tools`:
   ```bash
   talosctl -n <node-ip> get extensions
   ```

2. Check kernel modules are loaded:
   ```bash
   talosctl -n <node-ip> read /proc/modules | grep -E 'nbd|iscsi'
   ```

3. Verify kubelet extra mounts:
   ```bash
   talosctl -n <node-ip> get machineconfig -o yaml | grep -A 5 extraMounts
   ```

### Issue: "Schematic not found" Error

**Symptoms:**
- Terraform fails during apply
- Error: "Schematic ... not found in factory"

**Solution:**
1. Verify schematic ID is correct (64-character hex string)
2. Ensure Talos Factory generated the schematic successfully
3. Check Talos version matches between Factory and `talos_version` variable
4. Regenerate schematic if necessary

### Issue: Longhorn Volume Degraded

**Symptoms:**
- Volumes show as "Degraded" in Longhorn UI
- Pods can't access storage

**Solution** (for single-node):
- This is expected with 1 replica (no redundancy)
- Data is still accessible
- To fix: Expand to 3-node cluster and increase replica count

## Expanding to 3-Node High Availability

When ready to expand your single-node cluster to 3-node HA:

1. **Deploy 2 additional Talos nodes** with same configuration
2. **Join nodes to cluster** via talosctl
3. **Update Longhorn replica count**:
   ```bash
   kubectl edit settings.longhorn.io default-replica-count -n longhorn-system
   # Change value from "1" to "3"
   ```

4. **Volumes automatically replicate** across 3 nodes
5. **No data migration required** - Longhorn handles it automatically

## Best Practices

### ✅ DO:
- Generate schematic ID with required extensions before Terraform deployment
- Use external NAS for Longhorn backups (disaster recovery)
- Allocate at least 200GB disk for Talos node (Longhorn needs space)
- Monitor disk usage via Longhorn UI
- Test backup/restore procedures regularly

### ❌ DON'T:
- Deploy without iscsi-tools and util-linux-tools extensions
- Use default Talos metal-amd64 image (missing extensions)
- Skip schematic ID configuration in terraform.tfvars
- Allocate less than 150GB disk (insufficient for Longhorn + workloads)
- Ignore "Degraded" warnings without understanding single-node limitations

## Additional Resources

- **Longhorn Installation Guide**: `../kubernetes/longhorn/INSTALLATION.md`
- **Longhorn Helm Values**: `../kubernetes/longhorn/longhorn-values.yaml`
- **Storage Classes**: `../kubernetes/storage-classes/longhorn-storage-classes.yaml`
- **Talos Longhorn Documentation**: https://www.talos.dev/v1.10/kubernetes-guides/configuration/storage/
- **Longhorn Official Docs**: https://longhorn.io/docs/
- **Talos Factory**: https://factory.talos.dev/

---

**Last Updated**: 2025-11-22
**Terraform Version**: >= 1.9
**Talos Version**: v1.11.4+
**Longhorn Version**: v1.7+
