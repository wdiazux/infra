# Misc Namespace

Miscellaneous applications.

## Services

| Service | Description |
|---------|-------------|
| Twitch Miner | Twitch channel points collector |

## Deployment

Deployed via FluxCD from `kubernetes/apps/production/kustomization.yaml`.

```bash
# Check status
kubectl get pods -n misc
kubectl get svc -n misc
```
