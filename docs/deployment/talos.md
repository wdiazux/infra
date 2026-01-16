# Talos Deployment Guide

Complete guide for deploying a Talos Linux Kubernetes cluster on Proxmox VE.

---

## Overview

Talos Linux is an immutable, API-driven operating system purpose-built for Kubernetes. This project uses a **single-node cluster** configuration with:

- Cilium CNI with L2 LoadBalancer
- Longhorn storage with NFS backup
- Forgejo in-cluster Git server
- FluxCD GitOps
- NVIDIA GPU passthrough (optional)

**Deployment Time:** ~8-10 minutes

---

## Architecture

```
Talos Factory (factory.talos.dev)
    |
    v
Generate Schematic (select extensions)
    |
    v
import-talos-image.sh (download + import)
    |
    v
Template 9000 (talos-1.12.1-nvidia-template)
    |
    v
Terraform (clone template, configure, bootstrap)
    |
    v
Running Kubernetes Cluster
```

---

## Prerequisites

Before deploying, ensure you've completed the [Prerequisites Guide](../getting-started/prerequisites.md):

- [ ] Proxmox VE 9.0+ with API token
- [ ] Talos template 9000 imported
- [ ] SOPS Age key configured
- [ ] Secrets encrypted in `secrets/` directory

---

## Template Creation

Talos templates are created using **direct disk image import** from Talos Factory - not Packer. This is the recommended approach because:

- Talos has **no SSH** - Packer's communicator model doesn't work
- Talos requires **no customization** - configured via API after deployment
- Talos Factory provides **pre-built images** with custom extensions
- Direct import is **simpler and faster** than ISO-based workflows

### Generate Schematic

1. Visit https://factory.talos.dev/
2. Select **Platform**: Nocloud
3. Select **Version**: v1.12.1
4. Add **Required** extensions:
   - `siderolabs/qemu-guest-agent` - Proxmox integration
   - `siderolabs/iscsi-tools` - Longhorn storage
   - `siderolabs/util-linux-tools` - Longhorn volumes
5. Add **Optional** extensions (for GPU):
   - `siderolabs/nonfree-kmod-nvidia-production`
   - `siderolabs/nvidia-container-toolkit-production`
6. Click **Generate** and copy the Schematic ID

### Import Template

```bash
# Copy script to Proxmox
scp packer/talos/import-talos-image.sh root@pve:/tmp/

# SSH and run
ssh root@pve
cd /tmp && ./import-talos-image.sh

# Template 9000 created (~2-5 minutes)
```

---

## Deployment

### Quick Deploy

```bash
cd terraform/talos

# Initialize
terraform init

# Review
terraform plan

# Deploy
terraform apply -auto-approve
```

### What Terraform Does

1. **Clone template** to VM 1000
2. **Configure VM** - CPU, RAM, GPU passthrough
3. **Generate Talos secrets** - Cluster certificates
4. **Apply machine config** - Network, Kubernetes settings
5. **Bootstrap Kubernetes** - Initialize etcd, control plane
6. **Install Cilium** - CNI with L2 announcements
7. **Install Longhorn** - Distributed storage
8. **Deploy Forgejo** - Git server
9. **Bootstrap FluxCD** - GitOps

### Configuration

Customize deployment via `terraform.tfvars`:

```hcl
# Network
node_ip       = "10.10.2.10"
node_gateway  = "10.10.2.1"
dns_servers   = ["10.10.2.1", "8.8.8.8"]

# Resources
node_cpu_cores = 8
node_memory    = 32768  # MB
node_disk_size = 200    # GB

# GPU (optional)
enable_gpu_passthrough = true
gpu_mapping            = "nvidia-gpu"

# Services
enable_forgejo         = true
enable_fluxcd          = true
enable_longhorn_backups = true
```

---

## Verification

### Check Cluster

```bash
export KUBECONFIG=./kubeconfig
export TALOSCONFIG=./talosconfig

# Talos dashboard
talosctl dashboard

# Node status
kubectl get nodes

# All pods
kubectl get pods -A
```

### Check Services

