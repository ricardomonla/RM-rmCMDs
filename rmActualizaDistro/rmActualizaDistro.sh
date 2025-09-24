#!/bin/bash

# Lic. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmActualizaDistro: v250924-1207
#
# rmCMD=rmActualizaDistro.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/rmActualizaDistro/${rmCMD})"

rmCMD="rmActualizaDistro.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script de actualización y mantenimiento en Debian 12
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# ==============================================================

# --- Variables de Identificación ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="v250924-1207"

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

# --- Chequear si es necesario reiniciar ---
check_reboot() {
  if [ -f /var/run/reboot-required ]; then
    echo -e "${YELLOW}⚠️  El sistema requiere reinicio.${RESET}"
    return 0
  else
    echo -e "${GREEN}✅ No se requiere reinicio.${RESET}"
    return 1
  fi
}

# --- Actualizar sistema ---
update_system() {
  echo -e "${BLUE}📦 Actualizando repositorios y paquetes...${RESET}"
  apt update && apt -y full-upgrade
  check_reboot
}

# --- Limpiar sistema ---
clean_system() {
  echo -e "${BLUE}🧹 Limpiando paquetes y caché...${RESET}"
  apt -y autoremove && apt -y autoclean
  echo -e "${GREEN}✅ Limpieza completada.${RESET}"
}

# --- Reiniciar ---
reboot_system() {
  echo -e "${MAGENTA}♻️  Reiniciando el sistema...${RESET}"
  sleep 2
  reboot
}

# --- Menú principal ---
while true; do
  banner
  echo -e "${BOLD}${YELLOW}Seleccione una acción:${RESET}"
  echo "  1) Actualizar repositorios y aplicativos"
  echo "  2) Limpieza de paquetes y caché"
  echo "  3) Reiniciar el sistema"
  echo "  0) Salir"
  echo
  check_reboot
  echo
  read -p "Seleccione opción [0]: " OPC
  OPC=${OPC:-0}

  case $OPC in
    1) update_system ;;
    2) clean_system ;;
    3) reboot_system ;;
    0) echo -e "${CYAN}👋 Saliendo...${RESET}"; break ;;
    *) echo -e "${RED}❌ Opción inválida.${RESET}" ;;
  esac
  read -p "Presione Enter para continuar..." _
done

echo -e "${GREEN}✅ Proceso finalizado.${RESET}"

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"