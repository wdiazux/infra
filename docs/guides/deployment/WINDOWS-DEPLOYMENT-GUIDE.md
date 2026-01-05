# Windows 11 Golden Image: Complete Deployment Guide

**Date**: 2025-11-23
**Purpose**: Step-by-step guide for creating Windows 11 golden images with Packer and deploying VMs with Terraform

---

## Overview

This guide walks through the complete workflow:
1. **Day 0**: Prepare Windows 11 ISO, VirtIO drivers, and answer file
2. **Day 1**: Build golden image template with Packer (automated installation)
3. **Day 2**: Deploy production VMs from template with Terraform

**Total Time**: ~40-60 minutes (installation + Windows updates + sysprep)

---

## Prerequisites

### Tools Required

```bash
# Verify tool versions
packer version    # Should be 1.14.2+
terraform version # Should be 1.9.0+
ansible --version # Should be 2.16+ (optional, for provisioning)
```

### Proxmox Access

- Proxmox VE 9.0 host
- API token with permissions: `PVEVMAdmin`, `PVEDatastoreUser`
- Storage pool (e.g., `tank`)
- Network bridge (e.g., `vmbr0`)

### Windows Server Requirements

- **Windows 11 ISO**: Evaluation or licensed version
- **VirtIO Drivers ISO**: Required for Proxmox virtio-scsi and virtio-net
- **Product Key** (optional for evaluation, required for licensed versions)
- **License** (evaluation provides 180-day trial)

### Network Requirements

- DHCP enabled on network bridge OR static IP configuration
- DNS configured on Proxmox host
- Internet access for Windows Update (optional but recommended)

---

## Part 1: Day 0 - Prepare Windows ISO and Drivers

### Step 1: Get Windows 11 ISO

**Option A: Evaluation Version (Free 180-day trial)**
1. Visit: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11
2. Register and download ISO (Standard or Datacenter evaluation)
3. No product key required for evaluation

**Option B: Licensed Version**
1. Download from Volume Licensing Service Center (VLSC) or MSDN
2. Requires valid Windows Server license
3. Have product key ready

**ISO Details**:
- Size: ~5-6 GB
- Filename: `windows-11.iso` (rename for simplicity)
- Format: x86_64 / amd64

### Step 2: Get VirtIO Drivers

**Required**: Windows needs VirtIO drivers to recognize Proxmox virtio-scsi disk and virtio-net network.

Download latest stable VirtIO drivers:
1. Visit: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/
2. Download: `virtio-win-<version>.iso`
3. Rename to: `virtio-win.iso` (for simplicity)

**Alternative**: Latest version
- https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/

### Step 3: Upload ISOs to Proxmox

```bash
# SSH to Proxmox host
ssh root@proxmox

# Navigate to ISO storage
cd /var/lib/vz/template/iso

# Upload ISOs from local machine
# On your local machine:
scp windows-11.iso root@proxmox:/var/lib/vz/template/iso/
scp virtio-win.iso root@proxmox:/var/lib/vz/template/iso/

# Verify ISOs are uploaded
ls -lh /var/lib/vz/template/iso/ | grep -E "windows|virtio"
```

### Step 4: Verify Autounattend.xml

The Packer template uses an automated answer file located at `packer/windows/http/autounattend.xml`.

```bash
cd packer/windows

# Verify autounattend.xml exists
ls -la http/autounattend.xml
```

**What autounattend.xml does**:
1. Automated Windows installation (no user interaction)
2. Partitions disk (EFI + Windows partitions)
3. Installs VirtIO drivers during setup
4. Configures Windows (timezone, locale, keyboard)
5. Creates Administrator account with password
6. Enables WinRM for Packer remote access
7. Disables Windows Firewall temporarily (for Packer)
8. Runs first-boot scripts

**Key sections in autounattend.xml**:
- `DiskConfiguration`: Partitioning scheme
- `ImageInstall`: Windows edition selection
- `UserAccounts`: Administrator password
- `FirstLogonCommands`: Enable WinRM, disable firewall

