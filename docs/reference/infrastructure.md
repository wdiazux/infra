# Infrastructure Reference

Hardware specs, assumptions, and configuration values.

---

## Hardware Platform

**System:** Minisforum MS-A2

| Component | Specification |
|-----------|--------------|
| CPU | AMD Ryzen AI 9 HX 370 (12 cores) |
| RAM | 96GB |
| GPU | NVIDIA RTX 4000 SFF Ada (AD104GL) |
| Storage | 2x NVMe (ZFS mirror) |
| NICs | Intel X710 10GbE, Intel I226-V 2.5GbE |

---

## PCI IDs for Passthrough

| Device | PCI ID | Notes |
|--------|--------|-------|
| NVIDIA RTX 4000 | `07:00.0` | GPU passthrough |
| NVIDIA Audio | `07:00.1` | Pass with GPU |
| AMD iGPU | `01:00.0` | Proxmox display |
| Intel X710 | `05:00.0`, `05:00.1` | Dual SFP+ |
| Intel I226-V | `04:00.0` | Management NIC |

**IOMMU:** AMD IOMMU at `00:00.2`

---

## Storage Configuration

| Setting | Value |
|---------|-------|
| Pool Name | `tank` |
| Type | ZFS |
| ZFS ARC Max | 16GB |
| VM Disk Format | raw |

All VMs use ZFS storage exclusively.

---

## Resource Allocation

### Talos Node (Default)

| Resource | Value |
|----------|-------|
| CPU | 8 cores |
| RAM | 32GB |
| Disk | 200GB |
| GPU | RTX 4000 (passthrough) |

### Traditional VMs (Default)

| Resource | Value |
|----------|-------|
| CPU | 4 cores |
| RAM | 8GB |
| Disk | 40GB |

### System Overhead

| Component | RAM |
|-----------|-----|
| Proxmox | 4GB |
| ZFS ARC | 16GB |
| Available for VMs | 76GB |

---

## VM ID Ranges

| Type | Range | Default ID |
|------|-------|------------|
| Talos | 1000-1999 | 1000 |
| Template | 9000-9999 | 9000 |
| Ubuntu | 100-199 | 100 |
| Debian | 200-299 | 200 |
| Arch | 300-399 | 300 |
| NixOS | 400-499 | 400 |
| Windows | 500-599 | 500 |

---

## Talos Extensions

**Required for Longhorn:**
- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`

**Required for Proxmox:**
- `siderolabs/qemu-guest-agent`

**Optional for GPU:**
- `siderolabs/nonfree-kmod-nvidia-production`
- `siderolabs/nvidia-container-toolkit-production`

**Current Schematic ID:**
```
b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321
```

---

## Default Credentials

| Service | Username | Auth | Location |
|---------|----------|------|----------|
| Proxmox API | terraform@pve | Token | `secrets/proxmox-creds.enc.yaml` |
| Forgejo Admin | wdiaz | Password | `secrets/git-creds.enc.yaml` |
| VM User | admin | SSH Key | cloud-init |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `terraform/talos/kubeconfig` | Kubernetes access |
| `terraform/talos/talosconfig` | Talos access |
| `.sops.yaml` | SOPS encryption rules |
| `secrets/*.enc.yaml` | Encrypted credentials |

---

## Assumptions

These values are hard-coded or defaulted:

| Setting | Default | Location |
|---------|---------|----------|
| Proxmox Node | `pve` | `terraform/variables.tf` |
| Storage Pool | `tank` | `terraform/variables.tf` |
| Network Bridge | `vmbr0` | `terraform/variables.tf` |
| Gateway | `10.10.2.1` | `terraform/variables.tf` |
| DNS | `8.8.8.8` | `terraform/variables.tf` |
| CPU Type | `host` | `terraform/vm.tf` |
| Timezone | `America/El_Salvador` | `talos/*.yaml` |

---

## Customization

To customize for your environment:

```hcl
# terraform/terraform.tfvars

# Network
node_ip = "10.10.2.10"
node_gateway = "10.10.2.1"
dns_servers = ["8.8.8.8", "8.8.4.4"]

# Resources
node_cpu_cores = 8
node_memory = 32768  # MB
node_disk_size = 200  # GB

# Storage
node_disk_storage = "tank"

# Optional
enable_gpu = true
gpu_mapping = "nvidia-gpu"
```

---

**Last Updated:** 2026-01-15
