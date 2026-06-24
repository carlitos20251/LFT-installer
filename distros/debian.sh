#!/usr/bin/bash
set -e

DISK="$1"

# --- Formatear el disco ---
echo -e "\n[+] Formateando el disco $DISK..."
umount "${DISK}"* 2>/dev/null || true
if [[ "$DISK" =~ nvme|mmcblk ]]; then
    EFI="${DISK}p1"
    ROOT="${DISK}p2"
else
    EFI="${DISK}1"
    ROOT="${DISK}2"
fi

# Crear tabla de particiones (GPT)
parted -s "$DISK" mklabel gpt

# Crear particiones (EFI + Raíz)
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB  # EFI
parted -s "$DISK" mkpart primary ext4 512MiB 100%   # Raíz

# Formatear particiones
mkfs.fat -F32 "$EFI"
mkfs.ext4 "$ROOT"

# Montar particiones
mkdir -p /mnt
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$EFI" /mnt/boot

# --- Instalación de Debian ---
echo -e "\n[+] Instalando Debian..."
debootstrap --arch=amd64 stable /mnt http://deb.debian.org/debian/
genfstab -U /mnt >> /mnt/etc/fstab
chroot /mnt /bin/bash -c "
    apt update && apt install fastfetch
    echo 'root:toor' | chpasswd
"
