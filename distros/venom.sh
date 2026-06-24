#!/usr/bin/bash
set -e

DISK="$1"

# --- Formatear el disco ---
echo -e "\n[+] Formateando el disco $DISK..."
if [[ "$DISK" =~ nvme|mmcblk ]]; then
    EFI="${DISK}p1"
    ROOT="${DISK}p2"
else
    EFI="${DISK}1"
    ROOT="${DISK}2"
fi
umount "${DISK}"* 2>/dev/null || true

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

# --- Instalación de Gentoo ---
echo -e "\n[+] Instalando Venom..."
cd /mnt
wget https://nc.abetech.es/public.php/dav/files/fFAAeeBWfrt3mcR/venomlinux-rootfs-sysv-x86_64.tar.xz
tar -xvf venomlinux-*.tar.xz

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
    echo 'Ejecutando scratch update y scratch sysup para sincronizar Scratchpkg (puede tardar)...'
    if command -v scratch >/dev/null 2>&1; then
        scratch update || true
    fi
    # Como fallback, intentar scratch sysup directamente
    scratch sysup || true
"

echo -e "\n[+] Venom: sincronizacion completada."
