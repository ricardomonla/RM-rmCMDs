#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v4.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v4.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v4.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script: rmConfRedDebian_v4.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250923-2045
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

# --- Mostrar DNS de forma portable ---
mostrar_dns() {
  if command -v resolvectl >/dev/null 2>&1; then
    resolvectl status | grep "DNS Servers" -A2
  elif command -v systemd-resolve >/dev/null 2>&1; then
    systemd-resolve --status | grep "DNS Servers" -A2
  else
    echo "❌ No se encontró resolvectl ni systemd-resolve"
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

# --- Chequear IP duplicada ---
ip_duplicada() {
  EXISTE=$(ip -o addr show | awk '{print $4}' | grep -w "$1")
  [[ -n "$EXISTE" ]] && return 0 || return 1
}

# --- Chequear si ya hay gateway ---
existe_gateway() {
  ip route | grep -q "^default via"
}

# --- Elegir interfaz ---
elegir_iface() {
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
}

# --- Configurar una interfaz ---
configurar_interfaz() {
  elegir_iface

  if ! validar_iface "$IFACE"; then
    echo "❌ La interfaz $IFACE no existe."
    return
  fi

  echo "1) Configurar (static/dhcp)"
  echo "2) Desconfigurar (borrar)"
  read -p "Seleccione opción [1]: " OPC
  OPC=${OPC:-1}

  NET_CONF="/etc/systemd/network/10-$IFACE.network"

  if [ "$OPC" = "2" ]; then
    rm -f "$NET_CONF"
    systemctl restart systemd-networkd
    echo "✅ Configuración eliminada de $IFACE"
    return
  fi

  # Seleccionar modo de configuración
  read -p "Modo de configuración (static/dhcp) [static]: " MODE
  MODE=${MODE:-static}

  if [ "$MODE" = "dhcp" ]; then
    cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
DHCP=yes
EOF
    echo "✅ Configuración DHCP aplicada a $IFACE"
  else
    read -p "Dirección IP (con máscara) [${DEF_IP}]: " IP
    IP=${IP:-$DEF_IP}

    if ip_duplicada "$IP"; then
      echo "❌ La IP $IP ya está configurada en otra interfaz."
      return
    fi

    read -p "Gateway [${DEF_GW}]: " GW
    GW=${GW:-$DEF_GW}

    if existe_gateway && [ -n "$GW" ]; then
      echo "❌ Ya existe un default gateway configurado. Este no será aplicado."
      GW=""
    fi

    read -p "DNS1 [${DEF_DNS1}]: " DNS1
    DNS1=${DNS1:-$DEF_DNS1}

    read -p "DNS2 [${DEF_DNS2}]: " DNS2
    DNS2=${DNS2:-$DEF_DNS2}

    cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
Address=$IP
EOF
    [ -n "$GW" ] && echo "Gateway=$GW" >> "$NET_CONF"
    echo "DNS=$DNS1" >> "$NET_CONF"
    echo "DNS=$DNS2" >> "$NET_CONF"

    echo "✅ Configuración STATIC aplicada a $IFACE"
  fi

  systemctl enable systemd-networkd --now
  systemctl restart systemd-networkd
  systemctl restart systemd-resolved

  echo "--------------------------------------------------------------"
  echo "✅ Verificación de red para $IFACE:"
  ip addr show dev $IFACE
  ip route show
  mostrar_dns
  echo "--------------------------------------------------------------"
}

# --- Bucle principal ---
mostrar_resumen
while true; do
  configurar_interfaz
  read -p "¿Desea configurar otra interfaz? (s/n): " RESP
  case $RESP in
    [Ss]*) mostrar_resumen; continue ;;
    *) break ;;
  esac
done

echo "✅ Configuración finalizada."

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



