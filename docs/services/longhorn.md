# Longhorn Storage

Distributed block storage with snapshots, backups, and web UI.

---

## Overview

Longhorn is installed **automatically** via Terraform Helm release. Manual installation is not required.

**What's Automatic:**
- Longhorn deployment
- Storage classes creation
- NFS backup target configuration (if enabled)
- Longhorn UI LoadBalancer

**Configuration:** `terraform/talos/addons.tf`

---

## Key Features

| Feature | Description |
|---------|-------------|
| Distributed Storage | Block storage with replication |
| Snapshots | Point-in-time volume snapshots |
| Backups | NFS backup to external NAS |
| Web UI | Visual storage management |
| Expansion | Resize volumes online |

---

## Service URLs

| Service | URL |
|---------|-----|
| Longhorn UI | http://10.10.2.12 |

---

## Storage Classes

| Class | Use Case | Reclaim |
|-------|----------|---------|
| `longhorn-default` | General purpose | Delete |
| `longhorn-retain` | Critical data | Retain |
| `longhorn-fast` | High IOPS workloads | Delete |
| `longhorn-xfs` | Large files | Delete |

---

## Using Storage

### Create PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-default
  resources:
    requests:
      storage: 10Gi
```

### Mount in Pod

```yaml
spec:
  containers:
    - name: app
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-data
```

---

## NFS Backup

### Verify Backup Target

```bash
kubectl get backuptarget -n longhorn-system -o yaml
# Should show: available: true
```

### Manual Backup

Via Longhorn UI:
1. Go to Volume
2. Select volume → Take Snapshot
3. Click "Backup" on snapshot

Via kubectl:
```bash
kubectl -n longhorn-system create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: backup-$(date +%Y%m%d)
spec:
  snapshotName: snap-manual
EOF
```

### Recurring Backup

Configure in Longhorn UI:
1. Go to Recurring Job
2. Create new job:
   - Name: `daily-backup`
   - Task: Backup
   - Schedule: `0 2 * * *` (2 AM daily)
   - Retain: 7

---

## Verification

```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system

# Check node status
kubectl get nodes.longhorn.io -n longhorn-system

# Check volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check storage classes
kubectl get storageclass
```

---

## Single-Node Mode

With a single Talos node, Longhorn runs with:
- **Replicas:** 1 (no redundancy)
- **Data Locality:** Best-effort

When expanding to 3 nodes:
1. Change default replica count to 3
2. Existing volumes can be expanded to 3 replicas
3. Use `longhorn-ha` storage class for new volumes

---

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check PVC status
kubectl get pvc

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Verify kernel modules
talosctl -n 10.10.2.10 read /proc/modules | grep -E 'iscsi|nbd'
```

### Volumes Stuck in Attaching

```bash
# Check instance manager
kubectl get pods -n longhorn-system -l app=longhorn-instance-manager

# Restart instance manager
kubectl delete pod -n longhorn-system -l app=longhorn-instance-manager

# Check kubelet mounts
talosctl -n 10.10.2.10 get machineconfig -o yaml | grep -A 5 extraMounts
```

### Backup Target Unavailable

```bash
# Check backup target status
kubectl get backuptarget -n longhorn-system -o yaml

# Verify NAS is reachable
talosctl -n 10.10.2.10 ping 10.10.2.5

# Check backup secret
kubectl get secret longhorn-backup-secret -n longhorn-system
```

### No Space Left

```bash
# Check node disk usage
kubectl get nodes.longhorn.io -n longhorn-system -o yaml

# Access UI to manage volumes
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Delete unused volumes/snapshots
kubectl get volumes.longhorn.io -n longhorn-system
```

---

## Best Practices

1. **Keep 25-30% disk space free** for operations
2. **Regular backups** to external NAS
3. **Monitor volume health** via UI
4. **Use `longhorn-retain`** for important data
5. **Plan for 3-node expansion** for production

---

## Resources

- [Longhorn Documentation](https://longhorn.io/)
- [Talos Longhorn Guide](https://www.talos.dev/v1.12/kubernetes-guides/configuration/deploy-longhorn/)
- [Longhorn Troubleshooting](https://longhorn.io/docs/1.10.1/troubleshoot/)

---

**Last Updated:** 2026-01-15
