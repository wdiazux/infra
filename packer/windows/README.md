# Windows Server 2022 Golden Image Packer Template

This directory contains Packer configuration to build a Windows Server 2022 Datacenter Evaluation golden image for Proxmox VE 9.0 with Cloudbase-Init and QEMU guest agent support.

## Overview

Creates a production-ready Windows Server template with:
- **Windows Server 2022 Datacenter Evaluation** - 180-day trial (convertible to licensed)
- **Cloudbase-Init** - Windows equivalent of cloud-init for automated customization
- **QEMU Guest Agent** - For Proxmox integration
- **VirtIO drivers** - Optimized drivers for virtual hardware
- **WinRM** - Remote management enabled
- **Sysprep** - Generalized for cloning
- **Larger footprint** - ~60GB disk, 4GB RAM minimum

## Prerequisites

### Tools Required

```bash
# Packer 1.14.2+
packer --version
```

### Proxmox Setup

Same as Talos template - see [main Packer README](../../packer/talos/README.md#proxmox-setup).

### Download Required ISOs

#### 1. Windows Server 2022 ISO

Visit https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022

- **Edition**: Windows Server 2022 Datacenter (Evaluation)
- **Language**: English (United States)
- **Format**: ISO
- **Size**: ~5.3 GB

```
Example:
URL: https://software-download.microsoft.com/download/sg/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso
SHA256: 3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255e31
```

#### 2. VirtIO Drivers ISO

Visit https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/

- **File**: latest-virtio/virtio-win.iso
- **Size**: ~600 MB

```
URL: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
```

#### 3. Upload ISOs to Proxmox

```bash
# Via Proxmox web UI:
Datacenter → Storage (local) → ISO Images → Upload

# Or via command line on Proxmox host:
cd /var/lib/vz/template/iso/
wget <windows-iso-url> -O windows-server-2022.iso
wget <virtio-iso-url> -O virtio-win.iso
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
proxmox_url  = "https://your-proxmox:8006/api2/json"
proxmox_token = "PVEAPIToken=user@pam!token=secret"
proxmox_node = "pve"

# Note: ISO files must be uploaded to Proxmox first!
# Update iso_file paths in windows.pkr.hcl to match your uploaded files

# Storage
vm_disk_storage = "local-zfs"  # Your Proxmox storage pool
```

### 3. Update ISO Paths

Edit `windows.pkr.hcl` and update ISO file paths:

```hcl
# Main Windows ISO
iso_file = "local:iso/windows-server-2022.iso"  # Match your uploaded file name

# VirtIO drivers ISO
additional_iso_files {
  iso_file = "local:iso/virtio-win.iso"  # Match your uploaded file name
}
```

### 4. Initialize and Build

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template (this will take 30-90 minutes!)
packer build .
```

**Build time**: 30-90 minutes depending on:
- Network speed
- Storage performance
- Whether Windows updates are enabled

### 5. Verify Template

Check in Proxmox UI:
```
Datacenter → Node → VM Templates
```

Should see: `windows-server-2022-golden-template-YYYYMMDD-hhmm`

## Using the Template

### Option 1: Clone Manually in Proxmox UI

1. Right-click template → Clone
2. Full clone (not linked)
3. Set VM name and resources
4. Start VM
5. First boot will run Cloudbase-Init customization
6. Login with Administrator and password set in Cloudbase-Init

### Option 2: Clone with Terraform (Recommended)

```hcl
resource "proxmox_virtual_environment_vm" "windows_vm" {
  name      = "windows-vm-01"
  node_name = "pve"

  clone {
    vm_id = 9005  # Template ID
    full  = true
  }

  cpu {
    cores = 8
  }

  memory {
    dedicated = 16384
  }

  # Cloudbase-Init configuration (via ConfigDrive)
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloudbase_init.id

    ip_config {
      ipv4 {
        address = "192.168.1.150/24"
        gateway = "192.168.1.1"
      }
    }
  }
}
```

### Option 3: Customize with Cloudbase-Init

Create `user-data` file (similar to cloud-init):

```yaml
#cloud-config
set_hostname: my-windows-server
timezone: America/New_York

users:
  - name: admin
    groups: ['Administrators']
    passwd: 'MySecurePassword123!'

