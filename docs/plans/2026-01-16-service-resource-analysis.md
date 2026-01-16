# Service Resource Analysis for Homelab

**Date**: 2026-01-16
**Status**: Reference Document
**Purpose**: Document recommended resources for all services based on official documentation

## Hardware Context

| Component | Specification |
|-----------|--------------|
| System | Minisforum MS-A2 |
| CPU | AMD Ryzen AI 9 HX 370 (12 cores) |
| RAM | 96GB |
| GPU | NVIDIA RTX 4000 SFF Ada |
| Storage | 2x Samsung NVMe (ZFS mirror) |
| Talos VM Allocation | 8 cores, 32GB RAM |

---

## Service Inventory

### Core Infrastructure

| Service | Namespace | Purpose |
|---------|-----------|---------|
| Cilium | kube-system | CNI, L2 LoadBalancer, eBPF networking |
| Longhorn | longhorn-system | Distributed block storage |
| NVIDIA Device Plugin | kube-system | GPU resource advertisement |

### GitOps Stack

| Service | Namespace | Purpose |
|---------|-----------|---------|
| Forgejo | forgejo | In-cluster Git server |
| PostgreSQL | forgejo | Forgejo database backend |
| FluxCD | flux-system | GitOps continuous delivery |
| Weave GitOps | flux-system | FluxCD web dashboard |

### Applications

| Service | Namespace | Purpose |
|---------|-----------|---------|
| Twitch Miner | twitch-miner | Automation service |

---

## Resource Recommendations

### Cilium

