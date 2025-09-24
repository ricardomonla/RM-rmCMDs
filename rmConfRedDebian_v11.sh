#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v11.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v11.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v11.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script: rmConfRedDebian_v11.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250925-0824
# Objetivo: Configuración minimalista de red en Debian 12
# ==============================================================

# --- Colores ---
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# --- Asegurar ejecución como root (se relanza con sudo si es necesario) ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}🔒 Reejecutando con sudo...${RESET}"
  exec sudo bash "$0" "$@"
fi

# --- Valores predeterminados ---
DEF_IP="10.0.10.3/24"
DEF_GW="10.0.10.1"
DEF_DNS1="8.8.8.8"
DEF_DNS2="1.1.1.1"
DEF_DNS3=""

# --- Banner ---
banner() {
  clear
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
  echo -e "${BOLD}${GREEN} Script: rmConfRedDebian${RESET}"
  echo -e "${BOLD}${GREEN} Autor : Lic. Ricardo MONLA (https://github.com/ricardomonla)${RESET}"
  echo -e "${BOLD}${GREEN} Vers. : v250924-0200${RESET}"
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
}

# --- Obtener estado "activo" de una interfaz ---
# Retorna: mode;address_from_file;gateway_from_file;dnsline_from_file;ip_actual_assigned
estado_iface() {
  local iface=$1
  local netfile="/etc/systemd/network/10-$iface.network"
  local mode="DHCP"
  local addr gw dnsline ip_actual

  if [ -f "$netfile" ]; then
    if grep -q -E '^DHCP\s*=\s*yes' "$netfile" 2>/dev/null; then
      mode="DHCP"
    else
      mode="STATIC"
      addr=$(grep -m1 '^Address=' "$netfile" 2>/dev/null | cut -d= -f2-)
      gw=$(grep -m1 '^Gateway=' "$netfile" 2>/dev/null | cut -d= -f2-)
      dnsline=$(grep '^DNS=' "$netfile" 2>/dev/null | cut -d= -f2- | tr '\n' ',' | sed 's/,$//')
    fi
  fi

  ip_actual=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | head -n1)
  echo "${mode:-DHCP};${addr:-};${gw:-};${dnsline:-};${ip_actual:-}"
}

# --- Aplica y espera la nueva configuración, luego refresca estado ---
aplicar_y_refrescar() {
  local iface=$1
  local new_mode=$2
  local new_addr=$3
  local new_dnsline=$4
  local netfile="/etc/systemd/network/10-${iface}.network"

  # Escribir archivo
  if [ "$new_mode" = "DHCP" ]; then
    cat > "$netfile" <<EOF
[Match]
Name=$iface

[Network]
DHCP=yes
EOF
  else
    {
      echo "[Match]"
      echo "Name=$iface"
      echo
      echo "[Network]"
      echo "Address=$new_addr"
      for d in $(echo "$new_dnsline" | tr ',' ' '); do
        [ -n "$d" ] && echo "DNS=$d"
      done
      # No escribimos gateway global aquí; controlalo desde el menú principal si lo deseas.
    } > "$netfile"
  fi

  # Forzar limpieza de direcciones antiguas y reiniciar systemd-networkd
  ip addr flush dev "$iface" 2>/dev/null || true
  systemctl enable systemd-networkd --now
  systemctl restart systemd-networkd
  # systemd-resolved puede no existir en algunos entornos; intentar si existe
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart systemd-resolved 2>/dev/null || true
  fi

  # Esperar hasta que aparezca la IP (solo para DHCP) o confirmar la estática
  local waited=0
  local timeout=12   # segundos
  local got_ip=""
  while [ $waited -lt $timeout ]; do
    sleep 1
    ((waited++))
    got_ip=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | head -n1)
    if [ -n "$got_ip" ]; then
      break
    fi
  done

  # leer estado actualizado
  IFS=";" read new_mode_file new_addr_file new_gw_file new_dnsline_file new_ip_actual <<< "$(estado_iface "$iface")"

  # Mensaje resumen
  echo
  if [ -n "$new_ip_actual" ]; then
    echo -e "${GREEN}✅ Interfaz $iface: IP activa -> ${new_ip_actual}${RESET}"
  else
    if [ "$new_mode" = "DHCP" ]; then
      echo -e "${YELLOW}⚠️  DHCP activo, pero no se obtuvo IP en ${timeout}s.${RESET}"
    else
      echo -e "${GREEN}✅ Configuración estática aplicada: ${new_addr}${RESET}"
    fi
  fi
  echo
  # Retornar el estado actualizado (por stdout)
  echo "${new_mode_file};${new_addr_file};${new_gw_file};${new_dnsline_file};${new_ip_actual}"
}

# --- Guardar gateway global ---
guardar_gateway() {
  local gw="$1"
  if [ -z "$gw" ]; then
    echo -e "${RED}GW vacío, abortando.${RESET}"
    return 1
  fi
  ip route replace default via "$gw"
  echo -e "${GREEN}✅ Gateway actualizado a $gw${RESET}"
  return 0
}

