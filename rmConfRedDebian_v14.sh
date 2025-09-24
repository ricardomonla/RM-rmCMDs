#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v14.sh - v250924-0908
#
# rmCMD=rmConfRedDebian_v14.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v14.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script de Configuración minimalista de red en Debian 12
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# ==============================================================

# --- Variables de Identificación ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="v250924-0908"

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

# --- Valores predeterminados ---
DEF_IP="10.0.10.3/24"
DEF_GW="10.0.10.1"
DEF_DNS1="8.8.8.8"
DEF_DNS2="1.1.1.1"
DEF_DNS3="9.9.9.9"

# --- Banner ---
banner() {
  clear
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
  echo -e "${BOLD}${GREEN} Script: $SCRIPT_NAME${RESET}"
  echo -e "${BOLD}${GREEN} Autor : Lic. Ricardo MONLA (https://github.com/ricardomonla)${RESET}"
  echo -e "${BOLD}${GREEN} Vers. : $SCRIPT_VERSION${RESET}"
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
}

# --- Obtener estado de una interfaz ---
estado_iface() {
  local iface=$1
  local netfile="/etc/systemd/network/10-$iface.network"
  local mode="DHCP"
  local ip gw dnsline

  if [ -f "$netfile" ]; then
    if grep -q "DHCP=yes" "$netfile"; then
      mode="DHCP"
    else
      mode="STATIC"
      ip=$(grep -m1 "^Address=" "$netfile" | cut -d= -f2)
      gw=$(grep -m1 "^Gateway=" "$netfile" | cut -d= -f2)
      dnsline=$(grep "^DNS=" "$netfile" | cut -d= -f2 | tr '\n' ',' | sed 's/,$//')
    fi
  fi

  # IP actual si la tiene
  ip_actual=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | head -n1)

  echo "$mode;$ip;$gw;$dnsline;$ip_actual"
}

# --- Mostrar comparativa de configuración ---
mostrar_diff_config() {
  local iface=$1
  local new_mode=$2
  local new_ip=$3
  local new_dnsline=$4

  IFS=";" read cur_mode cur_ip cur_gw cur_dns cur_ip_actual <<< "$(estado_iface "$iface")"

  echo -e "${BOLD}${BLUE}📊 Comparativa configuración para $iface:${RESET}"
  echo -e "  Modo:     ${GREEN}${cur_mode}${RESET} -> ${MAGENTA}${new_mode}${RESET}"
  echo -e "  IP:       ${GREEN}${cur_ip:-$cur_ip_actual:-N/A}${RESET} -> ${MAGENTA}${new_ip:-N/A}${RESET}"
  echo -e "  DNS:      ${GREEN}${cur_dns:-N/A}${RESET} -> ${MAGENTA}${new_dnsline:-N/A}${RESET}"
}

# --- Guardar configuración ---
guardar_config() {
  local iface=$1
  local mode=$2
  local ip=$3
  local dnsline=$4
  local NET_CONF="/etc/systemd/network/10-$iface.network"

  # Mostrar comparativa antes de aplicar
  mostrar_diff_config "$iface" "$mode" "$ip" "$dnsline"
  read -p "¿Aplicar cambios? (s/N): " CONFIRM
  [[ "$CONFIRM" =~ ^[sS]$ ]] || { echo -e "${RED}❌ Cancelado.${RESET}"; return; }

  if [ "$mode" = "DHCP" ]; then
    cat > "$NET_CONF" <<EOF
[Match]
Name=$iface

[Network]
DHCP=yes
EOF
  else
    cat > "$NET_CONF" <<EOF
[Match]
Name=$iface

[Network]
Address=$ip
EOF
    for d in $(echo "$dnsline" | tr ',' ' '); do
      [ -n "$d" ] && echo "DNS=$d" >> "$NET_CONF"
    done
  fi

  systemctl enable systemd-networkd --now
  systemctl restart systemd-networkd
  systemctl restart systemd-resolved
  sleep 2
  echo -e "${GREEN}✅ Configuración aplicada en $iface${RESET}"
}

# --- Submenú de configuración ---
submenu_config() {
  local IFACE=$1
  local mode ip gw dnsline ip_actual
  IFS=";" read mode ip gw dnsline ip_actual <<< "$(estado_iface "$IFACE")"

  ip=${ip:-$DEF_IP}
  gw=${gw:-$DEF_GW}
  dnsline=${dnsline:-"$DEF_DNS1,$DEF_DNS2,$DEF_DNS3"}

  while true; do
    banner
    IFS=";" read mode ip gw dnsline ip_actual <<< "$(estado_iface "$IFACE")"

    echo -e "${BOLD}${BLUE}⚙ Configuración para $IFACE:${RESET}"
    if [ "$mode" = "DHCP" ]; then
      echo "  1) Cambiar a STATIC"
      echo "  2) Aplicar configuración"
      echo "  3) Regresar"
      read -p "Seleccione opción [3]: " OPC
      OPC=${OPC:-3}
      case $OPC in
        1) mode="STATIC";;
        2) guardar_config "$IFACE" "$mode" "$ip" "$dnsline";;
        3) return;;
        *) echo -e "${RED}❌ Opción inválida.${RESET}";;
      esac
    else
      echo "  1) Cambiar a DHCP"
      echo "  2) Dirección IP [$ip]"
      echo "  3) DNS [$dnsline]"
      echo "  4) Aplicar configuración"
      echo "  5) Regresar"
      read -p "Seleccione opción [5]: " OPC
      OPC=${OPC:-5}
      case $OPC in
        1) mode="DHCP";;
        2) read -p "Dirección IP [$ip]: " val; ip=${val:-$ip};;
        3) read -p "DNS separados por coma [$dnsline]: " val; dnsline=${val:-$dnsline};;
        4) guardar_config "$IFACE" "$mode" "$ip" "$dnsline";;
        5) return;;
        *) echo -e "${RED}❌ Opción inválida.${RESET}";;
      esac
    fi
    read -p "Presione Enter para continuar..." _
  done
}

# --- Menú principal ---
while true; do
  banner
  IFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)'))
  echo -e "${BOLD}${YELLOW}Interfaces detectadas:${RESET}"
  i=1
  for nic in "${IFACES[@]}"; do
    IFS=";" read mode ip gw dnsline ip_actual <<< "$(estado_iface "$nic")"
    if [ "$mode" = "STATIC" ]; then
      echo "  $i) $nic [$mode] --> IP: ${ip:-N/A}; DNS: ${dnsline:-N/A}"
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
    ip route replace default via "$NEWGW"
    echo -e "${GREEN}✅ Gateway actualizado a $NEWGW${RESET}"
    read -p "Presione Enter para continuar..." _
    continue
  fi

  IFACE="${IFACES[$((SEL-1))]}"
  [ -n "$IFACE" ] && submenu_config "$IFACE" || echo -e "${RED}❌ Opción inválida.${RESET}"
done

echo -e "${GREEN}✅ Configuración finalizada.${RESET}"

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



