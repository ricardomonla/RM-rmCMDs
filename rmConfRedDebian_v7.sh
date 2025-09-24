#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v7.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v7.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v7.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script: rmConfRedDebian_v7.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250923-2230
# Objetivo: Configuración interactiva de red en Debian 12
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

# --- Mostrar DNS de forma portable ---
mostrar_dns() {
  if command -v resolvectl >/dev/null 2>&1; then
    resolvectl status | grep "DNS Servers" -A2
  elif command -v systemd-resolve >/dev/null 2>&1; then
    systemd-resolve --status | grep "DNS Servers" -A2
  else
    grep "nameserver" /etc/resolv.conf | awk '{print $2}'
  fi
}

# --- Mostrar resumen inicial ---
mostrar_resumen() {
  echo "=============================================================="
  echo " 📋 Resumen de configuración de red actual"
  echo "=============================================================="
  ip -o addr show | awk '{print $2, $4}'
  echo "--------------------------------------------------------------"
  echo "Rutas:"
  ip route show
  echo "--------------------------------------------------------------"
  echo "DNS:"
  mostrar_dns
  echo "=============================================================="
}

# --- Validar si interfaz existe ---
validar_iface() {
  IFACES=($(ip -o link show | awk -F': ' '{print $2}'))
  for NIC in "${IFACES[@]}"; do
    [[ "$NIC" == "$1" ]] && return 0
  done
  return 1
}

# --- Configuración activa en la interfaz ---
mostrar_config_activa() {
  local iface=$1
  echo "--------------------------------------------------------------"
  echo "⚡ Configuración activa en $iface:"
  ip -o addr show dev "$iface" | awk '{print "  IP:", $4}'
  ip route show | grep -w "$iface" | grep "^default" | awk '{print "  GW:", $3}'
  echo "  DNS:"
  mostrar_dns
  echo "--------------------------------------------------------------"
}

# --- Submenú de configuración ---
submenu_config() {
  local IFACE=$1
  local MODE="static"
  local IP=$(ip -o -4 addr show dev "$IFACE" | awk '{print $4}' | head -n1)
  IP=${IP:-$DEF_IP}
  local GW=$(ip route show default 0.0.0.0/0 dev "$IFACE" 2>/dev/null | awk '{print $3}')
  GW=${GW:-$DEF_GW}
  local DNS1=$DEF_DNS1
  local DNS2=$DEF_DNS2
  local DNS3=$DEF_DNS3

  while true; do
    echo
    mostrar_config_activa "$IFACE"
    echo "⚙ Configuración temporal para $IFACE:"
    echo "  1) Modo  (actual: $MODE)"
    echo "  2) IP    (actual: $IP)"
    echo "  3) GW    (actual: $GW)"
    echo "  4) DNS1  (actual: $DNS1)"
    echo "  5) DNS2  (actual: $DNS2)"
    echo "  6) DNS3  (actual: $DNS3)"
    echo "  7) Aplicar configuración"
    echo "  8) Regresar al menú de interfaces"
    read -p "Seleccione opción [7]: " OPC
    OPC=${OPC:-7}

    case $OPC in
      1)
        echo "1) static"
        echo "2) dhcp"
        read -p "Seleccione modo [1]: " MSEL
        case $MSEL in
          2) MODE="dhcp";;
          *) MODE="static";;
        esac
        ;;
      2) read -p "Dirección IP [${IP}]: " IP; IP=${IP:-$IP} ;;
      3) read -p "Gateway [${GW}]: " GW; GW=${GW:-$GW} ;;
      4) read -p "DNS1 [${DNS1}]: " DNS1; DNS1=${DNS1:-$DNS1} ;;
      5) read -p "DNS2 [${DNS2}]: " DNS2; DNS2=${DNS2:-$DNS2} ;;
      6) read -p "DNS3 [${DNS3}]: " DNS3; DNS3=${DNS3:-$DNS3} ;;
      7)
        NET_CONF="/etc/systemd/network/10-$IFACE.network"
        if [ "$MODE" = "dhcp" ]; then
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
Address=$IP
Gateway=$GW
DNS=$DNS1
DNS=$DNS2
DNS=$DNS3
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
mostrar_resumen
while true; do
  IFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)'))
  echo "Interfaces detectadas:"
  i=1
  for nic in "${IFACES[@]}"; do
    echo "  $i) $nic"
    ((i++))
  done
  read -p "Seleccione interfaz [1]: " SEL
  SEL=${SEL:-1}
  IFACE="${IFACES[$((SEL-1))]}"

  if validar_iface "$IFACE"; then
    submenu_config "$IFACE"
  else
    echo "❌ Interfaz inválida."
  fi

  read -p "¿Desea configurar otra interfaz? (s/n): " RESP
  [[ "$RESP" =~ ^[Ss]$ ]] && continue || break
done

echo "✅ Configuración finalizada."


SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



