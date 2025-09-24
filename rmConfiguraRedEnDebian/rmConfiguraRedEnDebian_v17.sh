#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfiguraRedEnDebian_v17: v250924-1946
#
# rmCMD=rmConfiguraRedEnDebian_v17.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/rmConfiguraRedEnDebian/${rmCMD})"

rmCMD="rmConfiguraRedEnDebian_v17.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script de Configuración minimalista de red en Debian 12
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250924-2300
# ==============================================================

# --- Variables de Identificación ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="v250924-2300"

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
  echo -e "${GREEN}🔒 Reejecutando con sudo...${RESET}"
  exec sudo bash "$0" "$@"
fi

# --- Valores predeterminados ---
DEF_IP="10.0.10.3/24"
DEF_GW="10.0.10.1"
DEF_DNS1="8.8.8.8"
DEF_DNS2="1.1.1.1"
DEF_DNS3="9.9.9.9"
GW_FILE="/etc/systemd/network/99-default-gateway.network"

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

  ip_actual=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | head -n1)

  echo "$mode;$ip;$gw;$dnsline;$ip_actual"
}

# --- Mostrar comparativa ---
mostrar_diff_config() {
  local cur_mode=$1 cur_ip=$2 cur_dns=$3 cur_gw=$4
  local new_mode=$5 new_ip=$6 new_dns=$7 new_gw=$8

  echo -e "${BOLD}${BLUE}📊 Cambios detectados:${RESET}"
  if [ "$cur_mode" != "$new_mode" ]; then
    echo -e "  Modo: ${GREEN}${cur_mode}${RESET} -> ${MAGENTA}${new_mode}${RESET}"
  else
    echo -e "  Modo: ${GREEN}${cur_mode}${RESET}"
  fi
  if [ "$cur_ip" != "$new_ip" ]; then
    echo -e "  IP:   ${GREEN}${cur_ip:-N/A}${RESET} -> ${MAGENTA}${new_ip:-N/A}${RESET}"
  else
    echo -e "  IP:   ${GREEN}${cur_ip:-N/A}${RESET}"
  fi
  if [ "$cur_dns" != "$new_dns" ]; then
    echo -e "  DNS:  ${GREEN}${cur_dns:-N/A}${RESET} -> ${MAGENTA}${new_dns:-N/A}${RESET}"
  else
    echo -e "  DNS:  ${GREEN}${cur_dns:-N/A}${RESET}"
  fi
  if [ "$cur_gw" != "$new_gw" ]; then
    echo -e "  GW:   ${GREEN}${cur_gw:-N/A}${RESET} -> ${MAGENTA}${new_gw:-N/A}${RESET}"
  else
    echo -e "  GW:   ${GREEN}${cur_gw:-N/A}${RESET}"
  fi
}

# --- Guardar configuración de interfaz ---
guardar_config() {
  local iface=$1
  local mode=$2
  local ip=$3
  local dnsline=$4
  local gw=$5
  local NET_CONF="/etc/systemd/network/10-$iface.network"

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
Gateway=$gw
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

# --- Guardar Gateway global ---
guardar_gateway_global() {
  local newgw=$1
  cat > "$GW_FILE" <<EOF
[Match]
# Aplica a todas las interfaces

[Network]
Gateway=$newgw
EOF

  # Eliminar rutas previas y aplicar nueva
  ip route del default 2>/dev/null
  ip route add default via "$newgw"

  systemctl daemon-reload
  systemctl restart systemd-networkd
  echo -e "${GREEN}✅ Gateway global actualizado y persistente: $newgw${RESET}"
}

# --- Submenú de configuración ---
submenu_config() {
  local IFACE=$1
  local cur_mode cur_ip cur_gw cur_dns cur_ip_actual
  IFS=";" read cur_mode cur_ip cur_gw cur_dns cur_ip_actual <<< "$(estado_iface "$IFACE")"

  # Valores editables
  local new_mode=$cur_mode
  local new_ip=${cur_ip:-$DEF_IP}
  local new_dns=${cur_dns:-"$DEF_DNS1,$DEF_DNS2,$DEF_DNS3"}
  local new_gw=${cur_gw:-$DEF_GW}

  while true; do
    banner
    echo -e "${BOLD}${BLUE}⚙ Configuración para $IFACE:${RESET}"
    echo "  1) Modo [$new_mode]"
    if [ "$new_mode" = "STATIC" ]; then
      echo "  2) Dirección IP [$new_ip]"
      echo "  3) DNS [$new_dns]"
      echo "  4) Gateway [$new_gw]"
    fi

    local CHANGES=0
    [[ "$cur_mode" != "$new_mode" || "$cur_ip" != "$new_ip" || "$cur_dns" != "$new_dns" || "$cur_gw" != "$new_gw" ]] && CHANGES=1

    if [ $CHANGES -eq 1 ]; then
      echo "  9) Aplicar configuración"
      mostrar_diff_config "$cur_mode" "$cur_ip" "$cur_dns" "$cur_gw" "$new_mode" "$new_ip" "$new_dns" "$new_gw"
    fi
    echo "  0) Regresar"

    read -p "Seleccione opción [0]: " OPC
    OPC=${OPC:-0}

    case $OPC in
      1) 
        if [ "$new_mode" = "DHCP" ]; then new_mode="STATIC"; else new_mode="DHCP"; fi
        ;;
      2) 
        if [ "$new_mode" = "STATIC" ]; then
          read -p "Dirección IP [$new_ip]: " val; new_ip=${val:-$new_ip}
        fi
        ;;
      3) 
        if [ "$new_mode" = "STATIC" ]; then
          read -p "DNS separados por coma [$new_dns]: " val; new_dns=${val:-$new_dns}
        fi
        ;;
      4)
        if [ "$new_mode" = "STATIC" ]; then
          read -p "Gateway [$new_gw]: " val; new_gw=${val:-$new_gw}
        fi
        ;;
      9) 
        if [ $CHANGES -eq 1 ]; then
          guardar_config "$IFACE" "$new_mode" "$new_ip" "$new_dns" "$new_gw"
          return
        fi
        ;;
      0) return ;;
      *) echo -e "${RED}❌ Opción inválida.${RESET}" ;;
    esac
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
      echo "  $i) $nic [$mode] --> IP: ${ip:-N/A}; GW: ${gw:-N/A}; DNS: ${dnsline:-N/A}"
    else
      echo "  $i) $nic [$mode] --> IP: ${ip_actual:-N/A}"
    fi
    ((i++))
  done

  GW_ACTUAL=$(ip route show default | awk '/default/ {print $3; exit}')
  echo "  $i) Gateway Global [${GW_ACTUAL:-$DEF_GW}]"
  ((i++))
  echo "  $i) Salir"

  read -p "Seleccione la opción [$i]: " SEL
  SEL=${SEL:-1}

  if [ "$SEL" -eq "$i" ]; then
    echo -e "${CYAN}👋 Saliendo...${RESET}"
    break
  elif [ "$SEL" -eq $((i-1)) ]; then
    read -p "Nuevo Gateway [${GW_ACTUAL:-$DEF_GW}]: " NEWGW
    NEWGW=${NEWGW:-$GW_ACTUAL}
    guardar_gateway_global "$NEWGW"
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