**Official Documentation**: [Cilium System Requirements](https://docs.cilium.io/en/stable/operations/system_requirements/)

| Component | Current | Official Recommendation | Homelab Optimized |
|-----------|---------|------------------------|-------------------|
| Agent CPU Request | 100m | Scales with pods (~3-7% of 2vCPU) | 100m |
| Agent CPU Limit | 4000m | Not specified (critical component) | 2000m |
| Agent Memory Request | 512Mi | ~438MB average per agent | 512Mi |
| Agent Memory Limit | 4Gi | ~573MB max observed (50k pods) | 1Gi |
| Operator CPU Request | 100m | ~5% during pod creation | 100m |
| Operator CPU Limit | 1000m | Not specified | 500m |
| Operator Memory Request | 128Mi | Stable usage | 128Mi |
| Operator Memory Limit | 1Gi | Not specified | 512Mi |

**Notes**:
- Memory scales ~10.5KiB per pod in cluster
- Single-node homelab unlikely to exceed 500 pods
- Current 4Gi limit is excessive for this scale

---

### Longhorn

**Official Documentation**: [Longhorn Best Practices](https://longhorn.io/docs/1.10.1/best-practices/)

| Component | Current | Official Recommendation | Homelab Optimized |
|-----------|---------|------------------------|-------------------|
| CPU Request | 500m | Reserve 25% CPU for engines | 250m |
| CPU Limit | 1000m | 100m per engine/replica | 1000m |
| Memory Request | 1Gi | ~300MB per worker node | 512Mi |
| Memory Limit | 2Gi | 4GB minimum for storage nodes | 1Gi |
| Storage Reservation | 25% | 25% for system operations | 25% |

**Notes**:
- Single replica mode appropriate for single-node
- NVMe storage provides excellent latency
- Backup target configured to external NAS

---

### PostgreSQL (Bitnami)

**Official Documentation**: [PostgreSQL on Kubernetes](https://www.percona.com/blog/run-postgresql-on-kubernetes-a-practical-guide-with-benchmarks-best-practices/)

| Component | Current | Official Recommendation | Homelab Optimized |
|-----------|---------|------------------------|-------------------|
| CPU Request | 100m | 0.5-1 core minimum | 100m |
| CPU Limit | 500m | 1-2 cores recommended | 500m |
| Memory Request | 256Mi | 800Mi-1Gi for small DB | 256Mi |
| Memory Limit | 512Mi | shared_buffers = 25% of mem | 512Mi |
| Storage | 2Gi | 1-10Gi for small DB | 2Gi |

**Notes**:
- Forgejo is a light database user
- Current allocation is appropriate for homelab
- Consider increasing memory if performance issues arise

---

### Forgejo

**Official Documentation**: [Gitea Documentation](https://docs.gitea.com/)

| Component | Current | Official Recommendation | Homelab Optimized |
|-----------|---------|------------------------|-------------------|
| CPU Request | 100m | 1 core minimum | 100m |
| CPU Limit | 1000m | 2 cores recommended | 500m |
| Memory Request | 256Mi | 256MB minimum | 256Mi |
| Memory Limit | 1Gi | 1GB recommended | 512Mi |
| Storage | 5Gi | 1GB minimum | 5Gi |

**Notes**:
- Significantly lighter than GitLab (4-8GB)
- Can run on Raspberry Pi
- 5Gi storage allows room for repository growth

---

### FluxCD

**Official Documentation**: [FluxCD Vertical Scaling](https://fluxcd.io/flux/installation/configuration/vertical-scaling/)

| Controller | Current | Official Recommendation | Homelab Optimized |
|------------|---------|------------------------|-------------------|
| source-controller | Default | 30MB baseline | Default |
| kustomize-controller | Default | 30MB baseline | Default |
| helm-controller | Default | 30MB baseline | Default |
| notification-controller | Default | 30MB baseline | Default |
| image-reflector-controller | Default | 30MB baseline | Default |
| image-automation-controller | Default | 30MB baseline | Default |

**Notes**:
- Default resources (~30MB per controller) are optimal for homelab
- Large clusters (200k+ resources) may need 2Gi per controller
- Current setup is well within baseline requirements

---

### Weave GitOps

**Official Documentation**: [Weave GitOps Helm Values](https://github.com/weaveworks/weave-gitops/blob/main/charts/gitops-server/values.yaml)

| Component | Current | Official Recommendation | Homelab Optimized |
|-----------|---------|------------------------|-------------------|
| CPU Request | 50m | 100m suggested | 50m |
| CPU Limit | 500m | 100m suggested | 200m |
| Memory Request | 64Mi | Not specified | 64Mi |
| Memory Limit | 256Mi | 128Mi suggested | 128Mi |

**Notes**:
- Lightweight dashboard application
- Chart intentionally omits defaults for flexibility
- Current allocation is generous

---

## Total Resource Budget

### Current Configuration (Requests)

| Service | CPU | Memory |
|---------|-----|--------|
| Cilium Agent | 100m | 512Mi |
| Cilium Operator | 100m | 128Mi |
| Longhorn | 500m | 1Gi |
| PostgreSQL | 100m | 256Mi |
| Forgejo | 100m | 256Mi |
| FluxCD (6 controllers) | ~300m | ~180Mi |
| Weave GitOps | 50m | 64Mi |
| NVIDIA Plugin | - | - |
| Apps | 100m | 192Mi |
| **Total Requests** | **~1.35 cores** | **~2.6Gi** |

### Current Configuration (Limits)

| Service | CPU | Memory |
|---------|-----|--------|
| Cilium Agent | 4000m | 4Gi |
| Cilium Operator | 1000m | 1Gi |
| Longhorn | 1000m | 2Gi |
| PostgreSQL | 500m | 512Mi |
| Forgejo | 1000m | 1Gi |
| FluxCD (6 controllers) | ~600m | ~360Mi |
| Weave GitOps | 500m | 256Mi |
| Apps | 700m | 640Mi |
| **Total Limits** | **~9.3 cores** | **~9.8Gi** |

### Available Resources

| Resource | Talos VM | Used (Requests) | Used (Limits) | Headroom |
|----------|----------|-----------------|---------------|----------|
| CPU | 8 cores | 1.35 cores (17%) | 9.3 cores (116%) | Burstable |
| Memory | 32Gi | 2.6Gi (8%) | 9.8Gi (31%) | 22Gi free |

---

## Recommendations

### Immediate Optimizations (Optional)

1. **Reduce Cilium Agent memory limit**: 4Gi -> 1Gi (saves 3Gi burst capacity)
2. **Reduce Cilium Operator memory limit**: 1Gi -> 512Mi
3. **Reduce Weave GitOps CPU limit**: 500m -> 200m
4. **Reduce Forgejo CPU limit**: 1000m -> 500m

### Storage Allocations (Current - Appropriate)

| PVC | Size | Assessment |
|-----|------|------------|
| PostgreSQL | 2Gi | Appropriate for Forgejo |
| Forgejo | 5Gi | Room for repository growth |
| Twitch Miner | 250Mi | Minimal, appropriate |

### Future Considerations

- **Monitoring stack** (Prometheus/Loki): Add 2-4Gi memory, 500m-1000m CPU
- **Additional databases**: Each PostgreSQL instance ~512Mi-1Gi
- **HA mode** (3 nodes): Longhorn replicas increase storage 3x

---

## Conclusion

The current resource configuration is **well-suited for a single-node homelab**:

- Total requests use only ~17% CPU and ~8% memory
- Significant headroom for additional workloads
- Some limits (Cilium 4Gi) are conservative but not problematic
- Storage allocations are appropriate

No immediate changes required. The configuration provides a good balance between resource efficiency and operational safety margins.

---

## References

- [Cilium System Requirements](https://docs.cilium.io/en/stable/operations/system_requirements/)
- [Cilium Scalability Report](https://docs.cilium.io/en/stable/operations/performance/scalability/report/)
- [Longhorn Best Practices](https://longhorn.io/docs/1.10.1/best-practices/)
- [Longhorn Resource Investigation](https://github.com/longhorn/longhorn/issues/1691)
- [FluxCD Vertical Scaling](https://fluxcd.io/flux/installation/configuration/vertical-scaling/)
- [Gitea Documentation](https://docs.gitea.com/)
- [PostgreSQL on Kubernetes Guide](https://www.percona.com/blog/run-postgresql-on-kubernetes-a-practical-guide-with-benchmarks-best-practices/)
- [Weave GitOps Helm Chart](https://github.com/weaveworks/weave-gitops/blob/main/charts/gitops-server/values.yaml)

---

**Last Updated**: 2026-01-16
