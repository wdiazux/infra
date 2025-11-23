# Talos Linux Packer Template for Proxmox

This directory contains Packer configuration to build a customized Talos Linux template for Proxmox VE 9.0 with NVIDIA GPU support and qemu-guest-agent integration.

## Overview

Talos Linux is an immutable, minimal Linux distribution designed specifically for running Kubernetes. This Packer template creates a Proxmox VM template from a custom Talos Factory image that includes:

- **siderolabs/qemu-guest-agent**: Proxmox integration for better VM management
- **siderolabs/iscsi-tools**: iSCSI support for Longhorn storage (**REQUIRED**)
- **siderolabs/util-linux-tools**: Volume management for Longhorn storage (**REQUIRED**)
- **nonfree-kmod-nvidia-production**: NVIDIA GPU drivers for GPU passthrough (optional)
- **nvidia-container-toolkit-production**: NVIDIA container runtime for Kubernetes GPU workloads (optional)

## Prerequisites

### Tools Required

```bash
# Check versions
packer --version   # Should be 1.14.2+
```

Install if needed:
```bash
# Install Packer
wget https://releases.hashicorp.com/packer/1.14.2/packer_1.14.2_linux_amd64.zip
unzip packer_1.14.2_linux_amd64.zip
sudo mv packer /usr/local/bin/
```

### Proxmox Setup

1. **Create API Token** (recommended over username/password):
   ```
   Proxmox Web UI → Datacenter → Permissions → API Tokens → Add
   ```
   - User: `terraform@pam` (or create dedicated user)
   - Token ID: `terraform-token`
   - Privilege Separation: Unchecked (inherit user permissions)
   - Save the secret securely

2. **Grant Permissions** to the user/token:
   ```
   Proxmox Web UI → Datacenter → Permissions → Add → User Permission
   ```
   Required roles:
   - `PVEVMAdmin` (create/modify VMs)
   - `PVEDatastoreUser` (access datastores)
   - `PVETemplateUser` (create templates)

3. **Verify Network Access**:
   - Ensure Proxmox node can reach the internet (to download Talos image)
   - Verify network bridge `vmbr0` exists (or adjust in variables)

### Talos Factory Schematic

Talos Factory allows you to build custom Talos images with system extensions. You need to generate a schematic ID before building.

#### Step 1: Generate Schematic

Visit https://factory.talos.dev/

#### Step 2: Select Platform

Choose **"Metal"** (for Talos 1.8.0+)

#### Step 3: Select Talos Version