### Step 5: Review Setup Scripts

Windows provisioning scripts in `packer/windows/http/`:

- `setup-winrm.ps1`: Configures WinRM for Packer communication
- `install-virtio-drivers.ps1`: Installs all VirtIO drivers
- `install-cloudbase-init.ps1`: Installs Cloudbase-Init (Windows cloud-init)
- `optimize-windows.ps1`: Removes bloat, disables telemetry
- `sysprep.ps1`: Generalizes image for template use

---

## Part 2: Build Golden Image with Packer

### Step 1: Configure Packer Variables

```bash
cd packer/windows

# Copy example configuration
cp windows.auto.pkrvars.hcl.example windows.auto.pkrvars.hcl

# Edit configuration
vim windows.auto.pkrvars.hcl
```

**Required settings**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx"
proxmox_node     = "pve"
proxmox_skip_tls_verify = true

# Windows Configuration
windows_edition  = "Windows 11 Standard (Desktop Experience)"
# Options:
# - "Windows 11 Standard (Desktop Experience)"  # GUI
# - "Windows 11 Standard"                       # Server Core
# - "Windows 11 Datacenter (Desktop Experience)" # GUI
# - "Windows 11 Datacenter"                     # Server Core

# Template Configuration
template_name        = "windows-11-golden-template"
template_description = "Windows 11 Standard with Cloudbase-Init"
vm_id                = 9500

# VM Hardware (Windows needs more resources)
vm_cores  = 4
vm_memory = 4096  # 4GB minimum, 8GB recommended
vm_disk_size    = "60G"  # Windows needs 40GB+, 60GB recommended
vm_disk_storage = "tank"
vm_cpu_type     = "host"

# Network
vm_network_bridge = "vmbr0"

# WinRM Configuration (for Packer provisioning)
winrm_username = "Administrator"
winrm_password = "P@ssw0rd123!"  # Change this! (must meet complexity requirements)
winrm_timeout  = "60m"           # Windows install can take time

# Product Key (optional for evaluation)
# product_key = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
```

**Windows Password Requirements**:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character

### Step 2: Customize Autounattend.xml (Optional)

Edit `http/autounattend.xml` if needed:

```xml
<!-- Administrator Password -->
<Password>
    <Value>P@ssw0rd123!</Value>
    <PlainText>true</PlainText>
</Password>

<!-- Windows Edition Index -->
<MetaData wcm:action="add">
    <Key>/IMAGE/INDEX</Key>
    <Value>2</Value>  <!-- 2 = Standard Desktop Experience -->
</MetaData>

<!-- Timezone -->
<TimeZone>Pacific Standard Time</TimeZone>

<!-- Product Key (if licensed) -->
<ProductKey>
    <Key>XXXXX-XXXXX-XXXXX-XXXXX-XXXXX</Key>
</ProductKey>
```

### Step 3: Build the Template

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template (will take 40-60 minutes)
packer build .
```

**Build Process**:
1. Packer creates VM and attaches Windows + VirtIO ISOs
2. Boots from Windows ISO
3. Reads autounattend.xml from HTTP server
4. Automated Windows installation:
   - Partitions disk (EFI + Windows)
   - Installs VirtIO drivers
   - Installs Windows
   - Configures settings
   - Creates Administrator account
   - Enables WinRM
5. Packer connects via WinRM
6. Runs provisioning scripts:
   - Installs Windows Updates (optional, time-consuming)
   - Installs Cloudbase-Init
   - Installs additional software via Ansible (optional)
   - Optimizes Windows (removes bloat)
7. Runs Sysprep to generalize image
8. Converts VM to template

**Build Time**:
- Without Windows Update: ~30-40 minutes
- With Windows Update: ~60-90 minutes (recommended for production)

**Watch Progress**:
- Open Proxmox UI → VM 9500 → Console
- You'll see: Windows install → First boot → Provisioning → Sysprep

**Note**: Packer will connect via WinRM (not SSH) after Windows installation.

### Step 4: Verify Template

