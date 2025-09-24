#!/bin/bash

# Lic. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmCambiaNombreHost.sh - v250924-1107
#
# rmCMD=rmCambiaNombreHost.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/rmCambiaNombreHost/${rmCMD})"

rmCMD="rmCambiaNombreHost.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script de Cambio de Hostname en Debian 12
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# ==============================================================

# --- Variables de Identificación ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="v250924-1107"

# --- Colores ---
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# --- Asegurar ejecución como root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}🔒 Reejecutando con sudo...${RESET}"
  exec sudo bash "$0" "$@"
fi

# --- Banner ---
banner() {
  clear
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
  echo -e "${BOLD}${GREEN} Script: $SCRIPT_NAME${RESET}"
  echo -e "${BOLD}${GREEN} Autor : Lic. Ricardo MONLA (https://github.com/ricardomonla)${RESET}"
  echo -e "${BOLD}${GREEN} Vers. : $SCRIPT_VERSION${RESET}"
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
}

# --- Mostrar comparativa ---
mostrar_diff() {
  local cur=$1 new=$2
  echo -e "${BOLD}${BLUE}📊 Cambios detectados:${RESET}"
  if [ "$cur" != "$new" ]; then
    echo -e "  Hostname: ${GREEN}${cur}${RESET} -> ${MAGENTA}${new}${RESET}"
  else
    echo -e "  Hostname: ${GREEN}${cur}${RESET}"
  fi
}

# --- Guardar configuración ---
guardar_config() {
  local new=$1
  hostnamectl set-hostname "$new"
  echo "$new" > /etc/hostname

  # Actualizar /etc/hosts
  if grep -q "127.0.1.1" /etc/hosts; then
    sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$new/" /etc/hosts
  else
    echo -e "127.0.1.1\t$new" >> /etc/hosts
  fi

  echo -e "${GREEN}✅ Hostname cambiado exitosamente a: $new${RESET}"
  sleep 2
}

# --- Menú principal ---
submenu_hostname() {
  local cur_host=$(hostnamectl --static)
  local new_host=$cur_host

  while true; do
    banner
    echo -e "${BOLD}${BLUE}⚙ Configuración de Hostname:${RESET}"
    echo "  1) Hostname actual: [$new_host]"

    local CHANGES=0
    [[ "$cur_host" != "$new_host" ]] && CHANGES=1

    if [ $CHANGES -eq 1 ]; then
      echo "  9) Aplicar configuración"
      mostrar_diff "$cur_host" "$new_host"
    fi
    echo "  0) Salir"

    read -p "Seleccione opción [0]: " OPC
    OPC=${OPC:-0}

    case $OPC in
      1) 
        read -p "Nuevo hostname [$new_host]: " val
        new_host=${val:-$new_host}
        ;;
      9) 
        if [ $CHANGES -eq 1 ]; then
          guardar_config "$new_host"
          return
        fi
        ;;
      0) return ;;
      *) echo -e "${RED}❌ Opción inválida.${RESET}" ;;
    esac
    read -p "Presione Enter para continuar..." _
  done
}

# --- Ejecución ---
submenu_hostname
echo -e "${GREEN}✅ Configuración finalizada.${RESET}"

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"
