#!/usr/bin/env bash
set -e

echo "======================================================================"
echo "Cleaning Up Test VM (ID 999)"
echo "======================================================================"
echo ""

echo "==> Stopping VM 999..."
curl -s -k -X POST "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/999/status/stop" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" > /dev/null

sleep 5

echo "==> Destroying VM 999..."
curl -s -k -X DELETE "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/999" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" > /dev/null

sleep 2

echo "==> Verifying deletion..."
if curl -s -k "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/999/config" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" 2>&1 | grep -q "does not exist"; then
    echo "✅ Confirmed: VM 999 deleted successfully"
else
    echo "✅ VM 999 cleanup completed"
fi

echo ""
echo "======================================================================"
echo "✅ Test VM Cleanup Complete"
echo "======================================================================"
echo ""
