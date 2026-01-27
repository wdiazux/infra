# Upgrades

Procedures for upgrading Talos, Kubernetes, and cluster components.

---

## Overview

| Component | Current | Upgrade Method |
|-----------|---------|----------------|
| Talos Linux | v1.12.1 | talosctl upgrade |
| Kubernetes | v1.35.0 | talosctl upgrade-k8s |
| Cilium | 1.18.6 | Terraform apply |
| Longhorn | 1.10.1 | Terraform apply |
| Forgejo | 16.0.0 | Terraform apply |
| PostgreSQL | 18.2.0 | Terraform apply |

---

## Pre-Upgrade Checklist

- [ ] **Backup Terraform state**
  ```bash
  cp terraform.tfstate terraform.tfstate.pre-upgrade
  ```
- [ ] **Backup kubeconfig and talosconfig**
- [ ] **Verify Longhorn backups are current**
- [ ] **Check cluster health**
  ```bash
  talosctl health -n 10.10.2.10
  kubectl get nodes
  kubectl get pods -A | grep -v Running
  ```
- [ ] **Review upgrade notes** for the new version

---

## Talos Linux Upgrade

### Check Current Version

```bash
talosctl version -n 10.10.2.10
```

### Upgrade Process

1. **Generate new schematic** at factory.talos.dev with same extensions
2. **Get upgrade image URL:**
   ```bash
   # Format: factory.talos.dev/installer/{schematic-id}:v{version}
   UPGRADE_IMAGE="factory.talos.dev/installer/b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321:v1.13.0"
   ```

3. **Perform upgrade:**
   ```bash
   talosctl upgrade \
     --nodes 10.10.2.10 \
     --image $UPGRADE_IMAGE \
     --preserve
   ```

4. **Monitor upgrade:**
   ```bash
   talosctl dashboard -n 10.10.2.10
   ```

5. **Verify:**
   ```bash
   talosctl version -n 10.10.2.10
   kubectl get nodes
   ```

### Update Terraform

After successful upgrade, update `terraform.tfvars`:
```hcl
talos_version       = "v1.13.0"
talos_template_name = "talos-1.13.0-nvidia-template"
```

---

## Kubernetes Upgrade

### Check Current Version

```bash
kubectl version
talosctl -n 10.10.2.10 get kubernetesversion
```

### Upgrade Process

```bash
# Upgrade Kubernetes via talosctl
talosctl upgrade-k8s \
  --nodes 10.10.2.10 \
  --to v1.36.0

# Monitor progress
kubectl get nodes -w
```

### Verify

```bash
kubectl version
kubectl get nodes
kubectl get pods -A
```

### Update Terraform

Update `terraform.tfvars`:
```hcl
kubernetes_version = "v1.36.0"
```

---

## Cilium Upgrade

### Via Terraform

1. **Update version:**
   ```hcl
   # terraform.tfvars
   cilium_version = "1.19.0"
   ```

2. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

3. **Verify:**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=cilium
   cilium status
   ```

### Manual Upgrade (If Needed)

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --version 1.19.0 \
  --reuse-values
```

---

## Longhorn Upgrade

### Via Terraform

1. **Update version:**
   ```hcl
   # terraform.tfvars
   longhorn_version = "1.11.0"
   ```

2. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

3. **Verify:**
   ```bash
   kubectl get pods -n longhorn-system
   ```

### Manual Upgrade (If Needed)

```bash
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version 1.11.0 \
  --reuse-values
```

**Note:** Check Longhorn upgrade notes for any required pre-upgrade steps.

---

## Forgejo Upgrade

### Via Terraform

1. **Update version:**
   ```hcl
   # terraform.tfvars
   forgejo_chart_version = "11.0.0"
   ```

2. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

3. **Verify:**
   ```bash
   kubectl get pods -n forgejo
   curl http://10.10.2.16/api/v1/version
   ```

---

## FluxCD Upgrade

```bash
# Check current version
flux version

# Upgrade FluxCD
flux install

# Verify
flux check
```

---

## Template Update

When upgrading Talos to a new version, create a new template:

1. **Generate new schematic** at factory.talos.dev
2. **Update import script:**
   ```bash
   # packer/talos/import-talos-image.sh
   TALOS_VERSION="v1.13.0"
   SCHEMATIC_ID="new-schematic-id"
   ```
3. **Import new template** (use different VM ID):
   ```bash
   ./import-talos-image.sh 9001
   ```
4. **Test with new template** before updating Terraform

---

## Rollback

### Talos Rollback

```bash
# Talos keeps previous version
talosctl rollback -n 10.10.2.10
```

### Kubernetes Rollback

Kubernetes rollback is not straightforward. Options:
1. Restore from backup
2. Redeploy cluster

### Application Rollback (Database Migration Failed)

If a service upgrade ran a database migration that broke things, see the
[Upgrade Rollback Guide](upgrade-rollback.md) for step-by-step procedures
to restore volumes and pin image versions.

### Helm Rollback

```bash
# List releases
helm history cilium -n kube-system

# Rollback
helm rollback cilium 1 -n kube-system
```

---

## Troubleshooting

### Upgrade Stuck

```bash
# Check Talos status
talosctl dashboard -n 10.10.2.10

# Check kubelet logs
talosctl logs kubelet -n 10.10.2.10 --tail 100

# Force reboot if needed
talosctl reboot -n 10.10.2.10
```

### Pods Not Starting After Upgrade

```bash
# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Check specific pod
kubectl describe pod <pod-name> -n <namespace>

# Rolling restart
kubectl rollout restart deployment -n <namespace>
```

### CNI Issues After Upgrade

```bash
# Restart Cilium
kubectl rollout restart daemonset/cilium -n kube-system

# Verify
cilium status
```

---

## Best Practices

1. **Read release notes** before upgrading
2. **Backup everything** before major upgrades
3. **Upgrade one component at a time**
4. **Test in non-production** first (if available)
5. **Keep upgrade path minimal** (don't skip versions)
6. **Document changes** in Git commits
7. **Verify after each upgrade** before proceeding

---

## Upgrade Schedule

Recommended upgrade frequency:

| Component | Frequency | Notes |
|-----------|-----------|-------|
| Talos | Quarterly | Test new template first |
| Kubernetes | With Talos | Same upgrade window |
| Cilium | Monthly | Check changelog |
| Longhorn | Quarterly | Backup first |
| Forgejo | Monthly | Check breaking changes |

---

**Last Updated:** 2026-01-15
