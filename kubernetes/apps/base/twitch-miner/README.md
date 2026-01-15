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

## First-Time OAuth Setup

Twitch requires browser authentication on first run. After deployment:

```bash
# 1. Check pod logs for OAuth URL
kubectl logs -n twitch-miner -l app.kubernetes.io/name=twitch-miner -f

# 2. Open the URL in browser and authenticate

# 3. After auth, cookies are saved to PVC - subsequent restarts use cached auth
```

## Updating Configuration

To update streamers or settings:

1. Edit `run.py` directly
2. Commit and push
3. FluxCD will reconcile and redeploy

## Updating Credentials

```bash
# Decrypt, edit, re-encrypt
sops kubernetes/apps/base/twitch-miner/secret.enc.yaml
```

## Importing Existing Cookies

If you have existing cookies from a previous setup:

```bash
# Copy cookies to the PVC (after pod is running)
kubectl cp /path/to/cookies/ twitch-miner/twitch-miner-<pod-id>:/usr/src/app/cookies/
```