runcmd:
  - powershell -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
```

Upload to Proxmox as ConfigDrive for Cloudbase-Init to process.

## Customization

### Modify Autounattend File

Edit `http/autounattend.xml` to change:
- **Windows edition** - Change image name (Datacenter, Standard, Core)
- **Product key** - Use your licensed key or evaluation key
- **Disk partitioning** - Modify partition sizes
- **Locale/timezone** - Change from en-US/UTC
- **Administrator password** - Change default password (base64 encoded)

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

**Warning**: This can add 30-60 minutes to build time!

### Install Additional Software

Uncomment Chocolatey provisioner in `windows.pkr.hcl`:

```hcl
provisioner "powershell" {
  inline = [
    "# Install Chocolatey",
    "Set-ExecutionPolicy Bypass -Scope Process -Force",
    "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))",
    "",
    "# Install packages",
    "choco install -y git",
    "choco install -y 7zip",
    "choco install -y googlechrome"
  ]
}
```

### Change Disk Size

In `windows.auto.pkrvars.hcl`:

```hcl
vm_disk_size = "100G"  # Increase to 100GB
```

### Add Roles and Features

Create a new provisioner:

```hcl
provisioner "powershell" {
  inline = [
    "Install-WindowsFeature -Name Web-Server -IncludeManagementTools",
    "Install-WindowsFeature -Name DHCP -IncludeManagementTools",
    "Install-WindowsFeature -Name DNS -IncludeManagementTools"
  ]
}
```

## Post-Build Configuration

After deploying VMs from this template:

### 1. Activate Windows License

```powershell
# If using retail/volume license key
slmgr /ipk YOUR-LICENSE-KEY
slmgr /ato

# Convert evaluation to licensed (requires valid key)
DISM /online /Set-Edition:ServerDatacenter /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula
```

### 2. Join to Domain

```powershell
# Join Active Directory domain
Add-Computer -DomainName "domain.local" -Credential (Get-Credential) -Restart
```

### 3. Configure with PowerShell DSC

```powershell
# Example DSC configuration
Configuration WebServer {
    Node localhost {
        WindowsFeature IIS {
            Ensure = "Present"
            Name   = "Web-Server"
        }
    }
}

WebServer
Start-DscConfiguration -Path .\WebServer -Wait -Verbose
```

### 4. Or Configure with Ansible

```yaml
# Ansible playbook for Windows
- hosts: windows_servers
  tasks:
    - name: Install IIS
      win_feature:
        name: Web-Server
        state: present
        include_management_tools: yes
