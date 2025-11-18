#!/usr/bin/env bash
# NixOS Automated Installation Script
# Used by Packer to create golden image for Proxmox

set -e

# Variables
DISK="/dev/sda"
ROOT_PASSWORD="nixos"

echo "==> Starting NixOS installation..."

# Partition the disk
echo "==> Partitioning disk ${DISK}..."
parted -s ${DISK} -- mklabel gpt
parted -s ${DISK} -- mkpart ESP fat32 1MiB 512MiB
parted -s ${DISK} -- set 1 esp on
parted -s ${DISK} -- mkpart primary ext4 512MiB 100%

# Format partitions
echo "==> Formatting partitions..."
mkfs.fat -F 32 -n boot ${DISK}1
mkfs.ext4 -L nixos ${DISK}2

# Mount filesystems
echo "==> Mounting filesystems..."
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Generate NixOS configuration
echo "==> Generating NixOS configuration..."
nixos-generate-config --root /mnt

# Download custom configuration
echo "==> Downloading custom configuration..."
curl -o /mnt/etc/nixos/configuration.nix http://${PACKER_HTTP_ADDR}/configuration.nix

# Install NixOS
echo "==> Installing NixOS..."
nixos-install --no-root-passwd

# Set root password in the installed system
echo "==> Setting root password..."
nixos-enter --root /mnt -c "echo 'root:${ROOT_PASSWORD}' | chpasswd"

# Unmount filesystems
echo "==> Unmounting filesystems..."
umount -R /mnt

echo "==> NixOS installation complete!"
