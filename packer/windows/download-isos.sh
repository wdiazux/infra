#!/usr/bin/env bash
# Download ISOs for Windows 11 Packer builds
# Run this on Proxmox host to download VirtIO drivers
#
# Usage: ./download-isos.sh
#
# Note: Windows 11 ISO must be downloaded manually from Microsoft
#       VirtIO drivers are downloaded automatically

set -e

# Configuration
ISO_PATH="/var/lib/vz/template/iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
VIRTIO_ISO="virtio-win.iso"
WINDOWS_ISO="windows-11.iso"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "==========================================="
echo "Windows 11 Packer ISO Setup"
echo "==========================================="
echo ""

# Check if running on Proxmox
if ! command -v pvesm &> /dev/null; then
    echo -e "${RED}Error: This script must be run on a Proxmox host${NC}"
    echo ""
    echo "Usage: ssh root@pve 'bash -s' < download-isos.sh"
    exit 1
fi

echo -e "${GREEN}Running on Proxmox host${NC}"

# Create ISO directory if it doesn't exist
mkdir -p "$ISO_PATH"

# Download VirtIO drivers
echo ""
echo -e "${BLUE}[1/2] VirtIO Drivers${NC}"
echo "==========================================="
if [ -f "$ISO_PATH/$VIRTIO_ISO" ]; then
    SIZE=$(du -h "$ISO_PATH/$VIRTIO_ISO" | cut -f1)
    echo -e "${GREEN}VirtIO ISO already exists ($SIZE), skipping download${NC}"
else
    echo "Downloading from: $VIRTIO_URL"
    wget -O "$ISO_PATH/$VIRTIO_ISO" "$VIRTIO_URL" --progress=bar:force 2>&1
    echo -e "${GREEN}VirtIO drivers downloaded successfully!${NC}"
fi

# Check for Windows ISO
echo ""
echo -e "${BLUE}[2/2] Windows 11 ISO${NC}"
echo "==========================================="

if [ -f "$ISO_PATH/$WINDOWS_ISO" ]; then
    SIZE=$(du -h "$ISO_PATH/$WINDOWS_ISO" | cut -f1)
    echo -e "${GREEN}Windows 11 ISO found ($SIZE)${NC}"
else
    echo -e "${YELLOW}Windows 11 ISO not found!${NC}"
    echo ""
    echo "Windows 11 ISO must be downloaded manually from Microsoft."
    echo ""
    echo "Steps:"
    echo "  1. Go to: https://www.microsoft.com/software-download/windows11"
    echo ""
    echo "  2. Scroll to 'Download Windows 11 Disk Image (ISO)'"
    echo ""
    echo "  3. Select 'Windows 11 (multi-edition ISO for x64 devices)'"
    echo ""
    echo "  4. Choose your language and download (~5.5GB)"
    echo ""
    echo "  5. Upload to Proxmox via Web UI:"
    echo "     Datacenter → Storage → local → ISO Images → Upload"
    echo ""
    echo "  6. Rename the uploaded ISO to: ${WINDOWS_ISO}"
    echo "     ssh root@pve 'cd $ISO_PATH && mv Win11_*.iso $WINDOWS_ISO'"
    echo ""
fi

# Summary
echo ""
echo "==========================================="
echo "ISO Status Summary"
echo "==========================================="
echo ""

if [ -f "$ISO_PATH/$VIRTIO_ISO" ]; then
    SIZE=$(du -h "$ISO_PATH/$VIRTIO_ISO" | cut -f1)
    echo -e "  VirtIO drivers: ${GREEN}Ready${NC} ($SIZE)"
else
    echo -e "  VirtIO drivers: ${RED}Missing${NC}"
fi

if [ -f "$ISO_PATH/$WINDOWS_ISO" ]; then
    SIZE=$(du -h "$ISO_PATH/$WINDOWS_ISO" | cut -f1)
    echo -e "  Windows 11:     ${GREEN}Ready${NC} ($SIZE)"
else
    echo -e "  Windows 11:     ${RED}Missing${NC} (manual download required)"
fi

echo ""

# List ISOs in storage
echo "ISOs in Proxmox storage:"
pvesm list local --content iso 2>/dev/null | grep -E "iso" || echo "  (none found)"

echo ""
echo "==========================================="

if [ -f "$ISO_PATH/$VIRTIO_ISO" ] && [ -f "$ISO_PATH/$WINDOWS_ISO" ]; then
    echo -e "${GREEN}All ISOs ready! You can now run Packer build.${NC}"
    echo ""
    echo "Next steps (from your workstation):"
    echo "  cd packer/windows"
    echo "  nix-shell ../../shell.nix --run 'packer build .'"
else
    echo -e "${YELLOW}Some ISOs are missing. Complete the steps above.${NC}"
fi
