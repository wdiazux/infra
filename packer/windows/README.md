# Windows 11 Pro Golden Image Packer Template

This directory contains Packer configuration to build a Windows 11 Pro golden image for Proxmox VE 9.0 with Cloudbase-Init and QEMU guest agent support.

## Overview

Creates a production-ready Windows 11 template with:
- **Windows 11 Pro** - Consumer/Pro edition for desktop workloads
- **Cloudbase-Init** - Windows equivalent of cloud-init for automated customization
- **QEMU Guest Agent** - For Proxmox integration
- **VirtIO drivers** - Optimized drivers for virtual hardware
- **WinRM** - Remote management enabled during build
- **Sysprep** - Generalized for cloning
- **Hardware bypass** - TPM/SecureBoot/RAM checks bypassed for VM installation

## Prerequisites

### Tools Required

All tools are provided by the Nix development environment:

```bash
# Enter the development environment
cd /path/to/infra
nix-shell

# Verify tools
packer --version   # ~> 1.14.3
xorriso --version  # Required for CD ISO creation
```

### Proxmox Permissions

The Packer API token requires specific permissions to build Windows images.

#### Required Permissions

| Path | Permission | Purpose |
|------|------------|---------|
| `/storage/local` | `Datastore.AllocateTemplate` | Upload CD ISO with autounattend.xml |
| `/storage/local` | `Datastore.Allocate` | Allocate storage for ISOs |
| `/vms/{vmid}` | `VM.Config.*` | Configure VM settings |
| `/vms/{vmid}` | `VM.Allocate` | Create/delete VMs |

#### Setup Permissions

**Option 1: Command Line (on Proxmox host)**
```bash
# Add PVEDatastoreAdmin role on local storage
pveum acl modify /storage/local -user terraform@pve -role PVEDatastoreAdmin
```

**Option 2: Use the provided script**
```bash
ssh root@pve 'bash -s' < setup-proxmox-permissions.sh
```

**Option 3: Web UI**
```
Datacenter → Permissions → Add
  Path: /storage/local
  User: terraform@pve
  Role: PVEDatastoreAdmin
  Propagate: Yes
```

#### Verify Permissions
```bash
# On Proxmox host
pveum user permissions terraform@pve | grep local
```

### Download Required ISOs

#### Automated Download (Recommended)

Run the download script on your Proxmox host:

```bash
# Copy script to Proxmox
scp download-isos.sh root@pve:/tmp/

# Run on Proxmox
ssh root@pve 'cd /tmp && chmod +x download-isos.sh && ./download-isos.sh'
```

