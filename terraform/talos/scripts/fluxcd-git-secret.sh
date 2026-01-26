#!/usr/bin/env bash
set -euo pipefail

# Create FluxCD git credentials secret
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file
#   GIT_OWNER  - Git repository owner/username
#   GIT_TOKEN  - Git access token

echo "=== Creating FluxCD Git Credentials ==="

# Validate git owner
if [ -z "$GIT_OWNER" ]; then
  echo "ERROR: Git owner is empty."
  exit 1
fi

# Validate token
if [ -z "$GIT_TOKEN" ]; then
  echo "ERROR: Git token is empty."
  exit 1
fi

# Delete existing secret if present
kubectl --kubeconfig="$KUBECONFIG" delete secret flux-system \
  -n flux-system --ignore-not-found

# Create git credentials secret
kubectl --kubeconfig="$KUBECONFIG" create secret generic flux-system \
  --namespace=flux-system \
  --from-literal=username="$GIT_OWNER" \
  --from-literal=password="$GIT_TOKEN"

echo "=== FluxCD Git Credentials Created ==="
