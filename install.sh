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
        Arch)   ./distros/arch.sh "$DISK"; break ;;
        Gentoo) ./distros/gentoo.sh "$DISK"; break ;;
        Debian) ./distros/debian.sh "$DISK"; break ;;
        *) echo "Opción no válida."; exit 1 ;;
    esac
done

echo -e "\n[+] Instalación completada. Reinicia el sistema."
