#!/usr/bin/env bash
set -euo pipefail

# Install FluxCD components
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file

echo "=== Installing FluxCD Components ==="

# Validate flux CLI
if ! command -v flux &> /dev/null; then
  echo "ERROR: flux CLI not found. Install via nix-shell."
  exit 1
fi

# Pre-flight check
flux check --pre --kubeconfig="$KUBECONFIG" || true

# Install FluxCD components
flux install --kubeconfig="$KUBECONFIG" \
  --components-extra=image-reflector-controller,image-automation-controller

# Wait for controllers to be ready
echo "Waiting for FluxCD controllers..."
kubectl --kubeconfig="$KUBECONFIG" wait --for=condition=available \
  --timeout=300s deployment/source-controller -n flux-system
kubectl --kubeconfig="$KUBECONFIG" wait --for=condition=available \
  --timeout=300s deployment/kustomize-controller -n flux-system

echo "=== FluxCD Components Installed ==="
