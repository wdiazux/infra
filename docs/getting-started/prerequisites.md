# Prerequisites

Setup requirements before deploying the Talos Kubernetes cluster.

---

## Required Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Proxmox VE | 9.0+ | Hypervisor |
| Nix | Latest | Development environment |
| SOPS + Age | Latest | Secrets encryption |
| Talos Template | 9000 | VM template |

---

## 1. Proxmox Setup

### Create Terraform API User

```bash
# SSH into Proxmox host
ssh root@pve

# Create user (PVE realm - API-only access)
pveum useradd terraform@pve --comment "Terraform automation user"

# Create role with required privileges (Proxmox 9.0 compatible)
pveum roleadd TerraformProv -privs "Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,Sys.PowerMgmt,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt,VM.GuestAgent.Audit"

# Assign role to user
pveum aclmod / -user terraform@pve -role TerraformProv

# Create API token
pveum user token add terraform@pve terraform-token --privsep 0
# Save the token ID and secret!
```

### Verify Setup

```bash
# Check Proxmox version
pveversion  # Should show 9.x

# Check storage pool exists
zpool list  # Should show 'tank'

# Check network bridge
ip link show vmbr0
```

---

## 2. Development Environment

This project uses Nix for reproducible tooling.

### Install Nix

```bash
# Linux/macOS
sh <(curl -L https://nixos.org/nix/install)
```

### Enter Development Shell

```bash
cd /path/to/infra

# With direnv (recommended)
echo "use nix" > .envrc
direnv allow

# Or manually
nix-shell
```

All tools are now available: `terraform`, `packer`, `talosctl`, `kubectl`, `sops`, etc.

---

## 3. SOPS + Age Setup

### Generate Age Key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Get public key
age-keygen -y ~/.config/sops/age/keys.txt
```

### Configure Environment

Add to `~/.bashrc`:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

### Update .sops.yaml

Replace the public key in `.sops.yaml` with yours.

---

## 4. Create Talos Template

### Generate Schematic

1. Visit https://factory.talos.dev/
2. Select **Platform**: Nocloud
3. Select **Version**: v1.12.1
4. Add **Extensions**:
   - `siderolabs/qemu-guest-agent` (required)
   - `siderolabs/iscsi-tools` (required for Longhorn)
   - `siderolabs/util-linux-tools` (required for Longhorn)
   - `siderolabs/nonfree-kmod-nvidia-production` (optional, GPU)
   - `siderolabs/nvidia-container-toolkit-production` (optional, GPU)
5. Click **Generate** and copy the Schematic ID

### Import Template

```bash
# Copy script to Proxmox
scp packer/talos/import-talos-image.sh root@pve:/tmp/

# SSH and run
ssh root@pve
cd /tmp
./import-talos-image.sh
# Template 9000 created
```

---

## 5. Configure Secrets

### Encrypt Proxmox Credentials

```bash
# Create plaintext file
cat > secrets/proxmox-creds.yaml <<EOF
proxmox_url: "https://pve:8006/api2/json"
proxmox_user: "terraform@pve"
proxmox_token_id: "terraform-token"
proxmox_token_secret: "your-secret-here"
proxmox_node: "pve"
proxmox_storage_pool: "tank"
EOF

# Encrypt
sops -e secrets/proxmox-creds.yaml > secrets/proxmox-creds.enc.yaml
rm secrets/proxmox-creds.yaml
```

---

## 6. GPU Passthrough (Optional)

### Enable IOMMU

```bash
# Edit GRUB (AMD CPU)
nano /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"

# Update and reboot
update-grub && reboot
```

### Create GPU Mapping

In Proxmox UI: **Datacenter** → **Resource Mappings** → **PCI Devices** → **Add**

- Name: `nvidia-gpu`
- Device: Select your NVIDIA GPU

---

## Verification Checklist

Before running `terraform apply`:

- [ ] Proxmox VE 9.0+ installed
- [ ] Terraform API user created with correct privileges
- [ ] ZFS pool `tank` exists
- [ ] Network bridge `vmbr0` configured
- [ ] Nix shell working (all tools available)
- [ ] SOPS Age key generated and configured
- [ ] `.sops.yaml` updated with your public key
- [ ] Proxmox credentials encrypted
- [ ] Talos template 9000 imported
- [ ] (Optional) IOMMU enabled for GPU passthrough
- [ ] (Optional) GPU mapping created

---

## Quick Reference

### Network (Default)

| Component | IP |
|-----------|-----|
| Gateway | 10.10.2.1 |
| Proxmox | 10.10.2.2 |
| Talos Node | 10.10.2.10 |
| LoadBalancer Pool | 10.10.2.11-150 |

### Storage

- Pool: `tank` (ZFS)
- Template ID: 9000
- VM Disk: 200GB

---

**Next:** [Quickstart Guide](quickstart.md)
