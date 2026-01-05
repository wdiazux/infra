#!/usr/bin/env bash
set -e

echo "======================================================================"
echo "Cleaning Up Debian Base and Template VMs"
echo "======================================================================"
echo ""
echo "This script will remove:"
echo "  - VM 9110 (debian-13-cloud-base)"
echo "  - VM 9112 (debian-13-cloud-template)"
echo ""
echo "This is required before running a fresh Packer build test."
echo ""
echo "======================================================================"
echo ""

# Load Proxmox environment variables
if [ -f "../../scripts/load-proxmox-env.sh" ]; then
    source ../../scripts/load-proxmox-env.sh
else
    echo "❌ Error: Cannot find scripts/load-proxmox-env.sh"
    echo "Please ensure PROXMOX_URL, PROXMOX_USERNAME, PROXMOX_TOKEN, and PROXMOX_NODE are set."
    exit 1
fi

# Function to check if VM exists
vm_exists() {
    local vm_id=$1
    if curl -s -k "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${vm_id}/config" \
        -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" 2>&1 | grep -q "does not exist"; then
        return 1  # VM does not exist
    else
        return 0  # VM exists
    fi
}

# Function to stop and delete VM
cleanup_vm() {
    local vm_id=$1
    local vm_name=$2

    echo "==> Processing VM ${vm_id} (${vm_name})..."

    if ! vm_exists ${vm_id}; then
        echo "    ℹ️  VM ${vm_id} does not exist, skipping..."
        return 0
    fi

    echo "    Stopping VM ${vm_id}..."
    curl -s -k -X POST "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${vm_id}/status/stop" \
        -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" > /dev/null 2>&1 || true

    sleep 3

    echo "    Deleting VM ${vm_id}..."
    curl -s -k -X DELETE "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${vm_id}" \
        -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" > /dev/null 2>&1

    sleep 2

    if ! vm_exists ${vm_id}; then
        echo "    ✅ VM ${vm_id} deleted successfully"
    else
        echo "    ⚠️  VM ${vm_id} may still exist, please check manually"
    fi

    echo ""
}

# Clean up VMs
cleanup_vm 9110 "debian-13-cloud-base"
cleanup_vm 9112 "debian-13-cloud-template"

echo "======================================================================"
echo "✅ Cleanup Complete"
echo "======================================================================"
echo ""
echo "Next steps:"
echo "  1. Run import-cloud-image.sh to create base VM 9110"
echo "  2. Run packer build to create template VM 9112"
echo ""
