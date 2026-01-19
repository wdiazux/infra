# Kubernetes GitOps with FluxCD

This directory contains the Kubernetes manifests managed by FluxCD for the homelab cluster.

## Bootstrap Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: Terraform + Talos (Automatic)                          │
│   terraform apply                                                │
│   ├── Creates Talos VM                                          │
│   ├── Bootstraps Kubernetes                                     │
│   ├── Cilium CNI (via inlineManifest) ──► Node Ready           │
│   ├── Longhorn storage (via Helm)                               │
│   └── NVIDIA device plugin                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: FluxCD Bootstrap (Optional - via Terraform or Manual)  │
│   ├── FluxCD controllers installed                              │
│   └── Syncs kubernetes/clusters/homelab/                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: GitOps Management (Ongoing)                            │
│   ├── Longhorn managed by FluxCD HelmRelease                    │
│   ├── Applications deployed via git commits                     │
│   └── (Optional) Cilium management transferred to FluxCD        │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
kubernetes/
├── clusters/
│   └── homelab/              # Cluster entry point (FluxCD)
│       ├── kustomization.yaml
│       ├── infrastructure.yaml
│       └── apps.yaml
├── infrastructure/
│   ├── controllers/          # Core infrastructure (storage, GPU)
│   │   ├── kustomization.yaml
│   │   ├── helm-repositories.yaml
│   │   ├── cilium.yaml       # DISABLED: Installed via Talos inlineManifest
│   │   ├── longhorn.yaml     # DISABLED: Installed via Terraform
│   │   └── nvidia-gpu.yaml
│   ├── configs/              # Cluster configurations
│   │   ├── kustomization.yaml
│   │   ├── longhorn-storage-classes.yaml
│   │   ├── talos-node-reader.yaml
│   │   └── webhook-receiver-lb.yaml
│   ├── namespaces/           # Application namespaces
│   │   ├── kustomization.yaml
│   │   ├── tools.yaml        # it-tools, ntfy, attic, homepage
│   │   ├── misc.yaml         # twitch-miner
│   │   ├── arr-stack.yaml    # media acquisition services
│   │   └── media.yaml        # media streaming services
│   └── values/               # Helm values (reference/used by Terraform)
│       ├── cilium-values.yaml
│       ├── longhorn-values.yaml
│       └── forgejo-values.yaml
├── apps/
│   ├── base/                 # Base application manifests
│   │   ├── tools/            # Tools namespace
│   │   │   ├── it-tools/
│   │   │   ├── ntfy/
│   │   │   └── attic/
│   │   ├── misc/             # Misc namespace
│   │   │   └── twitch-miner/
│   │   ├── arr-stack/        # Media acquisition
│   │   │   ├── sabnzbd/
│   │   │   ├── qbittorrent/
│   │   │   ├── prowlarr/
│   │   │   ├── radarr/
│   │   │   ├── sonarr/
│   │   │   └── bazarr/
│   │   └── media/            # Media streaming
│   │       ├── emby/
│   │       └── navidrome/
│   └── production/           # Production overlays
│       └── kustomization.yaml
└── flux-system/              # FluxCD components (auto-generated)
```

## Quick Start

### Option 1: Full Automation (Recommended)

```bash
cd terraform/talos

# Set FluxCD variables
export TF_VAR_enable_fluxcd=true
export TF_VAR_github_token="<your-github-token>"
export TF_VAR_github_owner="<your-github-username>"

# Deploy everything
terraform apply
```

This will:
1. Create Talos VM with Cilium (via inlineManifest)
2. Install Longhorn storage
3. Install NVIDIA device plugin
4. Bootstrap FluxCD

### Option 2: Manual FluxCD Bootstrap

```bash
# First, deploy cluster without FluxCD
cd terraform/talos
terraform apply  # With enable_fluxcd=false (default)

# Then manually bootstrap FluxCD
export GITHUB_TOKEN=<your-token>
flux bootstrap github \
  --owner=<github-username> \
  --repository=infra \
  --path=kubernetes/clusters/homelab \
  --personal
```

## What's Managed Where

| Component | Bootstrap | Ongoing Management |
|-----------|-----------|-------------------|
| Cilium CNI | Talos inlineManifest | Talos (or FluxCD if enabled) |
| Cilium L2 Pool | Talos inlineManifest | Talos (or FluxCD if enabled) |
| Longhorn | Terraform Helm | FluxCD HelmRelease |
| NVIDIA Plugin | Terraform | FluxCD Kustomize |
| Applications | - | FluxCD |

## Transitioning Cilium to FluxCD (Optional)

If you want FluxCD to manage Cilium updates:

1. Edit `kubernetes/infrastructure/controllers/kustomization.yaml`
2. Uncomment `- cilium.yaml`
3. Commit and push changes
4. FluxCD will adopt the existing Cilium installation

## Managing Applications

### Adding a New Application

1. **Create application directory**:
   ```bash
   mkdir -p kubernetes/apps/production/my-app
   ```

2. **Add Kustomization or HelmRelease**:
   ```yaml
   # kubernetes/apps/production/my-app/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - deployment.yaml
     - service.yaml
   ```

3. **Register in production kustomization**:
   ```yaml
   # kubernetes/apps/production/kustomization.yaml
   resources:
     - my-app/
   ```

4. **Commit and push** - FluxCD will deploy automatically

### Example: Plex Media Server

```bash
mkdir -p kubernetes/apps/production/plex
```

```yaml
# kubernetes/apps/production/plex/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - pvc.yaml
```

## Secrets Management with SOPS

FluxCD integrates with SOPS for encrypted secrets.

### Setup

1. **Create SOPS config** (if not exists):
   ```yaml
   # .sops.yaml (repository root)
   creation_rules:
     - path_regex: kubernetes/.*\.enc\.yaml$
       age: >-
         <your-age-public-key>
   ```

2. **Create FluxCD SOPS secret**:
   ```bash
   # Export your Age private key
   cat ~/.config/sops/age/keys.txt | kubectl create secret generic sops-age \
     --namespace=flux-system \
     --from-file=age.agekey=/dev/stdin
   ```

3. **Encrypt secrets**:
   ```bash
   sops -e secret.yaml > secret.enc.yaml
   ```

4. **Reference in Kustomization**:
   ```yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   spec:
     decryption:
       provider: sops
       secretRef:
         name: sops-age
   ```

## Monitoring FluxCD

```bash
# Check overall status
flux check

# View all Flux resources
flux get all

# View Kustomizations
flux get kustomizations

# View HelmReleases
flux get helmreleases -A

# View recent events
flux events

# Watch reconciliation
flux logs --follow
```

## Troubleshooting

### HelmRelease Not Ready

```bash
# Check HelmRelease status
flux get hr -A

# Describe for details
kubectl describe helmrelease <name> -n <namespace>

# Check Helm history
helm history <release-name> -n <namespace>
```

### Kustomization Failed

```bash
# Check Kustomization status
flux get ks

# View events
kubectl describe kustomization <name> -n flux-system
```

### Force Reconciliation

```bash
# Reconcile all
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# Reconcile specific HelmRelease
flux reconcile hr cilium -n kube-system
```

## Component Versions

| Component | Version | Notes |
|-----------|---------|-------|
| FluxCD | Latest | Installed via bootstrap |
| Cilium | 1.18.6 | CNI + kube-proxy replacement |
| Longhorn | 1.10.1 | Distributed storage |
| NVIDIA Device Plugin | v0.18.1 | GPU support |

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [SOPS with FluxCD](https://fluxcd.io/docs/guides/mozilla-sops/)
