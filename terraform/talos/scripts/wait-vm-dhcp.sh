#!/usr/bin/env bash
set -euo pipefail

# Wait for Talos VM to boot and get DHCP IP
#
# Required environment variables:
#   PROXMOX_API_TOKEN - Proxmox API token
#   PROXMOX_URL       - Proxmox API URL
#   PROXMOX_NODE      - Proxmox node name
#   VM_ID             - VM ID to query
#   FALLBACK_IP       - Fallback IP if DHCP times out
#   OUTPUT_FILE       - Path to write detected IP

# Pre-flight checks
for cmd in curl jq; do
  if ! command -v $cmd &>/dev/null; then
    echo "ERROR: Required command '$cmd' not found. Install via nix-shell."
    exit 1
  fi
done

echo "Waiting for Talos VM to boot and get DHCP IP..."
for i in $(seq 1 60); do
  # Try to get IP from Proxmox QEMU guest agent
  IP=$(curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" \
    "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/agent/network-get-interfaces" 2>/dev/null \
    | jq -r '.data.result[]? | select(.name != "lo") | .["ip-addresses"][]? | select(.["ip-address-type"] == "ipv4") | .["ip-address"]' \
    | head -1 || true)

  if [ -n "$IP" ] && [ "$IP" != "null" ]; then
    echo "$IP" > "$OUTPUT_FILE"
    echo "VM got DHCP IP: $IP"
    exit 0
  fi
  echo "Waiting for DHCP IP... ($i/60)"
  sleep 5
done

# Timeout - use static IP as fallback but warn
echo "WARNING: Timeout waiting for DHCP IP after 5 minutes."
echo "Falling back to static IP ${FALLBACK_IP} (VM may not be ready yet)."
echo "${FALLBACK_IP}" > "$OUTPUT_FILE"
# Don't fail - let the config apply attempt proceed
