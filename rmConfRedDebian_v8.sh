#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v8.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v8.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v8.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script: rmConfRedDebian_v8.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250923-2315
# Objetivo: Configuración minimalista de red en Debian 12
# ==============================================================

# --- Asegurar ejecución como root ---
if [ "$EUID" -ne 0 ]; then
  echo "🔒 Reejecutando con sudo..."
  exec sudo bash "$0" "$@"
fi

# --- Valores predeterminados ---
DEF_IP="10.0.10.3/24"
DEF_GW="10.0.10.1"
DEF_DNS1="8.8.8.8"
DEF_DNS2="1.1.1.1"
DEF_DNS3="9.9.9.9"

# --- Obtener estado de una interfaz ---
estado_iface() {
  local iface=$1
  local netfile="/etc/systemd/network/10-$iface.network"
  local mode="STATIC"
  local ip gw dns1 dns2 dns3

  if [ -f "$netfile" ]; then
    grep -q "DHCP=yes" "$netfile" && mode="DHCP"
    ip=$(grep -m1 "^Address=" "$netfile" | cut -d= -f2)
    gw=$(grep -m1 "^Gateway=" "$netfile" | cut -d= -f2)
    dns1=$(grep -m1 "^DNS=" "$netfile" | cut -d= -f2)
    dns2=$(grep -m2 "^DNS=" "$netfile" | tail -n1 | cut -d= -f2)
    dns3=$(grep -m3 "^DNS=" "$netfile" | tail -n1 | cut -d= -f2)
  else
    mode="DHCP"
  fi

  echo "$mode;$ip;$gw;$dns1;$dns2;$dns3"
}

# --- Submenú de configuración ---
submenu_config() {
  local IFACE=$1
  local mode ip gw dns1 dns2 dns3
  IFS=";" read mode ip gw dns1 dns2 dns3 <<< "$(estado_iface "$IFACE")"

  ip=${ip:-$DEF_IP}
  gw=${gw:-$DEF_GW}
  dns1=${dns1:-$DEF_DNS1}
  dns2=${dns2:-$DEF_DNS2}
  dns3=${dns3:-""}

  while true; do
    echo
    echo "⚙ Configuración para $IFACE:"
    echo "  1) Modo  [$mode]"
    echo "  2) IP    [${ip}]"
    echo "  3) GW    [${gw}]"
    echo "  4) DNS1  [${dns1}]"
    echo "  5) DNS2  [${dns2}]"
    echo "  6) DNS3  [${dns3}]"
    echo "  7) Aplicar configuración"
    echo "  8) Regresar al menú de interfaces"
    read -p "Seleccione opción [7]: " OPC
    OPC=${OPC:-7}

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
      2) read -p "Dirección IP [${ip}]: " val; ip=${val:-$ip} ;;
      3) read -p "Gateway [${gw}]: " val; gw=${val:-$gw} ;;
      4) read -p "DNS1 [${dns1}]: " val; dns1=${val:-$dns1} ;;
      5) read -p "DNS2 [${dns2}]: " val; dns2=${val:-$dns2} ;;
      6) read -p "DNS3 [${dns3}]: " val; dns3=${val:-$dns3} ;;
      7)
        NET_CONF="/etc/systemd/network/10-$IFACE.network"
        if [ "$mode" = "DHCP" ]; then
          cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
DHCP=yes
EOF
        else
          cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
Address=$ip
Gateway=$gw
DNS=$dns1
DNS=$dns2
DNS=$dns3
EOF
        fi
        systemctl enable systemd-networkd --now
        systemctl restart systemd-networkd
        systemctl restart systemd-resolved
        echo "✅ Configuración aplicada en $IFACE"
        return
        ;;
      8) echo "↩ Regresando al menú de interfaces..."; return ;;
      *) echo "❌ Opción inválida." ;;
    esac
  done
}

# --- Menú principal ---
while true; do
  IFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)'))
  echo
  echo "Interfaces detectadas:"
  i=1
  for nic in "${IFACES[@]}"; do
    IFS=";" read mode ip gw dns1 dns2 dns3 <<< "$(estado_iface "$nic")"
    if [ "$mode" = "STATIC" ]; then
      echo "  $i) $nic [$mode] --> IP: ${ip:-N/A}; GW: ${gw:-N/A}; DN1: ${dns1:-}; DN2: ${dns2:-}"
    else
      echo "  $i) $nic [$mode]"
    fi
    ((i++))
  done
  echo "  $i) Salir"

  read -p "Seleccione la opción [1]: " SEL
  SEL=${SEL:-1}

  if [ "$SEL" -eq "$i" ]; then
    echo "👋 Saliendo..."
    break
  fi

  IFACE="${IFACES[$((SEL-1))]}"

  if [ -n "$IFACE" ]; then
    submenu_config "$IFACE"
  else
    echo "❌ Opción inválida."
  fi
done

echo "✅ Configuración finalizada."

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



