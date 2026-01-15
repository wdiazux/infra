#!/usr/bin/env bash
# Talos Cluster Destroy Script
#
# Properly destroys the Talos cluster by handling resources that fail
# during normal terraform destroy (Longhorn, namespaces with finalizers, etc.)
#
# Usage: ./destroy.sh
#
# Why this is needed:
# - talos_machine_secrets has lifecycle.prevent_destroy (safety feature)
# - Longhorn uninstall job often fails (BackoffLimitExceeded)
# - Kubernetes namespaces get stuck due to finalizers
#
# This script removes problematic resources from state and forces destroy.

set -e

echo "=== Talos Cluster Destroy ==="
echo "This will destroy the entire Talos cluster and all resources."
echo ""

# Confirm
read -p "Are you sure you want to destroy the cluster? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Removing protected resources from state..."

# Remove talos_machine_secrets (has prevent_destroy)
terraform state rm talos_machine_secrets.cluster 2>/dev/null || true

echo ""
echo "Step 2: Attempting normal destroy..."

# Try normal destroy first
if terraform destroy -auto-approve 2>&1; then
    echo ""
    echo "=== Destroy Complete ==="
    exit 0
fi

echo ""
echo "Step 3: Handling failed resources..."

# Remove Longhorn helm release (uninstall job often fails)
terraform state rm 'helm_release.longhorn[0]' 2>/dev/null || true
terraform state rm 'helm_release.longhorn' 2>/dev/null || true

# Remove stuck namespaces
terraform state rm 'kubernetes_namespace.longhorn[0]' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.longhorn' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.forgejo[0]' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.forgejo' 2>/dev/null || true

echo ""
echo "Step 4: Final destroy attempt..."

# Final destroy
terraform destroy -auto-approve

echo ""
echo "=== Destroy Complete ==="
echo ""
echo "Note: The following may still exist on Proxmox if destroy failed:"
echo "  - VM disk images in storage pool"
echo "  - PVC data (if using shared storage)"
echo ""
echo "To verify VM is deleted:"
echo "  pvesh get /nodes/pve/qemu --output-format json | jq '.[] | select(.vmid == 1000)'"
