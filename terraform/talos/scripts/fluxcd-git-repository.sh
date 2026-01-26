#!/usr/bin/env bash
set -euo pipefail

# Create FluxCD GitRepository source
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file
#   GIT_URL    - Git repository URL
#   GIT_BRANCH - Git branch to track

echo "=== Creating FluxCD GitRepository Source ==="
echo "URL: $GIT_URL"
echo "Branch: $GIT_BRANCH"

# Create GitRepository pointing to HTTP Forgejo
kubectl --kubeconfig="$KUBECONFIG" apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 5m
  url: ${GIT_URL}
  ref:
    branch: ${GIT_BRANCH}
  secretRef:
    name: flux-system
EOF

# Wait for GitRepository to be ready
echo "Waiting for GitRepository to sync..."
for i in $(seq 1 30); do
  STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get gitrepository flux-system \
    -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [ "$STATUS" = "True" ]; then
    echo "GitRepository is ready!"
    break
  fi
  echo "Waiting for GitRepository... ($i/30) Status: $STATUS"
  sleep 10
done

echo "=== FluxCD GitRepository Created ==="
