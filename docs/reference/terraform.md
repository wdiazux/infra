# Terraform Reference

Input variables, outputs, and provider configuration for the Talos deployment.

---

## Quick Start

```bash
cd terraform/talos

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply -auto-approve

# Destroy
./destroy.sh --force
```

---

## Configuration Files

| File | Purpose |
|------|---------|
| `main.tf` | Core resources and providers |
| `vm.tf` | Proxmox VM configuration |
| `talos.tf` | Talos machine configuration |
| `cilium-inline.tf` | Cilium CNI inline manifest |
| `addons.tf` | Longhorn, Forgejo deployments |
| `fluxcd.tf` | FluxCD GitOps bootstrap |
| `variables.tf` | Input variable definitions |
| `variables-services.tf` | Service-specific variables |
| `outputs.tf` | Output values |

---

## Required Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `siderolabs/talos` | ~> 0.10.0 | Talos configuration |
| `bpg/proxmox` | ~> 0.93.0 | VM provisioning |
| `hashicorp/helm` | ~> 3.1.0 | Helm releases |
| `hashicorp/kubernetes` | ~> 2.36.0 | K8s resources |
| `carlpett/sops` | ~> 1.1.1 | Secrets decryption |

---

## Key Input Variables

### Node Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `node_ip` | `10.10.2.10` | Static IP for Talos node |
| `node_gateway` | `10.10.2.1` | Network gateway |
| `node_cpu_cores` | `8` | CPU cores |
| `node_memory` | `32768` | RAM in MB |
| `node_disk_size` | `200` | Disk in GB |
| `node_name` | `talos-node` | VM name |
| `node_vm_id` | `1000` | Proxmox VM ID |

### Talos Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `talos_version` | `v1.12.1` | Talos Linux version |
| `talos_template_name` | `talos-1.12.1-nvidia-template` | Template name |
| `talos_schematic_id` | `b81082c...` | Factory schematic ID |
| `cluster_name` | `homelab-k8s` | Kubernetes cluster name |
| `kubernetes_version` | `v1.35.0` | Kubernetes version |

### GPU Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_gpu_passthrough` | `true` | Enable NVIDIA GPU |
| `gpu_mapping` | `nvidia-gpu` | Proxmox GPU mapping name |
| `auto_install_gpu_device_plugin` | `true` | Auto-deploy device plugin |

### Service Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_forgejo` | `true` | Deploy Forgejo Git server |
| `enable_fluxcd` | `true` | Bootstrap FluxCD |
| `enable_longhorn_backups` | `true` | Enable NFS backups |
| `cilium_version` | `1.18.6` | Cilium chart version |
| `longhorn_version` | `1.10.1` | Longhorn chart version |

### Network IPs

| Variable | Default | Description |
|----------|---------|-------------|
| `hubble_ui_ip` | `10.10.2.11` | Cilium Hubble UI |
| `longhorn_ui_ip` | `10.10.2.12` | Longhorn UI |
| `forgejo_ip` | `10.10.2.13` | Forgejo HTTP (port 80) |
| `forgejo_ssh_ip` | `10.10.2.14` | Forgejo SSH |
| `fluxcd_webhook_ip` | `10.10.2.15` | FluxCD webhook |
| `weave_gitops_ip` | `10.10.2.16` | Weave GitOps UI |
| `important_services_ip_start` | `10.10.2.11` | LoadBalancer pool start |
| `important_services_ip_stop` | `10.10.2.150` | LoadBalancer pool end |

---

## Outputs

| Output | Description |
|--------|-------------|
| `kubeconfig` | Kubeconfig content |
| `kubeconfig_path` | Path to kubeconfig file |
| `talosconfig_path` | Path to talosconfig file |
| `cluster_endpoint` | Kubernetes API endpoint |
| `node_ip` | Talos node IP address |
| `hubble_ui_url` | Cilium Hubble UI URL |
| `longhorn_ui_url` | Longhorn UI URL |
| `forgejo_http_url` | Forgejo Git server URL |
| `forgejo_ssh_url` | Forgejo SSH URL |
| `fluxcd_webhook_url` | FluxCD webhook URL |
| `access_instructions` | How to access cluster |
| `useful_commands` | Common commands |

---

## Customization

Create `terraform.tfvars` to override defaults:

```hcl
# Node configuration
node_ip        = "10.10.2.10"
node_gateway   = "10.10.2.1"
node_cpu_cores = 8
node_memory    = 32768

# Versions
talos_version      = "v1.12.1"
kubernetes_version = "v1.35.0"

# Features
enable_gpu_passthrough  = true
enable_forgejo          = true
enable_fluxcd           = true
enable_longhorn_backups = true

# Service IPs (optional - defaults work)
hubble_ui_ip    = "10.10.2.11"
longhorn_ui_ip  = "10.10.2.12"
forgejo_ip      = "10.10.2.13"
```

---

## Secrets Integration

Secrets are loaded from SOPS-encrypted files:

| Secret File | Purpose |
|-------------|---------|
| `secrets/proxmox-creds.enc.yaml` | Proxmox API credentials |
| `secrets/git-creds.enc.yaml` | Forgejo admin + FluxCD |
| `secrets/nas-backup-creds.enc.yaml` | NFS backup auth |
| `secrets/pangolin-creds.enc.yaml` | WireGuard tunnel |

Access in Terraform:
```hcl
data "sops_file" "proxmox_secrets" {
  source_file = "${path.module}/../../secrets/proxmox-creds.enc.yaml"
}

# Use: data.sops_file.proxmox_secrets.data["proxmox_url"]
```

---

## State Management

### Backup State

```bash
cp terraform.tfstate terraform.tfstate.backup
```

### Import Existing Resources

```bash
terraform import proxmox_virtual_environment_vm.talos_node pve/qemu/1000
```

### Remove from State

```bash
terraform state rm talos_machine_secrets.cluster
```

---

## Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate
terraform validate

# Show current state
terraform state list

# Show specific resource
terraform state show proxmox_virtual_environment_vm.talos_node

# Refresh state
terraform refresh

# Target specific resource
terraform apply -target=helm_release.longhorn
```

---

## Troubleshooting

### Lock File Issues

```bash
terraform init -upgrade
```

### Provider Issues

```bash
rm -rf .terraform
terraform init
```

### State Corruption

```bash
# Backup current state
mv terraform.tfstate terraform.tfstate.corrupted

# Re-import resources
terraform import ...
```

---

**Last Updated:** 2026-01-21

See [TERRAFORM.md](../../terraform/talos/TERRAFORM.md) for auto-generated provider documentation.
