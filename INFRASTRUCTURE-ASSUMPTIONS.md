# Infrastructure Assumptions & Prerequisites

This document lists all hard-coded assumptions in the infrastructure code. Review and customize these values for your specific environment before deployment.

---

## 🎯 Critical Prerequisites

### 1. Proxmox VE Environment

**Required:**
- **Proxmox VE Version:** 9.0 or later
- **Node Name:** Default is `pve` (customize in `terraform/variables.tf`)
- **API Access:** API token or password authentication
- **Network Access:** Packer build machine must reach Proxmox API

**To verify:**
```bash
# Check Proxmox version
pveversion

# List nodes
pvecm nodes  # or pvesh get /nodes

# Test API access
curl -k https://YOUR_PROXMOX_IP:8006/api2/json/version
```

---

## 💾 Storage Configuration

### ZFS Storage Pool

**This infrastructure uses ZFS for all VM storage.**

**Assumption:** ZFS storage pool named `tank` exists and is accessible.

**Storage Architecture:**
- **All VMs** (Talos, Ubuntu, Debian, Arch, NixOS, Windows) use ZFS storage
- **Storage Pool:** `tank` (ZFS)
- **Benefits:** Snapshots, compression, data integrity, copy-on-write

**Default in code:**
- Packer: `vm_disk_storage = "tank"`
- Terraform: `node_disk_storage = "tank"`

**To verify:**
```bash
# List storage pools
pvesm status

# Check ZFS pool
zpool list
zfs list
```

**If your storage pool has a different name:**
1. Update Packer variables: `packer/*/variables.pkr.hcl`
   ```hcl
   variable "vm_disk_storage" {
     default = "YOUR-STORAGE-POOL"  # Change this
   }
   ```

2. Update Terraform variables: `terraform/variables.tf`
   ```hcl
   variable "node_disk_storage" {
     default = "YOUR-STORAGE-POOL"  # Change this
   }
   ```

**Common Proxmox storage types:**
- `tank` - **ZFS pool (USED IN THIS PROJECT)**
- `local-zfs` - ZFS pool (alternative name)
- `local-lvm` - LVM-thin (not used)
- `local` - Directory storage (not used for VMs)

**This project exclusively uses ZFS (`tank`) for all VM virtual disks.**

---

## 🌐 Network Configuration

### Network Bridge

**Assumption:** Network bridge `vmbr0` exists and is connected to your network.

**Default in code:**
- Packer: `vm_network_bridge = "vmbr0"`
- Terraform: `network_bridge = "vmbr0"`

**To verify:**
```bash
# List network interfaces
ip link show

# Check bridge configuration
brctl show  # or: bridge link

# Proxmox web UI: Node → System → Network
```

**If using a different bridge:**
- Update variables in Packer and Terraform configurations
- Common alternatives: `vmbr1`, `vmbr2`, etc.

### Network Settings

**Assumptions:**
- **Gateway:** `10.10.2.1`
- **Proxmox Host:** `10.10.2.2`
- **DNS Servers:** `8.8.8.8`, `8.8.4.4` (Google DNS)
- **Subnet:** `10.10.2.0/24` (Class C private network)
- **DHCP:** Available for traditional VMs (optional)

**Your network may differ!**
- Corporate networks often use `10.0.0.0/8` or `172.16.0.0/12`
- Gateway might be `.254` or `.1` depending on router
- DNS servers might be internal (e.g., `10.10.2.1`)

**To customize:**
1. Terraform variables: `terraform/variables.tf`
   ```hcl
   variable "node_gateway" {
     default = "YOUR-GATEWAY"  # e.g., "10.10.2.1"
   }

   variable "dns_servers" {
     default = ["YOUR-DNS-1", "YOUR-DNS-2"]
   }
   ```

2. Ansible inventory: `ansible/inventories/terraform-managed.yml`
   ```yaml
   vars:
     dns_servers:
       - YOUR-DNS-1
       - YOUR-DNS-2
   ```

---

## 🔢 IP Address Allocation

### Network: 10.10.2.0/24

**Complete IP allocation table for this infrastructure:**

| Component | IP Address | Notes |
|-----------|------------|-------|
| **Gateway** | 10.10.2.1 | Router/gateway (REQUIRED) |
| **Proxmox Host** | 10.10.2.2 | Hypervisor host (REQUIRED) |
| **NAS** | 10.10.2.5 | External NAS for Longhorn backups (OPTIONAL) |
| **Talos Node** | 10.10.2.10 | Primary Kubernetes node (REQUIRED) |
| **Ubuntu VM** | 10.10.2.11 | Traditional VM (OPTIONAL) |
| **Debian VM** | 10.10.2.12 | Traditional VM (OPTIONAL) |
| **Arch VM** | 10.10.2.13 | Traditional VM (OPTIONAL) |
| **NixOS VM** | 10.10.2.14 | Traditional VM (OPTIONAL) |
| **Windows VM** | 10.10.2.15 | Traditional VM (OPTIONAL) |
| **DHCP Range** | 10.10.2.100-200 | If using DHCP for other devices |
| **Cilium LoadBalancer Pool** | 10.10.2.240-254 | For Kubernetes LoadBalancer services |

