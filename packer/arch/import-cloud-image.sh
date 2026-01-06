#!/usr/bin/env bash
# Import Arch Linux Cloud Image to Proxmox
# Run this script on the Proxmox host to create a base cloud image VM
#
# This is a ONE-TIME setup. After creating the base VM, use Packer to customize it.

set -e

# Configuration
VM_ID=${1:-9300}
VM_NAME="arch-cloud-base"
STORAGE_POOL="tank"
BRIDGE="vmbr0"

# Cloud image URL (official Arch Linux cloud image)
CLOUD_IMAGE_URL="https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
CLOUD_IMAGE_CHECKSUM_URL="https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2.SHA256"
CLOUD_IMAGE_FILE="Arch-Linux-x86_64-cloudimg.qcow2"

echo "==> Importing Arch Linux Cloud Image to Proxmox"
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
wget -q "${CLOUD_IMAGE_CHECKSUM_URL}" -O SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing

# Customize cloud image to enable password auth
# Note: qemu-guest-agent is already installed in the official Arch cloud image
echo "==> Customizing cloud image..."
if ! command -v virt-customize &> /dev/null; then
    echo "    ERROR: virt-customize not found. Installing libguestfs-tools..."
    apt-get update && apt-get install -y libguestfs-tools
fi

echo "    - Configuring SSH for password authentication"
virt-customize -a "${CLOUD_IMAGE_FILE}" \
  --run-command "sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
  --run-command "sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config"

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
qm set ${VM_ID} --ciuser arch --cipassword arch

# Configure network to use DHCP
echo "==> Configuring network to use DHCP..."
qm set ${VM_ID} --ipconfig0 ip=dhcp

# Add SSH public key if available
echo "==> Adding SSH public key..."
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    qm set ${VM_ID} --sshkeys "$HOME/.ssh/id_ed25519.pub"
    echo "    SSH key added from $HOME/.ssh/id_ed25519.pub"
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    qm set ${VM_ID} --sshkeys "$HOME/.ssh/id_rsa.pub"
    echo "    SSH key added from $HOME/.ssh/id_rsa.pub"
else
    echo "    Warning: No SSH key found - password auth only"
fi

# Resize disk (optional, increases from ~2GB to specified size)
echo "==> Resizing disk to 20GB..."
qm resize ${VM_ID} scsi0 +18G

# Set CPU type to host (better performance)
echo "==> Setting CPU type to host..."
qm set ${VM_ID} --cpu host

echo ""
echo "==> ✅ Arch Linux cloud image imported successfully!"
echo ""
echo "Base VM created: ${VM_ID} (${VM_NAME})"
echo ""
echo "Next steps:"
echo "1. Start VM to test: qm start ${VM_ID}"
echo "2. Find IP: qm guest cmd ${VM_ID} network-get-interfaces"
echo "3. SSH: ssh arch@<ip> (password: arch)"
echo "4. Stop VM: qm stop ${VM_ID}"
echo "5. Use Packer to customize and create template"
echo ""
echo "Or manually convert to template: qm template ${VM_ID}"