The script will:
1. Download VirtIO drivers from Fedora (~600MB)
2. Download Windows 11 ISO using [Mido](https://github.com/ElliotKillick/Mido) (~5.5GB)
3. Verify and report status

#### Manual Download

If automated download fails (Microsoft rate limiting):

**1. Windows 11 ISO**
- Visit: https://www.microsoft.com/software-download/windows11
- Select: Windows 11 (multi-edition ISO for x64 devices)
- Rename to: `windows-11.iso`

**2. VirtIO Drivers ISO**
- URL: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
- Rename to: `virtio-win.iso`

**3. Upload to Proxmox**
```bash
# Via Web UI:
Datacenter → Storage (local) → ISO Images → Upload

# Or via command line:
scp windows-11.iso virtio-win.iso root@pve:/var/lib/vz/template/iso/
```

## Quick Start

### 1. Copy Example Configuration

```bash
cd packer/windows
cp windows.auto.pkrvars.hcl.example windows.auto.pkrvars.hcl
```

### 2. Edit Configuration

Edit `windows.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url      = "https://your-proxmox:8006/api2/json"
proxmox_username = "terraform@pve!terraform-token"
proxmox_token    = "your-token-secret"
proxmox_node     = "pve"

# Storage
vm_disk_storage = "tank"  # Your Proxmox storage pool
```

### 3. Initialize and Build

```bash
# Enter Nix environment (provides xorriso)
nix-shell ../../shell.nix

# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template (40-90 minutes)
packer build .
```

### 4. Verify Template

Check in Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `windows-11-cloud-template-v1.0.0`

## Configuration Details

### autounattend.xml

The unattended installation file configures:
- **Windows 11 Pro** edition
- **UEFI boot** with GPT partitioning
- **Hardware bypass** - TPM, SecureBoot, RAM checks disabled for VM
- **Administrator account** with temporary password
- **WinRM enabled** via FirstLogonCommands
- **Timezone**: America/El_Salvador

### VM Hardware (Proxmox Best Practices)

| Setting | Value | Notes |
|---------|-------|-------|
| Machine | q35 | Better UEFI/PCIe support |
| BIOS | OVMF (UEFI) | Required for Windows 11 |
| CPU | host | Full CPU features |
| Disk | VirtIO SCSI | With IO thread, writeback cache |
| Network | VirtIO | Paravirtualized |
| Display | VGA (std) | Standard VGA |

### Build Process

1. **CD ISO Creation** - autounattend.xml + setup-winrm.ps1 packaged as ISO
2. **VM Creation** - Windows 11 ISO + VirtIO ISO + CD ISO attached
3. **Windows Setup** - Unattended installation runs
4. **WinRM Connection** - Packer connects after first login
5. **Provisioning** - Cloudbase-Init, VirtIO drivers, cleanup
6. **Sysprep** - Generalize image for cloning
7. **Template Conversion** - VM converted to template

## Customization

### Change Windows Edition

Edit `http/autounattend.xml`:

```xml
<MetaData wcm:action="add">
    <Key>/IMAGE/NAME</Key>
    <Value>Windows 11 Pro</Value>  <!-- or "Windows 11 Home" -->
</MetaData>
```

### Change Administrator Password

The password is base64 encoded in `autounattend.xml`. Current: `P@ssw0rd!`

To change:
```powershell
# Generate new encoded password (PowerShell)
$pass = "YourNewPassword!" + "AdministratorPassword"
[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($pass))
```

### Enable Windows Updates

Uncomment in `windows.pkr.hcl`:

```hcl
provisioner "windows-update" {
  search_criteria = "IsInstalled=0"
  filters = [
    "exclude:$_.Title -like '*Preview*'",
    "include:$true"
  ]
  update_limit = 25
}
```

**Warning**: Adds 30-60 minutes to build time!

### Install Additional Software

Add a provisioner in `windows.pkr.hcl`:

```hcl
provisioner "powershell" {
  inline = [
    "# Install Chocolatey",
    "Set-ExecutionPolicy Bypass -Scope Process -Force",
    "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))",
    "",
    "# Install packages",
    "choco install -y 7zip googlechrome vscode"
  ]
}
```

## Troubleshooting

### Permission Denied (403)

```
403 Permission check failed (/storage/local, Datastore.AllocateTemplate)
```

**Solution**: Add storage permissions (see [Proxmox Permissions](#proxmox-permissions))

### CD ISO Creation Failed

```
could not find a supported CD ISO creation command
```

**Solution**: Run inside nix-shell which provides `xorriso`:
```bash
nix-shell ../../shell.nix --run "packer build ."
```

### WinRM Timeout

```
Timeout waiting for WinRM
```

**Solutions**:
- Check autounattend.xml FirstLogonCommands ran
- Verify firewall allows port 5985
- Increase `winrm_timeout` in variables (default: 60m)
- Check Proxmox console for Windows setup progress

### Windows Setup Stuck

```
Windows setup prompts for input instead of running unattended
```

**Solutions**:
- Verify autounattend.xml is on the CD ISO (check Packer output)
- Validate XML syntax
- Ensure CD label is "OEMDRV"
- Check Windows edition matches autounattend.xml

### Sysprep Fails

**Solutions**:
- Check C:\Windows\System32\Sysprep\Panther\setuperr.log
- Ensure no pending Windows updates
- Verify Cloudbase-Init installed correctly
- Check Windows activation status

## Resource Requirements

Windows 11 requires more resources than Linux:

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Disk | 60 GB | 100+ GB |
| Build Time | 40 min | 60-90 min |

## Files

| File | Purpose |
|------|---------|
| `windows.pkr.hcl` | Main Packer template |
| `variables.pkr.hcl` | Variable definitions |
| `windows.auto.pkrvars.hcl` | Your configuration (gitignored) |
| `http/autounattend.xml` | Windows unattended installation |
| `scripts/setup-winrm.ps1` | Enable WinRM for Packer |
| `scripts/install-cloudbase-init.ps1` | Install Cloudbase-Init |
| `scripts/cleanup.ps1` | Clean temp files before sysprep |
| `download-isos.sh` | Download Windows/VirtIO ISOs |
| `setup-proxmox-permissions.sh` | Configure Proxmox permissions |

## References

- [Proxmox Windows 11 Best Practices](https://pve.proxmox.com/wiki/Windows_11_guest_best_practices)
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)
- [Cloudbase-Init Documentation](https://cloudbase-init.readthedocs.io/)
- [VirtIO Drivers](https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers)
- [Mido - Windows ISO Downloader](https://github.com/ElliotKillick/Mido)
- [Windows Autounattend Reference](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/automate-windows-setup)
