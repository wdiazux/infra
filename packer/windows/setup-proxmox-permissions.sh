#!/usr/bin/env bash
# Setup Proxmox permissions for Packer Windows builds
# Run this on the Proxmox host as root
#
# Usage: ssh root@pve 'bash -s' < setup-proxmox-permissions.sh

set -e

echo "==========================================="
echo "Proxmox Packer Permissions Setup"
echo "==========================================="

# Check if running on Proxmox
if ! command -v pveum &> /dev/null; then
    echo "Error: This script must be run on a Proxmox host"
    exit 1
fi

# The user that Packer uses
PACKER_USER="terraform@pve"

echo ""
echo "Adding permissions for: $PACKER_USER"
echo ""

# Add Datastore permissions on 'local' storage for ISO uploads
echo "[1/3] Adding Datastore.AllocateTemplate on /storage/local..."
pveum acl modify /storage/local -user "$PACKER_USER" -role PVEDatastoreAdmin

# Verify the permission was added
echo ""
echo "[2/3] Verifying permissions..."
pveum acl list | grep -E "(local|$PACKER_USER)" || true

# Show current user permissions
echo ""
echo "[3/3] Current permissions for $PACKER_USER:"
pveum user permissions "$PACKER_USER" | head -20

echo ""
echo "==========================================="
echo "Done! Packer should now be able to:"
echo "  - Upload CD ISOs to local storage"
echo "  - Create Windows VMs from ISO"
echo "  - Convert VMs to templates"
echo "==========================================="
