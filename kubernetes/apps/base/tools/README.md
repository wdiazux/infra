# Tools Namespace

Developer utilities and productivity tools.

## Services

| Service | IP | Port | Description |
|---------|-----|------|-------------|
| IT-Tools | 10.10.2.32 | 80 | Developer toolbox (converters, generators, etc.) |
| LibreSpeed | 10.10.2.33 | 80 | Network speed test |

## Access

| Service | URL |
|---------|-----|
| IT-Tools | http://10.10.2.32 |
| LibreSpeed | http://10.10.2.33 |

## Deployment

Deployed via FluxCD from `kubernetes/apps/production/kustomization.yaml`.

```bash
# Check status
kubectl get pods -n tools
kubectl get svc -n tools
```
