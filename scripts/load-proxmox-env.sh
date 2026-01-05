#!/usr/bin/env bash
# Load Proxmox credentials from SOPS into environment variables
# Usage: source scripts/load-proxmox-env.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_FILE="$PROJECT_ROOT/secrets/proxmox-creds.enc.yaml"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: Secrets file not found at $SECRETS_FILE"
    return 1
fi

# Check if SOPS_AGE_KEY_FILE is set
if [ -z "$SOPS_AGE_KEY_FILE" ]; then
    echo "Error: SOPS_AGE_KEY_FILE environment variable not set"
    echo "Run: export SOPS_AGE_KEY_FILE=\$HOME/.config/sops/age/keys.txt"
    return 1
fi

# Decrypt and export Proxmox credentials
echo "Loading Proxmox credentials from SOPS..."

export PROXMOX_URL=$(sops -d "$SECRETS_FILE" | yq '.proxmox_url')
export PROXMOX_TOKEN=$(sops -d "$SECRETS_FILE" | yq '.proxmox_token_secret')
export PROXMOX_NODE=$(sops -d "$SECRETS_FILE" | yq '.proxmox_node')
export PROXMOX_STORAGE_POOL=$(sops -d "$SECRETS_FILE" | yq '.proxmox_storage_pool')

# Construct full token string for Terraform/Packer
PROXMOX_USER=$(sops -d "$SECRETS_FILE" | yq '.proxmox_user')
PROXMOX_TOKEN_ID=$(sops -d "$SECRETS_FILE" | yq '.proxmox_token_id')
export PROXMOX_API_TOKEN="PVEAPIToken=${PROXMOX_USER}!${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN}"

echo "✓ Proxmox credentials loaded:"
echo "  PROXMOX_URL: $PROXMOX_URL"
echo "  PROXMOX_NODE: $PROXMOX_NODE"
echo "  PROXMOX_STORAGE_POOL: $PROXMOX_STORAGE_POOL"
echo "  PROXMOX_TOKEN: ***hidden***"
echo ""
echo "Environment variables are now set for Packer and Terraform."
