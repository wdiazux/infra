# Terraform Infrastructure

This directory contains Terraform configurations for deploying infrastructure on Proxmox VE.

## Directory Structure

```
terraform/
├── talos/                  # Talos Kubernetes cluster
│   ├── terraform.tf        # Provider versions
│   ├── providers.tf        # Proxmox + Talos + Helm providers
│   ├── sops.tf             # Secrets integration
│   ├── variables.tf        # Input variables
│   ├── locals.tf           # Computed values
│   ├── outputs.tf          # Cluster outputs
│   ├── secrets.tf          # Talos machine secrets
│   ├── config.tf           # Machine configuration
│   ├── vm.tf               # Proxmox VM resource
│   ├── apply.tf            # Config application
│   ├── bootstrap.tf        # Cluster bootstrap
│   ├── cilium-inline.tf    # Cilium CNI (inline manifest)
│   ├── helm.tf             # Longhorn storage (Helm)
│   ├── addons.tf           # NVIDIA GPU setup
│   └── fluxcd.tf           # FluxCD bootstrap (optional)
│
├── traditional-vms/        # Traditional VMs (Ubuntu, Debian, etc.)
│   └── ...
│
└── modules/                # Shared modules
    └── proxmox-vm/         # Generic Proxmox VM module
```

## Talos Kubernetes Cluster

### Bootstrap Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: Terraform Creates Infrastructure                       │
│                                                                 │
│   terraform apply                                               │
│   ├── Creates Proxmox VM from Talos template                   │
│   ├── Generates Talos machine config                           │
│   ├── Applies config (includes Cilium as inlineManifest)       │
│   ├── Bootstraps Kubernetes cluster                            │
│   └── Waits for API to be ready                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: Cilium CNI (Automatic via inlineManifest)              │
│                                                                 │
│   ├── Cilium deployed during Talos bootstrap                   │
│   ├── L2 LoadBalancer IP pool configured                       │
│   └── Node becomes Ready immediately                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: Additional Components (Terraform Helm)                 │
│                                                                 │
│   ├── Longhorn storage installed                               │
│   ├── NVIDIA RuntimeClass created                              │
│   └── NVIDIA device plugin deployed                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 4: FluxCD Bootstrap (Optional)                            │
│                                                                 │
│   ├── FluxCD controllers installed                             │
│   ├── Syncs kubernetes/clusters/homelab/                       │
│   └── GitOps management begins                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Quick Start

```bash
cd talos
terraform init
terraform plan
terraform apply
```

### With FluxCD (GitOps)

```bash
cd talos

# Set FluxCD variables
export TF_VAR_enable_fluxcd=true
export TF_VAR_github_token="<your-github-token>"
export TF_VAR_github_owner="<your-github-username>"

terraform apply
```

### Post-Deployment

```bash
export KUBECONFIG=$(pwd)/kubeconfig
export TALOSCONFIG=$(pwd)/talosconfig

# Verify cluster
kubectl get nodes
talosctl dashboard

# Verify components
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get pods -n longhorn-system
kubectl describe node | grep nvidia.com/gpu
```

### Component Management

| Component | Bootstrap Method | Ongoing Management |
|-----------|-----------------|-------------------|
| Cilium CNI | Talos inlineManifest | Talos (or FluxCD) |
| Cilium L2 Pool | Talos inlineManifest | Talos (or FluxCD) |
| Longhorn | Terraform Helm | FluxCD HelmRelease |
| NVIDIA Plugin | Terraform | FluxCD Kustomize |
| Forgejo | Terraform Helm | FluxCD HelmRelease |
| Applications | - | FluxCD |

### Service LoadBalancer IPs

The following services are exposed via Cilium L2 LoadBalancer:

| Service | IP Address | Port | Purpose |
|---------|------------|------|---------|
| Cilium Hubble UI | 10.10.2.11 | 80 | Network observability dashboard |
| Longhorn UI | 10.10.2.12 | 80 | Storage management dashboard |
| Forgejo HTTP | 10.10.2.13 | 3000 | Git web interface |
| Forgejo SSH | 10.10.2.13 | 22 | Git SSH access |
| FluxCD Webhook | 10.10.2.14 | 80 | GitOps webhook receiver |

**IP Ranges:**
- `10.10.2.11-20`: Important services (static assignments)
- `10.10.2.240-254`: General LoadBalancer pool (dynamic)

