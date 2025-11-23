# Packer Implementation Best Practices for Proxmox VE 9.0
## Comprehensive Research Report

**Date:** 2025-11-23
**Packer Version:** 1.14.0+
**Proxmox Version:** 9.0
**Target Operating Systems:** Talos Linux, Debian 12, Ubuntu 24.04, Arch Linux, NixOS, Windows Server 2022

---

## Table of Contents

1. [Official Documentation & Core Resources](#1-official-documentation--core-resources)
2. [Talos Linux Implementation](#2-talos-linux-implementation)
3. [Cloud-Init Integration for Traditional OSes](#3-cloud-init-integration-for-traditional-oses)
4. [Windows Server Automation](#4-windows-server-automation)
5. [Arch Linux & NixOS Templates](#5-arch-linux--nixos-templates)
6. [Common Pitfalls & Troubleshooting](#6-common-pitfalls--troubleshooting)
7. [QEMU Guest Agent Best Practices](#7-qemu-guest-agent-best-practices)
8. [NVIDIA GPU & Talos System Extensions](#8-nvidia-gpu--talos-system-extensions)
9. [ISO vs Clone Builder Strategy](#9-iso-vs-clone-builder-strategy)
10. [Network Configuration & Firewall](#10-network-configuration--firewall)
11. [Storage Pool & Disk Format Performance](#11-storage-pool--disk-format-performance)
12. [Plugin Versions & Compatibility](#12-plugin-versions--compatibility)
13. [Best Practices Summary](#13-best-practices-summary)
14. [Reference Implementation Patterns](#14-reference-implementation-patterns)

---

## 1. Official Documentation & Core Resources

### 1.1 HashiCorp Official Packer Proxmox Documentation

**URL:** [https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)

**Key Best Practices:**
- Use the official `hashicorp/proxmox` plugin (version >= 1.2.2 recommended)
- Starting from Packer 1.7+, use `packer init` command for automatic plugin installation
- Configure required plugins in your Packer configuration using HCL2 syntax
- The plugin provides two main builders: `proxmox-iso` and `proxmox-clone`

**Version Compatibility:**
- Packer 1.7.0+ supports automatic plugin installation
- Packer 1.12.0+ recommended for Proxmox 8.0+
- Packer 1.14.0+ works with Proxmox VE 9.0

**Configuration Example:**
```hcl
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
```

---

### 1.2 Proxmox ISO Builder Documentation

**URL:** [https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)

**Key Best Practices:**
- Use `proxmox-iso` builder for creating images from ISO files
- Configure ISO source with checksums for validation
- Set appropriate VM resources (CPU, memory, storage)
- Enable QEMU guest agent for better VM management
- Use cloud-init for automated provisioning

**Critical Configuration Parameters:**
- `proxmox_url`: Proxmox API endpoint (e.g., `https://proxmox.example.com:8006/api2/json`)
- `iso_file`: Path to ISO on Proxmox storage (e.g., `local:iso/debian-12.0.0-amd64-netinst.iso`)
- `qemu_agent`: Enable QEMU agent (default: true)
- `scsi_controller`: Use `virtio-scsi-pci` for best performance
- `cloud_init`: Add cloud-init CDROM drive for templates

---

### 1.3 GitHub Repository - packer-plugin-proxmox

**URL:** [https://github.com/hashicorp/packer-plugin-proxmox](https://github.com/hashicorp/packer-plugin-proxmox)

**Key Best Practices:**
- Review CHANGELOG.md for breaking changes between versions
- Check GitHub Issues for known bugs and workarounds
- Review example configurations in the repository
- Monitor plugin releases for security updates

**Version Compatibility Notes:**
- v1.1.1: Known regression with ISO upload (506 error)
- v1.2.0: Released September 2024, major improvements
- v1.2.2: CPU type passing bug
- v1.2.3: Latest stable (July 2025), fixes CPU type regression
- Recommended: Pin to v1.2.3 or use `~> 1.2.0` for automatic minor updates

---

### 1.4 Building Proxmox Templates with Packer (runtimeterror.dev)

**URL:** [https://runtimeterror.dev/building-proxmox-templates-packer/](https://runtimeterror.dev/building-proxmox-templates-packer/)

**Key Best Practices:**
- Use API tokens instead of passwords for authentication
- Create dedicated Packer user with minimal required permissions
- Use template naming with timestamps for versioning
- Implement proper error handling in build scripts
- Test templates thoroughly before production use

**Relevant Patterns:**
- Template naming: `{os-name}-{version}-{timestamp}`
- API token format: `user@pam!token-name`
- Minimal permissions: VM.Allocate, VM.Config, Datastore.AllocateSpace

---

### 1.5 GitHub - ajschroeder/proxmox-packer-examples

**URL:** [https://github.com/ajschroeder/proxmox-packer-examples](https://github.com/ajschroeder/proxmox-packer-examples)

**Key Best Practices:**
- Comprehensive examples for multiple OS families
- Uses HCL2 syntax (modern Packer format)
- Demonstrates variable management patterns
- Includes pre-commit hooks for validation

**Version Compatibility:**
- Requires Proxmox PVE 8.0 or later (compatible with 9.0)
- HashiCorp Packer 1.12.0 or higher
- Examples include Debian, Ubuntu, Rocky Linux, Fedora

**Relevant Patterns:**
```hcl
# Variable management
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

# Network configuration
network_adapters {
  bridge   = "vmbr0"
  model    = "virtio"
  firewall = false
}
```

---

## 2. Talos Linux Implementation

### 2.1 Packer and Talos Image Factory on Proxmox (JYSK Tech)

**URL:** [https://jysk.tech/packer-and-talos-image-factory-on-proxmox-76d95e8dc316](https://jysk.tech/packer-and-talos-image-factory-on-proxmox-76d95e8dc316)

**Key Best Practices:**
- Use Arch Linux ISO as intermediate boot environment
- Download Talos raw image from Image Factory during Packer build
- Write Talos image directly to VM disk using dd
- Shutdown VM and convert to template with sensible naming
- Use Image Factory API for custom system extensions

**Implementation Approach:**
1. Packer creates VM with specified resources
2. Boots Arch Linux live environment
3. Downloads Talos raw image from factory.talos.dev
4. Writes image to boot disk
5. Shuts down and converts to template

**Version Compatibility:**
- Talos 1.8.0+: Use "metal" images (recommended)
- Talos 1.7.x: Use "nocloud" images (cloud-init compatible)
- Proxmox VE 8.0+ (compatible with 9.0)

---

### 2.2 Automating Talos Installation with Packer and Terraform (Suraj Remanan)

**URL:** [https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/](https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/)

**Key Best Practices:**
- Create custom Talos images with system extensions via Image Factory
- Use schema.yaml for defining required extensions (qemu-guest-agent, nvidia-drivers)
- Integrate Packer templates with Terraform for full automation
- Configure Cilium and Longhorn during cluster deployment

**Custom Extensions Configuration:**
```yaml
# schema.yaml for Talos Image Factory
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
      - siderolabs/nvidia-container-toolkit-production
```

**Relevant Patterns:**
- Packer builds golden Talos image with extensions
- Terraform uses template to provision cluster nodes
- Ansible handles Day 2 operations and updates

---

### 2.3 Talos Kubernetes on Proxmox using OpenTofu (Stonegarden)

**URL:** [https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/)

**Key Best Practices:**
- Use Talos Image Factory for generating custom images (August 2024 approach)
- Automate image download and preparation in Packer build
- Set VM CPU type to "host" for Talos v1.0+ (x86-64-v2 requirement)
- Configure KubePrism and disable Flannel when using Cilium

**Version Compatibility:**
- Talos 1.8.0+ recommended
- OpenTofu/Terraform compatible workflow
- Proxmox 8.x+ (compatible with 9.0)

**Talos-Specific VM Requirements:**
- CPU type: "host" (not kvm64)
- Minimum: 2GB RAM, 2 cores, 10GB disk
- Recommended: 24-32GB RAM, 6-8 cores, 150-200GB disk

---

### 2.4 GitHub - kubebn/talos-proxmox-kaas

**URL:** [https://github.com/kubebn/talos-proxmox-kaas](https://github.com/kubebn/talos-proxmox-kaas)

**Key Best Practices:**
- Complete Kubernetes-as-a-Service implementation
- Packer template downloads Talos from Image Factory
- Terraform provisions cluster from template
- Includes GitOps setup with FluxCD

**Packer Configuration Example:**
- Uses Arch Linux 2024 ISO as boot medium
- Downloads Talos image during build
- Writes to disk and converts to template
- Reference: `packer/proxmox.pkr.hcl` in repository

---

### 2.5 GitHub - Robert-litts/Talos_Kubernetes

**URL:** [https://github.com/Robert-litts/Talos_Kubernetes](https://github.com/Robert-litts/Talos_Kubernetes)

**Key Best Practices:**
- Automated Talos cluster deployment with Packer + Terraform
- Includes network configuration automation
- Demonstrates single-node and multi-node cluster patterns
- GPU passthrough configuration examples

**Relevant Patterns:**
- End-to-end automation from image build to cluster deployment
- Integration with Proxmox API for VM management
- Documentation for troubleshooting common issues

---

## 3. Cloud-Init Integration for Traditional OSes

### 3.1 Ubuntu Server 22.04 with Packer and Subiquity (Julien Brochet)

**URL:** [https://www.aerialls.eu/posts/ubuntu-server-2204-image-packer-subiquity-for-proxmox/](https://www.aerialls.eu/posts/ubuntu-server-2204-image-packer-subiquity-for-proxmox/)

**Key Best Practices:**
- Use Subiquity autoinstall (YAML) instead of deprecated preseed
- Cloud-init YAML file for fully automated installation
- Install qemu-guest-agent package via cloud-init packages list
- Configure serial console for cloud-init communication
- Set network config to DHCP during template creation

**Autoinstall Configuration Structure:**
```yaml
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: ubuntu-template
    username: ubuntu
  ssh:
    install-server: true
  packages:
    - qemu-guest-agent
    - cloud-init
  late-commands:
    - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ubuntu
```

**Version Compatibility:**
- Ubuntu 20.04, 22.04, 24.04 (Subiquity-based)
- Packer 1.8.0+
- Proxmox VE 7.0+ (compatible with 9.0)

---

### 3.2 Create Cloud-Init VM Templates with Packer (The Uncommon Engineer)

**URL:** [https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/](https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/)

**Key Best Practices:**
- Comprehensive guide for Proxmox + Packer + Cloud-init workflow
- Packer starts HTTP server to serve user-data file
- VM downloads cloud-init config during first boot
- Cloud-init creates users, installs packages, and reboots
- After reboot, Packer connects via SSH to continue provisioning

**Critical Requirements:**
- qemu-guest-agent: Required for Packer to detect VM IP address
- cloud-init: Required for SSH key injection and initial config
- Serial console: Required for cloud-init communication
- Cloud-init CDROM drive: Added after template conversion

**Network Configuration:**
- http_bind_address must be reachable from Proxmox server
- Firewall rules may need adjustment for HTTP server
- DHCP recommended during template creation

---

### 3.3 GitHub - aerialls/madalynn-packer

**URL:** [https://github.com/aerialls/madalynn-packer](https://github.com/aerialls/madalynn-packer)

**Key Best Practices:**
- Production-ready Packer files for Ubuntu 20.04 and 22.04
- Uses cloud-init autoinstall method
- Includes proper cloud-init configuration templates
- Demonstrates variable management for multiple environments

**Relevant Patterns:**
- Separate directories for each OS version
- Shared variables for common configuration
- Cloud-init user-data templates
- Post-installation cleanup scripts

---

### 3.4 Proxmox Cloud-Init Support (Official Wiki)

**URL:** [https://pve.proxmox.com/wiki/Cloud-Init_Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)

**Key Best Practices:**
- Cloud-init requires IDE CDROM drive for config
- Configure DNS servers and search domains
- Support for user-data and vendor-data
- Network configuration via cloud-init or Proxmox UI

**Cloud-Init Configuration:**
- User data: Initial user creation, SSH keys, packages
- Network config: DHCP or static IP configuration
- Meta data: Instance ID, hostname, network info
- Vendor data: Additional provider-specific data

---

## 4. Windows Server Automation

### 4.1 Windows Server 2025 Proxmox Packer Build (Virtualization Howto)

**URL:** [https://www.virtualizationhowto.com/2024/11/windows-server-2025-proxmox-packer-build-fully-automated/](https://www.virtualizationhowto.com/2024/11/windows-server-2025-proxmox-packer-build-fully-automated/)

**Key Best Practices:**
- Create API token in Proxmox for Packer authentication
- Use Autounattend.xml for unattended Windows installation
- Install VirtIO drivers during installation
- Install Cloudbase-Init for cloud-init compatibility
- Run Windows Updates as part of build process

**Required Files:**
- Windows Server ISO (2022, 2025)
- VirtIO drivers ISO (version 1.271+)
- Autounattend.xml configuration
- Post-installation PowerShell scripts

**Version Compatibility:**
- Published: November 2024
- Windows Server 2022, 2025
- Proxmox VE 8.0+ (compatible with 9.0)
- Packer 1.10.0+

---

### 4.2 GitHub - EnsoIT/packer-windows-proxmox

**URL:** [https://github.com/EnsoIT/packer-windows-proxmox](https://github.com/EnsoIT/packer-windows-proxmox)

**Key Best Practices:**
- Automated Windows Server 2022 Desktop and Core templates
- Includes latest Windows Updates in build
- Installs VirtIO drivers automatically
- Installs Cloudbase-Init for cloud-init support

**Build Features:**
- Fully automated installation
- Windows Update integration
- VirtIO driver installation
- Cloud-init compatibility via Cloudbase-Init
- Template ready for Terraform deployment

---

### 4.3 GitHub - marcinbojko/proxmox-kvm-packer

**URL:** [https://github.com/marcinbojko/proxmox-kvm-packer](https://github.com/marcinbojko/proxmox-kvm-packer)

**Key Best Practices:**
- Comprehensive multi-OS Packer templates
- Requires at least 100GB free disk space for Windows builds
- VirtIO ISO version 1.271+ required
- Configure variables in `proxmox/variables*.pkvars.hcl`
- Datastore names must match Proxmox configuration

**Configuration Requirements:**
```hcl
# proxmox/variables.pkvars.hcl
storage_pool     = "local-lvm"
iso_file         = "local:iso/windows-server-2022.iso"
iso_storage_pool = "local"
```

**Supported Operating Systems:**
- Windows Server 2022
- Multiple Linux distributions
- Comprehensive variable management

---

## 5. Arch Linux & NixOS Templates

### 5.1 GitHub - jogleasonjr/packer-arch-proxmox

**URL:** [https://github.com/jogleasonjr/packer-arch-proxmox](https://github.com/jogleasonjr/packer-arch-proxmox)

**Key Best Practices:**
- Packer template for Arch Linux on Proxmox
- Uses archinstall scripts for automation
- Minimal base system installation
- Customizable package selection

**Build Command:**
```bash
packer build templates/archlinux-x86_64.json
```

**Relevant Patterns:**
- Arch Linux bootstrap process
- Package management automation
- Template configuration for rolling release

---

### 5.2 GitHub - dandyrow/packer-template-proxmox-archlinux

**URL:** [https://github.com/dandyrow/packer-template-proxmox-archlinux](https://github.com/dandyrow/packer-template-proxmox-archlinux)

**Key Best Practices:**
- Modern HCL2 Packer template for Arch Linux
- Automated partitioning and installation
- Cloud-init integration
- Minimal and optimized base system

**Version Compatibility:**
- Arch Linux 2024.xx.xx ISO
- Packer 1.8.0+
- Proxmox VE 8.0+ (compatible with 9.0)

---

### 5.3 Running NixOS on Proxmox (mtlynch.io)

**URL:** [https://mtlynch.io/notes/nixos-proxmox/](https://mtlynch.io/notes/nixos-proxmox/)

**Key Best Practices:**
- Generate VMA images for Proxmox import
- Use nixos-generators for template creation
- Configure CPU, memory, network in Nix configuration
- Avoid manual Proxmox UI configuration

**NixOS Template Generation:**
```bash
nix run github:nix-community/nixos-generators -- --format proxmox
```

**Relevant Patterns:**
- Declarative VM configuration in Nix
- Automated image generation
- Import VMA to Proxmox

---

### 5.4 NixOS Wiki - Proxmox Virtual Environment

**URL:** [https://nixos.wiki/wiki/Proxmox_Virtual_Environment](https://nixos.wiki/wiki/Proxmox_Virtual_Environment)

**Key Best Practices:**
- Multiple deployment options: VM and LXC containers
- NixOS 24.05+ with Proxmox 8.x compatibility
- Use nixos-generators for VM templates
- Download lxdContainerImage for LXC containers

**LXC Container Setup:**
1. Download latest NixOS x86_64 lxdContainerImage
2. Upload to Proxmox storage
3. Create container from template
4. Configure networking and resources

---

## 6. Common Pitfalls & Troubleshooting

### 6.1 Packer & Proxmox: A Bumpy Road (DEV Community)

**URL:** [https://dev.to/shandoncodes/packer-proxmox-a-bumpy-road-1de2](https://dev.to/shandoncodes/packer-proxmox-a-bumpy-road-1de2)

**Common Issues Identified:**

**1. Authentication Errors (401 Unauthorized):**
- **Problem:** Using wrong API token format
- **Solution:** Use `username@pam!token-name` format, not `username@pam`
- **Example:** `packer@pam!packer-token` instead of `packer@pam`

**2. Permission Errors (403 Forbidden):**
- **Problem:** Insufficient API token permissions
- **Solution:** Grant required permissions:
  - `VM.Allocate` - Create VMs
  - `VM.Config.*` - Configure VM settings
  - `Datastore.AllocateSpace` - Use storage
  - `Sys.Audit` - Query node resources

**3. ISO Upload Error (506):**
- **Problem:** Packer plugin v1.1.1 regression with HTTP headers
- **Solution:**
  - Revert to plugin version 1.1.0, or
  - Use `iso_file` instead of `iso_url` and pre-upload ISO

**4. VM Powerdown Timeout:**
- **Problem:** "VM quit/powerdown failed - got timeout"
- **Solution:**
  - qemu-guest-agent installed but not running/recognized
  - Restart VM after OS installation before template conversion
  - Increase shutdown timeout in Packer config

---

### 6.2 Proxmox Support Forum - Packer Issues (2024)

**URL:** [https://forum.proxmox.com/tags/packer/](https://forum.proxmox.com/tags/packer/)

**Recent Issues (2024):**

**1. "No space left on device" Error:**
- **Problem:** pveproxy error even with available storage
- **Solution:** Check /tmp and /var/lib/vz disk usage
- **Workaround:** Manually upload ISO and use `iso_file` parameter

**2. Template Conversion Error (500):**
- **Problem:** "Error updating template: 500 got no worker upid"
- **Solution:**
  - Occurs intermittently (~2/3 of builds)
  - Retry build operation
  - Check Proxmox task logs for details

**3. Ubuntu Installation Hangs:**
- **Problem:** Subiquity installer hangs at package installation
- **Solution:** Increase RAM allocation to 4GB during build
- **Reason:** Installer needs more memory for package operations

---

### 6.3 GitHub Issues - packer-plugin-proxmox

**URL:** [https://github.com/hashicorp/packer-plugin-proxmox/issues](https://github.com/hashicorp/packer-plugin-proxmox/issues)

**Known Issues:**

**1. CPU Type Not Passed (v1.2.2):**
- **Issue:** Regression where CPU type configuration ignored
- **Fixed:** Version 1.2.3
- **Workaround:** Pin to v1.2.1 or upgrade to v1.2.3

**2. Misleading 501 Error:**
- **Problem:** 501 error displayed instead of 401 Unauthorized
- **Solution:** Check authentication configuration first
- **Status:** Known issue, improve error messages

**3. Parameter Verification Errors (400):**
- **Problem:** Invalid format for network/disk options
- **Solution:** Review official documentation for correct parameter syntax
- **Common:** Incorrect disk storage pool format

---

## 7. QEMU Guest Agent Best Practices

### 7.1 Official Packer Proxmox ISO Builder Documentation

**URL:** [https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)

**Key Best Practices:**

**qemu_agent Configuration:**
- **Default:** `true` (enabled)
- **When enabled:** qemu-guest-agent MUST be installed in guest OS
- **When disabled:** Use `ssh_host` parameter for SSH connection
- **Requirement:** Essential for Packer to detect VM IP address

**Configuration Example:**
```hcl
source "proxmox-iso" "example" {
  qemu_agent = true

  # Wait for guest agent to be ready
  ssh_timeout = "20m"

  # SCSI controller for guest agent communication
  scsi_controller = "virtio-scsi-pci"
}
```

---

### 7.2 Cloud-Init Installation Best Practices

**URL:** [https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/](https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/)

**Installation Methods:**

**1. Via Cloud-Init (Recommended):**
```yaml
#cloud-config
packages:
  - qemu-guest-agent
  - cloud-init

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
```

**2. Via Pre-Installation (Advanced):**
```bash
# Using virt-customize on cloud image
virt-customize -a ubuntu-22.04-cloud.img \
  --install qemu-guest-agent \
  --run-command 'systemctl enable qemu-guest-agent'
```

**Benefits:**
- VM resource reporting in Proxmox UI
- Faster IP address detection for SSH
- Better shutdown/reboot handling
- Guest filesystem quiescing for snapshots

---

### 7.3 Common Guest Agent Issues

**URL:** [https://github.com/hashicorp/packer-plugin-proxmox/issues/91](https://github.com/hashicorp/packer-plugin-proxmox/issues/91)

**Issue:** "Error getting SSH address: 500 QEMU guest agent is not running"

**Root Causes:**
1. Guest agent not installed in VM
2. Guest agent installed but not started
3. Guest agent not recognized before first reboot
4. Insufficient wait time for agent startup

**Solutions:**
1. Ensure package installed via cloud-init or install script
2. Enable and start service: `systemctl enable --now qemu-guest-agent`
3. Add reboot step before template conversion
4. Increase `ssh_timeout` in Packer configuration
5. Use `boot_wait` to allow OS to fully initialize

---

## 8. NVIDIA GPU & Talos System Extensions

### 8.1 Talos NVIDIA GPU Official Documentation

**URL:** [https://www.talos.dev/v1.9/talos-guides/configuration/nvidia-gpu-proprietary/](https://www.talos.dev/v1.9/talos-guides/configuration/nvidia-gpu-proprietary/)

**Key Best Practices:**

**System Extensions Required:**
1. `nonfree-kmod-nvidia-production` - Proprietary NVIDIA kernel modules
2. `nvidia-container-toolkit-production` - Container runtime support

**Image Factory Configuration:**
```yaml
# schema.yaml for custom Talos image
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
      - siderolabs/nonfree-kmod-nvidia-production
      - siderolabs/nvidia-container-toolkit-production
```

**Machine Configuration:**
```yaml
machine:
  kernel:
    modules:
      - name: nvidia
      - name: nvidia_uvm
      - name: nvidia_drm
      - name: nvidia_modeset
```

**Version Compatibility:**
- Talos 1.8.0+: Improved NVIDIA support
- Extension versions tied to Talos release
- Update extensions when upgrading Talos

---

### 8.2 NVIDIA GPU Passthrough to TalosOS (Duck's Blog)

**URL:** [https://blog.duckdefense.cc/kubernetes-gpu-passthrough/](https://blog.duckdefense.cc/kubernetes-gpu-passthrough/)

**Key Best Practices:**

**Proxmox Host Setup:**
1. Enable IOMMU in BIOS
2. Add kernel parameters: `amd_iommu=on iommu=pt` (AMD) or `intel_iommu=on iommu=pt` (Intel)
3. Blacklist NVIDIA drivers on host
4. Bind GPU to VFIO driver

**Talos VM Configuration:**
1. Set CPU type to "host" (required for Talos 1.0+)
2. Add PCI device passthrough for GPU
3. Enable machine resources in VM config

**Talos Image Preparation:**
1. Build custom image from factory.talos.dev with NVIDIA extensions
2. Download image using correct schematic ID
3. Use Packer to prepare template with custom image

**Kubernetes Configuration:**
1. Install NVIDIA GPU Operator
2. Configure RuntimeClass for GPU workloads
3. Deploy workloads with GPU resource requests

---

### 8.3 Automating Talos with GPU Support (Suraj Remanan)

**URL:** [https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/](https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/)

**Automation Workflow:**

**1. Packer Build Phase:**
- Create schema.yaml with NVIDIA extensions
- Submit to Image Factory API
- Download custom Talos image
- Write to VM disk and create template

**2. Terraform Deployment Phase:**
- Provision VMs from Packer template
- Configure GPU passthrough via Proxmox provider
- Apply Talos machine configuration with GPU settings

**3. Kubernetes Configuration:**
- Deploy NVIDIA GPU Operator via Helm
- Configure device plugin for GPU scheduling
- Test GPU availability in pods

---

### 8.4 Talos System Extensions Repository

**URL:** [https://github.com/siderolabs/extensions](https://github.com/siderolabs/extensions)

**Available NVIDIA Extensions:**

**Production Branch:**
- `nonfree-kmod-nvidia-production` - Proprietary drivers (recommended for stability)
- `nvidia-container-toolkit-production` - Container runtime
- `nvidia-fabricmanager` - NVLink support (multi-GPU only)

**Open Source Branch:**
- `nvidia-open-gpu-kernel-modules` - Open source drivers (newer GPUs)

**Other Extensions:**
- `iscsi-tools` - Required for Longhorn storage
- `util-linux-tools` - Required for Longhorn
- `qemu-guest-agent` - Proxmox integration

**Extension Versioning:**
- Extensions tied to specific Talos versions
- Update extensions when upgrading Talos
- Check compatibility matrix in repository

---

## 9. ISO vs Clone Builder Strategy

### 9.1 Official Comparison (HashiCorp Documentation)

**URL:** [https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)

**proxmox-iso Builder:**
- **Purpose:** Build from installation media (ISO)
- **Use Case:** Creating initial base templates
- **Process:** Full OS installation from scratch
- **Time:** Longer build times (15-60 minutes depending on OS)
- **Advantages:** Complete control over installation, reproducible from source
- **Disadvantages:** Slower, requires more configuration

**proxmox-clone Builder:**
- **Purpose:** Clone existing cloud-init enabled template
- **Use Case:** Iterative updates, patching, layered approach
- **Process:** Clone template, apply updates, save as new template
- **Time:** Faster (5-15 minutes)
- **Advantages:** Quick iterations, efficient for updates
- **Disadvantages:** Requires initial template, depends on cloud-init

---

### 9.2 Clone Builder Best Practices (Mark Tinderholt's Blog)

**URL:** [https://www.marktinderholt.com/azure/terraform/proxmox/infrastructure-as-code/home%20lab/packer/cloud/2024/10/08/proxmox-packer-part2.html](https://www.marktinderholt.com/azure/terraform/proxmox/infrastructure-as-code/home%20lab/packer/cloud/2024/08/proxmox-packer-part2.html)

**Key Best Practices:**

**When to Use Clone Builder:**
1. Regular patching and updates
2. Creating specialized variants from base template
3. Testing configuration changes quickly
4. Maintaining multiple similar images

**Requirements for Clone Builder:**
- Source template must have qemu-guest-agent installed
- Source template must have cloud-init installed and configured
- Source template must be a valid Proxmox template (not regular VM)

**Workflow Example:**
```hcl
source "proxmox-clone" "ubuntu-updates" {
  clone_vm              = "ubuntu-22.04-base"  # Base template
  vm_name               = "ubuntu-22.04-patched-${formatdate("YYYYMMDD", timestamp())}"
  template_description  = "Ubuntu 22.04 with latest updates"

  # Cloud-init for customization
  cloud_init            = true
  cloud_init_storage_pool = "local-lvm"
}
```

---

### 9.3 Practical Comparison (Aaron S. Jackson)

**URL:** [https://aaronsplace.co.uk/blog/2021-08-07-packer-proxmox-clone.html](https://aaronsplace.co.uk/blog/2021-08-07-packer-proxmox-clone.html)

**Recommended Strategy:**

**Use ISO Builder For:**
- Initial golden image creation
- Major OS version upgrades
- Creating base templates for new OS distributions
- Annual or semi-annual rebuilds

**Use Clone Builder For:**
- Monthly security updates
- Application stack layering
- Environment-specific configurations
- Quick iterations during development

**Hybrid Approach (Recommended):**
1. Create base template with ISO builder (quarterly)
2. Create updated variants with clone builder (monthly)
3. Version templates with clear naming: `{os}-{type}-{date}`
4. Keep 2-3 recent versions for rollback capability

---

## 10. Network Configuration & Firewall

### 10.1 HTTP Bind Address Configuration

**URL:** [https://jeremyhajek.com/2020/12/19/packer-proxmox-iso-ssh-solved-copy.html](https://jeremyhajek.com/2020/12/19/packer-proxmox-iso-ssh-solved-copy.html)

**Key Best Practices:**

**http_bind_address Parameter:**
- **Default:** `0.0.0.0` (binds to all interfaces)
- **Best Practice:** Specify exact IP address reachable from Proxmox
- **Critical:** Must be network-accessible from Proxmox server

**Configuration Example:**
```hcl
source "proxmox-iso" "example" {
  # HTTP server for serving boot files
  http_bind_address = "192.168.1.100"  # Packer host IP
  http_port_min     = 8100
  http_port_max     = 8100

  # Proxmox will download from this HTTP server
  boot_command = [
    # Reference: http://{{ .HTTPIP }}:{{ .HTTPPort }}/user-data
  ]
}
```

**Common Issues:**
- Firewall blocking HTTP server ports
- Incorrect interface selection
- Network routing issues between Packer host and Proxmox

---

### 10.2 Firewall Configuration

**URL:** [https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)

**Network Adapter Firewall Setting:**
```hcl
network_adapters {
  bridge   = "vmbr0"
  model    = "virtio"
  firewall = false  # Disable Proxmox firewall for build VM
}
```

**Packer Host Firewall:**
- Open ports for HTTP server: `http_port_min` to `http_port_max`
- Common range: 8100-8200
- Required protocols: TCP

**iptables/nftables Configuration:**
```bash
# Allow incoming connections to Packer HTTP server
iptables -A INPUT -p tcp --dport 8100:8200 -j ACCEPT

# Or for nftables
nft add rule inet filter input tcp dport 8100-8200 accept
```

---

### 10.3 GitHub Issue - http_interface Problem

**URL:** [https://github.com/hashicorp/packer/issues/10369](https://github.com/hashicorp/packer/issues/10369)

**Issue:** Unable to use `http_interface` with Proxmox provider

**Workaround:**
- Use `http_bind_address` instead of `http_interface`
- Manually specify IP address rather than interface name
- Ensure IP is on correct network segment

**Example:**
```hcl
# Don't use this (may not work)
# http_interface = "eth0"

# Use this instead
http_bind_address = "192.168.1.100"
```

---

## 11. Storage Pool & Disk Format Performance

### 11.1 Raw vs qcow2 Performance (Proxmox Forum)

**URL:** [https://forum.proxmox.com/threads/raw-vs-qcow2.34566/](https://forum.proxmox.com/threads/raw-vs-qcow2.34566/)

**Key Findings:**

**Performance Comparison:**
- **Raw:** Direct disk access, faster performance
- **qcow2:** Overhead from CoW and metadata, ~5% slower (upstream QEMU)
- **Real-world:** Difference can be more significant with heavy usage

**Use Case Recommendations:**

**Use Raw Format When:**
- Storage backend has native CoW (ZFS, Ceph, LVM-thin)
- Maximum performance required
- Using snapshots at storage layer level
- Large VM workloads

**Use qcow2 Format When:**
- Storage backend lacks CoW features (directory storage)
- Need thin provisioning without storage-layer support
- Portability is priority
- Smaller VMs with light usage

---

### 11.2 Storage Backend Considerations

**URL:** [https://ikus-soft.com/en_CA/blog/techies-10/proxmox-ve-raw-qcow2-or-zvol-74](https://ikus-soft.com/en_CA/blog/techies-10/proxmox-ve-raw-qcow2-or-zvol-74)

**Best Practices by Storage Type:**

**ZFS Storage:**
- **Recommended:** Raw format on zvol
- **Reason:** ZFS provides native CoW, snapshots, compression
- **Avoid:** qcow2 on ZFS (double CoW overhead)

**LVM-Thin:**
- **Recommended:** Raw format
- **Reason:** LVM-thin provides thin provisioning
- **Note:** qcow2 not supported on lvm-thin

**Directory Storage (ext4, xfs):**
- **Options:** Raw or qcow2
- **Raw:** Better performance but no thin provisioning
- **qcow2:** Thin provisioning support

**Packer Configuration:**
```hcl
disks {
  disk_size         = "20G"
  storage_pool      = "local-zfs"  # ZFS pool
  format            = "raw"        # Use raw for ZFS
  type              = "scsi"
}
```

---

### 11.3 Packer qcow2 Format Issues

**URL:** [https://github.com/hashicorp/packer-plugin-proxmox/issues/23](https://github.com/hashicorp/packer-plugin-proxmox/issues/23)

**Known Issues:**

**Problem:** Packer creates raw disks regardless of format specification

**Status:** Historical issue, improved in recent versions

**Workaround:**
- Verify storage pool supports desired format
- Check Packer plugin version (1.2.0+ recommended)
- Use raw format for ZFS/LVM-thin storage
- Reserve qcow2 for directory-based storage

**Storage Pool Compatibility:**
| Storage Type | Raw | qcow2 |
|-------------|-----|-------|
| ZFS         | ✅  | ✅*   |
| LVM-thin    | ✅  | ❌    |
| Directory   | ✅  | ✅    |
| Ceph RBD    | ✅  | ❌    |

*Not recommended due to double CoW overhead

---

## 12. Plugin Versions & Compatibility

### 12.1 Packer Plugin Proxmox Releases

**URL:** [https://github.com/hashicorp/packer-plugin-proxmox/releases](https://github.com/hashicorp/packer-plugin-proxmox/releases)

**Version History:**

**v1.2.3 (July 2025) - RECOMMENDED:**
- Fixes CPU type regression from v1.2.2
- Stable and production-ready
- Compatible with Proxmox VE 9.0

**v1.2.2 (2024):**
- Known issue: CPU type not passed to build VM
- Skip this version

**v1.2.1 (2024):**
- Stable, some users pinned to this version
- Works well with Proxmox VE 8.x and 9.0

**v1.2.0 (September 2024):**
- Major feature release
- Improved Proxmox API integration
- Better error handling

**v1.1.8 (2024):**
- Last of v1.1.x series
- Stable but missing newer features

**v1.1.1 (2023):**
- Known bug: ISO upload error (506)
- Avoid this version

**v1.1.0 (2023):**
- Recommended alternative to v1.1.1
- Stable for Proxmox 7.x-8.x

---

### 12.2 Version Compatibility Matrix

**Recommended Combinations:**

| Packer Version | Plugin Version | Proxmox Version | Status |
|---------------|---------------|-----------------|---------|
| 1.14.0+       | 1.2.3         | 9.0            | ✅ Best |
| 1.12.0+       | 1.2.1-1.2.3   | 8.2-9.0        | ✅ Good |
| 1.10.0+       | 1.2.0         | 8.0-9.0        | ✅ Good |
| 1.9.0+        | 1.1.8         | 7.x-8.x        | ⚠️ Legacy |
| Any           | 1.2.2         | Any            | ❌ Avoid (bug) |
| Any           | 1.1.1         | Any            | ❌ Avoid (bug) |

---

### 12.3 Plugin Configuration Best Practices

**URL:** [https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)

**Recommended Plugin Block:**
```hcl
packer {
  required_version = ">= 1.14.0"

  required_plugins {
    proxmox = {
      version = "~> 1.2.3"  # Pin to exact version
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
```

**Version Pinning Strategies:**
- **Exact version:** `version = "1.2.3"` - Most stable, no surprises
- **Pessimistic:** `version = "~> 1.2.0"` - Allow patch updates (1.2.x)
- **Range:** `version = ">= 1.2.0, < 1.3.0"` - More flexible
- **Latest:** `version = ">= 1.2.0"` - Not recommended for production

---

## 13. Best Practices Summary

### 13.1 Universal Best Practices (All OS)

**Authentication & Security:**
1. Use API tokens instead of passwords
2. Create dedicated Packer user with minimal permissions
3. Store credentials in environment variables or HashiCorp Vault
4. Never commit credentials to version control

**Template Naming:**
1. Use descriptive names with versioning
2. Include timestamp for tracking: `{os}-{version}-{YYYYMMDD}`
3. Add template descriptions with build details
4. Maintain template inventory/documentation

**QEMU Guest Agent:**
1. Always install qemu-guest-agent in templates
2. Enable and start service before template conversion
3. Set `qemu_agent = true` in Packer configuration
4. Verify agent running before SSH provisioning

**Cloud-Init (Traditional OS):**
1. Install cloud-init package in all templates
2. Add cloud-init CDROM drive after template conversion
3. Configure serial console for cloud-init communication
4. Test cloud-init with minimal configuration before production

**Storage Configuration:**
1. Use raw format with ZFS/LVM-thin storage
2. Use qcow2 only with directory-based storage
3. Choose appropriate storage pool for VM workloads
4. Configure adequate disk size for OS and updates

**Network Configuration:**
1. Specify `http_bind_address` reachable from Proxmox
2. Open firewall ports for Packer HTTP server
3. Use virtio network adapter for best performance
4. Disable Proxmox firewall on build VMs

**Build Performance:**
1. Allocate sufficient RAM (4GB+ for modern OS)
2. Use SSD storage for faster builds
3. Enable KVM acceleration
4. Use local ISOs instead of remote downloads

---

### 13.2 OS-Specific Best Practices

**Talos Linux:**
1. Use Talos Image Factory for custom images
2. Include system extensions: qemu-guest-agent, nvidia (if GPU)
3. Use Arch Linux ISO as intermediate boot environment
4. Set VM CPU type to "host" (required for Talos 1.0+)
5. Download raw image during Packer build, not pre-downloaded
6. Disable Flannel and kube-proxy if using Cilium

**Debian/Ubuntu:**
1. Use Subiquity autoinstall (Ubuntu 20.04+) instead of preseed
2. Install qemu-guest-agent via packages list in cloud-init
3. Configure DHCP networking during template creation
4. Include cloud-init package in base installation
5. Clean apt cache and logs before template conversion
6. Test SSH key injection after template deployment

**Windows Server:**
1. Use Autounattend.xml for unattended installation
2. Install VirtIO drivers during OS installation
3. Install Cloudbase-Init for cloud-init compatibility
4. Run Windows Updates as part of build process
5. Allocate sufficient disk space (60GB+ for updates)
6. Sysprep before template conversion

**Arch Linux:**
1. Use latest Arch ISO (rolling release)
2. Automate partitioning and installation
3. Install base-devel and common packages
4. Enable systemd-networkd and systemd-resolved
5. Configure pacman mirrors for fastest downloads

**NixOS:**
1. Use nixos-generators for VMA image creation
2. Define VM configuration declaratively in Nix
3. Generate image with `--format proxmox`
4. Import VMA to Proxmox storage
5. Avoid manual UI configuration

---

### 13.3 CI/CD Integration Best Practices

**Version Control:**
1. Store all Packer templates in Git
2. Use separate branches for development and production
3. Tag releases for template versions
4. Include .gitignore for sensitive files

**Automation:**
1. Implement automated builds on schedule (weekly/monthly)
2. Run validation and linting in CI pipeline
3. Test templates in non-production environment first
4. Archive old templates with clear retention policy

**Documentation:**
1. Maintain README with build instructions
2. Document required variables and their purpose
3. Include troubleshooting section
4. Keep changelog of template modifications

**Testing:**
1. Validate Packer templates: `packer validate`
2. Test template deployment after build
3. Verify cloud-init functionality
4. Confirm qemu-guest-agent reporting

---

## 14. Reference Implementation Patterns

### 14.1 Basic ISO Builder Template (Ubuntu 24.04)

```hcl
packer {
  required_version = ">= 1.14.0"

  required_plugins {
    proxmox = {
      version = "~> 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API token ID"
  default     = "packer@pam!packer-token"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
  default     = "pve"
}

source "proxmox-iso" "ubuntu2404" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # VM configuration
  vm_name              = "ubuntu-24.04-${formatdate("YYYYMMDD", timestamp())}"
  template_description = "Ubuntu 24.04 LTS golden image"

  # ISO configuration
  iso_file         = "local:iso/ubuntu-24.04-live-server-amd64.iso"
  iso_checksum     = "sha256:CHECKSUM_HERE"
  unmount_iso      = true

  # Hardware configuration
  cores            = 2
  memory           = 4096
  scsi_controller  = "virtio-scsi-pci"

  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }

  disks {
    disk_size         = "20G"
    storage_pool      = "local-zfs"
    format            = "raw"
    type              = "scsi"
  }

  # QEMU agent
  qemu_agent = true

  # Cloud-init
  cloud_init              = true
  cloud_init_storage_pool = "local-zfs"

  # Boot configuration
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]

  # HTTP server for cloud-init files
  http_bind_address = "192.168.1.100"
  http_directory    = "http"
  http_port_min     = 8100
  http_port_max     = 8100

  # SSH configuration
  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout  = "20m"
}

build {
  sources = ["source.proxmox-iso.ubuntu2404"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y qemu-guest-agent cloud-init",
      "sudo systemctl enable qemu-guest-agent",
      "sudo apt-get clean"
    ]
  }

  # Cleanup before template conversion
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
      "sudo rm -f /etc/machine-id",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo sync"
    ]
  }
}
```

### 14.2 Talos Linux Template with Image Factory

```hcl
packer {
  required_version = ">= 1.14.0"

  required_plugins {
    proxmox = {
      version = "~> 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type = string
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "talos_version" {
  type    = string
  default = "v1.10.0"
}

# Talos Image Factory schematic ID with extensions
variable "talos_schematic_id" {
  type        = string
  description = "Talos Factory schematic ID with qemu-guest-agent and nvidia extensions"
  # Generate at https://factory.talos.dev/
}

source "proxmox-iso" "talos" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # VM configuration
  vm_name              = "talos-${var.talos_version}-${formatdate("YYYYMMDD", timestamp())}"
  template_description = "Talos Linux ${var.talos_version} with NVIDIA extensions"

  # Use Arch Linux ISO as boot medium
  iso_file     = "local:iso/archlinux-2024.12.01-x86_64.iso"
  iso_checksum = "sha256:ARCH_CHECKSUM_HERE"
  unmount_iso  = true

  # Hardware configuration - Talos requirements
  cpu_type     = "host"  # Required for Talos v1.0+
  cores        = 2
  memory       = 2048
  scsi_controller = "virtio-scsi-pci"

  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }

  disks {
    disk_size    = "20G"
    storage_pool = "local-zfs"
    format       = "raw"
    type         = "scsi"
  }

  # QEMU agent will be in Talos image
  qemu_agent = true

  # Boot into Arch Linux
  boot_wait = "10s"
  boot_command = [
    "<enter><wait30>",
  ]

  # SSH to Arch Linux live environment
  ssh_username = "root"
  ssh_password = "root"
  ssh_timeout  = "10m"
}

build {
  sources = ["source.proxmox-iso.talos"]

  # Download Talos image from Image Factory
  provisioner "shell" {
    inline = [
      "curl -L https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.raw.xz -o /tmp/talos.raw.xz",
      "xz -d /tmp/talos.raw.xz",
      "dd if=/tmp/talos.raw of=/dev/sda bs=4M status=progress",
      "sync"
    ]
  }
}
```

### 14.3 Windows Server 2022 Template

```hcl
packer {
  required_version = ">= 1.14.0"

  required_plugins {
    proxmox = {
      version = "~> 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type = string
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

source "proxmox-iso" "windows2022" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # VM configuration
  vm_name              = "windows-server-2022-${formatdate("YYYYMMDD", timestamp())}"
  template_description = "Windows Server 2022 with updates and cloudbase-init"

  # ISO configuration
  iso_file = "local:iso/windows-server-2022.iso"

  # Additional ISO for VirtIO drivers
  additional_iso_files {
    cd_files = [
      "./answer_files/Autounattend.xml",
      "./scripts/winrm.ps1"
    ]
    cd_label         = "cidata"
    iso_storage_pool = "local"
  }

  additional_iso_files {
    device           = "sata1"
    iso_file         = "local:iso/virtio-win-0.1.271.iso"
    unmount          = true
    iso_storage_pool = "local"
  }

  # Hardware configuration
  os           = "win11"
  cores        = 4
  memory       = 8192
  bios         = "ovmf"
  machine      = "q35"
  scsi_controller = "virtio-scsi-pci"

  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }

  disks {
    disk_size    = "60G"
    storage_pool = "local-zfs"
    format       = "raw"
    type         = "scsi"
    cache_mode   = "writeback"
  }

  # EFI disk for UEFI boot
  efi_config {
    efi_storage_pool = "local-zfs"
    efi_type         = "4m"
  }

  # QEMU agent
  qemu_agent = true

  # WinRM for provisioning
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = "YourPasswordHere"
  winrm_timeout  = "4h"
}

build {
  sources = ["source.proxmox-iso.windows2022"]

  # Install Windows Updates
  provisioner "powershell" {
    scripts = ["./scripts/install-updates.ps1"]
  }

  # Install Cloudbase-Init
  provisioner "powershell" {
    scripts = ["./scripts/install-cloudbase-init.ps1"]
  }

  # Cleanup and Sysprep
  provisioner "powershell" {
    scripts = ["./scripts/cleanup.ps1"]
  }
}
```

### 14.4 Clone Builder Template (Ubuntu Updates)

```hcl
packer {
  required_version = ">= 1.14.0"

  required_plugins {
    proxmox = {
      version = "~> 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type = string
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "base_template" {
  type        = string
  description = "Base template to clone"
  default     = "ubuntu-24.04-base"
}

source "proxmox-clone" "ubuntu-updates" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # Clone configuration
  clone_vm             = var.base_template
  vm_name              = "ubuntu-24.04-updates-${formatdate("YYYYMMDD", timestamp())}"
  template_description = "Ubuntu 24.04 with latest security updates"

  # Cloud-init for customization
  cloud_init              = true
  cloud_init_storage_pool = "local-zfs"

  # SSH configuration
  ssh_username = "ubuntu"
  ssh_timeout  = "15m"
}

build {
  sources = ["source.proxmox-clone.ubuntu-updates"]

  # Apply updates
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get dist-upgrade -y",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean"
    ]
  }

  # Cleanup before template conversion
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
      "sudo rm -f /etc/machine-id",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo sync"
    ]
  }
}
```

---

## Conclusion

This comprehensive research report covers best practices for building golden VM images with Packer on Proxmox VE 9.0 across multiple operating systems. The key takeaways are:

1. **Use Official Documentation First:** Always reference HashiCorp and Proxmox official documentation for latest syntax and features

2. **Version Compatibility Matters:** Pin to stable plugin versions (1.2.3 recommended), avoid known buggy versions (1.1.1, 1.2.2)

3. **QEMU Guest Agent is Essential:** Install and enable in all templates for proper Proxmox integration and SSH detection

4. **Cloud-Init for Traditional OS:** Use modern autoinstall methods (Subiquity for Ubuntu) instead of deprecated preseed files

5. **Talos Requires Special Approach:** Use Image Factory for custom images with system extensions, set CPU type to "host", use Arch Linux as intermediate boot environment

6. **Storage Format by Backend:** Use raw format with ZFS/LVM-thin, qcow2 only with directory storage

7. **Network Configuration Critical:** Ensure `http_bind_address` is reachable from Proxmox, open firewall ports for HTTP server

8. **ISO vs Clone Strategy:** Use ISO builder for base templates, clone builder for iterative updates and patching

9. **Windows Requires Additional Complexity:** Use Autounattend.xml, VirtIO drivers ISO, Cloudbase-Init for cloud-init compatibility

10. **Test Thoroughly:** Validate templates, test cloud-init functionality, verify qemu-guest-agent reporting before production use

---

## Sources Summary

### Official Documentation (3 sources)
1. [HashiCorp Packer Proxmox Integration](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)
2. [Packer Proxmox ISO Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)
3. [Proxmox Cloud-Init Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)

### GitHub Repositories (10 sources)
4. [hashicorp/packer-plugin-proxmox](https://github.com/hashicorp/packer-plugin-proxmox)
5. [ajschroeder/proxmox-packer-examples](https://github.com/ajschroeder/proxmox-packer-examples)
6. [kubebn/talos-proxmox-kaas](https://github.com/kubebn/talos-proxmox-kaas)
7. [Robert-litts/Talos_Kubernetes](https://github.com/Robert-litts/Talos_Kubernetes)
8. [aerialls/madalynn-packer](https://github.com/aerialls/madalynn-packer)
9. [EnsoIT/packer-windows-proxmox](https://github.com/EnsoIT/packer-windows-proxmox)
10. [marcinbojko/proxmox-kvm-packer](https://github.com/marcinbojko/proxmox-kvm-packer)
11. [jogleasonjr/packer-arch-proxmox](https://github.com/jogleasonjr/packer-arch-proxmox)
12. [dandyrow/packer-template-proxmox-archlinux](https://github.com/dandyrow/packer-template-proxmox-archlinux)
13. [siderolabs/extensions](https://github.com/siderolabs/extensions)

### Blog Posts & Tutorials (8 sources, 2024-2025)
14. [Building Proxmox Templates with Packer - runtimeterror.dev](https://runtimeterror.dev/building-proxmox-templates-packer/)
15. [Packer and Talos Image Factory on Proxmox - JYSK Tech](https://jysk.tech/packer-and-talos-image-factory-on-proxmox-76d95e8dc316)
16. [Automating Talos Installation - Suraj Remanan (Aug 2024)](https://surajremanan.com/posts/automating-talos-installation-on-proxmox-with-packer-and-terraform/)
17. [Talos Kubernetes on Proxmox - Stonegarden (Aug 2024)](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/)
18. [Ubuntu 22.04 with Packer and Subiquity - Julien Brochet](https://www.aerialls.eu/posts/ubuntu-server-2204-image-packer-subiquity-for-proxmox/)
19. [Create Cloud-Init VM Templates - The Uncommon Engineer](https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/)
20. [Windows Server 2025 Packer Build - Virtualization Howto (Nov 2024)](https://www.virtualizationhowto.com/2024/11/windows-server-2025-proxmox-packer-build-fully-automated/)
21. [Mark Tinderholt's Proxmox Packer Guide (Oct 2024)](https://www.marktinderholt.com/azure/terraform/proxmox/infrastructure-as-code/home%20lab/packer/cloud/2024/10/08/proxmox-packer-part2.html)

### Community Forums & Troubleshooting (5 sources)
22. [Packer & Proxmox: A Bumpy Road - DEV Community](https://dev.to/shandoncodes/packer-proxmox-a-bumpy-road-1de2)
23. [Proxmox Forum - Packer Tag](https://forum.proxmox.com/tags/packer/)
24. [packer-plugin-proxmox GitHub Issues](https://github.com/hashicorp/packer-plugin-proxmox/issues)
25. [NVIDIA GPU Passthrough to TalosOS - Duck's Blog](https://blog.duckdefense.cc/kubernetes-gpu-passthrough/)
26. [Packer HTTP Network Configuration - Jeremy Hajek](https://jeremyhajek.com/2020/12/19/packer-proxmox-iso-ssh-solved-copy.html)

### Talos-Specific (4 sources)
27. [Talos NVIDIA GPU Documentation](https://www.talos.dev/v1.9/talos-guides/configuration/nvidia-gpu-proprietary/)
28. [Talos Linux Image Factory](https://factory.talos.dev/)
29. [Running NixOS on Proxmox - mtlynch.io](https://mtlynch.io/notes/nixos-proxmox/)
30. [NixOS Wiki - Proxmox Virtual Environment](https://nixos.wiki/wiki/Proxmox_Virtual_Environment)

### Storage & Performance (3 sources)
31. [Proxmox Forum - Raw vs qcow2](https://forum.proxmox.com/threads/raw-vs-qcow2.34566/)
32. [Proxmox VE: RAW, QCOW2 or ZVOL - IKUS](https://ikus-soft.com/en_CA/blog/techies-10/proxmox-ve-raw-qcow2-or-zvol-74)
33. [packer-plugin-proxmox Issue #23 - qcow2 Format](https://github.com/hashicorp/packer-plugin-proxmox/issues/23)

**Total High-Quality Sources: 33**

---

**Report Prepared:** 2025-11-23
**Research Scope:** Packer 1.14.0+, Proxmox VE 9.0, Multiple OS (Talos, Debian, Ubuntu, Arch, NixOS, Windows)
**Documentation Status:** Comprehensive, Production-Ready
