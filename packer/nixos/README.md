# NixOS Cloud Image Packer Template

This directory contains Packer configuration to build a NixOS golden image for Proxmox VE 9.0 using the official Proxmox image from Hydra.

## Overview

Creates a production-ready NixOS template with:
- **NixOS 25.11** - Latest development release (from Hydra CI)
- **Declarative configuration** - Entire system defined in configuration.nix
- **Full cloud-init integration** - Hostname, IP, SSH keys via Terraform/Proxmox
- **QEMU Guest Agent** - Pre-installed for Proxmox integration
- **SSH Server** - Pre-configured with key-only authentication
- **Default user**: wdiaz with passwordless sudo
- **Fast builds** - 5-10 minutes (vs 20-30 min with ISO)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLOUD IMAGE APPROACH                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. ONE-TIME SETUP (on Proxmox host)                           │
│     └── import-cloud-image.sh                                  │
│         ├── Downloads NixOS VMA from Hydra                     │
│         ├── Restores as base VM (ID: 9200)                     │
│         └── Configures cloud-init, SSH, network                │
│                                                                 │
│  2. PACKER BUILD (from workstation)                            │
│     └── packer build .                                         │
│         ├── Clones base VM (proxmox-clone builder)             │
│         ├── Runs minimal shell provisioners                    │
│         ├── Cleans up for template                             │
│         └── Converts to template (ID: 9202)                    │
│                                                                 │
│  3. DEPLOY (Terraform or manual)                               │
│     └── Clone from template                                    │
│         ├── Cloud-init sets hostname, network, SSH keys        │
│         └── Configure via /etc/nixos/configuration.nix         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## What Makes NixOS Different

NixOS is **declarative** - no Ansible package installation needed:

**Traditional Linux** (Ubuntu/Debian):
```bash
apt install nginx
systemctl enable nginx
vim /etc/nginx/nginx.conf
```

**NixOS**:
```nix
# /etc/nixos/configuration.nix
services.nginx.enable = true;
# Then: nixos-rebuild switch
```

Benefits:
- **Reproducible**: Same config = same system
- **Atomic upgrades**: Rollback if something breaks
- **No dependency hell**: Each package has its own dependencies
- **Self-documenting**: configuration.nix IS the documentation

## Prerequisites

### Tools Required (via Nix shell)

```bash
# Enter project environment
cd /path/to/infra
nix-shell  # or direnv

# Verify
packer --version  # 1.14.3+
```

### Proxmox Setup

1. API token with VM creation permissions
2. Storage pool (default: `tank`)
3. Network bridge (default: `vmbr0`)

## Quick Start

### 1. Import Cloud Image (One-Time on Proxmox Host)

```bash
# Copy script to Proxmox host
scp packer/nixos/import-cloud-image.sh root@proxmox:/tmp/

# SSH to Proxmox and run
ssh root@proxmox
cd /tmp
chmod +x import-cloud-image.sh
./import-cloud-image.sh 9200  # Creates VM ID 9200
```

This downloads the NixOS Proxmox image from Hydra and creates a base VM.

### 2. Configure Packer Variables

```bash
cd packer/nixos
cp nixos.auto.pkrvars.hcl.example nixos.auto.pkrvars.hcl
```

Edit `nixos.auto.pkrvars.hcl`:

```hcl
# Proxmox connection (or use environment variables)
proxmox_url      = "https://proxmox.example.com:8006/api2/json"
proxmox_username = "packer@pve!packer-token"
proxmox_token    = "your-token-secret"
proxmox_node     = "pve"

# Cloud image base VM
cloud_image_vm_id = 9200

# Storage
vm_disk_storage = "tank"
```

**Note:** SSH keys are configured in `config/configuration.nix` (base key) and via cloud-init (additional keys per-VM).

### 3. Build Template

```bash
# Initialize Packer plugins
packer init .

# Validate configuration
packer validate .

# Build template
packer build .
```

**Build time**: 5-10 minutes

### 4. Verify Template