Choose **v1.11.5** (or latest stable from https://github.com/siderolabs/talos/releases)

#### Step 4: Add System Extensions

Click **"+ Add Extension"** and add the following:

1. **siderolabs/qemu-guest-agent**
   - Purpose: Proxmox VM integration
   - Enables: VM status reporting, proper shutdown, network info
   - Required: Yes

2. **nonfree-kmod-nvidia-production**
   - Purpose: NVIDIA proprietary GPU drivers
   - Enables: GPU passthrough support
   - Required: Only if using NVIDIA GPU

3. **nvidia-container-toolkit-production**
   - Purpose: NVIDIA container runtime
   - Enables: GPU workloads in Kubernetes
   - Required: Only if using NVIDIA GPU

4. **siderolabs/iscsi-tools**
   - Purpose: iSCSI initiator daemon and tools
   - Enables: Longhorn storage persistent volumes via iSCSI
   - Required: **YES (for Longhorn storage)**
   - Note: Longhorn is the primary storage solution for this infrastructure

5. **siderolabs/util-linux-tools**
   - Purpose: Volume management utilities (fstrim, nsenter, etc.)
   - Enables: Disk optimization and management for Longhorn
   - Required: **YES (for Longhorn storage)**
   - Note: Required for Longhorn volume operations

**IMPORTANT FOR LONGHORN:** Extensions #4 and #5 are **REQUIRED** if you plan to use Longhorn as your primary storage (which is the recommended configuration). Without these extensions, Longhorn will fail to create volumes.

#### Step 5: Copy Schematic ID

After adding extensions, Factory generates a schematic ID (example: `abc123def456...`).

**Copy this schematic ID** - you'll need it for the Packer build.

#### Alternative: Manual Image Download

If you prefer to download the image manually:

```bash
# Construct URL (replace with your schematic ID and version)
SCHEMATIC_ID="your-schematic-id-here"
VERSION="v1.11.5"
IMAGE_URL="https://factory.talos.dev/image/${SCHEMATIC_ID}/${VERSION}/metal-amd64.iso"

# Download ISO
wget "${IMAGE_URL}" -O talos-${VERSION}-custom.iso

# Or download raw disk image
wget "https://factory.talos.dev/image/${SCHEMATIC_ID}/${VERSION}/metal-amd64.raw.xz" -O talos.raw.xz
xz -d talos.raw.xz
```

## Configuration

### Step 1: Copy Example Variables

```bash
cd packer/talos
cp talos.auto.pkrvars.hcl.example talos.auto.pkrvars.hcl
```

### Step 2: Edit Variables

Edit `talos.auto.pkrvars.hcl` with your values:

```hcl
# Proxmox connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pam!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_node     = "pve"

# Talos configuration
talos_version      = "v1.11.5"
talos_schematic_id = "abc123def456..."  # Your schematic ID from Factory

# VM configuration
vm_id           = 9000
vm_disk_storage = "local-zfs"  # Your ZFS pool name
vm_disk_size    = "150G"
```

**Important Variables:**

- `proxmox_token`: Format is `PVEAPIToken=user@realm!token-id=secret`
- `talos_schematic_id`: From Talos Factory (Step 5 above)
- `vm_cpu_type`: Must be `"host"` for Talos v1.0+ and Cilium
- `vm_disk_storage`: Must match your Proxmox storage pool name

### Step 3: Optional - Use SOPS for Credentials

Instead of plain text credentials in `talos.auto.pkrvars.hcl`, use SOPS-encrypted secrets:

```bash
# Create encrypted Proxmox credentials
sops ../../secrets/proxmox-creds.enc.yaml

# Export decrypted values as environment variables
export PROXMOX_URL=$(sops -d ../../secrets/proxmox-creds.enc.yaml | yq '.proxmox_url')
export PROXMOX_TOKEN=$(sops -d ../../secrets/proxmox-creds.enc.yaml | yq '.proxmox_token_secret')
```

Then in `talos.auto.pkrvars.hcl`:
```hcl
proxmox_url   = env("PROXMOX_URL")
proxmox_token = env("PROXMOX_TOKEN")
```

## Building the Template

### Step 1: Initialize Packer

```bash
cd packer/talos
packer init .
```

This downloads required plugins (proxmox builder).

### Step 2: Validate Configuration

```bash
packer validate .
```

If validation fails, check:
- Variable syntax in `talos.auto.pkrvars.hcl`
- Schematic ID format
- Proxmox URL and credentials

### Step 3: Format Code (optional)

```bash
packer fmt .
```

### Step 4: Build Template

```bash
packer build .
```

**Expected Output:**
```
proxmox-iso.talos: output will be in this color.

==> proxmox-iso.talos: Downloading Talos ISO from Factory...
==> proxmox-iso.talos: Creating VM...
==> proxmox-iso.talos: Starting VM...
==> proxmox-iso.talos: Waiting for boot...
==> proxmox-iso.talos: Converting to template...
==> proxmox-iso.talos: Build complete!
```

**Build Time**: 5-15 minutes depending on:
- Internet speed (downloading Talos ISO ~150MB)
- Proxmox storage performance
- VM boot time

### Step 5: Verify Template

Check Proxmox web UI:
```
Proxmox Web UI → Node → VM Templates
```

You should see: `talos-1.11.5-nvidia-template-YYYYMMDD-hhmm`

Verify template properties:
- CPU type: host
- BIOS: OVMF (EFI)
- SCSI controller: VirtIO SCSI
- Network: VirtIO
- QEMU agent: Enabled

## Using the Template

### Option 1: Terraform (Recommended)

Use the Terraform configuration in `terraform/` to deploy VMs from this template:

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

See `terraform/README.md` for details.

### Option 2: Manual Deployment (Testing)

1. **Clone Template** in Proxmox:
   ```
   Right-click template → Clone
   Name: talos-test
   Full Clone: Yes
   ```

2. **Configure VM** (adjust resources as needed):
   - Memory: 24-32GB (for production workload)
   - CPU: 6-8 cores
   - Disk: Resize if needed (qm resize <vmid> scsi0 +50G)

3. **Optional: Add GPU Passthrough**:
   ```bash
   # Enable IOMMU in BIOS first, then:
   qm set <vmid> --hostpci0 01:00,pcie=1,rombar=0
   ```

4. **Start VM**:
   ```bash
   qm start <vmid>
   ```

5. **Apply Talos Configuration**:
   ```bash
   # Generate machine config
   talosctl gen config homelab-k8s https://<vm-ip>:6443

   # Apply configuration
   talosctl apply-config --insecure --nodes <vm-ip> --file controlplane.yaml

   # Bootstrap Kubernetes
   talosctl bootstrap --nodes <vm-ip>

   # Get kubeconfig
   talosctl kubeconfig --nodes <vm-ip>
   ```

## Post-Build Configuration

After deploying VMs from the template, you need to:

1. **Apply Talos Machine Configuration** via `talosctl`
2. **Bootstrap Kubernetes Cluster**
3. **Install Cilium CNI** (networking)
4. **Install NVIDIA GPU Operator** (if using GPU)
5. **Install Longhorn Storage Manager** (primary persistent storage for almost all services)
6. **Install NFS CSI Driver** (optional - Longhorn backup target to external NAS)
7. **Install FluxCD** (GitOps)

See `ansible/` directory for Day 0/1/2 automation.

## Troubleshooting

### Issue: Packer times out waiting for SSH

**Solution**: This is expected. Talos doesn't have SSH access. The Packer template uses `communicator = "none"` to skip SSH.

### Issue: "Error connecting to Proxmox API"

**Solutions**:
- Verify `proxmox_url` is correct (include `/api2/json`)
- Check API token format: `PVEAPIToken=user@pam!token=secret`
- Verify token permissions (PVEVMAdmin, PVEDatastoreUser)
- Test with curl:
  ```bash
  curl -k -H "Authorization: PVEAPIToken=user@pam!token=secret" \
    https://proxmox.local:8006/api2/json/nodes
  ```

### Issue: "Failed to download ISO"

**Solutions**:
- Verify schematic ID is correct (check factory.talos.dev)
- Ensure Proxmox node has internet access
- Check firewall rules
- Try downloading manually:
  ```bash
  wget https://factory.talos.dev/image/{schematic}/{version}/metal-amd64.iso
  ```

### Issue: "VM ID already exists"

**Solution**: Change `vm_id` in variables or delete existing VM:
```bash
qm destroy <vmid>
```

### Issue: "Insufficient permissions"

**Solution**: Grant additional roles to API token user:
```bash
pveum role add PVETemplateUser -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"
pveum aclmod / -user terraform@pam -role PVETemplateUser
```

### Issue: Template builds but can't boot

**Solutions**:
- Verify CPU type is set to "host" (required for Talos v1.0+)
- Check EFI disk was created
- Ensure SCSI controller is virtio-scsi-single
- Review Proxmox logs: `/var/log/pve/tasks/*.log`

## Updating the Template

When a new Talos version is released:

1. **Generate New Schematic** at factory.talos.dev with new version
2. **Update Variables**:
   ```hcl
   talos_version      = "v1.12.0"  # New version
   talos_schematic_id = "new-schematic-id"
   template_name      = "talos-1.12.0-nvidia-template"
   vm_id              = 9001  # New VM ID
   ```
3. **Rebuild Template**: `packer build .`
4. **Test New Template** before using in production
5. **Update Terraform** to use new template

## Template Customization

### Adjust Resources

Edit `variables.pkr.hcl` or override in `talos.auto.pkrvars.hcl`:

```hcl
# Increase disk size
vm_disk_size = "200G"

# More CPU cores for build
vm_cores = 8

# More memory
vm_memory = 16384  # 16GB
```

### Add/Remove Extensions

Regenerate schematic at factory.talos.dev with desired extensions:

**Common Extensions:**
- `siderolabs/qemu-guest-agent` - Always include for Proxmox
- `nonfree-kmod-nvidia-production` - NVIDIA GPU (proprietary)
- `nvidia-open-gpu-kernel-modules` - NVIDIA GPU (open source alternative)
- `nvidia-container-toolkit-production` - NVIDIA container runtime
- Various hardware support extensions

See https://github.com/siderolabs/extensions for full list.

### Use Different Platform

Talos supports multiple platforms. For bare metal or other virtualization:

- **Metal**: Generic x86-64 (recommended for Proxmox)
- **VMware**: VMware-specific optimizations
- **Hyper-V**: Microsoft Hyper-V
- **KVM**: QEMU/KVM optimizations

Change platform at factory.talos.dev when generating schematic.

## Best Practices

1. **Version Control**:
   - Commit Packer files to Git
   - Don't commit `talos.auto.pkrvars.hcl` (contains credentials)
   - Use SOPS for encrypted credentials

2. **Template Naming**:
   - Include version number: `talos-1.11.5-nvidia-template`
   - Include timestamp for rebuilds
   - Use consistent naming across environments

3. **Testing**:
   - Test template in dev environment first
   - Verify all extensions are loaded: `talosctl get extensions`
   - Check QEMU agent: `qm agent <vmid> ping`
   - Validate GPU detection (if applicable): `nvidia-smi` in container

4. **Security**:
   - Use API tokens instead of passwords
   - Restrict token permissions to minimum required
   - Rotate tokens regularly
   - Use SOPS for credential storage

5. **Documentation**:
   - Document schematic ID and extensions used
   - Record build date and Talos version
   - Note any customizations or deviations

## Resources

- **Talos Documentation**: https://www.talos.dev/
- **Talos Factory**: https://factory.talos.dev/
- **Talos on Proxmox Guide**: https://www.talos.dev/v1.10/talos-guides/install/virtualized-platforms/proxmox/
- **Packer Proxmox Builder**: https://www.packer.io/plugins/builders/proxmox
- **System Extensions**: https://github.com/siderolabs/extensions

## Support

For issues specific to this Packer template, check:
1. This README
2. `docs/versions.md` for version compatibility
3. `secrets/README.md` for SOPS setup
4. `CLAUDE.md` for project guidelines

For Talos issues:
- Talos Documentation: https://www.talos.dev/
- Talos GitHub Issues: https://github.com/siderolabs/talos/issues
- Talos Slack: https://slack.dev.talos-systems.io/

---

**Next Steps**: After building the template, proceed to `terraform/` to deploy Talos VMs and configure the Kubernetes cluster.
