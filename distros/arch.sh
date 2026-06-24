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
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

# Montar particiones
mkdir -p /mnt
mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# --- Instalación de Arch Linux ---
echo -e "\n[+] Descargando bootstrap de Arch Linux..."
BOOTSTRAP_URL="https://elmirror.cl/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
cd /tmp
wget -q --show-progress "$BOOTSTRAP_URL" -O arch-bootstrap.tar.zst
echo -e "\n[+] Extrayendo bootstrap en /mnt..."
tar -xvf arch-bootstrap.tar.zst -C /mnt --strip-components=1
rm arch-bootstrap.tar.zst
cp -r /mnt/root.x86_64/* /mnt/ 2>/dev/null || true

# Configurar fstab
genfstab -U /mnt > /mnt/etc/fstab

# Configurar sistema base (chroot)
echo -e "\n[+] Configurando sistema base..."
arch-chroot /mnt /bin/bash << 'EOF'
    echo 'Server = https://elmirror.cl/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
    # Configurar contraseña de root
    echo 'root:toor' | chpasswd
    # Instalando paquetes esenciales
    pacman-key --init
    pacma-key --populate
    pacman -Syy archlinux-keyring --noconfirm
    pacman -Syy fastfetch openssh networkmanager --noconfirm
    # Habilitar servicios
    systemctl enable sshd
    systemctl enable systemd-networkd
    systemctl enable systemd-resolved
    systemctl enable NetworkManager
EOF
