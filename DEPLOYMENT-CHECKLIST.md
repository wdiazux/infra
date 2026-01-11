# Deployment Validation Checklist

This checklist ensures all components are correctly configured and will work on first execution. Follow in order for best results.

---

## ✅ Phase 0: Prerequisites

### Environment Setup

- [ ] **Proxmox VE 9.0+ installed and accessible**
  ```bash
  pveversion  # Should show 9.0 or later
  ```

- [ ] **Required tools installed on build machine**
  ```bash
  # Packer
  packer version  # Should be 1.14.3+ (Dec 2025)

  # Terraform
  terraform version  # Should be 1.14.2+ (Dec 2025)

  # Ansible
  ansible --version  # Should be ansible-core 2.17.0+ (required by community.general v12)

  # Python (required by kubernetes.core v6)
  python3 --version  # Should be 3.9+ (Dec 2025)

  # SOPS (optional, for secrets)
  sops --version

  # Age (optional, for SOPS)
  age --version
  ```

- [ ] **Network connectivity verified**
  ```bash
  # Can reach Proxmox API
  curl -k https://YOUR_PROXMOX_IP:8006/api2/json/version

  # Can reach Talos Factory
  curl https://factory.talos.dev/

  # Can reach package repos
  ping -c 3 archive.ubuntu.com
  ```

### Infrastructure Assumptions Reviewed

- [ ] **Reviewed `INFRASTRUCTURE-ASSUMPTIONS.md`**
- [ ] **Customized values for your environment**
- [ ] **Created `terraform/terraform.tfvars` with required variables**

---

## ✅ Phase 1: Packer - Build Golden Images

### Pre-Build Checks

- [ ] **Proxmox storage pool exists**
  ```bash
  pvesm status | grep -E "tank|YOUR-STORAGE-POOL"
  ```

- [ ] **Proxmox network bridge exists**
  ```bash
  ip link show vmbr0  # Or your bridge
  ```

- [ ] **API credentials configured**
  ```bash
  # Test with your credentials
  export PROXMOX_TOKEN="PVEAPIToken=user@pam!token=secret"
  # Or set in .auto.pkrvars.hcl files
  ```

### Talos Image (Priority 1) - Direct Import (No Packer)

**Generate Talos Factory schematic first:**

- [ ] **Visit https://factory.talos.dev/**
- [ ] **Select platform:** "Metal" or "Nocloud"
- [ ] **Select version:** v1.12.1
- [ ] **Add required extensions:**
  - [ ] `siderolabs/qemu-guest-agent` (Proxmox integration)
  - [ ] `siderolabs/iscsi-tools` (required for Longhorn)
  - [ ] `siderolabs/util-linux-tools` (required for Longhorn)
  - [ ] `nonfree-kmod-nvidia-production` (if using GPU)
  - [ ] `nvidia-container-toolkit-production` (if using GPU)
- [ ] **Copy schematic ID** (64-character hex string)

**Import Talos template (run on Proxmox host):**

```bash
# 1. Edit import script with your schematic ID
cd packer/talos
vim import-talos-image.sh
# Update: SCHEMATIC_ID="your-64-char-hex-id"

# 2. Copy to Proxmox host
scp import-talos-image.sh root@pve:/tmp/

# 3. SSH to Proxmox and run
ssh root@pve
cd /tmp && chmod +x import-talos-image.sh
./import-talos-image.sh

# Takes ~2-5 minutes
```

- [ ] **Import script completed successfully**
- [ ] **Template visible in Proxmox UI**
- [ ] **Template name:** `talos-1.12.1-nvidia-template`
- [ ] **Template ID:** 9000

### Traditional OS Images (Optional - build as needed)

**Ubuntu 24.04:**

```bash
cd packer/ubuntu

# Create auto variables file
cat > ubuntu.auto.pkrvars.hcl <<EOF
proxmox_url = "https://YOUR_PROXMOX_IP:8006/api2/json"
proxmox_username = "root@pam"
proxmox_token = "PVEAPIToken=root@pam!token=YOUR-SECRET"
proxmox_node = "pve"
EOF

packer init .
packer validate .
packer build .  # Takes ~20-30 minutes
```

- [ ] **Ubuntu template built** (if needed)
- [ ] **Template name:** `ubuntu-24.04-golden-template`

**Debian 12:**

```bash
cd packer/debian
# Same process as Ubuntu
packer build .  # Takes ~20-30 minutes
```

