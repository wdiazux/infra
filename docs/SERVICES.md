# Services and Network Documentation

Network infrastructure documentation for the home-infra.net homelab.

## Network Overview

- **Domain**: `home-infra.net` (external), `.local` (internal)
- **Network**: `10.10.2.0/24`
- **Gateway**: `10.10.2.1`
- **DNS**: `10.10.2.1` (primary), `8.8.8.8` (fallback)

## IP Allocation Scheme

| Range | Purpose | Count |
|-------|---------|-------|
| 10.10.2.1-10 | Physical Computers & Core Infrastructure | 10 |
| 10.10.2.11-20 | Important Services (Management, Monitoring) | 10 |
| 10.10.2.21-50 | Applications & Services | 30 |
| 10.10.2.51-70 | Virtual Machines | 20 |
| 10.10.2.71-239 | Reserved (Future Use) | 169 |
| 10.10.2.240-254 | Kubernetes LoadBalancer Pool | 15 |
| 10.10.2.255 | Broadcast | 1 |

## Physical Computers & Core Infrastructure (10.10.2.1-10)

| IP | Hostname | Description | Status |
|----|----------|-------------|--------|
| 10.10.2.1 | gateway | Router/Gateway | Active |
| 10.10.2.2 | proxmox | Proxmox VE Host (Minisforum MS-A2) | Active |
| 10.10.2.3 | - | Reserved | - |
| 10.10.2.4 | - | Reserved | - |
| 10.10.2.5 | nas | NAS (Longhorn backup target) | Active |
| 10.10.2.6 | - | Reserved | - |
| 10.10.2.7 | - | Reserved | - |
| 10.10.2.8 | - | Reserved | - |
| 10.10.2.9 | - | Reserved | - |
| 10.10.2.10 | talos-node | Talos Kubernetes Node | Active |

## Important Services (10.10.2.11-20)

| IP | Hostname | Service | Port(s) | Status |
|----|----------|---------|---------|--------|
| 10.10.2.11 | - | Reserved (Proxmox Backup Server) | 8007 | Planned |
| 10.10.2.12 | - | Reserved | - | - |
| 10.10.2.13 | - | Reserved | - | - |
| 10.10.2.14 | - | Reserved | - | - |
| 10.10.2.15 | - | Reserved | - | - |
| 10.10.2.16 | - | Reserved | - | - |
| 10.10.2.17 | - | Reserved | - | - |
| 10.10.2.18 | - | Reserved | - | - |
| 10.10.2.19 | - | Reserved | - | - |
| 10.10.2.20 | - | Reserved | - | - |

## Applications & Services (10.10.2.21-50)

Services deployed on Kubernetes via LoadBalancer IPs or dedicated VMs.

| IP | Hostname | Service | Port(s) | Status |
|----|----------|---------|---------|--------|
| 10.10.2.21 | git | Forgejo Git Server | 443, 22 | Planned |
| 10.10.2.22-50 | - | Reserved for future services | - | - |

## Virtual Machines (10.10.2.51-70)

Traditional VMs for non-Kubernetes workloads.

| IP | Hostname | OS | Purpose | Status |
|----|----------|----|---------|--------|
| 10.10.2.51 | ubuntu-vm | Ubuntu 24.04 | General purpose | Planned |
| 10.10.2.52 | debian-vm | Debian 13 | General purpose | Planned |
| 10.10.2.53 | arch-vm | Arch Linux | Development | Planned |
| 10.10.2.54 | nixos-vm | NixOS 25.11 | Declarative config testing | Planned |
| 10.10.2.55 | windows-vm | Windows | Windows workloads | Planned |
| 10.10.2.56-70 | - | Reserved | - | - |

## Kubernetes LoadBalancer Pool (10.10.2.240-254)

Managed by Cilium L2 LoadBalancer. Services request IPs from this pool.

