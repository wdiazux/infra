# Twitch Channel Points Miner

Automatically watches Twitch streams to collect channel points.

**Source**: https://github.com/rdavydov/Twitch-Channel-Points-Miner-v2

## Files

| File | Purpose |
|------|---------|
| `run.py` | Main configuration (streamers, settings) - edit directly |
| `secret.enc.yaml` | SOPS-encrypted Twitch credentials |
| `deployment.yaml` | Kubernetes deployment |
| `pvc.yaml` | Persistent storage for cookies/logs |

## Operations

### Check Status

```bash
# Pod status
kubectl get pods -n twitch-miner

# Detailed pod info
kubectl describe pod -n twitch-miner -l app.kubernetes.io/name=twitch-miner
```

### View Logs

```bash
# Follow logs (live)
kubectl logs -n twitch-miner -l app.kubernetes.io/name=twitch-miner -f

# Last 100 lines
kubectl logs -n twitch-miner -l app.kubernetes.io/name=twitch-miner --tail=100

# Logs from previous container (after restart)
kubectl logs -n twitch-miner -l app.kubernetes.io/name=twitch-miner --previous
```

### Restart Pod

```bash
# Force restart (delete pod, deployment recreates it)
kubectl delete pod -n twitch-miner -l app.kubernetes.io/name=twitch-miner

# Or rollout restart
kubectl rollout restart deployment/twitch-miner -n twitch-miner
```

### Access Persistent Data

```bash
# List cookies/logs in PVC
kubectl exec -n twitch-miner -it deploy/twitch-miner -- ls -la /usr/src/app/cookies/
kubectl exec -n twitch-miner -it deploy/twitch-miner -- ls -la /usr/src/app/logs/

# Read log file
kubectl exec -n twitch-miner -it deploy/twitch-miner -- cat /usr/src/app/logs/twitch-miner.log
```

## First-Time OAuth Setup

Twitch requires browser authentication on first run:

```bash
# 1. Watch logs for OAuth code
kubectl logs -n twitch-miner -l app.kubernetes.io/name=twitch-miner -f

# 2. Go to https://www.twitch.tv/activate and enter the code

# 3. Cookies are saved to PVC - won't ask again unless cookies expire
```

## Updating Configuration

To update streamers or settings:

1. Edit `run.py` directly
2. Commit and push
3. FluxCD reconciles (up to 10 min) and redeploys

Force immediate update:
```bash
flux reconcile kustomization apps -n flux-system
```

## Updating Credentials

```bash
# Decrypt, edit, re-encrypt in one command
sops kubernetes/apps/base/twitch-miner/secret.enc.yaml
```

## Importing Existing Cookies

If you have cookies from a previous setup:

```bash
# Copy cookies to the PVC
kubectl cp /path/to/cookies/ twitch-miner/<pod-name>:/usr/src/app/cookies/
```

## Resizing Storage

PVCs can only expand, not shrink. To change size:

```bash
# 1. Edit pvc.yaml with new size
#    resources.requests.storage: 500Mi

# 2. Delete pod (releases PVC)
kubectl delete pod -n twitch-miner -l app.kubernetes.io/name=twitch-miner --force --grace-period=0

# 3. Delete PVC
kubectl delete pvc twitch-miner-data -n twitch-miner

# 4. Trigger FluxCD to recreate
flux reconcile kustomization apps -n flux-system

# 5. Verify new size
kubectl get pvc -n twitch-miner
```

**Note**: Longhorn has a minimum size of 1Gi. Requests smaller than this will be rounded up.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Pod stuck in `Pending` | Check PVC: `kubectl get pvc -n twitch-miner` |
| OAuth expired | Delete cookies, restart pod to re-auth |
| Streamer not found | Check username spelling in `run.py` |
| Config not updating | Check FluxCD: `kubectl get kustomization apps -n flux-system` |
