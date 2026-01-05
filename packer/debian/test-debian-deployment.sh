#!/usr/bin/env bash
# Test Debian Template Deployment
# Creates a test VM from the newly built template

set -e

TEST_VM_ID=999
TEST_VM_NAME="debian-test-vm"

echo "======================================================================"
echo "Testing Debian Template Deployment"
echo "======================================================================"
echo ""
echo "Test Configuration:"
echo "  Template: debian-13-cloud-template (VM 9112)"
echo "  Test VM ID: ${TEST_VM_ID}"
echo "  Test VM Name: ${TEST_VM_NAME}"
echo ""

# Check if test VM already exists
if curl -s -k "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${TEST_VM_ID}/status/current" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" 2>/dev/null | grep -q '"data"'; then
    echo "⚠️  Test VM ${TEST_VM_ID} already exists. Deleting..."
    curl -s -k -X DELETE "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${TEST_VM_ID}" \
        -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" > /dev/null
    sleep 3
fi

echo "==> Cloning template 9112 → Test VM ${TEST_VM_ID}..."
CLONE_RESPONSE=$(curl -s -k -X POST \
    "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/9112/clone" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"newid\": ${TEST_VM_ID}, \"name\": \"${TEST_VM_NAME}\", \"full\": 1}")

echo "$CLONE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'data' in data:
    print('✅ Clone operation started')
else:
    print('❌ Clone failed:', data.get('errors', data))
    sys.exit(1)
"

echo "==> Waiting for clone to complete..."
sleep 10

echo "==> Configuring cloud-init..."
curl -s -k -X PUT "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${TEST_VM_ID}/config" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"ciuser": "testuser", "cipassword": "testpass123", "ipconfig0": "ip=dhcp"}' > /dev/null

echo "==> Starting test VM..."
curl -s -k -X POST "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${TEST_VM_ID}/status/start" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" > /dev/null

echo "==> Waiting for VM to boot and cloud-init to complete (30 seconds)..."
sleep 30

echo "==> Getting VM IP address..."
VM_IP=$(curl -s -k "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${TEST_VM_ID}/agent/network-get-interfaces" \
    -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}" 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)['data']['result']
    for iface in data:
        if iface.get('name') not in ['lo']:
            for addr in iface.get('ip-addresses', []):
                if addr.get('ip-address-type') == 'ipv4' and not addr.get('ip-address', '').startswith('127'):
                    print(addr['ip-address'])
                    sys.exit(0)
except:
    pass
print('DHCP')
" || echo "DHCP")

echo ""
echo "======================================================================"
echo "✅ Test VM Deployed Successfully!"
echo "======================================================================"
echo ""
echo "Test VM Details:"
echo "  VM ID: ${TEST_VM_ID}"
echo "  VM Name: ${TEST_VM_NAME}"
echo "  IP Address: ${VM_IP}"
echo "  SSH User: testuser"
echo "  SSH Password: testpass123"
echo ""
echo "Test SSH Connection:"
echo "  ssh testuser@${VM_IP}"
echo ""
echo "Cleanup (when done):"
echo "  qm stop ${TEST_VM_ID} && qm destroy ${TEST_VM_ID}"
echo ""
