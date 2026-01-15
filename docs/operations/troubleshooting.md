# Troubleshooting

Common issues and solutions for the homelab infrastructure.

---

## Quick Diagnostics

```bash
# Cluster health
talosctl health -n 10.10.2.10
kubectl get nodes
kubectl get pods -A | grep -v Running

# Service status
kubectl get svc -A | grep LoadBalancer

# Recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

## Talos Issues

### Node Not Accessible

**Symptoms:** Can't connect via `talosctl` or `kubectl`

```bash
# Check VM is running in Proxmox
pvesh get /nodes/pve/qemu/1000/status/current

# Check network from Proxmox
ping 10.10.2.10

# Check Talos API directly
curl -k https://10.10.2.10:50000/machine/version
```

**Solutions:**
1. Check VM is started in Proxmox
2. Verify network bridge (`vmbr0`) is working
3. Check talosconfig is correct
4. Reboot VM if needed

### Node Stuck in Maintenance Mode

**Symptoms:** Talos dashboard shows "Maintenance Mode"

```bash
# Apply machine config
talosctl apply-config --insecure -n 10.10.2.10 --file controlplane.yaml
```

**Cause:** VM was not configured after clone

### etcd Issues

**Symptoms:** `talosctl health` shows etcd unhealthy

```bash
# Check etcd status
talosctl etcd status -n 10.10.2.10

# Check etcd members
talosctl etcd members -n 10.10.2.10

# View etcd logs
talosctl logs etcd -n 10.10.2.10 --tail 100
```

**Solutions:**
1. Wait for etcd to recover (single-node can take time)
2. Check disk space
3. If corrupted, may need cluster redeploy

---

## Kubernetes Issues

### Node NotReady

**Symptoms:** `kubectl get nodes` shows NotReady

```bash
# Check node conditions
kubectl describe node talos-node

# Check kubelet logs
talosctl logs kubelet -n 10.10.2.10 --tail 100
```

**Causes:**
- CNI not installed/working
- Disk pressure
- Memory pressure

**Solutions:**
```bash
# Restart Cilium
kubectl rollout restart daemonset/cilium -n kube-system

# Check resources
kubectl top nodes
```

### Pods Stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Common causes and solutions:
# - "Insufficient cpu/memory" → Check node resources
# - "No nodes available" → Check node taints
# - "PersistentVolumeClaim not found" → Check PVC exists
```

**Remove control-plane taint (single-node):**
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### Pods CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
- Configuration errors
- Missing secrets/configmaps
- Health check failing
- Insufficient resources

### DNS Not Working

```bash
# Test DNS
kubectl run dnstest --rm -it --restart=Never --image=busybox -- nslookup kubernetes

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

---

## Network Issues

### LoadBalancer External-IP Pending

```bash
# Check Cilium L2 pools
kubectl get ciliumloadbalancerippool

# Check L2 announcement
kubectl get ciliuml2announcementpolicy

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium --tail 100
```

**Solutions:**
1. Verify IP pool has available IPs
2. Check L2 announcement policy matches interface
3. Restart Cilium if needed

### Can't Reach Services

```bash
# Check service exists
kubectl get svc -A

# Check endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test connectivity
kubectl run curltest --rm -it --restart=Never --image=curlimages/curl -- curl <service-ip>
```

### Pods Can't Reach External Network

```bash
# Test from pod
kubectl run nettest --rm -it --restart=Never --image=busybox -- wget -O- google.com

# Check masquerading
kubectl -n kube-system exec ds/cilium -- cilium status | grep Masquerading

# Check node routing
talosctl get routes -n 10.10.2.10
```

---

## Storage Issues

### PVC Stuck in Pending

```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>

# Check Longhorn
kubectl get nodes.longhorn.io -n longhorn-system
kubectl logs -n longhorn-system -l app=longhorn-manager --tail 100
```

**Causes:**
- Storage class doesn't exist
- No available disk space
- Longhorn not healthy

### Volume Stuck in Attaching

```bash
# Check volume status in Longhorn
kubectl get volumes.longhorn.io -n longhorn-system

# Restart instance manager
kubectl delete pods -n longhorn-system -l app=longhorn-instance-manager