# --- Submenú de configuración (usa variables temporales y refresca estado cuando aplica) ---
submenu_config() {
  local IFACE=$1

  # Leer estado actual
  IFS=";" read cur_mode cur_addr cur_gw cur_dnsline cur_ip_actual <<< "$(estado_iface "$IFACE")"

  # Variables temporales (para editar)
  TMP_MODE="$cur_mode"
  TMP_ADDR="${cur_addr:-$DEF_IP}"
  TMP_DNSLINE="${cur_dnsline:-${DEF_DNS1},${DEF_DNS2},${DEF_DNS3}"

  while true; do
    banner
    echo -e "${BOLD}${BLUE}⚙ Configuración para ${YELLOW}$IFACE${RESET}"
    echo

    # Mostrar estado activo (real)
    echo -e "${CYAN}Estado ACTIVO:${RESET}"
    echo "  Modo : ${cur_mode}"
    echo "  IP   : ${cur_ip_actual:-N/A}"
    [ -n "$cur_addr" ] && echo "  File : Address=${cur_addr}"
    [ -n "$cur_gw" ] && echo "  File : Gateway=${cur_gw}"
    [ -n "$cur_dnsline" ] && echo "  File : DNS=${cur_dnsline}"
    echo

    # Mostrar buffer temporal (lo que se editará)
    echo -e "${CYAN}Edición (temporal):${RESET}"
    if [ "$TMP_MODE" = "DHCP" ]; then
      echo "  1) Modo : [DHCP]"
      echo "  2) (DHCP no requiere IP/DNS locales)"
      echo "  3) Aplicar configuración"
      echo "  4) Regresar"
      read -p "Seleccione opción [4]: " opc
      opc=${opc:-4}
      case $opc in
        1)
          echo "1) STATIC"
          echo "2) DHCP"
          read -p "Seleccione modo [1]: " msel
          case $msel in
            1) TMP_MODE="STATIC";;
            2) TMP_MODE="DHCP";;
            *) TMP_MODE="DHCP";;
          esac
          ;;
        3)
          # aplicar y refrescar
          newstate=$(aplicar_y_refrescar "$IFACE" "$TMP_MODE" "$TMP_ADDR" "$TMP_DNSLINE")
          IFS=";" read cur_mode cur_addr cur_gw cur_dnsline cur_ip_actual <<< "$newstate"
          # actualizar temporales según lo que quedó en archivo
          TMP_MODE="$cur_mode"
          TMP_ADDR="${cur_addr:-$DEF_IP}"
          TMP_DNSLINE="${cur_dnsline:-${DEF_DNS1},${DEF_DNS2},${DEF_DNS3}}"
          read -p "Presione Enter para continuar..." _
          ;;
        4) return ;;
        *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
      esac
    else
      echo "  1) Modo : [${TMP_MODE}]"
      echo "  2) IP   : [${TMP_ADDR}]"
      echo "  3) DNS  : [${TMP_DNSLINE}]"
      echo "  4) Aplicar configuración"
      echo "  5) Regresar"
      read -p "Seleccione opción [4]: " opc
      opc=${opc:-4}
      case $opc in
        1)
          echo "1) STATIC"
          echo "2) DHCP"
          read -p "Seleccione modo [1]: " msel
          case $msel in
            2) TMP_MODE="DHCP";;
            *) TMP_MODE="STATIC";;
          esac
          ;;
        2) read -p "Dirección IP (con máscara) [${TMP_ADDR}]: " val; TMP_ADDR=${val:-$TMP_ADDR} ;;
        3) read -p "DNS separados por coma [${TMP_DNSLINE}]: " val; TMP_DNSLINE=${val:-$TMP_DNSLINE} ;;
        4)
          newstate=$(aplicar_y_refrescar "$IFACE" "$TMP_MODE" "$TMP_ADDR" "$TMP_DNSLINE")
          IFS=";" read cur_mode cur_addr cur_gw cur_dnsline cur_ip_actual <<< "$newstate"
          TMP_MODE="$cur_mode"
          TMP_ADDR="${cur_addr:-$DEF_IP}"
          TMP_DNSLINE="${cur_dnsline:-${DEF_DNS1},${DEF_DNS2},${DEF_DNS3}}"
          read -p "Presione Enter para continuar..." _
          ;;
        5) return ;;
        *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
      esac
    fi
  done
}

# --- Menú principal ---
while true; do
  banner
  IFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)'))
  echo -e "${BOLD}${YELLOW}Interfaces detectadas:${RESET}"
  i=1
  for nic in "${IFACES[@]}"; do
    IFS=";" read mode addr gw dnsline ip_actual <<< "$(estado_iface "$nic")"
    if [ "$mode" = "STATIC" ]; then
      echo "  $i) $nic [$mode] --> IP: ${addr:-N/A}; DNS: ${dnsline:-N/A}"
    else
      echo "  $i) $nic [$mode] --> IP: ${ip_actual:-N/A}"
    fi
    ((i++))
  done

  # Gateway global
  GW_ACTUAL=$(ip route show default | awk '/default/ {print $3; exit}')
  echo "  $i) Gateway [${GW_ACTUAL:-$DEF_GW}]"
  ((i++))
  echo "  $i) Salir"

  read -p "Seleccione la opción [1]: " SEL
  SEL=${SEL:-1}

  if [ "$SEL" -eq "$i" ]; then
    echo -e "${CYAN}👋 Saliendo...${RESET}"
    break
  elif [ "$SEL" -eq $((i-1)) ]; then
    read -p "Nuevo Gateway [${GW_ACTUAL:-$DEF_GW}]: " NEWGW
    NEWGW=${NEWGW:-$GW_ACTUAL}
    guardar_gateway "$NEWGW"
    read -p "Presione Enter para continuar..." _
    continue
  fi

  IFACE="${IFACES[$((SEL-1))]}"
  if [ -n "$IFACE" ]; then
    submenu_config "$IFACE"
  else
    echo -e "${RED}❌ Opción inválida.${RESET}"
    sleep 1
  fi
done

echo -e "${GREEN}✅ Configuración finalizada.${RESET}"


SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



