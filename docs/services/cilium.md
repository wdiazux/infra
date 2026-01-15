# Cilium CNI

eBPF-based networking, L2 LoadBalancer, and network observability.

---

## Overview

Cilium is installed **automatically** via Talos inlineManifest during `terraform apply`. Manual installation is not required.

**What's Automatic:**
- Cilium CNI deployment
- L2 LoadBalancer IP pool (10.10.2.240/28)
- L2 announcement policy
- Hubble UI and Relay

**Configuration:** `terraform/talos/cilium-inline.tf`

---

## Key Features

| Feature | Description |
|---------|-------------|
| eBPF-based | Kernel-level networking for best performance |
| kube-proxy replacement | Eliminates iptables overhead |
| L2 LoadBalancer | No MetalLB needed |
| Network Policies | Built-in security enforcement |
| Hubble | Network observability and flow visualization |

---

## LoadBalancer IP Pool

```yaml
# Configured automatically
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: important-services
spec:
  blocks:
    - start: "10.10.2.11"
      stop: "10.10.2.20"
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: default-pool
spec:
  blocks:
    - cidr: "10.10.2.240/28"
```

---

## Service URLs

| Service | URL |
|---------|-----|
| Hubble UI | http://10.10.2.11 |

---

## Verification

```bash
# Check Cilium status
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium agent
kubectl -n kube-system exec ds/cilium -- cilium status

# View IP pools
kubectl get ciliumloadbalancerippool

# View L2 announcements
kubectl get ciliuml2announcementpolicy
```

---

## Common Commands

```bash
# Using Cilium CLI
cilium status              # Overall status
cilium connectivity test   # Test networking
cilium hubble observe      # View network flows

# Using kubectl
kubectl -n kube-system exec ds/cilium -- cilium status
kubectl get ciliumnetworkpolicies -A
```

---

## Access Hubble UI

The Hubble UI is exposed via LoadBalancer at **http://10.10.2.11**.

Alternative access via port-forward:
```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Access: http://localhost:12000
```

---

## Troubleshooting

### Nodes Stay NotReady

```bash
# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium logs
kubectl logs -n kube-system ds/cilium --tail=100

# Restart Cilium
kubectl rollout restart ds/cilium -n kube-system
```

### LoadBalancer Services Pending

```bash
# Verify IP pools have available IPs
kubectl get ciliumloadbalancerippool -o yaml

# Check L2 announcement policy
kubectl get ciliuml2announcementpolicy -o yaml

# Check Cilium detected the interface
kubectl -n kube-system exec ds/cilium -- cilium status | grep Device
```

### Pods Can't Reach External Internet

```bash
# Verify masquerading
kubectl -n kube-system exec ds/cilium -- cilium status | grep Masquerading

# Check default route
talosctl -n 10.10.2.10 get routes
```

---

## Advanced Configuration

### Network Policies

Cilium automatically enforces Kubernetes NetworkPolicies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 80
```

### WireGuard Encryption

Enable pod-to-pod encryption:

```bash
# Requires Talos upgrade
# Add to Cilium config:
# encryption.enabled: true
# encryption.type: wireguard
```

---

## Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Talos Cilium Guide](https://www.talos.dev/v1.12/kubernetes-guides/network/deploying-cilium/)
- [Cilium L2 Announcements](https://docs.cilium.io/en/stable/network/lb-ipam/)

---

**Last Updated:** 2026-01-15
