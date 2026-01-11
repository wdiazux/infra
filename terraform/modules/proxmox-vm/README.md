# Proxmox VM Terraform Module

Generic, reusable Terraform module for creating Proxmox VMs from Packer templates.

## Features

- Clone VMs from Packer-created templates
- Cloud-init configuration support
- Flexible CPU, memory, and disk configuration
- Multiple network interfaces
- UEFI or Legacy BIOS boot
- QEMU guest agent integration
- Startup order and delays
- Tags and metadata support

## Usage

### Basic Example

```hcl
module "ubuntu_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node  = "pve"
  template_name = "ubuntu-24.04-golden-template-20251118"
  vm_name       = "ubuntu-dev"
  vm_id         = 100

  cpu_cores = 4
  memory    = 8192

  disks = [{
    datastore_id = "tank"
    size         = 40
    interface    = "scsi0"
  }]

  network_devices = [{
    bridge = "vmbr0"
    model  = "virtio"
  }]

  tags = ["ubuntu", "development", "linux"]
}
```

### With Cloud-init

```hcl
module "debian_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node  = "pve"
  template_name = "debian-12-golden-template-20251118"
  vm_name       = "debian-prod"
  vm_id         = 101

  enable_cloud_init    = true
  cloud_init_user      = "admin"
  cloud_init_password  = "changeme"  # Use hashed password in production
  cloud_init_ssh_keys  = [
    "ssh-rsa AAAA... user@host"
  ]

  ip_configs = [{
    address = "192.168.1.100/24"
    gateway = "192.168.1.1"
  }]

  dns_servers = ["192.168.1.1", "8.8.8.8"]
  dns_domain  = "local"

  tags = ["debian", "production", "linux"]
}
```

### Multiple Disks

```hcl
module "storage_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node  = "pve"
  template_name = "ubuntu-24.04-golden-template-20251118"
  vm_name       = "storage-server"
  vm_id         = 102

  disks = [
    {
      datastore_id = "tank"
      size         = 20
      interface    = "scsi0"
    },
    {
      datastore_id = "tank"
      size         = 100
      interface    = "scsi1"
    },
    {
      datastore_id = "tank"
      size         = 500
      interface    = "scsi2"
    }
  ]
}
```

### Multiple Network Interfaces

```hcl
module "gateway_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node  = "pve"
  template_name = "debian-12-golden-template-20251118"
  vm_name       = "gateway"
  vm_id         = 103

  network_devices = [
    {
      bridge  = "vmbr0"  # WAN
      model   = "virtio"
    },
    {
      bridge  = "vmbr1"  # LAN
      model   = "virtio"
    }
  ]
}
```

## Inputs

See [variables.tf](./variables.tf) for complete variable documentation.

### Required

| Name | Type | Description |
|------|------|-------------|
| `proxmox_node` | string | Proxmox node name |
| `template_name` | string | Packer template name to clone |
| `vm_name` | string | Name for the VM |
| `vm_id` | number | Unique VM ID |

### Hardware

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cpu_type` | string | `"host"` | CPU type |
| `cpu_cores` | number | `2` | Number of CPU cores |
| `cpu_sockets` | number | `1` | Number of CPU sockets |
| `memory` | number | `2048` | Memory in MB |
| `disks` | list(object) | See variables.tf | Disk configurations |
| `network_devices` | list(object) | See variables.tf | Network devices |

### Boot Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `bios_type` | string | `"ovmf"` | BIOS type (ovmf=UEFI, seabios=Legacy) |
| `boot_order` | list(string) | `["scsi0"]` | Boot device order |
| `machine_type` | string | `"q35"` | Machine type |
| `scsi_hardware` | string | `"virtio-scsi-single"` | SCSI controller |

### Cloud-init

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enable_cloud_init` | bool | `true` | Enable cloud-init |
| `cloud_init_user` | string | `""` | Username (empty = skip) |
| `cloud_init_password` | string | `""` | Password (hashed or plain) |
| `cloud_init_ssh_keys` | list(string) | `[]` | SSH public keys |
| `ip_configs` | list(object) | DHCP | IP configurations |
| `dns_servers` | list(string) | `["8.8.8.8", "8.8.4.4"]` | DNS servers |
| `dns_domain` | string | `"local"` | DNS domain |

### Metadata

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `description` | string | `""` | VM description |
| `tags` | list(string) | `[]` | VM tags |
| `on_boot` | bool | `true` | Start on boot |
| `startup_order` | number | `10` | Startup order |

## Outputs

| Name | Description |
|------|-------------|
| `vm_id` | The VM ID |
| `vm_name` | The VM name |
| `node_name` | Proxmox node |
| `template_id` | Template VM ID |
| `template_name` | Template name |
| `ipv4_addresses` | IPv4 addresses (requires QEMU agent) |
| `ipv6_addresses` | IPv6 addresses (requires QEMU agent) |
| `mac_addresses` | MAC addresses |
| `cpu_cores` | Number of CPU cores |
| `memory_mb` | Memory in MB |
| `tags` | VM tags |

## Requirements

- Packer template must exist in Proxmox as a template
- Template should have cloud-init and qemu-guest-agent installed
- Proxmox provider version ~> 0.86.0

## Notes

- Uses full clone (not linked clone) for isolation
- QEMU guest agent required for IP address detection
- Cloud-init user creation only works if template has cloud-init
- For Windows VMs, use Cloudbase-Init instead of cloud-init
- Template name must match exactly (case-sensitive)
- VM ID must be unique across the Proxmox cluster

## Examples

See the following files for complete deployment examples:
- `../../vm-traditional.tf` - Module instantiation with for_each
- `../../locals-vms.tf` - VM definitions (CPU, memory, disk, etc.)
- `../../README.md` - Full documentation with usage examples