```bash
# SSH to Proxmox host
ssh root@proxmox

# List templates
qm list | grep -i template
# Should show: windows-11-golden-template

# Check template configuration
qm config 9500

# Verify it's marked as template
qm config 9500 | grep template
# Should show: template: 1

# Verify cloud-init drive exists
qm config 9500 | grep ide2
# Should show: ide2: tank:vm-9500-cloudinit
```

---

## Part 3: Deploy VM with Terraform

### Step 1: Configure Terraform Variables

```bash
cd ../../terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Key settings for Windows VM**:

```hcl
# Proxmox Connection
proxmox_url      = "https://proxmox.local:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token    = "PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx"
proxmox_node     = "pve"

# Windows VM Configuration
deploy_windows_vm     = true
windows_template_name = "windows-11-golden-template"
windows_vm_name       = "windows-prod-01"
windows_vm_id         = 500

# Resources (Windows needs more than Linux)
windows_cores  = 4
windows_memory = 8192  # 8GB RAM recommended

# Networking
windows_ip      = "192.168.1.140"
windows_netmask = "24"
windows_gateway = "192.168.1.1"
dns_servers     = ["8.8.8.8", "1.1.1.1"]

# Cloudbase-Init User (created on first boot)
windows_user     = "wdiaz"
windows_password = "NewP@ssw0rd456!"  # Must meet complexity requirements
```

### Step 2: Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

**Terraform will**:
1. Look up template "windows-11-golden-template" on Proxmox
2. Clone template → create new VM (ID 500)
3. Configure resources (4 cores, 8GB RAM)
4. Apply Cloudbase-Init configuration (hostname, IP, user)
5. Start VM

**Deploy Time**: ~3-5 minutes

**First Boot Process**:
1. VM boots from template
2. Cloudbase-Init runs (Windows equivalent of cloud-init)
3. Applies configuration:
   - Sets hostname
   - Configures network (static IP)
   - Creates user account
   - Sets password
   - Runs any custom scripts
4. Reboots (if configured)
5. Ready for use

### Step 3: Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Should show:
# windows_vm_id = "500"
# windows_vm_ip = "192.168.1.140"
# windows_vm_name = "windows-prod-01"
```

**In Proxmox UI**:
1. Navigate to VM 500
2. Check console - should show Windows boot process
3. Wait for Cloudbase-Init to complete (~5 minutes)

**Access Windows VM**:

**Option A: RDP (Remote Desktop)**
```bash
# From Linux/Mac with rdesktop or Remmina
rdesktop 192.168.1.140 -u wdiaz -p 'NewP@ssw0rd456!'

# From Windows
mstsc /v:192.168.1.140
```

**Option B: Proxmox Console**
1. Open Proxmox UI → VM 500 → Console
2. Log in: username `wdiaz`, password `NewP@ssw0rd456!`

**Option C: WinRM (PowerShell Remoting)**
```powershell
# From Windows machine
$cred = Get-Credential  # Enter wdiaz / NewP@ssw0rd456!
Enter-PSSession -ComputerName 192.168.1.140 -Credential $cred
```

---

## Part 4: Post-Deployment Configuration (Optional)

### Option 1: Install Windows Features

```powershell
# RDP or WinRM into VM
# Install IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Install Hyper-V (if nested virtualization)
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

# Install Active Directory
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

### Option 2: Join Active Directory Domain

```powershell
# Join domain
$domain = "contoso.com"
$cred = Get-Credential  # Domain admin credentials
Add-Computer -DomainName $domain -Credential $cred -Restart
```

### Option 3: Configure Windows Update

```powershell
# Install PSWindowsUpdate module
Install-Module PSWindowsUpdate -Force

# Get available updates
Get-WindowsUpdate

# Install all updates
Install-WindowsUpdate -AcceptAll -AutoReboot
```

### Option 4: Run Ansible Playbook

For automated configuration:

```bash
# On Ansible control machine
cd ansible

# Update inventory
vim inventory/windows.ini

