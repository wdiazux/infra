# Destroy Guide

How to properly destroy the Talos cluster and handle edge cases.

---

## Quick Start

**Recommended Method:** Use the destroy script which handles all edge cases:

```bash
cd terraform/talos

# With confirmation prompt
./destroy.sh

# Skip confirmation
./destroy.sh --force
```

---

## Why Standard `terraform destroy` Fails

Running `terraform destroy -auto-approve` directly will likely fail due to:

### 1. Protected Resources

`talos_machine_secrets.cluster` has `lifecycle.prevent_destroy = true` to prevent accidental loss of cluster secrets.

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

Longhorn requires `deleting-confirmation-flag` to be `true` before uninstallation.

**Error:**
```
Error: job longhorn-uninstall failed: BackoffLimitExceeded
```

**Solution:**
```bash
kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
  --type=merge -p '{"value": "true"}'
```

### 3. Webhook Configurations

Longhorn webhooks can block namespace deletion.

**Solution:**
```bash
kubectl delete validatingwebhookconfiguration longhorn-webhook-validator --ignore-not-found
kubectl delete mutatingwebhookconfiguration longhorn-webhook-mutator --ignore-not-found
```

### 4. Stuck Namespace Finalizers

Kubernetes namespaces can get stuck in `Terminating` state.

**Solution:**
```bash
kubectl patch namespace longhorn-system -p '{"metadata":{"finalizers":null}}' --type=merge
```

### 5. FluxCD Reconciliation

FluxCD recreates deleted resources during destroy.

**Solution:**
```bash
flux suspend kustomization --all
flux suspend source git --all
flux uninstall --silent
```

---

## Destroy Order

The correct order for destroying resources:

1. **Suspend FluxCD** - Stop reconciliation
2. **Delete FluxCD resources** - Kustomizations, HelmReleases
3. **Uninstall FluxCD** - Remove controllers
4. **Prepare Longhorn** - Set deleting-confirmation-flag
5. **Delete Helm releases** - Longhorn, Forgejo
6. **Delete namespaces** - After clearing finalizers
7. **Remove protected resources** - From Terraform state
8. **Destroy Talos** - Reset node configuration
9. **Destroy Proxmox VM** - Delete VM and disks

---

## Manual Destroy Steps

If `./destroy.sh` fails or you need manual control:

### Phase 1: Kubernetes Cleanup

```bash
export KUBECONFIG=./kubeconfig

# Suspend FluxCD
flux suspend kustomization --all
flux suspend source git --all

# Delete FluxCD resources
kubectl delete kustomization --all -A --ignore-not-found
kubectl delete helmrelease --all -A --ignore-not-found
kubectl delete gitrepository --all -A --ignore-not-found

# Uninstall FluxCD
flux uninstall --silent

# Prepare Longhorn
kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
  --type=merge -p '{"value": "true"}'

# Remove webhooks
kubectl delete validatingwebhookconfiguration longhorn-webhook-validator --ignore-not-found
kubectl delete mutatingwebhookconfiguration longhorn-webhook-mutator --ignore-not-found

# Scale down Longhorn
kubectl -n longhorn-system scale deployment --all --replicas=0

# Delete failed jobs
kubectl delete job longhorn-uninstall -n longhorn-system --ignore-not-found

# Remove namespace finalizers
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

### Phase 4: Handle Failed Resources

If destroy still fails, remove stuck resources from state:

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

---

## Cluster Inaccessible

If the cluster is down or inaccessible:

```bash
# Skip Kubernetes cleanup
terraform state rm talos_machine_secrets.cluster
terraform destroy -auto-approve

# If that fails, remove all from state
terraform state list | xargs -I {} terraform state rm "{}"
```

Then manually delete VM from Proxmox:

```bash
# Via CLI
pvesh delete /nodes/pve/qemu/1000

# Or via Proxmox UI
# Datacenter -> pve -> VM 1000 -> More -> Remove
```

---

## Verification

After destroy:

```bash
# Terraform state should be empty
terraform state list

# VM should be deleted
pvesh get /nodes/pve/qemu --output-format json | jq '.[] | select(.vmid == 1000)'
```

---

## Troubleshooting

### Namespace Stuck in Terminating

```bash
# Check what's blocking
kubectl get namespace <name> -o yaml | grep -A 20 finalizers

# Force remove finalizers
kubectl patch namespace <name> -p '{"metadata":{"finalizers":null}}' --type=merge
```

### Longhorn Volumes Not Deleting

```bash
# Check stuck volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Force delete
kubectl delete volumes.longhorn.io --all -n longhorn-system --force --grace-period=0
```

### VM Not Deleted from Proxmox

```bash
# Force delete via Proxmox
pvesh delete /nodes/pve/qemu/1000 --purge 1
```

---

## Pre-Destroy Resources

The Terraform configuration includes automatic cleanup:

| Resource | Purpose |
|----------|---------|
| `terraform_data.fluxcd_pre_destroy` | Suspends and uninstalls FluxCD |
| `terraform_data.longhorn_pre_destroy` | Sets deleting-confirmation-flag |
| `terraform_data.forgejo_pre_destroy` | Removes namespace finalizers |

These run automatically but may not handle all edge cases.

---

## References

- [Longhorn Uninstall Guide](https://longhorn.io/docs/1.10.1/deploy/uninstall/)
- [Terraform Lifecycle](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [FluxCD Uninstall](https://fluxcd.io/flux/installation/#uninstall)
- [Kubernetes Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)

---

**Last Updated:** 2026-01-15
