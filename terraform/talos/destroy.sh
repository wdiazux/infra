#!/usr/bin/env bash
# Talos Cluster Destroy Script
#
# Properly destroys the Talos cluster by handling resources that fail
# during normal terraform destroy (Longhorn, namespaces with finalizers, etc.)
#
# Usage: ./destroy.sh [--force]
#
# Options:
#   --force    Skip confirmation prompt
#
# Why this is needed:
# - talos_machine_secrets has lifecycle.prevent_destroy (safety feature)
# - Longhorn requires deleting-confirmation-flag=true before uninstall
# - Longhorn uninstall job often fails (BackoffLimitExceeded)
# - Kubernetes namespaces get stuck due to finalizers
# - FluxCD leaves finalizers on managed resources
#
# Destroy Order (critical for clean teardown):
# 1. Pre-destroy Kubernetes cleanup (FluxCD, Longhorn settings, webhooks)
# 2. Remove protected resources from Terraform state
# 3. Run terraform destroy
# 4. Handle any failed resources and retry
#
# Manual Steps This Script Automates:
# - terraform state rm talos_machine_secrets.cluster
# - kubectl patch longhorn setting deleting-confirmation-flag
# - kubectl delete validatingwebhookconfiguration/mutatingwebhookconfiguration
# - kubectl patch namespace finalizers
# - flux uninstall

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

KUBECONFIG="${SCRIPT_DIR}/kubeconfig"
FORCE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force)
            FORCE=true
            shift
            ;;
    esac
done

echo "=== Talos Cluster Destroy ==="
echo "This will destroy the entire Talos cluster and all resources."
echo ""
echo "Working directory: $SCRIPT_DIR"
echo "Kubeconfig: $KUBECONFIG"
echo ""

# Confirm unless --force
if [ "$FORCE" != "true" ]; then
    read -p "Are you sure you want to destroy the cluster? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Helper function to check if cluster is accessible
cluster_accessible() {
    [ -f "$KUBECONFIG" ] && kubectl --kubeconfig="$KUBECONFIG" get nodes &>/dev/null 2>&1
}

# Helper function to run kubectl
kctl() {
    kubectl --kubeconfig="$KUBECONFIG" "$@"
}

echo ""
echo "=============================================="
echo "Phase 1: Pre-destroy Kubernetes Cleanup"
echo "=============================================="

if cluster_accessible; then
    echo ""
    echo "Step 1.1: Suspending FluxCD reconciliation..."
    if command -v flux &>/dev/null; then
        flux suspend kustomization --all --kubeconfig="$KUBECONFIG" 2>/dev/null || true
        flux suspend source git --all --kubeconfig="$KUBECONFIG" 2>/dev/null || true
    fi

    echo ""
    echo "Step 1.2: Deleting FluxCD resources..."
    kctl delete kustomization --all -A --ignore-not-found 2>/dev/null || true
    kctl delete helmrelease --all -A --ignore-not-found 2>/dev/null || true
    kctl delete gitrepository --all -A --ignore-not-found 2>/dev/null || true

    echo ""
    echo "Step 1.3: Uninstalling FluxCD..."
    if command -v flux &>/dev/null; then
        flux uninstall --kubeconfig="$KUBECONFIG" --silent 2>/dev/null || true
    fi

    echo ""
    echo "Step 1.4: Setting Longhorn deleting-confirmation-flag..."
    # Try both methods - patch existing setting or create it
    kctl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
        --type=merge -p '{"value": "true"}' 2>/dev/null || \
    kctl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag 2>/dev/null || true

    echo ""
    echo "Step 1.5: Deleting Longhorn webhook configurations..."
    # These can block namespace deletion
    kctl delete validatingwebhookconfiguration longhorn-webhook-validator --ignore-not-found 2>/dev/null || true
    kctl delete mutatingwebhookconfiguration longhorn-webhook-mutator --ignore-not-found || true

    echo ""
    echo "Step 1.6: Scaling down Longhorn deployments..."
    kctl -n longhorn-system scale deployment --all --replicas=0 2>/dev/null || true

    echo ""
    echo "Step 1.7: Deleting failed Longhorn uninstall jobs..."
    kctl delete jobs -n longhorn-system -l app=longhorn-uninstall --ignore-not-found 2>/dev/null || true
    kctl delete job longhorn-uninstall -n longhorn-system --ignore-not-found 2>/dev/null || true

    echo ""
    echo "Step 1.8: Deleting FluxCD-managed app resources..."
    # Delete apps in tools and misc namespaces before namespace cleanup
    for ns in tools misc; do
        if kctl get namespace "$ns" &>/dev/null 2>&1; then
            echo "  - Deleting resources in namespace: $ns"
            kctl delete deployments,services,pvc,configmaps,secrets --all -n "$ns" --ignore-not-found 2>/dev/null || true
        fi
    done

    echo ""
    echo "Step 1.9: Deleting Zitadel OIDC setup jobs..."
    kctl delete cronjob zitadel-oidc-sync -n auth --ignore-not-found 2>/dev/null || true
    kctl delete job -n auth -l app.kubernetes.io/name=zitadel-oidc-sync --ignore-not-found 2>/dev/null || true
    kctl delete job zitadel-oidc-setup-initial -n auth --ignore-not-found 2>/dev/null || true

    echo ""
    echo "Step 1.10: Cleaning namespace finalizers..."
    for ns in flux-system longhorn-system forgejo auth media ai management monitoring arr-stack tools misc; do
        if kctl get namespace "$ns" &>/dev/null 2>&1; then
            echo "  - Removing finalizers from namespace: $ns"
            kctl patch namespace "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        fi
    done

    echo ""
    echo "Step 1.11: Deleting CRD finalizers (Longhorn, Zitadel)..."
    # Longhorn CRDs can have finalizers that block deletion
    for crd in $(kctl get crd -o name 2>/dev/null | grep -E 'longhorn|zitadel' || true); do
        echo "  - Patching: $crd"
        kctl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    done
