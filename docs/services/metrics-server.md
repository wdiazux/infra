# Metrics Server

Kubernetes resource metrics aggregator for `kubectl top` and HPA.

---

## Overview

Metrics Server collects resource metrics (CPU and memory) from kubelets and exposes them through the Kubernetes Metrics API. This enables `kubectl top`, k9s resource displays, and Horizontal Pod Autoscaler (HPA).

| Property | Value |
|----------|-------|
| Namespace | `kube-system` |
| Chart | `metrics-server/metrics-server` |
| Version | `3.13.0` |

**Key Features:**

| Feature | Description |
|---------|-------------|
| Resource Metrics | CPU and memory usage per pod/node |
| Metrics API | Kubernetes `metrics.k8s.io` API |
| HPA Support | Enables horizontal pod autoscaling |
| kubectl top | Powers `kubectl top pods/nodes` |

---

## Talos Linux Requirement

Talos Linux uses self-signed certificates for kubelet. Metrics Server requires the `--kubelet-insecure-tls` flag to connect:

```yaml
args:
  - --kubelet-insecure-tls
```

This is safe because:
- Communication stays within the cluster
- Kubelet authentication still uses service account tokens
- Only certificate validation is skipped (not authentication)

---

## Metrics Server vs VictoriaMetrics

| Component | Purpose | Data Retention |
|-----------|---------|----------------|
| **Metrics Server** | Real-time resource metrics for Kubernetes API | None (current values only) |
| **VictoriaMetrics** | Historical metrics storage and alerting | Configurable (days/weeks) |

Both are needed:
- Metrics Server: `kubectl top`, HPA, k9s real-time display
- VictoriaMetrics: Grafana dashboards, historical analysis, alerting

---

## Common Operations

### View Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (all namespaces)
kubectl top pods -A

# Pod resource usage (specific namespace)
kubectl top pods -n ai

# Sort by CPU
kubectl top pods -A --sort-by=cpu

# Sort by memory
kubectl top pods -A --sort-by=memory
```

### Check Metrics API

```bash
# Verify Metrics API is available
kubectl get apiservices | grep metrics

# Query Metrics API directly
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

---

## Verification

```bash
# Check Metrics Server pod
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Check deployment
kubectl get deployment -n kube-system metrics-server

# Verify API service
kubectl get apiservices v1beta1.metrics.k8s.io

# Test metrics collection
kubectl top nodes
kubectl top pods -n kube-system
```

---

## Troubleshooting

### kubectl top Returns "Metrics not available"

```bash
# Check Metrics Server logs
kubectl logs -n kube-system deployment/metrics-server --tail=100

# Verify API service status
kubectl get apiservices v1beta1.metrics.k8s.io -o yaml

# Check if --kubelet-insecure-tls is set (required for Talos)
kubectl get deployment -n kube-system metrics-server -o yaml | grep kubelet-insecure-tls
```

### Metrics Server CrashLoopBackOff

```bash
# Check pod events
kubectl describe pod -n kube-system -l app.kubernetes.io/name=metrics-server

# Common causes:
# 1. Missing --kubelet-insecure-tls for Talos
# 2. Network policy blocking kubelet access
# 3. Insufficient resources
```

### Partial Metrics (Some Pods Missing)

```bash
# Check kubelet connectivity
kubectl get nodes -o wide

# Verify Metrics Server can reach kubelet
kubectl exec -n kube-system deployment/metrics-server -- \
  wget -qO- --no-check-certificate https://<node-ip>:10250/metrics/resource
```

---

## Resources

| Resource | Requests | Limits |
|----------|----------|--------|
| CPU | 50m | 100m |
| Memory | 64Mi | 128Mi |

---

## HPA Example

With Metrics Server running, you can use Horizontal Pod Autoscaler:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

---

## Documentation

- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes Metrics API](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

---

**Last Updated:** 2026-01-28
