# Tools Namespace

Developer utilities and productivity tools.

## Services

| Service | IP | Port | Description |
|---------|-----|------|-------------|
| IT-Tools | 10.10.2.32 | 80 | Developer toolbox (converters, generators, etc.) |

## Access

| Service | URL |
|---------|-----|
| IT-Tools | http://10.10.2.32 |

## Deployment

Deployed via FluxCD from `kubernetes/apps/production/kustomization.yaml`.

```bash
# Check status
kubectl get pods -n tools
kubectl get svc -n tools
```
