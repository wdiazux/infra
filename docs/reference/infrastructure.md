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

## Proxmox Storage Configuration

| Setting | Value |
|---------|-------|
| Pool Name | `tank` |
| Type | ZFS |
| ZFS ARC Max | 16GB |
| VM Disk Format | raw |

All VMs use ZFS storage exclusively.

---

## TrueNAS Storage (NAS)

**System:** TrueNAS Community Edition (hostname: `atlas`)
**IP Address:** 10.10.2.5

### Storage Pools

| Pool | Type | Raw Capacity | Usable Capacity | Available | Purpose |
|------|------|--------------|-----------------|-----------|---------|
| **tank** | RAIDZ1 (5 disks) | 3.64 TiB | 14.39 TiB | 13.69 TiB | Primary media storage |
| **downloads** | Single disk | 1.82 TiB | 1.76 TiB | 1.76 TiB | Download staging |

**Total Usable Capacity:** ~16.15 TiB

### Pool Health & Maintenance

| Pool | Health | Auto TRIM | Scrub Schedule |
|------|--------|-----------|----------------|
| tank | Online | On | Day 1 of month, 03:00 |
| downloads | Online | Off | Sunday, 00:00 |

### NFS Exports (Kubernetes)

| Export Path | K8s PVC | Namespace | Capacity |
|-------------|---------|-----------|----------|
| `/mnt/tank/media` | `nfs-media` | arr-stack, media | 1 TiB |
| `/mnt/downloads/...` | `nfs-downloads` | arr-stack | 500 Gi |

**Note:** The `downloads` pool (single disk) has no redundancy. Critical data should be stored on the RAIDZ1 `tank` pool.

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

## Deployed Applications

Applications deployed via FluxCD GitOps. For current container versions, see [Services Reference](services.md). For IP addresses, see [Network Reference](network.md).

### Quick Reference by Namespace

| Namespace | Services | Purpose |
|-----------|----------|---------|
| `monitoring` | VictoriaMetrics, VMAgent, Grafana, kube-state-metrics, node-exporter | Observability |
| `automation` | Home Assistant, n8n | Smart home, workflows |
| `ai` | Ollama, Open WebUI, ComfyUI | LLM inference, image generation |
| `media` | Immich, Emby, Navidrome | Photos, video, music |
| `arr-stack` | SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr | Media automation |
| `tools` | Homepage, IT-Tools, Attic, ntfy | Developer utilities |
| `management` | Paperless-ngx, Wallos | Documents, subscriptions |
| `printing` | Obico | 3D printer monitoring |
| `backup` | MinIO, Velero | Disaster recovery |
| `forgejo` | Forgejo, Forgejo Runner | Git server, CI/CD |

---

**Last Updated:** 2026-01-21
