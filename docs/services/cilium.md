# Cilium CNI

eBPF-based networking, Gateway API, L2 LoadBalancer, and network observability.

---

## Overview

Cilium is deployed in **two stages**:

1. **Bootstrap** (Terraform inline manifest): Embedded in Talos machine config via `terraform/talos/cilium-inline.tf`. Applied during `terraform apply` to make nodes Ready immediately.
2. **Ongoing** (FluxCD HelmRelease): `kubernetes/infrastructure/controllers/cilium.yaml` takes over management after bootstrap. FluxCD reconciles any drift.

Both configurations must stay synchronized. The Terraform inline is the initial config; FluxCD is the source of truth for ongoing changes.

**Key Features:**

| Feature | Description |
|---------|-------------|
| eBPF-based | Kernel-level networking for best performance |
| kube-proxy replacement | Eliminates iptables overhead |
| Gateway API | Primary ingress via HTTPRoute/GRPCRoute |
| L2 LoadBalancer | Cilium L2 announcements (no MetalLB) |
| Network Policies | Kubernetes + CiliumNetworkPolicy enforcement |
| Hubble | Network observability and flow visualization |

---

## Gateway API

All web services are accessed via Cilium Gateway API with TLS termination:

- **Gateway IP**: 10.10.2.20 (LoadBalancer via `io.cilium/lb-ipam-ips`)
- **Protocol**: HTTPS only (TLS termination at Gateway)
- **Routes**: HTTPRoute and GRPCRoute resources per service

```bash
# Verify Gateway
kubectl get gateway -A
kubectl get httproute -A
kubectl get grpcroute -A

# Check Cilium Gateway API status
kubectl -n kube-system exec ds/cilium -- cilium status | grep GatewayAPI
```

---

## LoadBalancer IP Pool

```yaml
# Configured automatically via Terraform inline
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: homelab-pool
spec:
  blocks:
    # Services and applications (10.10.2.11-150)
    # Traditional VMs use 10.10.2.151-254
    - start: "10.10.2.11"
      stop: "10.10.2.150"
```

---

## Service URLs

| Service | URL | Access Method |
|---------|-----|---------------|
| Hubble UI | https://hubble.home-infra.net | Gateway API |
| All web UIs | https://*.home-infra.net | Gateway API |

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

# Check Gateway API
kubectl get gateway -A
kubectl get httproute -A
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

Hubble UI is accessed via Gateway API at **https://hubble.home-infra.net**.

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

### Gateway API Routes Not Working

```bash
# Check Gateway status
kubectl get gateway -A -o wide

# Check HTTPRoute status
kubectl get httproute -A -o wide

# Check Cilium envoy logs
kubectl -n kube-system logs -l app.kubernetes.io/name=cilium-envoy --tail=50
```

---

## Configuration Sync

When modifying Cilium configuration, update **both** sources:

| Setting | Terraform (`cilium-inline.tf`) | FluxCD (`cilium.yaml`) |
|---------|-------------------------------|------------------------|
| Purpose | Bootstrap (first boot) | Ongoing management |
| Applied | `terraform apply` | `flux reconcile` |
| Priority | Initial config only | Source of truth |

**Changes should go to FluxCD first**, then sync to Terraform for new cluster bootstraps.

---

## Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Talos Cilium Guide](https://www.talos.dev/v1.12/kubernetes-guides/network/deploying-cilium/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)
- [Cilium L2 Announcements](https://docs.cilium.io/en/stable/network/lb-ipam/)

---

**Last Updated:** 2026-01-27
