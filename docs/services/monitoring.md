# Monitoring Stack

VictoriaMetrics and Grafana observability stack for Kubernetes monitoring.

---

## Overview

| Component | Purpose | IP Address |
|-----------|---------|------------|
| VictoriaMetrics | Time-series database | http://10.10.2.24 |
| VMAgent | Metrics collector | Internal only |
| Grafana | Visualization | http://10.10.2.23 |

**Namespace:** `monitoring`

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────┐    scrape     ┌─────────────────────────┐ │
│  │   VMAgent    │──────────────►│   Kubernetes Targets    │ │
│  └──────┬───────┘               │ - api-server            │ │
│         │                       │ - nodes (kubelet)       │ │
│         │ remote write          │ - cadvisor (containers) │ │
│         ▼                       │ - service endpoints     │ │
│  ┌──────────────┐               │ - pods with annotations │ │
│  │VictoriaMetrics│              └─────────────────────────┘ │
│  │  (TSDB)      │                                           │
│  └──────┬───────┘                                           │
│         │ query                                              │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   Grafana    │◄───── User Access (10.10.2.23)            │
│  │ (Dashboards) │                                           │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### VictoriaMetrics

Prometheus-compatible time-series database with better performance and lower resource usage.

**Configuration:**
- **Image:** `victoriametrics/victoria-metrics:v1.134.0`
- **Retention:** 90 days
- **Storage:** 10Gi Longhorn PVC
- **Port:** 8428

**Why VictoriaMetrics over Prometheus:**
- Lower memory usage (important for homelab)
- Single binary, simpler deployment
- Full Prometheus compatibility
- Built-in downsampling and retention

### VMAgent

Lightweight metrics collector that scrapes Prometheus targets and writes to VictoriaMetrics.

**Configuration:**
- **Image:** `victoriametrics/vmagent:v1.134.0`
- **Scrape Interval:** 30s
- **RBAC:** ClusterRole for Kubernetes service discovery

**Scrape Targets:**
| Target | Description |
|--------|-------------|
| kubernetes-apiservers | API server metrics |
| kubernetes-nodes | Kubelet metrics |
| kubernetes-cadvisor | Container metrics |
| kubernetes-service-endpoints | Services with `prometheus.io/scrape: "true"` |
| kubernetes-pods | Pods with `prometheus.io/scrape: "true"` |
| kube-state-metrics | Kubernetes state metrics |
| node-exporter | Node-level system metrics |

**Duplicate Target Prevention:**

VMAgent uses `keep_if_equal` relabeling to prevent duplicate scrape targets when services have multiple ports or pods have multiple containers:

```yaml
# For service endpoints - only scrape ports matching annotation
- if: '{__meta_kubernetes_service_annotation_prometheus_io_port=~".+"}'
  source_labels: [__meta_kubernetes_service_annotation_prometheus_io_port, __meta_kubernetes_endpoint_port_number]
  action: keep_if_equal

# For pods - only scrape container ports matching annotation
- if: '{__meta_kubernetes_pod_annotation_prometheus_io_port=~".+"}'
  source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_container_port_number]
  action: keep_if_equal
```

### Grafana

Visualization platform with pre-configured dashboards.

**Configuration:**
- **Image:** `grafana/grafana:12.3.1`
- **Storage:** 2Gi Longhorn PVC
- **Default Credentials:** admin / admin

**Pre-configured:**
- VictoriaMetrics datasource (auto-provisioned)
- Kubernetes Cluster Overview dashboard
- Node Overview dashboard

---

## Access

| Service | URL | Authentication |
|---------|-----|----------------|
| Grafana | http://10.10.2.23 | admin / admin |
| VictoriaMetrics | http://10.10.2.24 | None |

**Change Grafana password on first login.**

---

## Adding Custom Scrape Targets

### Service with Metrics Endpoint

Add annotations to your Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  ports:
    - port: 8080
```

### Pod with Metrics Endpoint

Add annotations to your Pod template:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
```

---

## Adding Grafana Dashboards

### Via ConfigMap

1. Create a ConfigMap with dashboard JSON:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |
    {
      "title": "My Dashboard",
      ...
    }
```

2. Add to `kubernetes/apps/base/monitoring/grafana/kustomization.yaml`

### Via Grafana UI

1. Access http://10.10.2.23
2. Create dashboard in UI
3. Dashboard persists in Longhorn PVC

---

## Querying Metrics

### PromQL in Grafana

VictoriaMetrics supports full PromQL:

```promql
# CPU usage by container
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by pod
container_memory_working_set_bytes{container!=""}

# Network traffic
rate(container_network_receive_bytes_total[5m])
```

### Direct VictoriaMetrics API

```bash
# Query metrics
curl 'http://10.10.2.24/api/v1/query?query=up'

# Query range
curl 'http://10.10.2.24/api/v1/query_range?query=up&start=2026-01-17T00:00:00Z&end=2026-01-17T12:00:00Z&step=1h'

# List all metrics
curl 'http://10.10.2.24/api/v1/label/__name__/values'
```

---

## Storage

| Component | PVC | Size | StorageClass |
|-----------|-----|------|--------------|
| VictoriaMetrics | victoriametrics-data | 10Gi | longhorn |
| Grafana | grafana-data | 2Gi | longhorn |

---

## Troubleshooting

### VMAgent Not Scraping Targets

```bash
# Check VMAgent logs
kubectl logs -n monitoring -l app=vmagent

# Verify RBAC permissions
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:vmagent -A

# Check scrape config
kubectl get configmap -n monitoring vmagent-config -o yaml
```

### Grafana Datasource Error

```bash
# Verify VictoriaMetrics is running
kubectl get pods -n monitoring -l app=victoriametrics

# Test connectivity from Grafana pod
kubectl exec -n monitoring -it deploy/grafana -- wget -qO- http://victoriametrics:8428/api/v1/query?query=up
```

### High Memory Usage

VictoriaMetrics memory depends on:
- Number of active time series
- Ingestion rate
- Query complexity

```bash
# Check current memory
kubectl top pods -n monitoring

# Reduce retention if needed (in deployment args)
--retentionPeriod=30d
```

### Missing Metrics

```bash
# Verify target is being scraped
curl 'http://10.10.2.24/api/v1/targets'

# Check for scrape errors
kubectl logs -n monitoring -l app=vmagent | grep -i error
```

---

## Maintenance

### Backup Grafana Dashboards

```bash
# Export dashboards via API
curl -H "Authorization: Bearer <api-key>" \
  http://10.10.2.23/api/dashboards/uid/<dashboard-uid> \
  > dashboard-backup.json
```

### Data Retention

VictoriaMetrics automatically deletes data older than retention period (90 days default). No manual cleanup needed.

### Upgrade Components

Update image tags in deployment manifests:
- `kubernetes/apps/base/monitoring/victoriametrics/deployment.yaml`
- `kubernetes/apps/base/monitoring/vmagent/deployment.yaml`
- `kubernetes/apps/base/monitoring/grafana/deployment.yaml`

---

## File Structure

```
kubernetes/apps/base/monitoring/
├── kustomization.yaml
├── victoriametrics/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── vmagent/
│   ├── kustomization.yaml
│   ├── rbac.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── grafana/
    ├── kustomization.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── pvc.yaml
    ├── datasources.yaml
    ├── dashboard-provider.yaml
    └── dashboards.yaml
```

---

## Resources

- [VictoriaMetrics Documentation](https://docs.victoriametrics.com/)
- [VMAgent Documentation](https://docs.victoriametrics.com/vmagent/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)

---

**Last Updated:** 2026-01-21