```

## Troubleshooting

### Issue: Autounattend not applied

```
Installation prompts for settings instead of using autounattend.xml
```

**Solution**:
- Verify autounattend.xml exists in http/ directory
- Check HTTP server starts: PACKER_LOG=1 packer build .
- Ensure file is named exactly `autounattend.xml`
- Validate XML syntax with online validator

### Issue: WinRM timeout

```
Timeout waiting for WinRM
```

**Solution**:
- Check setup-winrm.ps1 ran successfully
- Verify firewall allows port 5985
- Increase winrm_timeout in variables
- Check autounattend.xml FirstLogonCommands section

### Issue: VirtIO drivers not installed

```
Network or disk not detected during installation
```

**Solution**:
- Verify virtio-win.iso is uploaded to Proxmox
- Check iso_file path matches uploaded file
- Ensure additional_iso_files is configured correctly
- Windows should auto-detect drivers from ISO

### Issue: Sysprep fails

```
Sysprep fails or VM won't boot after sysprep
```

**Solution**:
- Check Windows activation status
- Ensure no pending Windows updates
- Review C:\Windows\System32\Sysprep\Panther\setuperr.log
- Verify cloudbase-init is installed correctly

### Issue: Cloudbase-Init not working

```
Cloudbase-Init configuration not applied on first boot
```

**Solution**:
- Verify installed: Check "C:\Program Files\Cloudbase Solutions\"
- Check service: Get-Service cloudbase-init
- Review logs: C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
- Ensure ConfigDrive is provided during VM clone

### Issue: Disk is full

```
C: drive runs out of space during build
```

**Solution**:
- Increase vm_disk_size (minimum 60GB recommended)
- Disable Windows updates during build
- Check cleanup.ps1 is running
- Enable disk cleanup in cleanup.ps1

## Template Details

### Installed Components

**Base System**:
- Windows Server 2022 Datacenter (Evaluation)
- Latest cumulative updates (if enabled)
- QEMU Guest Agent
- Cloudbase-Init
- VirtIO drivers (network, storage, balloon)

**Enabled Services**:
- WinRM (Remote PowerShell)
- Remote Desktop (disabled by default, enable as needed)
- Windows Firewall
- Windows Defender

**Removed/Disabled**:
- Windows Store apps (Server doesn't have many)
- Unnecessary services
- Temporary files and caches

### Cloudbase-Init Configuration

The template includes Cloudbase-Init with:
- Network configuration (static or DHCP)
- User creation and password setting
- Hostname configuration
- Windows activation
- Execution of custom scripts
- Metadata services (ConfigDrive, HTTP, EC2)

### QEMU Guest Agent

Enabled and configured for:
- VM status reporting to Proxmox
- Graceful shutdown/reboot
- IP address discovery
- Filesystem quiescing for snapshots
- Time synchronization

## Windows-Specific Considerations

### Licensing

- **Evaluation**: 180 days free trial
- **Conversion**: Can convert to licensed with valid key
- **Activation**: Requires internet or KMS server
- **Compliance**: Ensure you have proper licenses

### Resource Requirements

Windows requires significantly more resources than Linux:
- **Minimum**: 2 cores, 4GB RAM, 60GB disk
- **Recommended**: 4+ cores, 8GB+ RAM, 100GB+ disk
- **Production**: 8+ cores, 16GB+ RAM, based on workload

### Build Time

Windows templates take much longer to build:
- **Without updates**: 30-45 minutes
- **With updates**: 60-90 minutes
- **With software**: Add 10-30 minutes

### Storage Usage

Windows templates are much larger:
- **Base template**: ~20-30 GB
- **With updates**: ~40-50 GB
- **With software**: Varies significantly

## Best Practices

1. **Keep Templates Updated**
   - Rebuild monthly with latest Windows updates
   - Test new template before replacing production
   - Track which updates are included

2. **Use Cloudbase-Init**
   - Don't modify template directly
   - Use Cloudbase-Init for VM-specific config
   - Keep template generic

3. **Configuration Management**
   - Use PowerShell DSC or Ansible
   - Version control configurations
   - Test in dev before production

4. **Security Hardening**
   - Change default passwords immediately
   - Enable Windows Defender
   - Configure Windows Firewall
   - Install security updates
   - Disable unnecessary services

5. **Licensing Management**
   - Track activation status
   - Use KMS for multiple VMs
   - Document license keys securely
   - Comply with Microsoft licensing

## Resources

- **Windows Server Documentation**: https://docs.microsoft.com/en-us/windows-server/
- **Cloudbase-Init**: https://cloudbase.it/cloudbase-init/
- **VirtIO Drivers**: https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers
- **Autounattend Reference**: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/
- **Packer Windows Builder**: https://www.packer.io/docs/builders/proxmox/iso

## Important Notes

### Evaluation vs Licensed

**Evaluation Version**:
- Free for 180 days
- Full Datacenter features
- Can be converted to licensed
- Requires periodic activation

**Licensed Version**:
- Requires valid product key
- Perpetual or subscription-based
- May require KMS server for activation

### Remote Management

**WinRM** (Windows Remote Management):
- PowerShell remoting
- Used by Ansible, Packer, Terraform
- Port 5985 (HTTP) or 5986 (HTTPS)

**RDP** (Remote Desktop Protocol):
- GUI access
- Port 3389
- Enable via: `Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0`

### Windows Updates

**Methods**:
1. **During build**: Packer windows-update provisioner
2. **After deployment**: WSUS, Windows Update, or manual
3. **Rebuild template**: Recommended monthly

## Next Steps

After building the Windows template:

1. Test deployment with Cloudbase-Init
2. Create PowerShell DSC or Ansible baseline
3. Document custom configurations
4. Set up automated template rebuilds

See `../../terraform/` for deploying VMs from this template.
