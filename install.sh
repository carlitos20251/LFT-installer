#!/usr/bin/bash
set -e  # Salir si hay un error

clear

# --- Mensaje de advertencia ---
cat << "EOF"
====================================
     INSTALADOR LINUX AUTOMÁTICO
====================================

ADVERTENCIA:

Este script BORRARÁ COMPLETAMENTE el disco seleccionado.
Se perderán todos los datos, particiones y sistemas operativos.

Solo continúa si sabes lo que haces.

EOF

read -rp "Escribe SI para continuar: " RESP
[[ "$RESP" != "SI" ]] && exit 1

# --- Mostrar discos disponibles ---
echo -e "\nDiscos disponibles:"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "disk|nvme"
echo

read -rp "Disco destino (ej: sda, nvme0n1): " DISK
DISK="/dev/$DISK"

# Validar que el disco existe
if [[ ! -e "$DISK" ]]; then
    echo "Error: El disco $DISK no existe."
    exit 1
fi

echo -e "\nDisco seleccionado: $DISK"
read -rp "Confirmar (SI/NO): " CONFIRM
[[ "$CONFIRM" != "SI" ]] && exit 1

# --- Seleccionar distribución ---
PS3="Selecciona distribución: "
select DISTRO in "Arch" "Gentoo" "Debian"; do
    case $DISTRO in
        Arch)   DISTRO="arch"; break ;;
        Gentoo) DISTRO="gentoo"; break ;;
        Debian) DISTRO="debian"; break ;;
        *) echo "Opción no válida."; exit 1 ;;
    esac
done

echo -e "\nDistribución elegida: $DISTRO"

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

# --- Instalación según distribución ---
case "$DISTRO" in
    arch)
        echo -e "\n[+] Descargando bootstrap de Arch Linux..."
        # Descargar el bootstrap más reciente de Arch
        BOOTSTRAP_URL="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.gz"
        cd /tmp
        wget -q --show-progress "$BOOTSTRAP_URL" -O arch-bootstrap.tar.gz
        echo -e "\n[+] Extrayendo bootstrap en /mnt..."
        tar -xzf arch-bootstrap.tar.gz -C /mnt --strip-components=1
        rm arch-bootstrap.tar.gz

        # Configurar fstab
        genfstab -U /mnt > /mnt/etc/fstab

        # Configurar sistema base (chroot)
        echo -e "\n[+] Configurando sistema base..."
        arch-chroot /mnt /bin/bash << 'EOF'
            # Configurar contraseña de root
            echo 'root:toor' | chpasswd

            # Instalar GRUB para UEFI
            pacman -Sy --noconfirm grub efibootmgr
            grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
            grub-mkconfig -o /boot/grub/grub.cfg

            # Habilitar servicios
            systemctl enable sshd
            systemctl enable systemd-networkd
            systemctl enable systemd-resolved
        EOF
        ;;

    gentoo)
        echo -e "\n[+] Instalando Gentoo..."
        cd /mnt
        wget https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/latest-stage3-amd64-openrc.tar.xz
        tar xpvf latest-stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
        wget https://bouncer.gentoo.org/fetch/root/all/snapshots/portage-latest.tar.xz
        tar xpvf portage-latest.tar.xz -C /mnt/usr
        ;;

    debian)
        echo -e "\n[+] Instalando Debian..."
        debootstrap --arch=amd64 bullseye /mnt http://deb.debian.org/debian/
        chroot /mnt /bin/bash -c "
            apt update && apt install -y grub-efi-amd64 efibootmgr
            echo 'root:toor' | chpasswd
            grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
            update-grub
        "
        ;;
esac

echo -e "\n[+] Instalación completada. Reinicia el sistema."
umount -R /mnt