### Talos Node

**Required:** Static IP address must be set manually.

**Default:** EMPTY (must be configured in `terraform.tfvars`)

**Example allocation:**
- **Gateway:** `10.10.2.1` (REQUIRED - your router)
- **Proxmox:** `10.10.2.2` (REQUIRED - hypervisor host)
- **NAS:** `10.10.2.5` (OPTIONAL - for Longhorn backups)
- **Talos Node:** `10.10.2.10` (REQUIRED - Kubernetes node)
- **Traditional VMs:** `10.10.2.11-15` (OPTIONAL)
- **DHCP Range:** `10.10.2.100-200` (if using DHCP)
- **LoadBalancer Pool:** `10.10.2.240-254` (Cilium L2)

**IMPORTANT:** Ensure IP addresses don't conflict with:
- DHCP pool range
- Other static devices (router, NAS, etc.)
- Proxmox host itself

**To set:**
```hcl
# terraform/terraform.tfvars
node_ip = "10.10.2.10"  # Your chosen static IP
```

### Traditional VMs

**Options:**
- **DHCP:** Default behavior (VM gets IP from router)
- **Static:** Set in `terraform/terraform.tfvars`
  ```hcl
  ubuntu_ip_address = "10.10.2.11/24"
  debian_ip_address = "10.10.2.12/24"
  arch_ip_address   = "10.10.2.13/24"
  nixos_ip_address  = "10.10.2.14/24"
  windows_ip_address = "10.10.2.15/24"
  ```

---

## 🖥️ VM ID Ranges

**Assumption:** VM IDs follow this convention:

| VM Type | Range | Default |
|---------|-------|---------|
| Talos | 1000-1999 | 1000 |
| Ubuntu | 100-199 | 100 |
| Debian | 200-299 | 200 |
| Arch | 300-399 | 300 |
| NixOS | 400-499 | 400 |
| Windows | 500-599 | 500 |

**These MUST be unique cluster-wide** (across all Proxmox nodes).

**To check for conflicts:**
```bash
# List all VM IDs in use
qm list

# Or via API
pvesh get /cluster/resources --type vm
```

---

## 🔐 Authentication & Access

### Proxmox API

**Assumptions:**
- **Username:** `root@pam` (PAM authentication)
- **Auth method:** API token recommended (password also supported)

**To create API token:**
```bash
# Proxmox web UI: Datacenter → Permissions → API Tokens
# Or via CLI:
pveum user token add root@pam mytoken --privsep=0
```

**To use:**
```bash
# Environment variable
export PROXMOX_TOKEN="PVEAPIToken=root@pam!mytoken=<your-secret>"

# Or in terraform.tfvars (encrypted with SOPS)
proxmox_api_token = "PVEAPIToken=root@pam!mytoken=<your-secret>"
```

### VM Access

**Assumptions:**
- **Cloud-init user:** `admin`
- **Default password:** `changeme` (should be changed immediately)
- **SSH keys:** Injected via cloud-init (recommended)

**Security best practice:**
- Use SSH keys, not passwords
- Disable password authentication after key injection
- Change default credentials immediately

---

## 🎮 GPU Passthrough (Optional)

### Single GPU Limitation

**Critical constraint:** Consumer GPUs (like RTX 4000) can only be passed through to **ONE VM at a time**.

**Assumption in code:**
- GPU assigned to Talos node only
- Traditional VMs do NOT get GPU access

**Requirements for GPU passthrough:**
1. **BIOS:** IOMMU enabled (AMD-Vi or Intel VT-d)
2. **GRUB:** IOMMU kernel parameters configured
3. **Proxmox host:** NVIDIA drivers blacklisted
4. **PCI device:** GPU bound to VFIO driver

**To configure:**
See `PROXMOX-SETUP.md` for complete GPU passthrough guide.

**GPU PCI ID:**
- **Default assumption:** `01:00` (your GPU may differ)
- Find your GPU: `lspci | grep -i nvidia`
- Update in `terraform/variables.tf`: `gpu_pci_id = "YOUR:ID"`

---

## ⏰ Timezone & Localization

**Assumptions:**
- **Timezone:** UTC
- **NTP Servers:** `time.cloudflare.com`
- **Locale:** en_US.UTF-8 (system default)

**To customize:**
- Terraform: `terraform/variables.tf`
  ```hcl
  variable "ntp_servers" {
    default = ["YOUR-NTP-SERVER"]
  }
  ```

- Ansible: Update playbooks to set desired timezone
  ```yaml
  - name: Set timezone
    community.general.timezone:
      name: America/New_York  # Your timezone
  ```

---

## 📦 System Resources

### Minimum Requirements

**Proxmox Host (assumed specs: Minisforum MS-A2):**
- **RAM:** 96GB total (20GB for Proxmox + ZFS ARC, 76GB available for VMs)
- **CPU:** 12 cores (AMD Ryzen AI 9 HX 370)
- **Storage:** 2x NVMe in ZFS mirror (assumed 2TB usable)

