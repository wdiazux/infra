#!/usr/bin/env bash
set -euo pipefail

# Zitadel pre-destroy cleanup
#
# Required environment variables:
#   KUBECONFIG - Path to kubeconfig file
#   NAMESPACE  - Auth namespace (default: auth)

echo "=== Zitadel Pre-Destroy Cleanup ==="

NAMESPACE="${NAMESPACE:-auth}"

# Check if cluster is accessible
if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1; then
  echo "Cluster not accessible, skipping Zitadel cleanup"
  exit 0
fi

# Check if namespace exists
if ! kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  echo "Auth namespace does not exist, skipping"
  exit 0
fi

# Delete OIDC setup CronJob and Jobs
echo "Deleting Zitadel OIDC setup jobs..."
kubectl --kubeconfig="$KUBECONFIG" delete cronjob zitadel-oidc-sync \
  -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete job \
  -n "$NAMESPACE" -l app.kubernetes.io/name=zitadel-oidc-sync --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete job zitadel-oidc-setup-initial \
  -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

# Remove finalizers from Zitadel CRDs
echo "Removing Zitadel CRD finalizers..."
for crd in $(kubectl --kubeconfig="$KUBECONFIG" get crd -o name 2>/dev/null | grep zitadel || true); do
  kubectl --kubeconfig="$KUBECONFIG" patch "$crd" \
    -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done

# Remove finalizers from auth namespace
echo "Removing auth namespace finalizers..."
kubectl --kubeconfig="$KUBECONFIG" patch namespace "$NAMESPACE" \
  -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

# Also clean up OIDC secrets in target namespaces
echo "Cleaning up OIDC secrets..."
kubectl --kubeconfig="$KUBECONFIG" delete secret grafana-oidc-secrets -n monitoring --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete secret forgejo-oidc-secrets -n forgejo --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete secret immich-oidc-secrets -n media --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete secret open-webui-oidc-secrets -n ai --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete secret paperless-oidc-secrets -n management --ignore-not-found 2>/dev/null || true
kubectl --kubeconfig="$KUBECONFIG" delete secret oauth2-proxy-oidc-secrets -n auth --ignore-not-found 2>/dev/null || true

echo "=== Zitadel Pre-Destroy Complete ==="
