#!/usr/bin/env bash
# Import Debian Cloud Image to Proxmox
# Run this script on the Proxmox host to create a base cloud image VM
#
# This is a ONE-TIME setup. After creating the base VM, use Packer to customize it.

set -e

# Configuration
VM_ID=${1:-9110}
VM_NAME="debian-12-cloud-base"
DEBIAN_VERSION="12"
DEBIAN_RELEASE="trixie"
STORAGE_POOL="local-zfs"
BRIDGE="vmbr0"

# Cloud image URL
CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/${DEBIAN_RELEASE}/latest/debian-${DEBIAN_VERSION}-genericcloud-amd64.qcow2"
CLOUD_IMAGE_FILE="debian-${DEBIAN_VERSION}-genericcloud-amd64.qcow2"

echo "==> Importing Debian ${DEBIAN_VERSION} (${DEBIAN_RELEASE}) Cloud Image to Proxmox"
echo "    VM ID: ${VM_ID}"
echo "    VM Name: ${VM_NAME}"
echo "    Storage: ${STORAGE_POOL}"

# Download cloud image
echo "==> Downloading cloud image..."
if [ ! -f "${CLOUD_IMAGE_FILE}" ]; then
    wget "${CLOUD_IMAGE_URL}" -O "${CLOUD_IMAGE_FILE}"
else
    echo "    Cloud image already downloaded, skipping..."
fi

# Verify checksum
echo "==> Verifying checksum..."
wget -q "https://cloud.debian.org/images/cloud/${DEBIAN_RELEASE}/latest/SHA512SUMS" -O SHA512SUMS
sha512sum -c SHA512SUMS --ignore-missing

# Create VM
echo "==> Creating VM ${VM_ID}..."
qm create ${VM_ID} \
    --name "${VM_NAME}" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=${BRIDGE}

# Import disk
echo "==> Importing disk to VM..."
qm importdisk ${VM_ID} "${CLOUD_IMAGE_FILE}" ${STORAGE_POOL}

# Attach disk to VM
echo "==> Attaching disk to VM..."
qm set ${VM_ID} --scsihw virtio-scsi-single --scsi0 ${STORAGE_POOL}:vm-${VM_ID}-disk-0

# Configure boot
echo "==> Configuring boot order..."
qm set ${VM_ID} --boot order=scsi0

# Add CloudInit drive
echo "==> Adding CloudInit drive..."
qm set ${VM_ID} --ide2 ${STORAGE_POOL}:cloudinit

# Configure serial console
echo "==> Configuring serial console..."
qm set ${VM_ID} --serial0 socket --vga serial0

# Enable QEMU guest agent
echo "==> Enabling QEMU guest agent..."
qm set ${VM_ID} --agent enabled=1

# Set default CloudInit user
echo "==> Configuring default CloudInit user..."
qm set ${VM_ID} --ciuser debian --cipassword debian

# Resize disk (optional, increases from ~2GB to specified size)
echo "==> Resizing disk to 20GB..."
qm resize ${VM_ID} scsi0 +18G

# Set CPU type to host (better performance)
echo "==> Setting CPU type to host..."
qm set ${VM_ID} --cpu host

echo ""
echo "==> ✅ Debian ${DEBIAN_VERSION} (${DEBIAN_RELEASE}) cloud image imported successfully!"
echo ""
echo "Base VM created: ${VM_ID} (${VM_NAME})"
echo ""
echo "Next steps:"
echo "1. Start VM to test: qm start ${VM_ID}"
echo "2. Find IP: qm guest cmd ${VM_ID} network-get-interfaces"
echo "3. SSH: ssh debian@<ip> (password: debian)"
echo "4. Stop VM: qm stop ${VM_ID}"
echo "5. Use Packer to customize and create template"
echo ""
echo "Or manually convert to template: qm template ${VM_ID}"