| IP | Service | Namespace | Status |
|----|---------|-----------|--------|
| 10.10.2.240 | - | - | Available |
| 10.10.2.241 | - | - | Available |
| 10.10.2.242 | - | - | Available |
| 10.10.2.243 | - | - | Available |
| 10.10.2.244 | - | - | Available |
| 10.10.2.245 | - | - | Available |
| 10.10.2.246 | - | - | Available |
| 10.10.2.247 | - | - | Available |
| 10.10.2.248 | - | - | Available |
| 10.10.2.249 | - | - | Available |
| 10.10.2.250 | - | - | Available |
| 10.10.2.251 | - | - | Available |
| 10.10.2.252 | - | - | Available |
| 10.10.2.253 | - | - | Available |
| 10.10.2.254 | - | - | Available |

## Credentials Reference

All credentials are encrypted with SOPS + Age. Never commit plaintext secrets.

### SOPS Encrypted Files

| File | Contents | Used By |
|------|----------|---------|
| `secrets/proxmox-creds.enc.yaml` | Proxmox API token, URL, node | Terraform, Packer |
| `secrets/git-creds.enc.yaml` | Forgejo token, hostname, owner | FluxCD, Terraform |

### Accessing Credentials

```bash
# View encrypted file
sops -d secrets/proxmox-creds.enc.yaml

# Edit encrypted file (opens in $EDITOR)
sops secrets/proxmox-creds.enc.yaml

# Create new encrypted file
sops -e plaintext.yaml > encrypted.enc.yaml
```

### Service Accounts

| Service | Username | Auth Method | Credential Location |
|---------|----------|-------------|---------------------|
| Proxmox API | terraform@pve | API Token | `secrets/proxmox-creds.enc.yaml` |
| Forgejo | wdiaz | Personal Access Token | `secrets/git-creds.enc.yaml` |
| Talos | - | Machine Config Secrets | `terraform/talos/talosconfig` |
| Kubernetes | - | Kubeconfig | `terraform/talos/kubeconfig` |

### Environment Variables (Auto-loaded via direnv)

The `.envrc` file automatically loads credentials from SOPS:

```bash
# Proxmox credentials
PROXMOX_URL          # API endpoint
PROXMOX_USERNAME     # user@realm!tokenid
PROXMOX_TOKEN        # API token secret
PROXMOX_API_TOKEN    # Full PVEAPIToken format

# Git/FluxCD credentials
TF_VAR_git_provider  # forgejo
TF_VAR_git_hostname  # git.home-infra.net
TF_VAR_git_owner     # wdiaz
TF_VAR_git_token     # Personal access token
GITEA_TOKEN          # For flux CLI
```

## DNS Records

Configure these DNS records in your DNS server or `/etc/hosts`:

| Hostname | IP | Type |
|----------|-----|------|
| gateway.home-infra.net | 10.10.2.1 | A |
| proxmox.home-infra.net | 10.10.2.2 | A |
| nas.home-infra.net | 10.10.2.5 | A |
| talos.home-infra.net | 10.10.2.10 | A |
| git.home-infra.net | 10.10.2.21 | A |
| *.home-infra.net | 10.10.2.240 | A (wildcard for K8s ingress) |

## Quick Reference

### Access Points

| Service | URL | Notes |
|---------|-----|-------|
| Proxmox Web UI | https://proxmox.home-infra.net:8006 | Use API token from SOPS |
| Forgejo | https://git.home-infra.net | Personal access token |
| Kubernetes API | https://10.10.2.10:6443 | Via kubeconfig |
| Talos API | https://10.10.2.10:50000 | Via talosconfig |
| Longhorn UI | http://longhorn.home-infra.net | Via K8s ingress |

### Common Commands

```bash
# Kubernetes
export KUBECONFIG=terraform/talos/kubeconfig
kubectl get nodes
kubectl get pods -A

# Talos
export TALOSCONFIG=terraform/talos/talosconfig
talosctl dashboard
talosctl health

# FluxCD
flux get all -A
flux reconcile source git flux-system
```

---

**Last Updated**: 2026-01-13