- [ ] **Debian template built** (if needed)
- [ ] **Template name:** `debian-12-golden-template`

**Other OS** (Arch, NixOS, Windows):
- [ ] Build as needed following same pattern

---

## ✅ Phase 2: Terraform - Deploy Infrastructure

### Pre-Deployment Checks

- [ ] **Terraform initialized**
  ```bash
  cd terraform
  terraform init
  ```

- [ ] **Created `terraform.tfvars`** with required variables:
  ```hcl
  # REQUIRED
  node_ip = "10.10.2.10"  # Your static IP for Talos

  # REQUIRED if using custom Talos image
  talos_schematic_id = "your-64-char-hex-id"

  # REQUIRED for Proxmox connection
  proxmox_url = "https://YOUR_PROXMOX_IP:8006/api2/json"
  proxmox_api_token = "PVEAPIToken=root@pam!token=YOUR-SECRET"
  proxmox_node = "pve"  # Or your node name

  # OPTIONAL (only if different from defaults)
  node_gateway = "10.10.2.1"
  dns_servers = ["8.8.8.8", "8.8.4.4"]
  ```

- [ ] **IP address not conflicting** with existing devices
- [ ] **VM IDs not conflicting** (check: `qm list`)

### Validation

```bash
cd terraform

# 1. Format check
terraform fmt -check

# 2. Validate configuration
terraform validate

# 3. Plan deployment
terraform plan
```

- [ ] **Terraform plan** shows expected resources
- [ ] **No errors** in validation
- [ ] **Review plan output** carefully

### Deploy Talos Cluster

```bash
# Apply Terraform configuration
terraform apply

# Confirm with 'yes' when prompted
```

**Expected duration:** 15-20 minutes

- [ ] **Terraform apply completed successfully**
- [ ] **VM created in Proxmox**
- [ ] **Talos configuration applied**
- [ ] **Cluster bootstrapped**
- [ ] **Kubeconfig generated:** `terraform/kubeconfig`
- [ ] **Talosconfig generated:** `terraform/talosconfig`

### Post-Deployment Validation

```bash
# 1. Export kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# 2. Check cluster nodes
kubectl get nodes

# Should show:
# NAME         STATUS     ROLES           AGE   VERSION
# talos-node   NotReady   control-plane   1m    v1.35.0

# Note: Node will be NotReady until CNI (Cilium) is installed
```

```bash
# 3. Export talosconfig
export TALOSCONFIG=$(pwd)/talosconfig

# 4. Check Talos status
talosctl --nodes YOUR_NODE_IP version
talosctl --nodes YOUR_NODE_IP health
```

- [ ] **Node accessible via kubectl**
- [ ] **Node shows NotReady** (expected - no CNI yet)
- [ ] **Talosctl can connect**
- [ ] **Talos health check passes**

---

## ✅ Phase 3: Kubernetes - Install Core Components

### Install Cilium CNI

```bash
# 1. Add Cilium Helm repo
helm repo add cilium https://helm.cilium.io/
helm repo update

# 2. Install Cilium
helm install cilium cilium/cilium \
  --version 1.18.0 \
  --namespace kube-system \
  --values ../kubernetes/cilium/cilium-values.yaml
```

**Wait for Cilium to be ready (2-3 minutes):**

```bash
# Watch for Cilium pods to be Running
kubectl get pods -n kube-system -w

# Check Cilium status
cilium status  # If cilium CLI installed
```

- [ ] **Cilium pods running** (cilium-operator, cilium-agent)
- [ ] **Node shows Ready:**
  ```bash
  kubectl get nodes
  # NAME         STATUS   ROLES           AGE   VERSION
  # talos-node   Ready    control-plane   5m    v1.35.0
  ```

### Remove Control Plane Taint (Single-Node Only)

```bash
# Allow pods to schedule on control plane node
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

- [ ] **Taint removed successfully**
- [ ] **Test pod can schedule:**
  ```bash
  kubectl run test --image=nginx --restart=Never
  kubectl get pod test  # Should show Running
  kubectl delete pod test
  ```

### Install Longhorn Storage

```bash
# 1. Add Longhorn Helm repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# 2. Create namespace (already done by Terraform)
kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -

# 3. Label namespace
kubectl label namespace longhorn-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite

