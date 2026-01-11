# Cilium Installation Guide for Talos Linux

This guide provides step-by-step instructions for installing and configuring Cilium as the CNI (Container Network Interface) and kube-proxy replacement for your Talos Linux cluster.

## ⚠️ CRITICAL PREREQUISITES

**BEFORE installing Cilium, ensure:**

1. **Talos cluster is deployed and bootstrapped** via Terraform (`terraform apply` completed successfully)
2. **Kubernetes API is accessible** via `kubectl --kubeconfig=./kubeconfig get nodes`
3. **NO OTHER CNI IS INSTALLED** - Cilium must be the first and only CNI
4. **Talos machine config has `cni.name: none`** and `proxy.disabled: true` (already configured in Terraform)
5. **KubePrism is enabled** on port 7445 (already configured in Terraform)

**IMPORTANT**: Nodes will show `NotReady` until Cilium is installed. This is expected behavior.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Why Cilium](#why-cilium)
3. [Install Cilium](#install-cilium)
4. [Verify Installation](#verify-installation)
5. [Configure L2 Load Balancing](#configure-l2-load-balancing)
6. [Access Hubble UI](#access-hubble-ui)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Configuration](#advanced-configuration)

---

## Prerequisites

Before installing Cilium, ensure you have:

- ✅ Talos cluster deployed via Terraform (`terraform apply` completed)
- ✅ Cluster is bootstrapped and accessible via kubectl
- ✅ **NO OTHER CNI INSTALLED** (Cilium must be first)
- ✅ Helm 3.x installed on your management machine
- ✅ kubectl configured with cluster access

**IMPORTANT**: Cilium must be installed **BEFORE** any other workloads or CNI. The cluster will not be fully functional until Cilium is installed.

---

## Why Cilium

**Cilium is chosen for this project because:**

- ✅ **eBPF-based**: Kernel-level networking for best performance
- ✅ **Replaces kube-proxy**: Eliminates iptables overhead
- ✅ **L2 Load Balancing**: No need for external load balancer (MetalLB, etc.)
- ✅ **Network Policies**: Built-in security
- ✅ **Hubble**: Network observability and flow visualization
- ✅ **Talos-optimized**: Works perfectly with Talos Linux

---

## Install Cilium

### Step 1: Add Cilium Helm Repository

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

### Step 2: Install Cilium

**Option A: Install with Custom Values (Recommended)**

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --values kubernetes/cilium/cilium-values.yaml \
  --wait
```

**Option B: Install with CLI Parameters**

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set l2announcements.enabled=true \
  --set externalIPs.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --wait
```

**Important Parameters Explained:**

| Parameter | Value | Why |
|-----------|-------|-----|
| `k8sServiceHost` | `localhost` | Use KubePrism (Talos local API proxy) |
| `k8sServicePort` | `7445` | KubePrism port (not 6443) |
| `kubeProxyReplacement` | `true` | Replace kube-proxy with Cilium |
| `l2announcements.enabled` | `true` | Enable L2 load balancing |

### Step 3: Wait for Cilium to Be Ready

```bash
# Watch Cilium pods come up
kubectl get pods -n kube-system -l k8s-app=cilium -w

# Or use Cilium CLI
cilium status --wait
```

Expected output (all components running):
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (not required)
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

DaemonSet              cilium             Desired: 1, Ready: 1/1, Available: 1/1
Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium             Running: 1
                       cilium-operator    Running: 1
                       hubble-relay       Running: 1
                       hubble-ui          Running: 1
```

---

## Verify Installation

### Check All Nodes Are Ready

```bash
kubectl get nodes
```

Expected output:
```
NAME          STATUS   ROLES           AGE   VERSION
talos-node    Ready    control-plane   5m    v1.35.0
```

**Note**: Nodes will show `NotReady` until Cilium is fully deployed!

### Check Cilium Pods

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

All pods should be in `Running` state:
```
NAME                               READY   STATUS    RESTARTS   AGE
cilium-operator-5c7b5f4d9d-xxxxx   1/1     Running   0          2m
cilium-xxxxx                       1/1     Running   0          2m
hubble-relay-7d8f9c8b9d-xxxxx      1/1     Running   0          2m
hubble-ui-6b8c7d4f8d-xxxxx         1/1     Running   0          2m
```

### Verify Cilium Status

**Using Cilium CLI** (recommended):

```bash
# Install Cilium CLI if not already installed
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Check Cilium status
cilium status
```

**Using kubectl**:

```bash
kubectl -n kube-system exec ds/cilium -- cilium status
```

---

## Configure L2 Load Balancing

Cilium's L2 announcements allow you to use `LoadBalancer` type services without an external load balancer.

### Step 1: Define IP Pool for LoadBalancer Services

Create a CiliumLoadBalancerIPPool:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: homelab-pool
spec:
  blocks:
    - cidr: "192.168.1.240/28"  # Adjust to your network
      # This gives you IPs: 192.168.1.241-254
  serviceSelector:
    matchLabels: {}  # Match all services
EOF
```

**Important**: Choose an IP range that:
- Is in your LAN subnet
- Does NOT conflict with DHCP range
- Has unused IPs available

### Step 2: Configure L2 Announcement Policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: homelab-l2-policy
spec:
  loadBalancerIPs: true
  interfaces:
    - ^eth0  # Adjust if your interface is different
  nodeSelector:
    matchLabels: {}  # Match all nodes
EOF
```

### Step 3: Test LoadBalancer Service

```bash
# Deploy a test service
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check the external IP
kubectl get svc nginx
```

Expected output:
```
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
nginx   LoadBalancer   10.96.123.45    192.168.1.241    80:30123/TCP   10s
```

You should be able to access nginx at `http://192.168.1.241`.

---

## Access Hubble UI

Hubble provides network observability and flow visualization.

### Option 1: Port Forward (Quick Access)

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

Then access: **http://localhost:12000**

### Option 2: Ingress (Permanent Access)

If you have an ingress controller (install after Cilium):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hubble-ui
  namespace: kube-system
spec:
  ingressClassName: cilium  # or nginx, traefik, etc.
  rules:
    - host: hubble.yourdomain.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hubble-ui
                port:
                  number: 80
```

### Option 3: LoadBalancer Service

```bash
kubectl patch svc hubble-ui -n kube-system -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc hubble-ui -n kube-system
```

Access via the assigned external IP.

---

## Testing

### Test 1: Basic Connectivity

```bash
# Run connectivity test (requires Cilium CLI)
cilium connectivity test
```

This runs ~50 tests to verify pod-to-pod, pod-to-service, and external connectivity.

### Test 2: Pod-to-Pod Communication

```bash
# Create test pods
kubectl run test1 --image=nginx
kubectl run test2 --image=busybox --command -- sleep 3600

# Get test1 pod IP
TEST1_IP=$(kubectl get pod test1 -o jsonpath='{.status.podIP}')

# Test connectivity from test2 to test1
kubectl exec test2 -- wget -qO- http://$TEST1_IP
```

Expected: HTML output from nginx.

### Test 3: External Connectivity

```bash
kubectl exec test2 -- wget -qO- http://www.google.com
```

Expected: HTML output from Google.

### Test 4: Service Discovery

```bash
# Create a service
kubectl expose pod test1 --port=80

# Test service DNS
kubectl exec test2 -- wget -qO- http://test1.default.svc.cluster.local
```

Expected: HTML output from nginx via service.

---

## Troubleshooting

### Issue: Nodes Stay in "NotReady" State

**Symptom**: `kubectl get nodes` shows `NotReady` after Cilium installation.

**Solution**:
```bash
# Check Cilium pods are running
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium agent logs
kubectl logs -n kube-system ds/cilium --tail=100

# Restart Cilium pods
kubectl rollout restart ds/cilium -n kube-system
```

### Issue: Pods Can't Reach External Internet

**Symptom**: Pods can reach each other but not external IPs.

**Solution**:
1. Verify masquerading is enabled:
   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium status | grep Masquerading
   ```
   Should show: `Masquerading: IPTables [...]` or `eBPF [...]`

2. Check default gateway on Talos node:
   ```bash
   talosctl -n <node-ip> get routes
   ```

3. Ensure Proxmox VM has internet connectivity

### Issue: LoadBalancer Services Don't Get External IP

**Symptom**: `kubectl get svc` shows `<pending>` for LoadBalancer services.

**Solution**:
1. Verify L2 announcements are enabled:
   ```bash
   kubectl get ciliumloadbalancerippool
   kubectl get ciliuml2announcementpolicy
   ```

2. Check IP pool configuration has available IPs

3. Verify Cilium has detected correct network interface:
   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium status | grep Device
   ```

### Issue: Hubble UI Not Accessible

**Symptom**: Port forward works but UI doesn't load.

**Solution**:
```bash
# Check Hubble pods
kubectl get pods -n kube-system -l k8s-app=hubble-ui
kubectl get pods -n kube-system -l k8s-app=hubble-relay

# Check logs
kubectl logs -n kube-system deploy/hubble-ui
kubectl logs -n kube-system deploy/hubble-relay
```

---

## Advanced Configuration

### Enable Network Policies

Cilium automatically enforces Kubernetes NetworkPolicies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 80
```

### Enable Encryption (WireGuard)

For pod-to-pod encryption:

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
```

### Enable BBR Congestion Control

For better network performance:

```bash
# On Talos nodes (via machine config):
# machine.sysctls:
#   net.core.default_qdisc: fq
#   net.ipv4.tcp_congestion_control: bbr

# Then enable in Cilium:
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set enableBBR=true
```

### Monitor with Prometheus

If you have kube-prometheus-stack:

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set prometheus.enabled=true \
  --set prometheus.serviceMonitor.enabled=true
```

---

## Summary

You now have Cilium installed as your CNI! 🎉

**What You Have:**
- ✅ eBPF-based networking
- ✅ kube-proxy replacement
- ✅ L2 load balancing for LoadBalancer services
- ✅ Network observability via Hubble
- ✅ Network policy enforcement

**Next Steps:**
1. Install Longhorn for storage
2. Deploy your applications
3. Configure ingress controller (optional)
4. Install NVIDIA GPU Operator (if using GPU)

**Useful Commands:**
```bash
# Check Cilium status
cilium status

# View network flows
cilium hubble observe

# Connectivity test
cilium connectivity test

# Get Cilium config
kubectl -n kube-system exec ds/cilium -- cilium config view
```

---

**Documentation Version**: 1.0.0
**Last Updated**: 2025-11-22
**Cilium Version**: v1.18+
**Talos Version**: v1.8+
