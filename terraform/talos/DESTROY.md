# Talos Cluster Destroy Guide

This document describes how to properly destroy the Talos cluster and the challenges involved.

## Quick Start

**Recommended Method**: Use the destroy script which handles all edge cases:

```bash
./destroy.sh
```

Or with `--force` to skip confirmation:

```bash
./destroy.sh --force
```

## Why Standard `terraform destroy` Fails

Running `terraform destroy -auto-approve` directly will likely fail due to:

### 1. Protected Resources (`prevent_destroy`)

`talos_machine_secrets.cluster` has `lifecycle.prevent_destroy = true` to prevent accidental loss of cluster secrets. This is a safety feature.

**Error:**
```
Error: Instance cannot be destroyed
Resource talos_machine_secrets.cluster has lifecycle.prevent_destroy set
```

**Solution:**
```bash
terraform state rm talos_machine_secrets.cluster
```

### 2. Longhorn Uninstall Requirements

Longhorn requires `deleting-confirmation-flag` to be `true` before it allows uninstallation. Without this, the Helm uninstall job fails with `BackoffLimitExceeded`.

**Error:**
```
Error: 1 error occurred:
    * job longhorn-uninstall failed: BackoffLimitExceeded
```

**Solution:**
```bash
kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
  --type=merge -p '{"value": "true"}'
```

### 3. Webhook Configurations Blocking Deletion

Longhorn webhook configurations (`ValidatingWebhookConfiguration`, `MutatingWebhookConfiguration`) can block namespace deletion.

**Solution:**
```bash
kubectl delete validatingwebhookconfiguration longhorn-webhook-validator --ignore-not-found
kubectl delete mutatingwebhookconfiguration longhorn-webhook-mutator --ignore-not-found
```

### 4. Stuck Namespace Finalizers

Kubernetes namespaces can get stuck in `Terminating` state due to finalizers.

**Solution:**
```bash
kubectl patch namespace longhorn-system -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl patch namespace flux-system -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl patch namespace forgejo -p '{"metadata":{"finalizers":null}}' --type=merge
```

### 5. FluxCD Reconciliation Blocking Deletion

FluxCD continuously reconciles resources, which can recreate deleted resources during destroy.

**Solution:**
```bash
flux suspend kustomization --all
flux suspend source git --all
flux uninstall --silent
```

## Destroy Order (Critical)

The correct order for destroying resources is:

1. **Suspend FluxCD** - Stop reconciliation to prevent resource recreation
2. **Delete FluxCD resources** - Remove Kustomizations, HelmReleases, GitRepositories
3. **Uninstall FluxCD** - Remove FluxCD controllers
4. **Prepare Longhorn** - Set deleting-confirmation-flag, remove webhooks
5. **Delete Helm releases** - Longhorn, Forgejo
6. **Delete namespaces** - After finalizers are cleared
7. **Remove protected resources from state** - talos_machine_secrets
8. **Destroy Talos configuration** - Reset nodes
9. **Destroy Proxmox VM** - Delete VM and disks

## Terraform Pre-Destroy Resources

The Terraform configuration includes `terraform_data` resources with destroy-time provisioners that automatically handle cleanup:

| Resource | Purpose |
|----------|---------|
| `terraform_data.fluxcd_pre_destroy` | Suspends and uninstalls FluxCD |
| `terraform_data.longhorn_pre_destroy` | Sets deleting-confirmation-flag, removes webhooks |
| `terraform_data.forgejo_pre_destroy` | Removes namespace finalizers |

These run automatically during `terraform destroy`, but may not catch all edge cases.

## Manual Destroy Steps

If `./destroy.sh` fails or you need manual control:

### Phase 1: Kubernetes Cleanup (if cluster accessible)

```bash
export KUBECONFIG=./kubeconfig

# 1. Suspend FluxCD
flux suspend kustomization --all
flux suspend source git --all

# 2. Delete FluxCD resources
kubectl delete kustomization --all -A --ignore-not-found
kubectl delete helmrelease --all -A --ignore-not-found
kubectl delete gitrepository --all -A --ignore-not-found

# 3. Uninstall FluxCD
flux uninstall --silent

# 4. Prepare Longhorn for deletion
kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
  --type=merge -p '{"value": "true"}'

# 5. Remove webhooks
kubectl delete validatingwebhookconfiguration longhorn-webhook-validator --ignore-not-found
kubectl delete mutatingwebhookconfiguration longhorn-webhook-mutator --ignore-not-found

# 6. Scale down Longhorn
kubectl -n longhorn-system scale deployment --all --replicas=0

# 7. Delete failed uninstall jobs
kubectl delete job longhorn-uninstall -n longhorn-system --ignore-not-found

# 8. Remove namespace finalizers
for ns in flux-system longhorn-system forgejo; do
  kubectl patch namespace "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done
```

### Phase 2: Terraform State Cleanup

```bash
# Remove protected resources
terraform state rm talos_machine_secrets.cluster
```

### Phase 3: Terraform Destroy

```bash
terraform destroy -auto-approve
```

### Phase 4: Handle Failed Resources (if needed)

If destroy fails, remove stuck resources from state:

```bash
# Helm releases
terraform state rm 'helm_release.longhorn[0]'
terraform state rm 'helm_release.forgejo[0]'

# Namespaces
terraform state rm 'kubernetes_namespace.longhorn[0]'
terraform state rm 'kubernetes_namespace.forgejo[0]'

# FluxCD resources
for r in flux_verify flux_kustomization flux_git_repository flux_git_secret flux_install; do
  terraform state rm "null_resource.${r}[0]" 2>/dev/null || true
done

# Retry destroy
terraform destroy -auto-approve
```

## Verification

After destroy, verify cleanup:

```bash
# Check Terraform state is empty
terraform state list

# Check VM deleted from Proxmox
pvesh get /nodes/pve/qemu --output-format json | jq '.[] | select(.vmid == 1000)'
```

## Troubleshooting

### Namespace Stuck in Terminating

```bash
# Check what's blocking deletion
kubectl get namespace <name> -o yaml | grep -A 20 finalizers

# Force remove finalizers
kubectl patch namespace <name> -p '{"metadata":{"finalizers":null}}' --type=merge
```

### Longhorn Volumes Not Deleting

```bash
# Check for stuck volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Delete stuck volumes
kubectl delete volumes.longhorn.io --all -n longhorn-system --force --grace-period=0
```

### VM Not Deleted from Proxmox

If Terraform fails to delete the VM:

```bash
# Via Proxmox CLI
pvesh delete /nodes/pve/qemu/1000

# Or via Proxmox UI
# Datacenter -> pve -> VM 1000 -> More -> Remove
```

### Cannot Access Cluster

If the cluster is down/inaccessible:

```bash
# Skip Kubernetes cleanup, go straight to state removal
terraform state rm talos_machine_secrets.cluster
terraform destroy -auto-approve

# If that fails, remove all resources from state
terraform state list | xargs -I {} terraform state rm "{}"
```

## References

- [Longhorn Uninstall Guide](https://longhorn.io/docs/1.10.1/deploy/uninstall/)
- [Terraform Lifecycle](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [FluxCD Uninstall](https://fluxcd.io/flux/installation/#uninstall)
- [Kubernetes Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)