**Talos Node (default allocation):**
- **RAM:** 32GB
- **CPU:** 8 cores
- **Disk:** 200GB
- **GPU:** RTX 4000 (if enabled)

**Traditional VMs (example defaults):**
- **Ubuntu:** 8GB RAM, 4 cores, 40GB disk
- **Debian:** 8GB RAM, 4 cores, 40GB disk

**IMPORTANT:** Adjust resource allocation based on YOUR hardware.

**To customize:**
```hcl
# terraform/terraform.tfvars
node_cpu_cores = 6        # Reduce if less CPU available
node_memory = 24576       # 24GB instead of 32GB
ubuntu_memory = 4096      # 4GB instead of 8GB
```

---

## 🗄️ External Storage (Optional)

### NAS / NFS Server

**Assumption:** External NAS is optional (used only for Longhorn backups).

**Default values:**
- **NFS Server:** Empty (not configured)
- **NFS Path:** `/mnt/tank/longhorn-backups`

**If you have a NAS:**
```hcl
# terraform/terraform.tfvars
nfs_server = "10.10.2.5"  # Your NAS IP
nfs_path = "/volume1/backups/longhorn"  # Your NFS export
```

**NAS must:**
- Be reachable from Talos node
- Have NFS shares configured and exported
- Allow connections from your network

---

## 🔧 Talos-Specific Assumptions

### Factory Image & Extensions

**Assumption:** You will generate a custom Talos image with required extensions.

**Required extensions for Longhorn:**
- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`

**Recommended:**
- `siderolabs/qemu-guest-agent` (Proxmox integration)

**Optional (if using GPU):**
- `nonfree-kmod-nvidia-production`
- `nvidia-container-toolkit-production`

**To generate:**
1. Visit https://factory.talos.dev/
2. Select platform: "Metal" (for Talos 1.8.0+)
3. Add extensions
4. Copy schematic ID
5. Set in `terraform/terraform.tfvars`:
   ```hcl
   talos_schematic_id = "your-64-char-hex-id"
   ```

### CPU Type

**Critical assumption:** VM CPU type is set to `host`.

**Why:** Talos v1.0+ requires x86-64-v2 microarchitecture support.

**Verification:** This is hardcoded and validated in code (see `terraform/variables.tf`).

---

## 📋 Validation Checklist

Before deploying, verify these assumptions match your environment:

### Proxmox
- [ ] Proxmox VE 9.0 or later installed
- [ ] Node name is `pve` OR updated in all configs
- [ ] API token created and tested
- [ ] Network bridge `vmbr0` exists OR updated in configs
- [ ] Storage pool `tank` exists OR updated in configs

### Network
- [ ] Gateway IP confirmed (default: `10.10.2.1`)
- [ ] DNS servers confirmed (default: `8.8.8.8`, `8.8.4.4`)
- [ ] Subnet confirmed (default: `10.10.2.0/24`)
- [ ] Static IPs chosen and not conflicting

### Resources
- [ ] Sufficient RAM available (76GB minimum for example allocation)
- [ ] Sufficient CPU cores (10-11 cores available)
- [ ] Sufficient disk space (2TB+ recommended)

### Talos
- [ ] Talos Factory schematic generated with required extensions
- [ ] Schematic ID set in terraform.tfvars
- [ ] Static IP chosen for Talos node
- [ ] CPU type set to `host` (default, verified)

### Optional
- [ ] GPU PCI ID identified (if using GPU passthrough)
- [ ] NAS NFS shares configured (if using external backup)
- [ ] IOMMU enabled in BIOS (if using GPU)

---

## 🚀 Quick Start Customization

**Minimum required changes for deployment:**

1. **Create `terraform/terraform.tfvars`:**
   ```hcl
   # REQUIRED
   node_ip = "10.10.2.10"  # Your Talos node IP

   # REQUIRED if using custom Talos image
   talos_schematic_id = "your-64-char-hex-id-from-factory"

   # OPTIONAL (only if your environment differs from defaults)
   proxmox_node = "your-node-name"  # if not 'pve'
   node_gateway = "your-gateway"    # if not 10.10.2.1
   dns_servers = ["dns1", "dns2"]   # if not using Google DNS
   ```

2. **If storage pool is different:**
   - Update `packer/*/variables.pkr.hcl`
   - Update `terraform/variables.tf`

3. **If network bridge is different:**
   - Update `packer/*/variables.pkr.hcl`
   - Update `terraform/variables.tf`

---

## 📚 Related Documentation

- **Proxmox Setup:** `PROXMOX-SETUP.md`
- **Deployment Guide:** `README.md`
- **Research Reports:**
  - Packer: `docs/packer-proxmox-research-report.md`
  - Ansible: `docs/ANSIBLE_RESEARCH_REPORT.md`
  - Talos: `docs/talos-research-report.md`

---

**Last Updated:** November 23, 2025
**Project:** wdiazux/infra
**Homelab Setup:** Single MS-A2 with Proxmox VE 9.0
