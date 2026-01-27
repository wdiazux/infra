#!/usr/bin/env bash
# Import NixOS Proxmox Image to Proxmox
# Run this script on the Proxmox host to create a base cloud image VM
#
# This is a ONE-TIME setup. After creating the base VM, use Packer to customize it.
#
# The NixOS Proxmox image is built by Hydra CI and includes:
# - QEMU guest agent pre-installed
# - Cloud-init support
# - Optimized for Proxmox VE

set -euo pipefail

# Configuration
VM_ID="${1:-9200}"
VM_NAME="nixos-cloud-base"
STORAGE_POOL="tank"
BRIDGE="vmbr0"

# NixOS Proxmox image from Hydra (VMA format - native Proxmox backup)
# Using 25.11 (unstable/development) - update to stable when available
# Check https://hydra.nixos.org/job/nixos/release-25.11/nixos.proxmoxImage.x86_64-linux for latest
NIXOS_VERSION="25.11"
VMA_URL="https://hydra.nixos.org/build/318359969/download/1/vzdump-qemu-nixos-25.11pre-git.vma.zst"
VMA_FILE="vzdump-qemu-nixos-${NIXOS_VERSION}.vma.zst"
VMA_UNCOMPRESSED="vzdump-qemu-nixos-${NIXOS_VERSION}.vma"

# Cleanup downloaded files on failure
cleanup() { rm -f "${VMA_FILE}" "${VMA_UNCOMPRESSED}"; }
trap cleanup ERR

echo "==> Importing NixOS ${NIXOS_VERSION} Proxmox Image"
echo "    VM ID: ${VM_ID}"
echo "    VM Name: ${VM_NAME}"
echo "    Storage: ${STORAGE_POOL}"

# Check if VM already exists
if qm status "${VM_ID}" &>/dev/null; then
    echo "ERROR: VM ${VM_ID} already exists. Please remove it first or use a different ID."
    echo "       To remove: qm destroy ${VM_ID}"
    exit 1
fi

# Download VMA image
echo "==> Downloading NixOS Proxmox image..."
if [ ! -f "${VMA_FILE}" ]; then
    wget "${VMA_URL}" -O "${VMA_FILE}"
else
    echo "    VMA image already downloaded, skipping..."
fi

# Decompress VMA (Zstandard compression)
echo "==> Decompressing VMA image..."
if [ ! -f "${VMA_UNCOMPRESSED}" ]; then
    if ! command -v zstd &> /dev/null; then
        echo "    ERROR: zstd not found. Installing..."
        apt-get update && apt-get install -y zstd
    fi
    zstd -d "${VMA_FILE}" -o "${VMA_UNCOMPRESSED}"
else
    echo "    VMA already decompressed, skipping..."
fi

# Restore VMA to create VM
echo "==> Restoring VMA as VM ${VM_ID}..."
qmrestore "${VMA_UNCOMPRESSED}" "${VM_ID}" --storage "${STORAGE_POOL}"

# Rename VM
echo "==> Renaming VM to ${VM_NAME}..."
qm set "${VM_ID}" --name "${VM_NAME}"

# Configure network bridge
echo "==> Configuring network..."
qm set "${VM_ID}" --net0 "virtio,bridge=${BRIDGE}"

# Enable QEMU guest agent (should already be in image, but ensure VM config has it)
echo "==> Enabling QEMU guest agent..."
qm set "${VM_ID}" --agent enabled=1

# Add CloudInit drive if not present
echo "==> Adding CloudInit drive..."
qm set "${VM_ID}" --ide2 "${STORAGE_POOL}:cloudinit" 2>/dev/null || echo "    CloudInit drive already exists or not needed"

# Set default CloudInit user
echo "==> Configuring default CloudInit user..."
qm set "${VM_ID}" --ciuser nixos --cipassword nixos

# Configure network to use DHCP
echo "==> Configuring network to use DHCP..."
qm set "${VM_ID}" --ipconfig0 ip=dhcp

# Add SSH public key if available
echo "==> Adding SSH public key..."
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    qm set "${VM_ID}" --sshkeys "$HOME/.ssh/id_ed25519.pub"
    echo "    SSH key added from $HOME/.ssh/id_ed25519.pub"
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    qm set "${VM_ID}" --sshkeys "$HOME/.ssh/id_rsa.pub"
    echo "    SSH key added from $HOME/.ssh/id_rsa.pub"
else
    echo "    Warning: No SSH key found - password auth only"
fi

# Set CPU type to host (better performance)
echo "==> Setting CPU type to host..."
qm set "${VM_ID}" --cpu host

# Resize disk if needed (NixOS image is typically small)
echo "==> Resizing disk to 20GB..."
# Get the disk name first
DISK_NAME=$(qm config "${VM_ID}" | grep -E "^scsi0:|^virtio0:" | cut -d: -f1)
if [ -n "${DISK_NAME}" ]; then
    qm resize "${VM_ID}" "${DISK_NAME}" 20G 2>/dev/null || echo "    Disk already at or above 20GB"
else
    echo "    Warning: Could not find primary disk to resize"
fi

# Configure SSH for password authentication (via cloud-init or virt-customize if available)
echo "==> Configuring SSH for password authentication..."
if command -v virt-customize &> /dev/null; then
    # Get the disk path
    DISK_PATH=$(pvesm path "${STORAGE_POOL}:vm-${VM_ID}-disk-0" 2>/dev/null) || true
    if [ -n "${DISK_PATH}" ] && [ -f "${DISK_PATH}" ]; then
        virt-customize -a "${DISK_PATH}" \
            --run-command "sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
            --run-command "sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config" 2>/dev/null || \
            echo "    Note: Could not modify SSH config (may need manual configuration)"
    fi
else
    echo "    Note: virt-customize not available - SSH password auth may need manual configuration"
    echo "    Install with: apt-get install libguestfs-tools"
fi

echo ""
echo "==> NixOS Proxmox image imported successfully!"
echo ""
echo "Base VM created: ${VM_ID} (${VM_NAME})"
echo ""
echo "Next steps:"
echo "1. Start VM to test: qm start ${VM_ID}"
echo "2. Find IP: qm guest cmd ${VM_ID} network-get-interfaces"
echo "3. SSH: ssh nixos@<ip> (password: nixos)"
echo "4. Stop VM: qm stop ${VM_ID}"
echo "5. Use Packer to customize and create template"
echo ""
echo "Or manually convert to template: qm template ${VM_ID}"
echo ""
echo "Note: NixOS configuration is declarative. After SSH access, edit"
echo "      /etc/nixos/configuration.nix and run 'nixos-rebuild switch'"