# Add:
# [windows_servers]
# windows-prod-01 ansible_host=192.168.1.140 ansible_user=wdiaz ansible_password=NewP@ssw0rd456! ansible_connection=winrm ansible_winrm_server_cert_validation=ignore

# Run Windows baseline playbook
ansible-playbook -i inventory/windows.ini playbooks/windows-baseline.yml
```

---

## Troubleshooting

### Issue: Packer build fails - autounattend.xml not found

**Symptoms**:
```
Windows installation prompts for language/keyboard (not automated)
```

**Solutions**:
1. Verify HTTP server started: Check Packer output for HTTP port (8104)
2. Ensure autounattend.xml exists: `ls -la packer/windows/http/autounattend.xml`
3. Check network connectivity from VM to Packer host
4. Verify autounattend.xml syntax (valid XML)

### Issue: VirtIO drivers not loading during install

**Symptoms**:
- Windows installer can't find disk
- "No drives were found" error

**Solutions**:
1. Verify virtio-win.iso uploaded to Proxmox: `ls -la /var/lib/vz/template/iso/virtio-win.iso`
2. Check additional_iso_files in Packer template points to correct ISO
3. Download latest VirtIO drivers
4. Ensure autounattend.xml includes driver injection

### Issue: WinRM connection timeout

**Symptoms**:
```
Timeout waiting for WinRM to become available
```

**Solutions**:
1. Increase `winrm_timeout` in `windows.auto.pkrvars.hcl` to "90m"
2. Check Windows Firewall is disabled (autounattend.xml should handle this)
3. Verify WinRM service started: View Proxmox console, check services
4. Ensure setup-winrm.ps1 ran successfully
5. Check network connectivity (DHCP assigned IP)

### Issue: Windows activation fails

**Symptoms**:
```
This copy of Windows is not activated
```

**Solutions**:
1. **Evaluation version**: 180-day trial, no activation needed
2. **Licensed version**:
   - Add product key to autounattend.xml
   - Or activate after deployment: `slmgr /ipk XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`
   - Then: `slmgr /ato`
3. **KMS activation** (enterprise):
   - Set KMS server: `slmgr /skms kms.contoso.com`
   - Activate: `slmgr /ato`

### Issue: Sysprep fails

**Symptoms**:
```
Sysprep was not able to validate your Windows installation
```

**Solutions**:
1. Check sysprep logs: `C:\Windows\System32\Sysprep\Panther\setuperr.log`
2. Remove Windows Store apps before sysprep (optimize-windows.ps1 should handle this)
3. Ensure no pending Windows Updates
4. Run sysprep with different options:
   ```powershell
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /mode:vm
   ```

### Issue: Cloudbase-Init not running on deployed VM

**Symptoms**:
- User account not created
- Hostname not set
- Network not configured

**Solutions**:
1. Verify Cloudbase-Init installed: Check `C:\Program Files\Cloudbase Solutions\`
2. Check service status: `Get-Service cloudbase-init`
3. View logs: `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\`
4. Ensure cloud-init drive exists: `qm config 500 | grep ide2`
5. Rebuild template with correct Cloudbase-Init installation

---

## Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│     Day 0: Prepare Windows ISO, VirtIO, Answer File        │
├─────────────────────────────────────────────────────────────┤
│ 1. Download Windows 11 ISO (eval or licensed)      │
│ 2. Download VirtIO drivers ISO                              │
│ 3. Upload both ISOs to Proxmox: /var/lib/vz/template/iso/  │
│ 4. Verify autounattend.xml exists                           │
│ 5. Review setup scripts (setup-winrm.ps1, etc.)             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         Day 1: Build Golden Image (40-90 min)               │
├─────────────────────────────────────────────────────────────┤
│ cd packer/windows                                            │
│ cp windows.auto.pkrvars.hcl.example windows.auto.pkrvars.hcl│
│ vim windows.auto.pkrvars.hcl  # Set Proxmox and WinRM config│
│ packer init .                                                │
│ packer build .                                               │
│ → Boots Windows ISO                                          │
│ → Reads autounattend.xml from HTTP server                   │
│ → Automated install (partitions, installs, configures)      │
│ → Reboots, enables WinRM                                    │
│ → Packer connects via WinRM                                 │
│ → Runs provisioning scripts:                                │
│   - Installs Cloudbase-Init                                 │
│   - Installs Windows Updates (optional)                     │
│   - Optimizes Windows                                       │
│ → Runs Sysprep to generalize image                          │
│ → Creates template "windows-11-golden-template"    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│          Day 2: Deploy Production VMs (3-5 min)             │
├─────────────────────────────────────────────────────────────┤
│ cd terraform                                                 │
│ cp terraform.tfvars.example terraform.tfvars                │
│ vim terraform.tfvars  # Configure VM settings                │
│ terraform init                                               │
│ terraform apply                                              │
│ → Clones template → creates VM (ID 500)                     │
│ → Configures resources (cores, RAM, disk)                   │
│ → Applies Cloudbase-Init config (network, user)             │
│ → Starts VM                                                  │
│ → Cloudbase-Init runs on first boot (~5 min)                │
│ → VM ready for RDP/WinRM access                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Keep Templates Updated with Windows Update

```powershell
# Include Windows Update in Packer build
# Or update template quarterly:
# 1. Clone template to temporary VM
# 2. Boot VM
# 3. Install-WindowsUpdate -AcceptAll -AutoReboot
# 4. Run sysprep
# 5. Convert to new template
```

### 2. Use Server Core for Production (Less Attack Surface)

```hcl
# In windows.auto.pkrvars.hcl
windows_edition = "Windows 11 Standard"  # Server Core (no GUI)
```

**Benefits**:
- Smaller attack surface
- Less disk space
- Faster updates
- Lower resource usage

**Trade-off**: Command-line only (PowerShell/cmd)

### 3. Separate Templates for Different Roles

Build different templates for different server roles:
- `windows-iis-template` - Pre-configured IIS web server
- `windows-sqlserver-template` - SQL Server pre-installed
- `windows-dc-template` - Domain Controller ready

### 4. Automate License Management

```powershell
# Use KMS for enterprise
# Or Volume Activation Management Tool (VAMT)
# Or Azure Hybrid Benefit for cloud-licensed servers
```

### 5. Regular Security Updates

```powershell
# Monthly: Update template with latest security patches
# Use PSWindowsUpdate module for automation
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
```

---

## Windows Server Specific Considerations

### Licensing

**Evaluation**:
- 180-day trial
- Full features
- Needs re-arm (3 times max) or rebuild

**Licensed**:
- Requires product key
- Volume licensing for multiple VMs
- Consider licensing model (per core, datacenter unlimited VMs)

### Cloudbase-Init vs Cloud-Init

**Cloudbase-Init** is Windows equivalent of cloud-init:
- Configures network
- Creates users
- Runs scripts
- Sets hostname
- Compatible with most cloud-init user-data

**Configuration**: `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf`

### Windows Updates

**Options**:
1. **WSUS** (Windows Server Update Services) - Enterprise
2. **Windows Update** - Direct from Microsoft
3. **Offline updates** - For air-gapped environments

**Automation**:
```powershell
# PSWindowsUpdate module
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot
```

---

## Next Steps

1. ✅ Complete Windows Server deployment
2. Configure Windows Features (IIS, AD, Hyper-V, etc.)
3. Set up automated Windows Update (WSUS or PSWindowsUpdate)
4. Implement backup strategy (Proxmox snapshots + Windows Backup)
5. Build role-specific templates (web server, database, domain controller)

---

## Related Documentation

- **Packer Windows Template**: `packer/windows/README.md`
- **Terraform Configuration**: `terraform/README.md`
- **Ansible Windows Playbooks**: `ansible/playbooks/windows-baseline.yml`
- **Windows Server Documentation**: https://docs.microsoft.com/en-us/windows-server/
- **Cloudbase-Init**: https://cloudbase-init.readthedocs.io/

---

**Last Updated**: 2025-11-23
**Maintained By**: wdiazux