else
    echo "Cluster not accessible (kubeconfig missing or cluster down)"
    echo "Skipping Kubernetes cleanup - proceeding with Terraform destroy"
fi

echo ""
echo "=============================================="
echo "Phase 2: Remove Protected Resources from State"
echo "=============================================="

echo ""
echo "Step 2.1: Removing talos_machine_secrets (has prevent_destroy)..."
terraform state rm talos_machine_secrets.cluster 2>/dev/null || true

echo ""
echo "=============================================="
echo "Phase 3: Terraform Destroy (First Attempt)"
echo "=============================================="

# Try normal destroy first
if terraform destroy -auto-approve 2>&1; then
    echo ""
    echo "=============================================="
    echo "Destroy Complete!"
    echo "=============================================="
    exit 0
fi

echo ""
echo "=============================================="
echo "Phase 4: Handling Failed Resources"
echo "=============================================="
echo "First destroy attempt failed. Removing stuck resources from state..."

echo ""
echo "Step 4.1: Removing Helm releases from state..."
terraform state rm 'helm_release.longhorn[0]' 2>/dev/null || true
terraform state rm 'helm_release.longhorn' 2>/dev/null || true
terraform state rm 'helm_release.forgejo[0]' 2>/dev/null || true
terraform state rm 'helm_release.forgejo' 2>/dev/null || true
terraform state rm 'helm_release.postgresql[0]' 2>/dev/null || true
terraform state rm 'helm_release.postgresql' 2>/dev/null || true
terraform state rm 'helm_release.weave_gitops[0]' 2>/dev/null || true
terraform state rm 'helm_release.weave_gitops' 2>/dev/null || true

echo ""
echo "Step 4.2: Removing stuck namespaces from state..."
terraform state rm 'kubernetes_namespace.longhorn[0]' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.longhorn' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.forgejo[0]' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.forgejo' 2>/dev/null || true

echo ""
echo "Step 4.3: Removing FluxCD null_resources from state..."
for resource in flux_verify flux_kustomization flux_git_repository flux_git_secret flux_install create_sops_age_secret; do
    terraform state rm "null_resource.${resource}[0]" 2>/dev/null || true
    terraform state rm "null_resource.${resource}" 2>/dev/null || true
done

echo ""
echo "Step 4.4: Removing Forgejo null_resources from state..."
for resource in wait_for_forgejo forgejo_generate_token forgejo_create_repo forgejo_push_repo; do
    terraform state rm "null_resource.${resource}[0]" 2>/dev/null || true
    terraform state rm "null_resource.${resource}" 2>/dev/null || true
done

echo ""
echo "Step 4.5: Removing kubernetes services from state..."
terraform state rm 'kubernetes_service.forgejo_http_proxy[0]' 2>/dev/null || true
terraform state rm 'kubernetes_service.forgejo_http_proxy' 2>/dev/null || true
terraform state rm 'kubernetes_service.weave_gitops_lb[0]' 2>/dev/null || true
terraform state rm 'kubernetes_service.weave_gitops_lb' 2>/dev/null || true

echo ""
echo "Step 4.6: Removing terraform_data pre-destroy resources from state..."
terraform state rm 'terraform_data.fluxcd_pre_destroy[0]' 2>/dev/null || true
terraform state rm 'terraform_data.longhorn_pre_destroy[0]' 2>/dev/null || true
terraform state rm 'terraform_data.forgejo_pre_destroy[0]' 2>/dev/null || true
terraform state rm 'terraform_data.weave_gitops_pre_destroy[0]' 2>/dev/null || true
terraform state rm 'terraform_data.zitadel_pre_destroy[0]' 2>/dev/null || true

echo ""
echo "=============================================="
echo "Phase 5: Final Terraform Destroy"
echo "=============================================="

terraform destroy -auto-approve

echo ""
echo "=============================================="
echo "Destroy Complete!"
echo "=============================================="
echo ""
echo "Verification commands:"
echo "  # Check Terraform state is empty:"
echo "  terraform state list"
echo ""
echo "  # Check VM is deleted from Proxmox:"
echo "  pvesh get /nodes/pve/qemu --output-format json | jq '.[] | select(.vmid == 1000)'"
echo ""
echo "Note: If any resources remain on Proxmox, delete manually via the Proxmox UI."
