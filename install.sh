#!/usr/bin/bash
set -e  # Salir si hay un error

clear

# --- Función: asegurar que comandos necesarios estén instalados ---
# Intenta instalar los paquetes que contienen los comandos: genfstab, wget, parted
# Compatible con: Arch (pacman), Debian/Ubuntu (apt), Gentoo (emerge), Fedora (dnf/yum)
ensure_required_commands() {
    local cmds=(genfstab wget parted debootstrap)
    local missing=()
    for c in "${cmds[@]}"; do
        if ! command -v "$c" >/dev/null 2>&1; then
            missing+=("$c")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        return 0
    fi

    echo -e "\n[!] Faltan comandos: ${missing[*]}\nIntentando instalarlos según el gestor de paquetes disponible..."

    # Detectar gestor de paquetes
    local pm=""
    if command -v pacman >/dev/null 2>&1; then
        pm="pacman"
    elif command -v apt-get >/dev/null 2>&1; then
        pm="apt"
    elif command -v emerge >/dev/null 2>&1; then
        pm="emerge"
    elif command -v dnf >/dev/null 2>&1; then
        pm="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pm="yum"
    else
        echo "No se detectó un gestor de paquetes soportado. Instala manualmente: ${missing[*]}"
        return 1
    fi

    # Mapear paquetes por gestor. genfstab está disponible en arch-install-scripts (Arch).
    local pkgs=()
    for c in "${missing[@]}"; do
        case "$c" in
            genfstab)
                    case "$pm" in
                    pacman) pkgs+=(arch-install-scripts) ;;
                    emerge) pkgs+=(sys-fs/genfstab) ;;
                    esac
                ;;
            wget)
                case "$pm" in
                    pacman) pkgs+=(wget) ;;
                    apt) pkgs+=(wget) ;;
                    emerge) pkgs+=(net-misc/wget) ;;
                    dnf|yum) pkgs+=(wget) ;;
                esac
                ;;
            parted)
                case "$pm" in
                    pacman) pkgs+=(parted) ;;
                    apt) pkgs+=(parted) ;;
                    emerge) pkgs+=(sys-block/parted) ;;
                    dnf|yum) pkgs+=(parted) ;;
                esac
                ;;
            debootstrap)
                case "$pm" in
                    pacman) pkgs+=(debootstrap) ;;
                    apt) pkgs+=(debootstrap) ;;
                    emerge) pkgs+=(dev-util/debootstrap) ;;
                esac
               ;;
            *)
                echo "No conozco cómo instalar '$c' automáticamente." ;;
        esac
    done

    if [ ${#pkgs[@]} -eq 0 ]; then
        echo "No hay paquetes conocidos para instalar. Revisa las advertencias anteriores." >&2
        return 1
    fi

    echo "Gestor detectado: $pm. Paquetes a instalar: ${pkgs[*]}"

    # Ejecutar instalación según gestor
    case "$pm" in
        pacman)
            pacman -Sy --noconfirm "${pkgs[@]}"
            ;;
        apt)
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
            ;;
        emerge)
            # Gentoo suele ejecutarse dentro del sistema construido; aquí intentamos instalar si emerge está disponible
            emerge --quiet "${pkgs[@]}"
            ;;
        dnf)
            dnf install -y "${pkgs[@]}"
            ;;
        yum)
            yum install -y "${pkgs[@]}"
            ;;
    esac

    return 0
}

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

# Intentar instalar dependencias necesarias si faltan
ensure_required_commands || echo "Continuando aunque no se instalaron todas las dependencias; algunas operaciones pueden fallar."

# --- Mostrar discos disponibles ---
echo -e "\nDiscos disponibles:"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "disk|"
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
select DISTRO in "Arch" "Gentoo" "Debian" "Venom"; do
    case $DISTRO in
        Arch)   ./distros/arch.sh "$DISK"; break ;;
        Gentoo) ./distros/gentoo.sh "$DISK"; break ;;
        Debian) ./distros/debian.sh "$DISK"; break ;;
        Venom) ./distros/venom.sh "$DISK"; break ;;
        *) echo "Opción no válida."; exit 1 ;;
    esac
done
rm /mnt/etc/os-release
cat > /mnt/etc/os-release << EOF
NAME="Linux From Tallbar"
PRETTY_NAME="LFT Beta 1.1 RC1 ($DISTRO Backend)"
ID=lft
VERSION_ID="1.1"
EOF

echo -e "\n[+] Instalación completada. 
-- Advertencia
El sistema apenas esta en la etapa de bootstrap con agregados,por favor completar el resto manualmente."