# 4. Install Longhorn
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values ../kubernetes/longhorn/longhorn-values.yaml
```

**Wait for Longhorn to be ready (5-10 minutes):**

```bash
# Watch Longhorn pods
kubectl get pods -n longhorn-system -w

# Check Longhorn status
kubectl get pods -n longhorn-system
```

- [ ] **All Longhorn pods running**
- [ ] **Longhorn manager accessible:**
  ```bash
  kubectl -n longhorn-system get svc longhorn-frontend
  # Port-forward to access UI
  kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
  # Visit http://localhost:8080
  ```

### Apply Storage Classes

```bash
# Apply Longhorn storage classes
kubectl apply -f ../kubernetes/storage-classes/longhorn-storage-classes.yaml

# Verify
kubectl get sc
```

- [ ] **Storage classes created:**
  - longhorn-default (default)
  - longhorn-retain
  - longhorn-fast
  - longhorn-backup (if NFS configured)
  - longhorn-xfs

### Test Storage

```bash
# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-default
  resources:
    requests:
      storage: 1Gi
EOF

# Check PVC status
kubectl get pvc test-pvc
# Should show Bound

# Clean up
kubectl delete pvc test-pvc
```

- [ ] **PVC bound successfully**
- [ ] **Volume visible in Longhorn UI**

### Install NVIDIA GPU Operator (If GPU Enabled)

```bash
# Only if enable_gpu_passthrough = true

# 1. Add NVIDIA Helm repo
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# 2. Install GPU Operator
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=false  # Driver in Talos image

# 3. Wait for pods
kubectl get pods -n gpu-operator -w
```

- [ ] **GPU Operator pods running** (if GPU enabled)
- [ ] **GPU visible in cluster:**
  ```bash
  kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
  # Should show: "1"
  ```

---

## ✅ Phase 4: Ansible - Configure Traditional VMs (Optional)

### Prerequisites

- [ ] **Ansible collections installed**
  ```bash
  cd ansible
  ansible-galaxy collection install -r requirements.yml
  ```

- [ ] **Inventory created** from Terraform outputs
  ```bash
  # Copy example inventory
  cp inventories/terraform-managed.yml.example inventories/terraform-managed.yml

  # Update with actual IPs from Terraform
  cd terraform
  terraform output | grep -i ip

  # Update inventory file with actual IPs
  ```

### Test Connectivity

```bash
cd ansible

# Test SSH connectivity
ansible all -i inventories/terraform-managed.yml -m ping

# Should see SUCCESS for all traditional VMs
```

- [ ] **All VMs reachable** via SSH
- [ ] **Cloud-init user created** (admin)
- [ ] **SSH keys working**

### Apply Baseline Configuration

```bash
# Configure all VMs
ansible-playbook -i inventories/terraform-managed.yml playbooks/site.yml

# Or configure specific groups
ansible-playbook -i inventories/terraform-managed.yml playbooks/ubuntu-baseline.yml
ansible-playbook -i inventories/terraform-managed.yml playbooks/debian-baseline.yml
```

- [ ] **Playbooks executed successfully**
- [ ] **No errors** in output
- [ ] **QEMU guest agent running:**
  ```bash
  ansible traditional_vms -i inventories/terraform-managed.yml \
    -m systemd -a "name=qemu-guest-agent state=started"
  ```

---

## ✅ Phase 5: Final Validation

### Cluster Health

```bash
# Overall cluster health
kubectl get nodes
kubectl get pods -A
kubectl top nodes  # Requires metrics-server

# Component status
kubectl get --raw /healthz
kubectl get --raw /readyz
```

- [ ] **All nodes Ready**
- [ ] **All system pods Running**
- [ ] **No CrashLoopBackOff pods**

### Talos Health

```bash
# Export talosconfig if not already
export TALOSCONFIG=terraform/talosconfig

# Check Talos services
talosctl --nodes YOUR_NODE_IP services
talosctl --nodes YOUR_NODE_IP health

# View Talos dashboard
talosctl --nodes YOUR_NODE_IP dashboard
```

- [ ] **All Talos services healthy**
- [ ] **etcd healthy**
- [ ] **kubelet running**

### Storage Health

```bash
# Longhorn volumes
kubectl get volumes -n longhorn-system

# Storage classes
kubectl get sc

# Test volume creation
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: validation-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-default
  resources:
    requests:
      storage: 100Mi
EOF

kubectl get pvc validation-test
# Should be Bound

