#!/bin/bash
# Import Talos Linux disk image to Proxmox
# This script downloads the Talos Factory disk image and imports it as a VM template
#
# Usage: ./import-talos-image.sh [VM_ID]
# Default VM ID: 9000

set -euo pipefail

# Configuration
VM_ID="${1:-9000}"
TALOS_VERSION="v1.12.1"
SCHEMATIC_ID="c4bf8f99153627fb9c361f156baa9f81c38ecbe7fd40ca761dc6b68a1590a01b"
STORAGE_POOL="tank"
BRIDGE="vmbr0"

# Disk image URL from Talos Factory (non-SecureBoot for homelab simplicity)
IMAGE_URL="https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_VERSION}/nocloud-amd64.raw.xz"
IMAGE_FILE="talos-${TALOS_VERSION}.raw.xz"
RAW_FILE="talos-${TALOS_VERSION}.raw"

TEMPLATE_NAME="talos-${TALOS_VERSION//v/}-nvidia-template"

echo "=============================================="
echo "Talos Linux Disk Image Import"
echo "=============================================="
echo "Version:     ${TALOS_VERSION}"
echo "Schematic:   ${SCHEMATIC_ID:0:16}..."
echo "VM ID:       ${VM_ID}"
echo "Template:    ${TEMPLATE_NAME}"
echo "Storage:     ${STORAGE_POOL}"
echo "SecureBoot:  No (recommended for homelab)"
echo "=============================================="
echo ""

# Check if VM already exists
if qm status "${VM_ID}" &>/dev/null; then
    echo "ERROR: VM ${VM_ID} already exists!"
    echo "Delete it first: qm destroy ${VM_ID} --purge"
    exit 1
fi

# Create temp directory
WORK_DIR=$(mktemp -d)
cd "${WORK_DIR}"
echo "Working directory: ${WORK_DIR}"

# Download disk image
echo ""
echo "==> Downloading Talos disk image..."
echo "    URL: ${IMAGE_URL}"
wget -q --show-progress -O "${IMAGE_FILE}" "${IMAGE_URL}"

# Decompress
echo ""
echo "==> Decompressing disk image..."
xz -d "${IMAGE_FILE}"
echo "    Decompressed: ${RAW_FILE} ($(du -h "${RAW_FILE}" | cut -f1))"

# Create VM
echo ""
echo "==> Creating VM ${VM_ID}..."
qm create "${VM_ID}" \
    --name "${TEMPLATE_NAME}" \
    --description "Talos Linux ${TALOS_VERSION} with NVIDIA GPU, Longhorn, ZFS support" \
    --ostype l26 \
    --machine q35 \
    --cpu host \
    --cores 2 \
    --sockets 1 \
    --memory 4096 \
    --net0 "virtio,bridge=${BRIDGE}" \
    --scsihw virtio-scsi-single \
    --agent enabled=1 \
    --bios ovmf \
    --tags "talos,kubernetes,nvidia-gpu"

# Add EFI disk (no SecureBoot for homelab simplicity)
echo "==> Adding EFI disk..."
qm set "${VM_ID}" --efidisk0 "${STORAGE_POOL}:1,efitype=4m"

# Import disk image
echo ""
echo "==> Importing disk image to ${STORAGE_POOL}..."
qm importdisk "${VM_ID}" "${RAW_FILE}" "${STORAGE_POOL}" --format raw

# Attach the imported disk
echo ""
echo "==> Attaching disk to VM..."
qm set "${VM_ID}" --scsi0 "${STORAGE_POOL}:vm-${VM_ID}-disk-1,discard=on,iothread=1,ssd=1"

# Set boot order
echo "==> Setting boot order..."
qm set "${VM_ID}" --boot "order=scsi0"

# Resize disk to 150GB
echo ""
echo "==> Resizing disk to 150GB..."
qm resize "${VM_ID}" scsi0 150G

# Convert to template
echo ""
echo "==> Converting to template..."
qm template "${VM_ID}"

# Cleanup
echo ""
echo "==> Cleaning up..."
cd /
rm -rf "${WORK_DIR}"

echo ""
echo "=============================================="
echo "SUCCESS! Talos template created"
echo "=============================================="
echo ""
echo "Template ID:   ${VM_ID}"
echo "Template Name: ${TEMPLATE_NAME}"
echo ""
echo "Extensions included:"
echo "  - qemu-guest-agent (Proxmox integration)"
echo "  - iscsi-tools (Longhorn storage)"
echo "  - util-linux-tools (Longhorn volumes)"
echo "  - nonfree-kmod-nvidia-production (NVIDIA GPU)"
echo "  - nvidia-container-toolkit-production (GPU containers)"
echo "  - zfs, nfs-utils, amd-ucode, thunderbolt, uinput, newt"
echo ""
echo "Next steps:"
echo "  1. Clone: qm clone ${VM_ID} 100 --name talos-node --full"
echo "  2. Configure: qm set 100 --memory 32768 --cores 8"
echo "  3. Start: qm start 100"
echo "  4. Apply config: talosctl apply-config --insecure --nodes <IP> --file controlplane.yaml"
echo ""
