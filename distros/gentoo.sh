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

# --- Instalación de Gentoo ---
echo -e "\n[+] Instalando Gentoo..."
cd /mnt
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20260621T164603Z/stage3-amd64-systemd-20260621T164603Z.tar.xz
tar -xvf stage3-*.tar.xz

# Generar fstab si genfstab está disponible (consistencia con otros backends)
if command -v genfstab >/dev/null 2>&1; then
    genfstab -U /mnt > /mnt/etc/fstab || true
fi

# Copiar resolv.conf para que el chroot tenga DNS
cp -L /etc/resolv.conf /mnt/etc/resolv.conf || true

# Montajes necesarios para chroot
mount --types proc /proc /mnt/proc 2>/dev/null || true
mount --rbind /sys /mnt/sys 2>/dev/null || true
mount --rbind /dev /mnt/dev 2>/dev/null || true

# Ejecutar configuración dentro del chroot: contraseña root y sincronización de Portage
chroot /mnt /bin/bash -c "
    echo 'Estableciendo contraseña de root por defecto...'
    echo 'root:toor' | chpasswd
    echo 'Ejecutando emerge-webrsync y emerge --sync para sincronizar Portage (puede tardar)...'
    if command -v emerge-webrsync >/dev/null 2>&1; then
        emerge-webrsync || true
    fi
    # Como fallback, intentar emerge --sync directamente
    emerge --sync || true
"

echo -e "\n[+] Gentoo: sincronización de Portage completada (si los comandos estaban disponibles)."
