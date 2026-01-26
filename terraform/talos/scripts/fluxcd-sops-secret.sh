#!/usr/bin/env bash
set -euo pipefail

# Create SOPS Age secret for FluxCD
#
# Required environment variables:
#   KUBECONFIG        - Path to kubeconfig file
#   SOPS_AGE_KEY_FILE - Path to SOPS Age key file

echo "Creating SOPS Age secret for FluxCD..."

# Expand tilde in path (shell expansion doesn't work directly)
SOPS_KEY_FILE="$SOPS_AGE_KEY_FILE"
if [ ! -f "$SOPS_KEY_FILE" ]; then
  echo "ERROR: SOPS Age key file not found: $SOPS_KEY_FILE"
  exit 1
fi

# Check if secret already exists
if kubectl --kubeconfig="$KUBECONFIG" get secret sops-age -n flux-system &>/dev/null; then
  echo "sops-age secret already exists, skipping"
  exit 0
fi

# Create the secret
kubectl --kubeconfig="$KUBECONFIG" create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey="$SOPS_KEY_FILE"

echo "SOPS Age secret created successfully"
