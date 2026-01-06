#!/usr/bin/env bash
# Import Ubuntu Cloud Image to Proxmox
# Run this script on the Proxmox host to create a base cloud image VM
#
# This is a ONE-TIME setup. After creating the base VM, use Packer to customize it.

set -e

# Configuration
VM_ID=${1:-9100}
VM_NAME="ubuntu-2404-cloud-base"
UBUNTU_VERSION="24.04"
STORAGE_POOL="tank"
BRIDGE="vmbr0"

# Cloud image URL
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img"
CLOUD_IMAGE_FILE="ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img"

echo "==> Importing Ubuntu ${UBUNTU_VERSION} Cloud Image to Proxmox"
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
wget -q "https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/SHA256SUMS" -O SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing

# Customize cloud image to install qemu-guest-agent and enable password auth
echo "==> Customizing cloud image..."
if ! command -v virt-customize &> /dev/null; then
    echo "    ERROR: virt-customize not found. Installing libguestfs-tools..."
    apt-get update && apt-get install -y libguestfs-tools
fi

echo "    - Installing qemu-guest-agent and configuring SSH"
virt-customize -a "${CLOUD_IMAGE_FILE}" \
  --install qemu-guest-agent \
  --run-command "systemctl enable qemu-guest-agent" \
  --run-command "sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
  --run-command "sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf" \
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
qm set ${VM_ID} --ciuser ubuntu --cipassword ubuntu

# Configure network to use DHCP
echo "==> Configuring network to use DHCP..."
qm set ${VM_ID} --ipconfig0 ip=dhcp

# Add SSH public key if available
echo "==> Adding SSH public key..."
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    qm set ${VM_ID} --sshkeys "$HOME/.ssh/id_rsa.pub"
    echo "    SSH key added from $HOME/.ssh/id_rsa.pub"
else
    echo "    Warning: No SSH key found at $HOME/.ssh/id_rsa.pub - password auth only"
fi

# Resize disk (optional, increases from ~2GB to specified size)
echo "==> Resizing disk to 20GB..."
qm resize ${VM_ID} scsi0 +18G

# Set CPU type to host (better performance)
echo "==> Setting CPU type to host..."
qm set ${VM_ID} --cpu host

echo ""
echo "==> ✅ Ubuntu ${UBUNTU_VERSION} cloud image imported successfully!"
echo ""
echo "Base VM created: ${VM_ID} (${VM_NAME})"
echo ""
echo "Next steps:"
echo "1. Start VM to test: qm start ${VM_ID}"
echo "2. Find IP: qm guest cmd ${VM_ID} network-get-interfaces"
echo "3. SSH: ssh ubuntu@<ip> (password: ubuntu)"
echo "4. Stop VM: qm stop ${VM_ID}"
echo "5. Use Packer to customize and create template"
echo ""
echo "Or manually convert to template: qm template ${VM_ID}"
