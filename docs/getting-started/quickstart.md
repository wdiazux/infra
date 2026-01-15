# Quickstart

Deploy a Talos Kubernetes cluster in 10 minutes.

**Prerequisites:** Complete the [Prerequisites Guide](prerequisites.md) first.

---

## Deploy Cluster

```bash
# Enter project directory (Nix shell auto-activates)
cd terraform/talos

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Deploy
terraform apply -auto-approve
```

Deployment takes ~8-10 minutes. Terraform will:
1. Clone Talos template to VM 1000
2. Apply machine configuration
3. Bootstrap Kubernetes
4. Install Cilium CNI
5. Install Longhorn storage
6. Deploy Forgejo git server
7. Bootstrap FluxCD

---

## Verify Deployment

### Check Cluster Status

```bash
# Set kubeconfig
export KUBECONFIG=./kubeconfig
export TALOSCONFIG=./talosconfig

# View Talos dashboard
talosctl dashboard

# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A
```

### Check Services

| Service | URL | Check |
|---------|-----|-------|
| Hubble UI | http://10.10.2.11 | Cilium network visualization |
| Longhorn UI | http://10.10.2.12 | Storage management |
| Forgejo | http://10.10.2.13:3000 | Git server |

### Check FluxCD

```bash
# Git repository status
flux get sources git -A

# Kustomization status
flux get kustomizations -A
```

---

## Common Commands

### Talos

```bash
# Dashboard (real-time)
talosctl dashboard

# Node health
talosctl --nodes 10.10.2.10 health

# View services
talosctl --nodes 10.10.2.10 services

# View logs
talosctl --nodes 10.10.2.10 dmesg
```

### Kubernetes

```bash
# All pods
kubectl get pods -A

# Pod logs
kubectl logs -n <namespace> <pod-name>

# Events
kubectl get events -A --sort-by='.lastTimestamp'

# Terminal UI
k9s
```

### FluxCD

```bash
# Force reconciliation
flux reconcile source git flux-system

# Check status
flux get all -A

# View logs
kubectl logs -n flux-system deployment/source-controller
```

---

## Destroy Cluster

```bash
# Safe destroy (handles finalizers, webhooks, etc.)
./destroy.sh --force

# Or with confirmation prompt
./destroy.sh
```

---

## Next Steps

1. **Deploy an application** via FluxCD
2. **Configure backups** in Longhorn UI
3. **Add secrets** using SOPS encryption
4. **Enable monitoring** with kube-prometheus-stack

---

**See Also:**
- [Talos Deployment Guide](../deployment/talos.md)
- [Services Documentation](../services/)
- [Operations Guide](../operations/)