# Check iSCSI
talosctl -n 10.10.2.10 read /proc/modules | grep iscsi
```

### NFS Backup Unavailable

```bash
# Check backup target
kubectl get backuptarget -n longhorn-system -o yaml

# Test NFS connectivity
talosctl -n 10.10.2.10 ping 10.10.2.5

# Check backup secret
kubectl get secret longhorn-backup-secret -n longhorn-system
```

**Solutions:**
1. Verify NAS is accessible
2. Check NFS export permissions
3. Verify backup target URL matches NAS export

---

## FluxCD Issues

### GitRepository Not Ready

```bash
# Check status
kubectl get gitrepository -n flux-system -o yaml

# Check source-controller logs
kubectl logs -n flux-system deployment/source-controller -f
```

**Causes:**
- Authentication failed
- Repository doesn't exist
- Network issues

### Kustomization Failed

```bash
# Check status
kubectl get kustomization -n flux-system -o yaml

# Check kustomize-controller logs
kubectl logs -n flux-system deployment/kustomize-controller -f
```

**Common errors:**
- SOPS decryption failed → Check `sops-age` secret
- Invalid manifests → Validate YAML locally
- Dependencies not ready → Check dependsOn

### Force Reconciliation

```bash
flux reconcile source git flux-system --with-source
flux reconcile kustomization flux-system
```

---

## GPU Issues

### GPU Not Detected

```bash
# Check NVIDIA device plugin
kubectl get pods -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin
kubectl logs -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin

# Check Talos extensions
talosctl -n 10.10.2.10 get extensions | grep nvidia

# Check node capacity
kubectl get nodes -o json | jq '.items[].status.capacity'
```

**Solutions:**
1. Verify GPU passthrough in Proxmox
2. Check Talos schematic has NVIDIA extensions
3. Restart NVIDIA device plugin

### nvidia-smi Fails in Pod

```bash
# Ensure runtimeClassName is set
kubectl get pod <pod-name> -o yaml | grep runtimeClassName

# Check RuntimeClass exists
kubectl get runtimeclass nvidia
```

---

## Terraform Issues

### Destroy Fails

See [Destroy Guide](destroy.md) for detailed steps.

Quick fix:
```bash
./destroy.sh --force
```

### State Out of Sync

```bash
# Refresh state
terraform refresh

# Import missing resource
terraform import <resource> <id>

# Remove orphaned resource
terraform state rm <resource>
```

---

## Proxmox Issues

### VM Won't Start

```bash
# Check VM status
pvesh get /nodes/pve/qemu/1000/status/current

# Check for errors
journalctl -u pve-qemu@1000 --no-pager -n 50

# Verify template exists
qm list | grep 9000
```

### GPU Passthrough Failed

```bash
# Check IOMMU
dmesg | grep -i iommu

# Check GPU binding
lspci -nnk -s 07:00.0

# Check Proxmox GPU mapping
cat /etc/pve/mapping/pci.cfg
```

---

## Logs Reference

| Component | Log Command |
|-----------|-------------|
| Talos | `talosctl logs <service> -n 10.10.2.10` |
| Kubelet | `talosctl logs kubelet -n 10.10.2.10` |
| Cilium | `kubectl logs -n kube-system ds/cilium` |
| Longhorn | `kubectl logs -n longhorn-system -l app=longhorn-manager` |
| FluxCD | `kubectl logs -n flux-system deployment/source-controller` |
| Forgejo | `kubectl logs -n forgejo -l app.kubernetes.io/name=forgejo` |

---

## Emergency Recovery

### Cluster Completely Down

1. Check Proxmox host is accessible
2. Verify VM 1000 is running
3. Try `talosctl dashboard -n 10.10.2.10`
4. If no response, reboot VM
5. If still failing, redeploy:
   ```bash
   ./destroy.sh --force
   terraform apply
   ```
6. Restore from backups

### Lost kubeconfig/talosconfig

If Terraform state exists:
```bash
# Regenerate from state
terraform output kubeconfig > kubeconfig
terraform output talosconfig > talosconfig
```

If state is lost:
```bash
# Regenerate talosconfig
talosctl gen config homelab https://10.10.2.10:6443

# Apply and bootstrap (will reset cluster!)
```

---

**Last Updated:** 2026-01-15
