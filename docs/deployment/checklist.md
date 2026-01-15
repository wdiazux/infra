# Deployment Checklist

Validation checklist to ensure all components are correctly configured before and after deployment.

---

## Phase 0: Prerequisites

### Environment

- [ ] Proxmox VE 9.0+ installed
  ```bash
  pveversion  # Should show 9.0 or later
  ```

- [ ] Development tools available (Nix shell)
  ```bash
  terraform version  # >= 1.14.2
  packer version     # >= 1.14.3
  talosctl version   # >= 1.12.0
  kubectl version
  sops --version
  ```

- [ ] Network connectivity verified
  ```bash
  curl -k https://YOUR_PROXMOX_IP:8006/api2/json/version
  curl https://factory.talos.dev/
  ```

### Infrastructure

- [ ] Reviewed [Infrastructure Reference](../reference/infrastructure.md)
- [ ] Reviewed [Network Reference](../reference/network.md)
- [ ] Proxmox storage pool exists
  ```bash
  pvesm status | grep tank
  ```
- [ ] Network bridge configured
  ```bash
  ip link show vmbr0
  ```

### Secrets

- [ ] SOPS Age key generated
- [ ] `.sops.yaml` configured with your public key
- [ ] Proxmox credentials encrypted (`secrets/proxmox-creds.enc.yaml`)
- [ ] Git credentials encrypted (`secrets/git-creds.enc.yaml`)
- [ ] NAS credentials encrypted (`secrets/nas-backup-creds.enc.yaml`)

---

## Phase 1: Talos Template

### Generate Schematic

- [ ] Visit https://factory.talos.dev/
- [ ] Select **Platform**: Nocloud
- [ ] Select **Version**: v1.12.1
- [ ] Add extensions:
  - [ ] `siderolabs/qemu-guest-agent`
  - [ ] `siderolabs/iscsi-tools`
  - [ ] `siderolabs/util-linux-tools`
  - [ ] `siderolabs/nonfree-kmod-nvidia-production` (if GPU)
  - [ ] `siderolabs/nvidia-container-toolkit-production` (if GPU)
- [ ] Copy Schematic ID

### Import Template

```bash
scp packer/talos/import-talos-image.sh root@pve:/tmp/
ssh root@pve
cd /tmp && ./import-talos-image.sh
```

- [ ] Import completed successfully
- [ ] Template visible in Proxmox UI
- [ ] Template ID: 9000

---

## Phase 2: Terraform Deployment

### Pre-Deployment

- [ ] Terraform initialized
  ```bash
  cd terraform/talos
  terraform init
  ```

- [ ] Configuration validated
  ```bash
  terraform fmt -check
  terraform validate
  terraform plan
  ```

- [ ] IP address available (10.10.2.10)
- [ ] VM ID available (1000)

### Deploy

```bash
terraform apply -auto-approve
```

- [ ] Terraform apply completed (~8-10 minutes)
- [ ] VM created in Proxmox
- [ ] `kubeconfig` file generated
- [ ] `talosconfig` file generated

---

## Phase 3: Post-Deployment Validation

### Cluster Access

```bash
export KUBECONFIG=./kubeconfig
export TALOSCONFIG=./talosconfig
```

- [ ] Talos dashboard accessible
  ```bash
  talosctl dashboard
  ```

- [ ] Node status Ready
  ```bash
  kubectl get nodes
  # NAME         STATUS   ROLES           AGE   VERSION
  # talos-node   Ready    control-plane   5m    v1.35.0
  ```

- [ ] All system pods running
  ```bash
  kubectl get pods -A
  # No CrashLoopBackOff or Error pods
  ```

### Network (Cilium)

- [ ] Cilium pods running
  ```bash
  kubectl get pods -n kube-system -l k8s-app=cilium
  ```

- [ ] Hubble UI accessible: http://10.10.2.11

- [ ] Pod networking works
  ```bash
  kubectl run test --image=nginx --restart=Never
  kubectl get pod test  # Should be Running
  kubectl delete pod test
  ```

### Storage (Longhorn)

- [ ] Longhorn pods running
  ```bash
  kubectl get pods -n longhorn-system
  ```

- [ ] Longhorn UI accessible: http://10.10.2.12

- [ ] PVC creation works
  ```bash
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-pvc
  spec:
    accessModes: [ReadWriteOnce]
    storageClassName: longhorn-default
    resources:
      requests:
        storage: 1Gi
  EOF
  kubectl get pvc test-pvc  # Should be Bound
  kubectl delete pvc test-pvc
  ```

- [ ] NFS backup target available
  ```bash
  kubectl get backuptarget -n longhorn-system
  # Should show "available: true"
  ```

### Git Server (Forgejo)

- [ ] Forgejo pods running
  ```bash
  kubectl get pods -n forgejo
  ```

- [ ] Forgejo UI accessible: http://10.10.2.16

- [ ] Can log in with admin credentials

### GitOps (FluxCD)

- [ ] FluxCD pods running
  ```bash
  kubectl get pods -n flux-system
  ```

- [ ] Git source ready
  ```bash
  flux get sources git -A
  # Should show "Ready: True"
  ```

- [ ] Kustomization reconciling
  ```bash
  flux get kustomizations -A
  # Should show "Ready: True"
  ```

### GPU (Optional)

- [ ] GPU detected
  ```bash
  kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
  # Should show "1"
  ```

- [ ] GPU test passes
  ```bash
  kubectl run gpu-test \
    --image=nvidia/cuda:12.0-base \
    --restart=Never \
    --rm -it \
    --limits=nvidia.com/gpu=1 \
    -- nvidia-smi
  ```

---

## Phase 4: Final Steps

### Documentation

- [ ] Actual IP addresses documented
- [ ] Any customizations noted
- [ ] Access credentials stored securely

### Backup

- [ ] Terraform state backed up
- [ ] kubeconfig backed up
- [ ] talosconfig backed up
- [ ] Longhorn backup target configured

### Security

- [ ] Default passwords changed
- [ ] API tokens stored in password manager
- [ ] Firewall rules reviewed

---

## Success Criteria

Your deployment is successful if:

| Component | Status |
|-----------|--------|
| Talos Node | Ready |
| All System Pods | Running |
| Cilium | Healthy |
| Longhorn | Healthy |
| Forgejo | Accessible |
| FluxCD | Reconciling |
| GPU (if enabled) | Detected |
| NFS Backup | Available |

---

## Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Node NotReady | Wait for Cilium, check `talosctl health` |
| Template not found | Verify template name matches exactly |
| Longhorn volumes fail | Check for `iscsi-tools` extension |
| GPU not detected | Enable IOMMU, check Proxmox mapping |
| FluxCD not syncing | Check `flux get sources git`, verify repo exists |

See [Troubleshooting Guide](../operations/troubleshooting.md) for detailed solutions.

---

**Last Updated:** 2026-01-15