Check in Proxmox UI: `Datacenter → Node → VM Templates`

Should see: `nixos-golden-template`

## VM ID Allocation

| ID | Purpose | Name |
|----|---------|------|
| 9200 | Base cloud image VM | nixos-cloud-base |
| 9202 | Golden template | nixos-golden-template |

## Using the Template

### Option 1: Clone in Proxmox UI

1. Right-click template → Clone
2. Full clone (not linked)
3. Set VM name (becomes hostname via cloud-init)
4. Configure cloud-init: IP, SSH keys (optional)
5. Start VM
6. SSH: `ssh wdiaz@<ip>` (SSH key auth only)
7. Configure via `/etc/nixos/configuration.nix`

### Option 2: Deploy with Terraform

The NixOS template supports full cloud-init integration. VM name becomes hostname, and SSH keys can be added per-VM:

```hcl
resource "proxmox_virtual_environment_vm" "nixos_vm" {
  name      = "nixos-vm-01"  # → becomes hostname
  node_name = "pve"

  clone {
    vm_id = 9202  # Template ID
    full  = true
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
  }

  initialization {
    # Static IP configuration
    ip_config {
      ipv4 {
        address = "10.10.2.14/24"
        gateway = "10.10.2.1"
      }
    }

    # User configuration (optional - default user is 'wdiaz')
    user_account {
      username = "wdiaz"
      # Additional SSH keys (ADDED to base key, not replaced)
      keys = [
        "ssh-ed25519 AAAA... additional-key@example"
      ]
    }
  }
}
```

**Cloud-init features:**

| Setting | Terraform Field | Notes |
|---------|-----------------|-------|
| Hostname | `name` | VM name becomes hostname |
| Static IP | `initialization.ip_config` | Overrides DHCP |
| SSH Keys | `initialization.user_account.keys` | Added to base key |
| User | `initialization.user_account.username` | Default: wdiaz |

### Option 3: Configure with NixOS

After deployment, edit `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Hostname
  networking.hostName = "nixos-vm";

  # Timezone
  time.timeZone = "America/El_Salvador";

  # Users
  users.users.wdiaz = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA... your-key"
    ];
  };

  # Services
  services.openssh.enable = true;
  virtualisation.docker.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
    vim git htop
  ];

  system.stateVersion = "25.11";
}
```

Apply changes:
```bash
sudo nixos-rebuild switch
```

## NixOS-Specific Operations

### Update System

```bash
# Update channels
sudo nix-channel --update

# Rebuild with latest packages
sudo nixos-rebuild switch --upgrade
```

### Rollback

```bash
# List generations
nixos-rebuild list-generations

# Rollback to previous
sudo nixos-rebuild switch --rollback
```

### Garbage Collection

```bash
# Remove old generations
sudo nix-collect-garbage -d

# Check disk usage
du -sh /nix/store
```

## Troubleshooting

### SSH Connection Issues

```bash
# On Proxmox, check VM IP
qm guest cmd 9202 network-get-interfaces

# Verify SSH is running (via console)
systemctl status sshd
```

### Cloud-init Not Working

```bash
# Check status
cloud-init status --long

# View logs
journalctl -u cloud-init
```

### Configuration Errors

```bash
# Check syntax before applying
nixos-rebuild switch --show-trace

# Test changes without making permanent
sudo nixos-rebuild test
```

## Hydra Image Source

The NixOS Proxmox image is built by Hydra CI:
- **Job**: https://hydra.nixos.org/job/nixos/release-25.11/nixos.proxmoxImage.x86_64-linux
- **Format**: VMA (Proxmox native backup format)
- **Includes**: cloud-init, qemu-guest-agent, SSH

To update to a newer build, edit `import-cloud-image.sh` and update the `VMA_URL`.

## Resources

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **NixOS Options Search**: https://search.nixos.org/options
- **Nix Packages Search**: https://search.nixos.org/packages
- **NixOS Wiki**: https://nixos.wiki/
- **Hydra CI**: https://hydra.nixos.org/
