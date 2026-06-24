# LFT Installer

## ¿Qué es LFT?

LFT, que por sus abreviaturas significa "Linux From Tallbar", es una especie de "distribución", o más precisamente un instalador que permite desplegar sistemas Linux basados en bootstrap de forma sencilla.

Actualmente soporta:

* Arch Linux
* Gentoo
* Debian
- (Y proximamente Venom Linux tambien)

El objetivo de LFT es proporcionar una forma simple de instalar distintas distribuciones desde una única herramienta basada en terminal.

## Instalación

Clona el repositorio:

```bash
git clone https://github.com/carlitos20251/LFT-installer.git
cd LFT-installer
```

Otorga permisos de ejecución:

```bash
chmod +x install.sh
chmod +x distros/*
```

Ejecuta el instalador:

```bash
./install.sh
```

## Advertencia

LFT borrará completamente el disco seleccionado durante la instalación.

Asegúrate de realizar copias de seguridad antes de continuar.
