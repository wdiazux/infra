# Terraform Infrastructure

This directory contains Terraform configurations for deploying infrastructure on Proxmox VE.

## Directory Structure

```
terraform/
├── talos/                  # Talos Kubernetes cluster
│   ├── terraform.tf        # Provider versions
│   ├── providers.tf        # Proxmox + Talos providers
│   ├── sops.tf             # Secrets integration
│   ├── variables.tf        # Input variables
│   ├── locals.tf           # Computed values
│   ├── outputs.tf          # Cluster outputs
│   ├── secrets.tf          # Talos machine secrets
│   ├── config.tf           # Machine configuration
│   ├── vm.tf               # Proxmox VM resource
│   ├── apply.tf            # Config application
│   ├── bootstrap.tf        # Cluster bootstrap
│   └── addons.tf           # Post-bootstrap setup
│
├── traditional-vms/        # Traditional VMs (Ubuntu, Debian, etc.)
│   ├── terraform.tf        # Provider versions
│   ├── providers.tf        # Proxmox provider
│   ├── sops.tf             # Secrets integration
│   ├── variables.tf        # Input variables
│   ├── locals.tf           # VM definitions
│   ├── outputs.tf          # VM outputs
│   └── main.tf             # VM resources
│
└── modules/                # Shared modules
    └── proxmox-vm/         # Generic Proxmox VM module
```

## Deployment

Each subdirectory is an independent Terraform root module with its own state.

### Talos Kubernetes Cluster

```bash
cd talos
terraform init
terraform plan
terraform apply
```

After deployment:
```bash
export KUBECONFIG=$(pwd)/kubeconfig
export TALOSCONFIG=$(pwd)/talosconfig
kubectl get nodes
talosctl dashboard
```

### Traditional VMs

```bash
cd traditional-vms
terraform init
terraform plan
terraform apply
```

## Prerequisites

1. **SOPS + Age** for secrets encryption
   ```bash
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   ```

2. **Proxmox API Token** configured in `../secrets/proxmox-creds.enc.yaml`

3. **Templates** built with Packer:
   - Talos: `packer/talos/import-talos-image.sh`
   - Traditional: `packer/<os>/` directories

## State Management

- Each subdirectory has independent Terraform state
- Talos changes don't affect traditional VMs
- Traditional VM changes don't affect Talos cluster

## GPU Support (Talos)

The Talos cluster includes NVIDIA GPU passthrough:
- Driver: `nonfree-kmod-nvidia-production` (Talos extension)
- Toolkit: `nvidia-container-toolkit-production` (Talos extension)
- Device Plugin: Automatically installed via Terraform

GPU Operator is **NOT** used - it conflicts with Talos's immutable design.

## Documentation

Generate documentation with terraform-docs:
```bash
cd talos && terraform-docs markdown . > TERRAFORM.md
cd traditional-vms && terraform-docs markdown . > TERRAFORM.md
```

## Related Documentation

- [Talos Linux](https://www.talos.dev/)
- [Proxmox VE](https://pve.proxmox.com/)
- [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)
- [siderolabs/talos Provider](https://registry.terraform.io/providers/siderolabs/talos/latest)