kubectl delete pvc validation-test
```

- [ ] **Longhorn healthy**
- [ ] **Volumes can be created**
- [ ] **Storage working correctly**

### Network Health

```bash
# Cilium status
kubectl get pods -n kube-system -l k8s-app=cilium

# Test pod-to-pod networking
kubectl run test1 --image=nginx --port=80
kubectl run test2 --image=busybox --rm -it -- wget -O- http://test1
kubectl delete pod test1
```

- [ ] **Cilium pods healthy**
- [ ] **Pod networking works**
- [ ] **DNS resolution works**

### GPU Validation (If Enabled)

```bash
# Check GPU availability
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'

# Run GPU test pod
kubectl run gpu-test \
  --image=nvidia/cuda:12.0-base \
  --restart=Never \
  --rm -it \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi

# Should show GPU information
```

- [ ] **GPU detected** in cluster
- [ ] **nvidia-smi works** in pod
- [ ] **GPU workloads can schedule**

---

## ✅ Phase 6: Documentation & Cleanup

### Documentation

- [ ] **Document actual IP addresses used**
- [ ] **Document any customizations made**
- [ ] **Update `terraform.tfvars.example` with working examples**
- [ ] **Note any deviations from defaults**

### Security

- [ ] **Change default passwords** (if using passwords)
- [ ] **Rotate API tokens** (if using tokens)
- [ ] **Review firewall rules**
- [ ] **Enable Proxmox firewall** (if desired)

### Backup

- [ ] **Backup Terraform state:** `terraform/terraform.tfstate`
- [ ] **Backup kubeconfig:** `terraform/kubeconfig`
- [ ] **Backup talosconfig:** `terraform/talosconfig`
- [ ] **Backup Talos machine secrets** (in state file)
- [ ] **Configure Longhorn backup** to NAS (if available)

### Optional Enhancements

- [ ] **Set up FluxCD** for GitOps
- [ ] **Install Prometheus** for monitoring
- [ ] **Install Grafana** for dashboards
- [ ] **Install Loki** for logging
- [ ] **Configure external DNS**
- [ ] **Set up ingress controller**

---

## 🎯 Success Criteria

Your deployment is successful if:

✅ **Talos Cluster:**
- Node shows `Ready` status
- Kubernetes API accessible via kubectl
- etcd healthy
- All system pods running

✅ **Networking:**
- Cilium installed and healthy
- Pods can communicate
- DNS resolution works

✅ **Storage:**
- Longhorn installed and healthy
- Storage classes created
- Volumes can be provisioned

✅ **VMs (if deployed):**
- Traditional VMs accessible via SSH
- QEMU guest agent running
- Ansible playbooks executed successfully

✅ **GPU (if enabled):**
- GPU visible in cluster
- GPU pods can be scheduled
- nvidia-smi works in containers

---

## 🚨 Troubleshooting Common Issues

### Talos Node Stuck in "NotReady"

**Cause:** CNI not installed yet
**Solution:** Install Cilium (see Phase 3)

### "Template not found" Error in Terraform

**Cause:** Template name mismatch
**Solution:** Verify template names match exactly:
```bash
# In Proxmox
qm list | grep template

# Should match Terraform variables
grep template_name terraform/variables.tf
```

### Longhorn Volumes Fail to Attach

**Cause:** Missing system extensions in Talos image
**Solution:** Regenerate schematic at factory.talos.dev with `iscsi-tools` and `util-linux-tools`, then re-run import script

### Pods Can't Schedule (Taint Error)

**Cause:** Control plane taint still present
**Solution:**
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### GPU Not Detected

**Cause:** IOMMU not enabled or drivers not loaded
**Solution:**
1. Enable IOMMU in BIOS
2. Configure GRUB (see `PROXMOX-SETUP.md`)
3. Verify GPU bound to VFIO
4. Regenerate Talos schematic with NVIDIA extensions, re-run import script

---

## 📚 Related Documentation

- **Infrastructure Assumptions:** `INFRASTRUCTURE-ASSUMPTIONS.md`
- **Session Recovery Summary:** `SESSION-RECOVERY-SUMMARY.md`
- **Research Reports:**
  - `docs/packer-proxmox-research-report.md`
  - `docs/ANSIBLE_RESEARCH_REPORT.md`
  - `docs/talos-research-report.md`

---

**Checklist Version:** 1.1
**Last Updated:** January 11, 2026
**For Project:** wdiazux/infra
