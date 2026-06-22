#!/usr/bin/bash
set -e

DISK="$1"

# --- Formatear el disco ---
echo -e "\n[+] Formateando el disco $DISK..."
umount "${DISK}"* 2>/dev/null || true

# Crear tabla de particiones (GPT)
parted -s "$DISK" mklabel gpt

# Crear particiones (EFI + Raíz)
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB  # EFI
parted -s "$DISK" mkpart primary ext4 512MiB 100%   # Raíz

# Formatear particiones
mkfs.fat -F32 "${DISK}p1" || mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}p2" || mkfs.ext4 "${DISK}2"

# Montar particiones
mkdir -p /mnt
mount "${DISK}p2" /mnt || mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}p1" /mnt/boot || mount "${DISK}1" /mnt/boot

# --- Instalación de Debian ---
echo -e "\n[+] Instalando Debian..."
debootstrap --arch=amd64 bullseye /mnt http://deb.debian.org/debian/
genfstab -U /mnt >> /mnt/etc/fstab
chroot /mnt /bin/bash -c "
    apt update && apt install fastfetch
    echo 'root:toor' | chpasswd
"
