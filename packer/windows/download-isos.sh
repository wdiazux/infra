#!/bin/bash
# Download Windows 11 ISOs for Packer builds
# Run this on Proxmox host to download and upload ISOs
#
# Usage: ./download-isos.sh
#
# Uses Mido.sh (https://github.com/ElliotKillick/Mido) to download
# Windows ISOs directly from Microsoft servers.

set -e

# Configuration
ISO_STORAGE="local"
ISO_PATH="/var/lib/vz/template/iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
VIRTIO_ISO="virtio-win.iso"
WINDOWS_ISO="windows-11.iso"
MIDO_URL="https://raw.githubusercontent.com/ElliotKillick/Mido/main/Mido.sh"

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

# Check dependencies
check_deps() {
    local missing=()
    for cmd in curl sha256sum grep sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing dependencies: ${missing[*]}${NC}"
        echo "Install with: apt install curl coreutils grep sed"
        exit 1
    fi
}

check_deps

# Check if running on Proxmox (optional - can run elsewhere and copy)
if command -v pvesm &> /dev/null; then
    echo -e "${GREEN}Running on Proxmox host${NC}"
    ON_PROXMOX=true
else
    echo -e "${YELLOW}Not running on Proxmox - ISOs will be downloaded locally${NC}"
    echo "You'll need to copy them to Proxmox storage afterwards"
    ISO_PATH="."
    ON_PROXMOX=false
fi

# Create ISO directory if it doesn't exist
mkdir -p "$ISO_PATH"

# Download VirtIO drivers
echo ""
echo -e "${BLUE}[1/2] VirtIO Drivers${NC}"
echo "==========================================="
if [ -f "$ISO_PATH/$VIRTIO_ISO" ]; then
    echo -e "${GREEN}VirtIO ISO already exists, skipping download${NC}"
else
    echo "Downloading from: $VIRTIO_URL"
    curl -L -o "$ISO_PATH/$VIRTIO_ISO" "$VIRTIO_URL" --progress-bar
    echo -e "${GREEN}VirtIO drivers downloaded successfully!${NC}"
fi

# Download Windows 11 using Mido
echo ""
echo -e "${BLUE}[2/2] Windows 11 ISO${NC}"
echo "==========================================="

if [ -f "$ISO_PATH/$WINDOWS_ISO" ]; then
    echo -e "${GREEN}Windows 11 ISO already exists, skipping download${NC}"
else
    echo "Downloading Windows 11 using Mido.sh..."
    echo "(This downloads directly from Microsoft servers)"
    echo ""

    # Download Mido.sh
    MIDO_SCRIPT=$(mktemp)
    curl -sL "$MIDO_URL" -o "$MIDO_SCRIPT"
    chmod +x "$MIDO_SCRIPT"

    # Run Mido to download Windows 11
    cd "$ISO_PATH"

    echo -e "${YELLOW}Note: Microsoft may rate-limit downloads. If it fails, wait and retry.${NC}"
    echo ""

    if bash "$MIDO_SCRIPT" win11x64; then
        # Mido downloads to Win11_*_x64.iso, rename it
        WIN11_FILE=$(ls -1 Win11_*_x64*.iso 2>/dev/null | head -1)
        if [ -n "$WIN11_FILE" ] && [ -f "$WIN11_FILE" ]; then
            mv "$WIN11_FILE" "$WINDOWS_ISO"
            echo -e "${GREEN}Windows 11 ISO downloaded and renamed to $WINDOWS_ISO${NC}"
        else
            echo -e "${RED}Download completed but ISO file not found${NC}"
            echo "Looking for: Win11_*_x64*.iso"
            ls -la *.iso 2>/dev/null || echo "No ISO files found"
        fi
    else
        echo -e "${RED}Mido download failed${NC}"
        echo ""
        echo "Alternative: Download manually from Microsoft:"
        echo "  https://www.microsoft.com/software-download/windows11"
        echo ""
        echo "Then copy to: $ISO_PATH/$WINDOWS_ISO"
    fi

    # Cleanup
    rm -f "$MIDO_SCRIPT"
    cd - > /dev/null
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
    echo -e "  Windows 11:     ${RED}Missing${NC}"
fi

echo ""

# Verify ISOs are visible to Proxmox
if [ "$ON_PROXMOX" = true ]; then
    echo "Checking Proxmox storage..."
    pvesm list $ISO_STORAGE --content iso 2>/dev/null | grep -E "(virtio|windows)" || echo "  (no matching ISOs found in storage)"
    echo ""
fi

echo "==========================================="

if [ -f "$ISO_PATH/$VIRTIO_ISO" ] && [ -f "$ISO_PATH/$WINDOWS_ISO" ]; then
    echo -e "${GREEN}All ISOs ready! You can now run Packer build.${NC}"
    echo ""
    echo "Next steps:"
    echo "  cd /home/wdiaz/devland/infra/packer/windows"
    echo "  packer init ."
    echo "  packer build ."
else
    echo -e "${YELLOW}Some ISOs are missing. Check the errors above.${NC}"
fi
