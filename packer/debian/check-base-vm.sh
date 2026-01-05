#!/usr/bin/env bash
# Check if Debian base VM exists on Proxmox

echo "======================================================================"
echo "Checking Debian Cloud Base VM (ID: 9110)"
echo "======================================================================"
echo ""
echo "Proxmox Node: ${PROXMOX_NODE}"
echo "Proxmox URL: ${PROXMOX_URL}"
echo ""

# Check if environment variables are set
if [ -z "$PROXMOX_URL" ] || [ -z "$PROXMOX_USERNAME" ] || [ -z "$PROXMOX_TOKEN" ]; then
    echo "❌ ERROR: Proxmox environment variables not set"
    echo "   Run: direnv allow"
    exit 1
fi

echo "Querying Proxmox API for VM 9110..."
echo ""

# Query Proxmox API
API_URL="${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/9110/config"
RESPONSE=$(curl -s -k "$API_URL" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}")

# Check if VM exists
if echo "$RESPONSE" | grep -q '"name"'; then
    echo "✅ VM 9110 EXISTS!"
    echo ""
    echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)['data']
    print('VM Details:')
    print(f\"  Name: {data.get('name', 'N/A')}\")
    print(f\"  Cores: {data.get('cores', 'N/A')}\")
    print(f\"  Memory: {data.get('memory', 'N/A')} MB\")
    print(f\"  SCSI0: {data.get('scsi0', 'N/A')}\")
    print(f\"  Cloud-init: {data.get('ide2', 'N/A')}\")
    print(f\"  QEMU Agent: {data.get('agent', 'N/A')}\")
except Exception as e:
    print(f'  (Details unavailable: {e})')
"
    echo ""
    echo "✅ Ready to build Debian template!"
else
    echo "❌ VM 9110 NOT FOUND!"
    echo ""
    echo "You need to create the base VM first:"
    echo "  1. SSH to Proxmox host: ssh root@${PROXMOX_NODE}"
    echo "  2. Copy import script: scp packer/debian/import-cloud-image.sh root@${PROXMOX_NODE}:/root/"
    echo "  3. Run: ./import-cloud-image.sh 9110"
    echo ""
fi
