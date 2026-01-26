#!/usr/bin/env bash
set -euo pipefail

# Wait for Talos node to reboot with static IP
#
# Required environment variables:
#   NODE_IP     - Expected static IP address
#   TALOSCONFIG - Path to talosconfig file
#   OUTPUT_FILE - Path to write confirmed IP

echo "Waiting for Talos node to reboot with static IP ${NODE_IP}..."
for i in $(seq 1 60); do
  if talosctl --talosconfig "$TALOSCONFIG" --nodes "$NODE_IP" version --insecure 2>/dev/null | grep -q "Server:"; then
    echo "Node is up with static IP ${NODE_IP}"
    # Update the IP file so future Terraform runs use the static IP
    echo "${NODE_IP}" > "$OUTPUT_FILE"
    exit 0
  fi
  echo "Waiting for static IP... ($i/60)"
  sleep 5
done

echo "ERROR: Timeout waiting for static IP ${NODE_IP} after 5 minutes."
echo "Check VM console in Proxmox for boot errors."
exit 1
