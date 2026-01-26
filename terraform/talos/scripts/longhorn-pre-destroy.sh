#!/usr/bin/env bash
set -euo pipefail

# Longhorn pre-destroy cleanup
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file
#   NAMESPACE  - Longhorn namespace (default: longhorn-system)

echo "=== Longhorn Pre-Destroy Cleanup ==="

NAMESPACE="${NAMESPACE:-longhorn-system}"

# Check if cluster is accessible
if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1; then
  echo "Cluster not accessible, skipping Longhorn cleanup"
  exit 0
fi

# Check if Longhorn namespace exists
if ! kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  echo "Longhorn namespace does not exist, skipping"
  exit 0
fi

# Set deleting-confirmation-flag (CRITICAL for Longhorn uninstall)
echo "Setting Longhorn deleting-confirmation-flag..."
kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" \
  patch settings.longhorn.io deleting-confirmation-flag \
  --type=merge -p '{"value": "true"}' 2>/dev/null || true

# Delete webhook configurations (can block namespace deletion)
echo "Deleting Longhorn webhook configurations..."
kubectl --kubeconfig="$KUBECONFIG" delete validatingwebhookconfiguration \
  longhorn-webhook-validator --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete mutatingwebhookconfiguration \
  longhorn-webhook-mutator --ignore-not-found 2>/dev/null || true

# Scale down Longhorn to speed up deletion
echo "Scaling down Longhorn deployments..."
kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" \
  scale deployment --all --replicas=0 2>/dev/null || true

# Delete any failed uninstall jobs (from previous attempts)
echo "Cleaning up failed uninstall jobs..."
kubectl --kubeconfig="$KUBECONFIG" delete jobs -n "$NAMESPACE" \
  -l app=longhorn-uninstall --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete job longhorn-uninstall \
  -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

# Remove finalizers from Longhorn CRDs if they exist
echo "Removing Longhorn CRD finalizers..."
for crd in $(kubectl --kubeconfig="$KUBECONFIG" get crd -o name 2>/dev/null | grep longhorn || true); do
  kubectl --kubeconfig="$KUBECONFIG" patch "$crd" \
    -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done

# Remove finalizers from namespace
echo "Removing namespace finalizers..."
kubectl --kubeconfig="$KUBECONFIG" patch namespace "$NAMESPACE" \
  -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

echo "=== Longhorn Pre-Destroy Complete ==="