| Service | URL | Check |
|---------|-----|-------|
| Kubernetes API | https://10.10.2.10:6443 | `kubectl get nodes` |
| Talos API | https://10.10.2.10:50000 | `talosctl health` |
| Hubble UI | http://10.10.2.11 | Cilium observability |
| Longhorn UI | http://10.10.2.12 | Storage management |
| Forgejo | http://10.10.2.13 | Git server |

### Check FluxCD

```bash
# Git repository status
flux get sources git -A

# Kustomization status
flux get kustomizations -A
```

---

## Single-Node Considerations

### Control Plane Taint

Terraform automatically removes the control-plane taint to allow workload scheduling:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### Longhorn Replicas

With a single node, Longhorn runs in single-replica mode. When adding nodes later, increase the replica count.

### High Availability

For production workloads, consider expanding to 3 nodes for:
- etcd quorum
- Control plane redundancy
- Longhorn data replication

---

## GPU Passthrough

### Enable in Terraform

```hcl
enable_gpu_passthrough = true
gpu_mapping            = "nvidia-gpu"
```

### Verify GPU

```bash
# Check GPU in cluster
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'

# Test GPU pod
kubectl run gpu-test \
  --image=nvidia/cuda:12.0-base \
  --restart=Never \
  --rm -it \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi
```

---

## Upgrading

### Talos Version

1. Generate new schematic at factory.talos.dev
2. Update `import-talos-image.sh` with new version/schematic
3. Import new template (different VM ID)
4. Update `terraform.tfvars`:
   ```hcl
   talos_version       = "v1.13.0"
   talos_template_name = "talos-1.13.0-nvidia-template"
   ```
5. Plan carefully - this requires node migration

### Kubernetes Version

```bash
# Via talosctl
talosctl upgrade-k8s --nodes 10.10.2.10 --to v1.36.0
```

---

## Terraform Inputs (Key Variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `node_ip` | 10.10.2.10 | Static IP for Talos node |
| `node_gateway` | 10.10.2.1 | Network gateway |
| `node_cpu_cores` | 8 | CPU cores |
| `node_memory` | 32768 | RAM in MB |
| `node_disk_size` | 200 | Disk in GB |
| `enable_gpu_passthrough` | true | Enable NVIDIA GPU |
| `talos_version` | v1.12.1 | Talos Linux version |
| `kubernetes_version` | v1.35.0 | Kubernetes version |
| `cilium_version` | 1.18.6 | Cilium chart version |
| `longhorn_version` | 1.10.1 | Longhorn chart version |
| `forgejo_chart_version` | 16.0.0 | Forgejo chart version |
| `postgresql_version` | 18.2.0 | PostgreSQL chart version |

See `terraform/talos/TERRAFORM.md` for complete input/output reference.

---

## Terraform Outputs

| Output | Description |
|--------|-------------|
| `kubeconfig_path` | Path to kubeconfig file |
| `talosconfig_path` | Path to talosconfig file |
| `cluster_endpoint` | Kubernetes API endpoint |
| `node_ip` | Talos node IP address |
| `hubble_ui_url` | Cilium Hubble UI URL |
| `longhorn_ui_url` | Longhorn UI URL |
| `forgejo_http_url` | Forgejo Git server URL |

---

## Troubleshooting

### Node Stuck in NotReady

**Cause:** CNI not installed yet
**Solution:** Wait for Cilium installation or check Terraform logs

### Template Not Found

**Cause:** Template name mismatch
**Solution:**
```bash
# Check template name
qm list | grep template
# Update terraform.tfvars to match
```

### Longhorn Volumes Fail

**Cause:** Missing extensions in Talos image
**Solution:** Regenerate schematic with `iscsi-tools` and `util-linux-tools`

### GPU Not Detected

**Cause:** IOMMU not enabled or drivers not loaded
**Solution:**
1. Enable IOMMU in BIOS
2. Configure GRUB (see [Prerequisites](../getting-started/prerequisites.md))
3. Verify GPU mapping in Proxmox
4. Ensure schematic includes NVIDIA extensions

---

## Resources

- [Talos Documentation](https://www.talos.dev/)
- [Talos Factory](https://factory.talos.dev/)
- [Talos on Proxmox](https://www.talos.dev/v1.12/talos-guides/install/virtualized-platforms/proxmox/)
- [Terraform Provider](https://registry.terraform.io/providers/siderolabs/talos/latest)

---

**Last Updated:** 2026-01-15
