# Longhorn Installation Guide for Talos Linux Single-Node Cluster

This guide provides step-by-step instructions for installing and configuring Longhorn as the **primary storage solution** for your Talos Linux cluster on Proxmox.

---

## ⚠️ **CRITICAL: Install Cilium CNI BEFORE Longhorn**

**STOP!** Before installing Longhorn, you **MUST** install Cilium first.

Longhorn requires a functioning Container Network Interface (CNI) to operate. Without Cilium:
- Longhorn pods will fail to start
- Network communication between components won't work
- Volume operations will fail

**Installation Order:**
1. **FIRST:** Install Cilium CNI → See [`kubernetes/cilium/INSTALLATION.md`](../cilium/INSTALLATION.md)
2. **SECOND:** Install Longhorn (this guide)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Talos Image Preparation](#talos-image-preparation)
3. [Talos Configuration](#talos-configuration)
4. [Install Longhorn](#install-longhorn)
5. [Verify Installation](#verify-installation)
6. [Configure Storage Classes](#configure-storage-classes)
7. [Optional: Configure Backups](#optional-configure-backups)
8. [Testing](#testing)
9. [Monitoring](#monitoring)
10. [Troubleshooting](#troubleshooting)
11. [Expanding to 3-Node HA](#expanding-to-3-node-ha)

---

## Prerequisites

Before installing Longhorn, ensure you have:

- ✅ Talos Linux v1.8+ installed on Proxmox
- ✅ Kubernetes cluster bootstrapped and accessible via kubectl
- ✅ Helm 3.x installed on your management machine
- ✅ At least 50GB free disk space on the Talos node
- ✅ CPU type set to "host" in Proxmox VM configuration (required for Talos)

### Resource Requirements

**Minimum:**
- 2 CPU cores
- 4GB RAM
- 50GB disk space

**Recommended for Production:**
- 4+ CPU cores
- 8GB+ RAM
- 100GB+ dedicated disk (separate from OS)

---

## Talos Image Preparation

Longhorn requires specific system extensions that must be included in your Talos image.

### Option A: Build Custom Image via Talos Factory (Recommended)

1. **Visit Talos Factory**: https://factory.talos.dev/

2. **Select Talos Version**: Choose v1.8.0 or later

3. **Add System Extensions**:
   - `siderolabs/iscsi-tools` (required for iSCSI operations)
   - `siderolabs/util-linux-tools` (required for fstrim and volume management)
   - `siderolabs/qemu-guest-agent` (recommended for Proxmox integration)
   - `nonfree-kmod-nvidia-production` (optional, for GPU passthrough)
   - `nvidia-container-toolkit-production` (optional, for GPU workloads)

4. **Generate Schematic**: Click "Generate" to create your custom image

5. **Download Image**: Download the `nocloud-amd64.raw.xz` image for Proxmox

6. **Upload to Proxmox**: Upload the image to your Proxmox storage

### Option B: Use Existing Image with Extensions

If you already have a Talos image, verify it includes the required extensions:

```bash
talosctl get extensions -n <node-ip>
```

Look for:
- `iscsi-tools`
- `util-linux-tools`

If missing, rebuild your image using Option A.

---

## Talos Configuration

### ✅ If You Deployed with Terraform (Recommended)

**No manual configuration needed!** The Longhorn requirements are already configured in `terraform/main.tf` (lines 130-149):

- ✅ Kernel modules: `nbd`, `iscsi_tcp`, `iscsi_generic`, `configfs`
- ✅ Kubelet extra mounts: `/var/lib/longhorn` with `rshared` propagation

**Skip to verification steps below** to confirm they're loaded.

---

### ⚠️ If You Deployed Manually with talosctl

If you deployed Talos manually (NOT with Terraform), you need to add these configurations to your machine config:

```yaml
machine:
  kernel:
    modules:
      - name: nbd
      - name: iscsi_tcp
      - name: iscsi_generic
      - name: configfs

  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
```

Apply with:
```bash
talosctl patch machineconfig --nodes <node-ip> --patch @/path/to/patch.yaml
```

---

### Step 1: Verify Kernel Modules

After applying the patch and rebooting (if necessary), verify the kernel modules are loaded:

```bash
talosctl -n <node-ip> read /proc/modules | grep -E 'nbd|iscsi|configfs'
```

Expected output should show:
```
nbd
iscsi_tcp
iscsi_generic
configfs
```

### Step 3: Verify System Extensions

```bash
talosctl -n <node-ip> get extensions
```

Verify `iscsi-tools` and `util-linux-tools` are listed.

---

## Install Longhorn

### Step 1: Create Namespace with Pod Security Labels

```bash
kubectl create namespace longhorn-system

kubectl label namespace longhorn-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged
```

### Step 2: Add Longhorn Helm Repository

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

### Step 3: Install Longhorn with Custom Values

```bash
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version 1.7.2 \
  --values kubernetes/longhorn/longhorn-values.yaml
```

**Note**: Adjust the version to the latest stable release if needed.

### Step 4: Wait for Deployment

Monitor the installation progress:

```bash
# Watch all pods in longhorn-system namespace
kubectl get pods -n longhorn-system -w

# Or use k9s for interactive monitoring
k9s -n longhorn-system
```

Wait until all pods are in `Running` state. This may take 2-5 minutes.

---

## Verify Installation

### Check Longhorn Pods

```bash
kubectl get pods -n longhorn-system
```

Expected output (all pods should be Running):
```
NAME                                        READY   STATUS    RESTARTS   AGE
csi-attacher-xxx                           1/1     Running   0          2m
csi-provisioner-xxx                        1/1     Running   0          2m
csi-resizer-xxx                            1/1     Running   0          2m
csi-snapshotter-xxx                        1/1     Running   0          2m
engine-image-ei-xxx                        1/1     Running   0          2m
instance-manager-xxx                       1/1     Running   0          2m
longhorn-csi-plugin-xxx                    3/3     Running   0          2m
longhorn-driver-deployer-xxx               1/1     Running   0          2m
longhorn-manager-xxx                       1/1     Running   0          2m
longhorn-ui-xxx                            1/1     Running   0          2m
```

### Check Longhorn Nodes

```bash
kubectl get nodes.longhorn.io -n longhorn-system
```

Expected output should show your node as `Ready`:
```
NAME          STATE   READY   SCHEDULABLE   AGE
talos-node1   Ready   True    True          3m
```

### Check Default Storage Class

```bash
kubectl get storageclass
```

Expected output:
```
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           3m
```

### Access Longhorn UI (Optional)

**Option 1: Port Forward**
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

Then access: http://localhost:8080

**Option 2: Ingress** (if you have Cilium ingress configured)
Edit `kubernetes/longhorn/longhorn-values.yaml` and set:
```yaml
ingress:
  enabled: true
  host: longhorn.yourdomain.com
  ingressClassName: cilium
```

Then upgrade Longhorn:
```bash
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values kubernetes/longhorn/longhorn-values.yaml
```

---

## Configure Storage Classes

Apply the predefined storage classes for different use cases:

```bash
kubectl apply -f kubernetes/storage-classes/longhorn-storage-classes.yaml
```

### Available Storage Classes

| Storage Class | Use Case | Reclaim Policy | Features |
|---------------|----------|----------------|----------|
| `longhorn` (default) | General purpose | Delete | Standard performance |
| `longhorn-fast` | Databases, high-IOPS | Delete | Strict local data locality |
| `longhorn-retain` | Critical data | Retain | Data persists after PVC deletion |
| `longhorn-backup` | Disaster recovery | Retain | Automatic recurring snapshots |
| `longhorn-xfs` | Large files, media | Delete | XFS filesystem |

### Verify Storage Classes

```bash
kubectl get storageclass
```

---

## Optional: Configure Backups

To enable backups to your external NAS:

### Step 1: Create NFS Share on Your NAS

Create a directory on your NAS for Longhorn backups:
- Example: `/mnt/storage/longhorn-backups`
- Ensure Talos node can access the NFS share

### Step 2: Test NFS Mount from Talos

```bash
talosctl -n <node-ip> read /proc/mounts | grep nfs
```

### Step 3: Create Backup Target Secret (if needed)

If your NFS requires authentication, create a secret:

```bash
kubectl create secret generic longhorn-backup-secret \
  --from-literal=AWS_ACCESS_KEY_ID=<key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret> \
  -n longhorn-system
```

### Step 4: Configure Backup Target in Longhorn

**Via Helm values** (update `kubernetes/longhorn/longhorn-values.yaml`):

```yaml
defaultSettings:
  backupTarget: "nfs://192.168.1.100:/mnt/storage/longhorn-backups"
  backupTargetCredentialSecret: "longhorn-backup-secret"  # if needed
```

Then upgrade:
```bash
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values kubernetes/longhorn/longhorn-values.yaml
```

**Via Longhorn UI**:
1. Access Longhorn UI (see above)
2. Go to Settings → General
3. Set Backup Target: `nfs://192.168.1.100:/mnt/storage/longhorn-backups`
4. Save

### Step 5: Create Recurring Backup Job (Optional)

In Longhorn UI:
1. Go to Recurring Job
2. Create new job:
   - Name: `daily-backup`
   - Task: Backup
   - Schedule: `0 2 * * *` (2 AM daily)
   - Retain: 7

---

## Testing

### Test 1: Create a Test PVC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-longhorn-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF
```

### Test 2: Verify PVC is Bound

```bash
kubectl get pvc test-longhorn-pvc
```

Expected:
```
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-longhorn-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO            longhorn       10s
```

### Test 3: Create Test Pod Using PVC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-longhorn-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "echo 'Hello Longhorn' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-longhorn-pvc
EOF
```

### Test 4: Verify Data Persistence

```bash
# Check pod is running
kubectl get pod test-longhorn-pod

# Verify file was created
kubectl exec test-longhorn-pod -- cat /data/test.txt
```

Expected output: `Hello Longhorn`

### Test 5: Cleanup

```bash
kubectl delete pod test-longhorn-pod
kubectl delete pvc test-longhorn-pvc
```

---

## Monitoring

### Using kubectl

```bash
# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check Longhorn nodes
kubectl get nodes.longhorn.io -n longhorn-system

# Check Longhorn settings
kubectl get settings.longhorn.io -n longhorn-system

# View Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager
```

### Using Longhorn UI

Access the UI (see [Verify Installation](#verify-installation)) and monitor:
- Node disk space usage
- Volume health and status
- Replica status
- Snapshot schedules

### Using Prometheus (if kube-prometheus-stack is installed)

Enable ServiceMonitor in `longhorn-values.yaml`:
```yaml
metrics:
  serviceMonitor:
    enabled: true
```

Then upgrade Longhorn.

---

## Troubleshooting

### Issue: Pods Stuck in Pending State

**Symptom**: Longhorn pods remain in `Pending` state.

**Solutions**:
1. Check Pod Security labels:
   ```bash
   kubectl get namespace longhorn-system -o yaml | grep pod-security
   ```
2. Verify kernel modules are loaded (see [Talos Configuration](#talos-configuration))
3. Check node resources:
   ```bash
   kubectl describe node
   ```

### Issue: Volumes Stuck in "Attaching" State

**Symptom**: PVCs are bound but pods can't start; volumes show "Attaching" in Longhorn UI.

**Solutions**:
1. Verify kubelet extra mounts:
   ```bash
   talosctl -n <node-ip> get machineconfig -o yaml | grep -A 5 extraMounts
   ```
2. Check iSCSI daemon:
   ```bash
   talosctl -n <node-ip> service iscsi
   ```
3. Restart instance manager:
   ```bash
   kubectl delete pod -n longhorn-system -l app=longhorn-instance-manager
   ```

### Issue: "No Space Left on Device"

**Symptom**: Can't create new volumes; node shows no available space.

**Solutions**:
1. Check node disk usage:
   ```bash
   kubectl get nodes.longhorn.io -n longhorn-system -o yaml
   ```
2. Adjust storage reservation in Longhorn settings
3. Clean up old volumes/snapshots:
   ```bash
   kubectl get volumes.longhorn.io -n longhorn-system
   ```

### Issue: High CPU/Memory Usage

**Symptom**: Longhorn pods consuming excessive resources.

**Solutions**:
1. Increase resource limits in `longhorn-values.yaml`
2. Reduce number of snapshots
3. Check for stuck volume operations

### Get Help

**Longhorn Logs**:
```bash
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
```

**Longhorn Events**:
```bash
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'
```

**Talos Logs**:
```bash
talosctl -n <node-ip> logs kubelet
talosctl -n <node-ip> dmesg | grep iscsi
```

---

## Expanding to 3-Node HA

When you're ready to expand to a 3-node high-availability cluster:

### Step 1: Deploy 2 Additional Talos Nodes

1. Create 2 more Proxmox VMs with same Talos image (with iscsi-tools and util-linux-tools)
2. Apply same machine config patch with Longhorn requirements
3. Join them to your cluster via `talosctl`

### Step 2: Update Longhorn Default Replica Count

**Option A: Via Longhorn UI**
1. Go to Settings → General
2. Change "Default Replica Count" from 1 to 3
3. Save

**Option B: Via kubectl**
```bash
kubectl edit settings.longhorn.io default-replica-count -n longhorn-system
# Change value from "1" to "3"
```

### Step 3: Update Existing Volumes (Optional)

Existing volumes will remain at 1 replica. To add replicas:

**Via Longhorn UI**:
1. Go to Volume
2. Select volume → Update Replicas Count → 3

**Via kubectl**:
```bash
kubectl patch volumes.longhorn.io <volume-name> -n longhorn-system \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/numberOfReplicas", "value": 3}]'
```

### Step 4: Create HA Storage Class

Uncomment the `longhorn-ha` storage class in `kubernetes/storage-classes/longhorn-storage-classes.yaml` and apply:

```bash
kubectl apply -f kubernetes/storage-classes/longhorn-storage-classes.yaml
```

### Step 5: Verify Replication

```bash
# Check node status
kubectl get nodes.longhorn.io -n longhorn-system

# Check volumes - should show 3 replicas
kubectl get volumes.longhorn.io -n longhorn-system -o wide
```

---

## Summary

You now have Longhorn installed as your **primary storage solution** for your Talos cluster! 🎉

**Next Steps**:
1. Deploy your applications using Longhorn PVCs
2. Configure recurring backups to your NAS
3. Monitor disk usage via Longhorn UI
4. Plan expansion to 3-node HA cluster when ready

**Storage Class Recommendations**:
- Use `longhorn` (default) for most workloads
- Use `longhorn-fast` for databases
- Use `longhorn-retain` for critical data
- Configure `longhorn-backup` for disaster recovery

**Best Practices**:
- Keep 25-30% disk space free
- Regular backups to external NAS
- Monitor volume health via Longhorn UI
- Plan for 3-node expansion for production workloads

---

**Documentation Version**: 1.0.0
**Last Updated**: 2025-11-22
**Talos Version**: v1.8+
**Longhorn Version**: v1.7+
