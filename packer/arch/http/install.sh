#!/bin/bash
# Arch Linux Automated Installation Script
# Used by Packer to create golden image for Proxmox

set -e

# Variables
DISK="/dev/sda"
ROOT_PASSWORD="arch"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
KEYMAP="us"
HOSTNAME="archlinux"

echo "==> Starting Arch Linux installation..."

# Update system clock
timedatectl set-ntp true

# Partition the disk
echo "==> Partitioning disk ${DISK}..."
parted -s ${DISK} mklabel gpt
parted -s ${DISK} mkpart ESP fat32 1MiB 513MiB
parted -s ${DISK} set 1 esp on
parted -s ${DISK} mkpart primary ext4 513MiB 100%

# Format partitions
echo "==> Formatting partitions..."
mkfs.fat -F32 ${DISK}1
mkfs.ext4 -F ${DISK}2

# Mount filesystems
echo "==> Mounting filesystems..."
mount ${DISK}2 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot

# Install base system
echo "==> Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
echo "==> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure system
echo "==> Configuring system..."
arch-chroot /mnt /bin/bash <<EOF
set -e

# Set timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Localization
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Network configuration
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# Install essential packages
echo "==> Installing essential packages..."
pacman -Sy --noconfirm \
    sudo \
    openssh \
    qemu-guest-agent \
    cloud-init \
    cloud-guest-utils \
    vim \
    curl \
    wget \
    git \
    htop \
    net-tools \
    dnsutils \
    python \
    python-pip \
    networkmanager \
    dhcpcd

# Configure initramfs
echo "==> Configuring initramfs..."
mkinitcpio -P

# Install and configure bootloader (systemd-boot)
echo "==> Installing bootloader..."
bootctl install

# Create bootloader entries
cat > /boot/loader/loader.conf <<LOADER
default arch.conf
timeout 3
console-mode max
editor no
LOADER

cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=${DISK}2 rw
ENTRY

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Enable services
systemctl enable sshd
systemctl enable qemu-guest-agent
systemctl enable NetworkManager
systemctl enable cloud-init
systemctl enable cloud-init-local
systemctl enable cloud-config
systemctl enable cloud-final

# Configure SSH
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Configure cloud-init
cat > /etc/cloud/cloud.cfg.d/99_pve.cfg <<CLOUDINIT
datasource_list: [ NoCloud, ConfigDrive ]
CLOUDINIT

echo "==> Installation complete!"
EOF

# Unmount filesystems
echo "==> Unmounting filesystems..."
umount -R /mnt

echo "==> Arch Linux installation finished successfully!"
