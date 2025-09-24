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
# Versión: v250924-0015
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
DEF_DNS3=""

# --- Banner ---
banner() {
  clear
  echo -e "${BOLD}${CYAN}==============================================================${RESET}"
  echo -e "${BOLD}${GREEN} Script: rmConfRedDebian${RESET}"
  echo -e "${BOLD}${GREEN} Autor : Lic. Ricardo MONLA (https://github.com/ricardomonla)${RESET}"
  echo -e "${BOLD}${GREEN} Vers. : v250924-0015${RESET}"
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

# --- Guardar configuración ---
guardar_config() {
  local iface=$1
  local mode=$2
  local ip=$3
  local dnsline=$4
  local NET_CONF="/etc/systemd/network/10-$iface.network"

  if [ "$mode" = "DHCP" ]; then
    cat > "$NET_CONF" <<EOF
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
      echo "Address=$ip"
      for d in $(echo "$dnsline" | tr ',' ' '); do
        [ -n "$d" ] && echo "DNS=$d"
      done
    } > "$NET_CONF"
  fi
  systemctl enable systemd-networkd --now
  systemctl restart systemd-networkd
  systemctl restart systemd-resolved
  echo -e "${GREEN}✅ Configuración aplicada en $iface${RESET}"
}

# --- Submenú de configuración ---
submenu_config() {
  local IFACE=$1
  while true; do
    clear
    IFS=";" read mode ip gw dnsline ip_actual <<< "$(estado_iface "$IFACE")"
    ip=${ip:-$DEF_IP}
    gw=${gw:-$DEF_GW}
    dnsline=${dnsline:-"$DEF_DNS1,$DEF_DNS2,$DEF_DNS3"}

    echo -e "${C_CYAN}⚙ Configuración para ${C_YELLOW}$IFACE${C_RESET}"
    echo "--------------------------------------------------------------"
    if [ "$mode" = "DHCP" ]; then
      echo "  1) Modo:  DHCP (IP activa: ${ip_actual:-N/A})"
      echo "  2) Cambiar modo (STATIC/DHCP)"
      echo "  3) Regresar al menú de interfaces"
      read -p "Seleccione opción [3]: " OPC
      OPC=${OPC:-3}
      case $OPC in
        1|2)
          echo "1) STATIC"
          echo "2) DHCP"
          read -p "Seleccione modo [2]: " MSEL
          case $MSEL in
            1) mode="STATIC";;
            2) mode="DHCP";;
          esac
          ;;
        3) return ;;
        *) echo "❌ Opción inválida." ;;
      esac
    else
      echo "  1) Modo  [$mode]"
      echo "  2) IP    [$ip]"
      echo "  3) DNS   [$dnsline]"
      echo "  4) Aplicar configuración"
      echo "  5) Regresar al menú de interfaces"
      read -p "Seleccione opción [4]: " OPC
      OPC=${OPC:-4}
      case $OPC in
        1)
          echo "1) STATIC"
          echo "2) DHCP"
          read -p "Seleccione modo [1]: " MSEL
          case $MSEL in
            2) mode="DHCP";;
            *) mode="STATIC";;
          esac
          ;;
        2) read -p "Dirección IP [$ip]: " val; ip=${val:-$ip} ;;
        3) read -p "DNS separados por coma [$dnsline]: " val; dnsline=${val:-$dnsline} ;;
        4)
          NET_CONF="/etc/systemd/network/10-$IFACE.network"
          if [ "$mode" = "DHCP" ]; then
            cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
DHCP=yes
EOF
            ip addr flush dev "$IFACE"   # 🔑 Limpia IP previa
          else
            {
              echo "[Match]"
              echo "Name=$IFACE"
              echo
              echo "[Network]"
              echo "Address=$ip"
              for d in $(echo "$dnsline" | tr ',' ' '); do
                [ -n "$d" ] && echo "DNS=$d"
              done
              [ -n "$gw" ] && echo "Gateway=$gw"
            } > "$NET_CONF"
            ip addr flush dev "$IFACE"
          fi
          systemctl restart systemd-networkd
          systemctl restart systemd-resolved
          sleep 2
          IFS=";" read mode ip gw dnsline ip_actual <<< "$(estado_iface "$IFACE")"
          echo -e "${C_GREEN}✅ Configuración aplicada en $IFACE${C_RESET}"
          read -p "Presione ENTER para continuar..."
          ;;
        5) return ;;
        *) echo "❌ Opción inválida." ;;
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



