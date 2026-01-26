#!/usr/bin/env bash
set -euo pipefail

# FluxCD pre-destroy cleanup
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file

echo "=== FluxCD Pre-Destroy Cleanup ==="

# Check if cluster is accessible
if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1; then
  echo "Cluster not accessible, skipping FluxCD cleanup"
  exit 0
fi

# Suspend all reconciliations first
echo "Suspending FluxCD reconciliation..."
if command -v flux &>/dev/null; then
  flux suspend kustomization --all --kubeconfig="$KUBECONFIG" 2>/dev/null || true
  flux suspend source git --all --kubeconfig="$KUBECONFIG" 2>/dev/null || true
fi

# Delete FluxCD-managed resources
echo "Deleting FluxCD resources..."
kubectl --kubeconfig="$KUBECONFIG" delete kustomization --all -A --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete helmrelease --all -A --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete gitrepository --all -A --ignore-not-found 2>/dev/null || true

# Uninstall FluxCD
echo "Uninstalling FluxCD..."
if command -v flux &>/dev/null; then
  flux uninstall --kubeconfig="$KUBECONFIG" --silent 2>/dev/null || true
fi

# Clean up flux-system namespace finalizers
echo "Removing flux-system namespace finalizers..."
kubectl --kubeconfig="$KUBECONFIG" patch namespace flux-system \
  -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

# Clean up FluxCD-managed app namespaces (tools, misc)
echo "Cleaning up FluxCD-managed app namespaces..."
for ns in tools misc; do
  if kubectl --kubeconfig="$KUBECONFIG" get namespace "$ns" &>/dev/null 2>&1; then
    echo "  - Deleting resources in namespace: $ns"
    kubectl --kubeconfig="$KUBECONFIG" delete deployments,services,pvc,configmaps,secrets \
      --all -n "$ns" --ignore-not-found 2>/dev/null || true
    echo "  - Removing finalizers from namespace: $ns"
    kubectl --kubeconfig="$KUBECONFIG" patch namespace "$ns" \
      -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  fi
done

echo "=== FluxCD Pre-Destroy Complete ==="
