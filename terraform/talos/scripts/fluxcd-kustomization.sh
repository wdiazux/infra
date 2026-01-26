#!/usr/bin/env bash
set -euo pipefail

# Create FluxCD Kustomization
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file
#   FLUXCD_PATH - Path within git repository to sync

echo "=== Creating FluxCD Kustomization ==="
echo "Path: $FLUXCD_PATH"

# Create Kustomization to sync from path
kubectl --kubeconfig="$KUBECONFIG" apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m
  path: ./${FLUXCD_PATH}
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
  timeout: 3m
EOF

echo "=== FluxCD Kustomization Created ==="
