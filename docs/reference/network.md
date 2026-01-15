# Network Reference

Network configuration and IP allocations for the homelab infrastructure.

---

## Overview

| Setting | Value |
|---------|-------|
| Network | `10.10.2.0/24` |
| Gateway | `10.10.2.1` |
| DNS | `10.10.2.1`, `8.8.8.8` |
| Domain | `home-infra.net` |

---

## IP Allocation Scheme

| Range | Purpose | Count |
|-------|---------|-------|
| 10.10.2.1-10 | Core Infrastructure | 10 |
| 10.10.2.11-20 | Kubernetes Services (LoadBalancer) | 10 |
| 10.10.2.21-50 | Applications & Services | 30 |
| 10.10.2.51-70 | Traditional VMs | 20 |
| 10.10.2.71-239 | Reserved | 169 |
| 10.10.2.240-254 | Cilium LoadBalancer Pool | 15 |

---

## Core Infrastructure (10.10.2.1-10)

| IP | Hostname | Description | Status |
|----|----------|-------------|--------|
| 10.10.2.1 | gateway | Router/Gateway | Required |
| 10.10.2.2 | proxmox | Proxmox VE Host | Required |
| 10.10.2.5 | nas | NAS (Longhorn backup) | Optional |
| 10.10.2.10 | talos-node | Talos Kubernetes Node | Required |

---

## Kubernetes Services (10.10.2.11-20)

LoadBalancer IPs assigned to Kubernetes services.

| IP | Service | Port | Namespace |
|----|---------|------|-----------|
| 10.10.2.11 | Hubble UI | 80 | kube-system |
| 10.10.2.12 | Longhorn UI | 80 | longhorn-system |
| 10.10.2.13 | Forgejo HTTP | 3000 | forgejo |
| 10.10.2.14 | Forgejo SSH | 22 | forgejo |
| 10.10.2.15 | FluxCD Webhook | 80 | flux-system |
| 10.10.2.16 | Forgejo Proxy | 80 | forgejo |
| 10.10.2.17-20 | Reserved | - | - |

---

## Traditional VMs (10.10.2.51-70)

| IP | Hostname | OS | Status |
|----|----------|----|--------|
| 10.10.2.51 | ubuntu-vm | Ubuntu 24.04 | Planned |
| 10.10.2.52 | debian-vm | Debian 13 | Planned |
| 10.10.2.53 | arch-vm | Arch Linux | Planned |
| 10.10.2.54 | nixos-vm | NixOS 25.11 | Planned |
| 10.10.2.55 | windows-vm | Windows | Planned |

---

## Cilium LoadBalancer Pool (10.10.2.240-254)

Dynamic pool for new Kubernetes LoadBalancer services.

```yaml
# Cilium L2 Announcement configuration
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
spec:
  blocks:
    - cidr: "10.10.2.240/28"
```

---

## Service Access Points

| Service | URL | Auth |
|---------|-----|------|
| Proxmox | https://10.10.2.2:8006 | API Token |
| Kubernetes API | https://10.10.2.10:6443 | kubeconfig |
| Talos API | https://10.10.2.10:50000 | talosconfig |
| Hubble UI | http://10.10.2.11 | None |
| Longhorn UI | http://10.10.2.12 | None |
| Forgejo | http://10.10.2.16 | Username/Password |
| Forgejo SSH | ssh://git@10.10.2.14 | SSH Key |

---

## DNS Records

Configure in your DNS server or `/etc/hosts`:

```
10.10.2.1    gateway.home-infra.net
10.10.2.2    proxmox.home-infra.net pve
10.10.2.5    nas.home-infra.net
10.10.2.10   talos.home-infra.net
10.10.2.11   hubble.home-infra.net
10.10.2.12   longhorn.home-infra.net
10.10.2.16   git.home-infra.net forgejo.home-infra.net
```

---

## Quick Check Commands

```bash
# Check service IPs
kubectl get svc -A | grep LoadBalancer

# Check Cilium IP pool
kubectl get ciliumloadbalancerippool -A

# Test service connectivity
curl -s http://10.10.2.11  # Hubble
curl -s http://10.10.2.12  # Longhorn
curl -s http://10.10.2.16  # Forgejo
```

---

**Last Updated:** 2026-01-15