### Why Cilium Uses inlineManifest

Cilium is embedded in the Talos machine configuration (not installed via Helm) to solve the **chicken-and-egg problem**:

1. FluxCD needs a working CNI to sync from Git
2. But FluxCD would normally install the CNI
3. By embedding Cilium in Talos config, it's applied during bootstrap
4. Node becomes Ready immediately, allowing FluxCD to work

FluxCD can optionally take over Cilium management later by uncommenting the HelmRelease in `kubernetes/infrastructure/controllers/kustomization.yaml`.

## Traditional VMs

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

4. **GitHub Token** (if using FluxCD):
   ```bash
   export TF_VAR_github_token="<token>"
   export TF_VAR_github_owner="<username>"
   ```

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

## Destroy and Recreate

### Proper Destroy Procedure

When destroying the Talos cluster, follow this procedure to avoid state issues:

```bash
cd talos

# 1. If cluster is running, destroy normally
terraform destroy -auto-approve

# 2. If cluster is DOWN and destroy fails with connection errors:
#    Remove Helm releases from state (they can't be deleted without API)
terraform state rm helm_release.longhorn
terraform state rm helm_release.forgejo  # if enabled

#    Remove protected secrets (required for full destroy)
terraform state rm talos_machine_secrets.cluster

#    Then destroy remaining resources
terraform destroy -auto-approve -refresh=false
```

### Common Destroy Errors

| Error | Solution |
|-------|----------|
| `Kubernetes cluster unreachable` | Remove Helm releases from state: `terraform state rm helm_release.longhorn` |
| `prevent_destroy` on secrets | Remove from state: `terraform state rm talos_machine_secrets.cluster` |
| `BackoffLimitExceeded` | Cluster is down, remove Helm from state |

### Clean Recreate

After destroy, recreate with fresh state:

```bash
# Verify clean state
terraform state list  # Should be empty or only data sources

# Recreate cluster
terraform apply
```

## FluxCD Variables (Forgejo)

FluxCD is configured for **Forgejo** (API-compatible with Gitea).

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_fluxcd` | Enable FluxCD bootstrap | `false` |
| `enable_forgejo` | Deploy in-cluster Forgejo | `false` |
| `git_token` | Git PAT with repo permissions | `""` |
| `git_hostname` | Git server hostname | `"git.home-infra.net"` |
| `git_owner` | Git username or organization | `""` |
| `git_repository` | Repository name | `"infra"` |
| `git_branch` | Branch to sync | `"main"` |
| `git_personal` | Use personal account (not org) | `true` |
| `git_private` | Repository is private | `false` |
| `fluxcd_path` | Path in repo for cluster config | `"kubernetes/clusters/homelab"` |
| `sops_age_key_file` | Path to Age key for SOPS | `""` |

### In-Cluster Forgejo

Deploy Forgejo inside the cluster for a self-hosted Git server:

```bash
export TF_VAR_enable_forgejo=true
export TF_VAR_enable_fluxcd=true
# Forgejo token is auto-generated
terraform apply
```

### External Forgejo Example

Credentials can be auto-loaded via direnv + SOPS (see `secrets/git-creds.yaml.example`):

```bash
# Option 1: Auto-load via SOPS (recommended)
# Copy and encrypt: cp secrets/git-creds.yaml.example /tmp/git-creds.yaml
# Edit credentials, then: sops -e /tmp/git-creds.yaml > secrets/git-creds.enc.yaml
# direnv will auto-load TF_VAR_* from the encrypted file

# Option 2: Manual export
export TF_VAR_enable_fluxcd=true
export TF_VAR_git_token="<forgejo-token>"
export TF_VAR_git_owner="<username>"

terraform apply
```

## Documentation

Generate documentation with terraform-docs:
```bash
cd talos && terraform-docs markdown . > TERRAFORM.md
cd traditional-vms && terraform-docs markdown . > TERRAFORM.md
```

## Related Documentation

- [Kubernetes GitOps README](../kubernetes/README.md)
- [Talos Linux](https://www.talos.dev/)
- [Cilium](https://docs.cilium.io/)
- [Longhorn](https://longhorn.io/)
- [FluxCD](https://fluxcd.io/)
- [Proxmox VE](https://pve.proxmox.com/)
- [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)
- [siderolabs/talos Provider](https://registry.terraform.io/providers/siderolabs/talos/latest)
