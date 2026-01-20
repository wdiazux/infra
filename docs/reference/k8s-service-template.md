# Kubernetes Service Template

Reference structure for Kubernetes services based on the Grafana deployment pattern.

## Directory Structure

```
kubernetes/apps/base/<namespace>/<service>/
├── kustomization.yaml      # Required: lists all resources
├── deployment.yaml         # or statefulset.yaml for stateful apps
├── service.yaml            # Service exposure
├── pvc.yaml                # If persistent storage needed
├── secret.enc.yaml         # If secrets needed (SOPS encrypted)
├── configmap.yaml          # If configuration needed
└── rbac.yaml               # If RBAC needed
```

## Required: kustomization.yaml

Every service MUST have a kustomization.yaml with header comment:

```yaml
# Service Name Kustomization
#
# Brief description of what the service does.
# https://link-to-official-docs
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - pvc.yaml          # Storage first
  - configmap.yaml    # Config before deployment
  - secret.enc.yaml   # Secrets before deployment
  - deployment.yaml   # Workload
  - service.yaml      # Exposure
```

## Required: Labels

All workloads MUST include these labels:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <service-name>
    app.kubernetes.io/component: <server|database|cache|worker|ui>
    app.kubernetes.io/part-of: <namespace>
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
        app.kubernetes.io/component: <server|database|cache|worker|ui>
        app.kubernetes.io/part-of: <namespace>
```

## Required: Deployment Elements

### Security Context (when mounting volumes)

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: <GID>
        fsGroupChangePolicy: "OnRootMismatch"
```

### Resource Requests and Limits

```yaml
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    memory: 512Mi
```

Note: CPU limits are optional (can cause throttling).

### Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30
readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
```

For slow-starting apps, add startupProbe:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: http
  failureThreshold: 30
  periodSeconds: 10
```

### Named Ports

```yaml
ports:
  - name: http
    containerPort: 8080
    protocol: TCP
```

### Timezone

```yaml
env:
  - name: TZ
    value: "America/El_Salvador"
```

## Example: Complete Deployment

```yaml
# Service Name Deployment
#
# Brief description.
# https://docs-url
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
  namespace: my-namespace
  labels:
    app.kubernetes.io/name: my-service
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: my-namespace
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: my-service
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-service
        app.kubernetes.io/component: server
        app.kubernetes.io/part-of: my-namespace
    spec:
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: my-service
          image: myregistry/my-service:v1.2.3
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          env:
            - name: TZ
              value: "America/El_Salvador"
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              memory: 512Mi
          volumeMounts:
            - name: data
              mountPath: /data
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: my-service-data
```

## Warnings (Review Flags)

The review-kubernetes skill flags these as warnings:

| Issue | Severity |
|-------|----------|
| Missing `app.kubernetes.io/name` label | Warning |
| Missing `app.kubernetes.io/component` label | Warning |
| Missing `app.kubernetes.io/part-of` label | Warning |
| Missing resource requests | Warning |
| Missing resource limits (memory) | Warning |
| Missing livenessProbe | Warning |
| Missing readinessProbe | Warning |
| Using `:latest` image tag | Warning |
| Missing kustomization.yaml header comment | Info |
| Missing TZ environment variable | Info |

---
**Last Updated**: 2026-01-20
