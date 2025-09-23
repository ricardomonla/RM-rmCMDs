#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v3.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v3.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v3.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script: rmConfRedDebian_v3.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250923-2010
# Objetivo: Configuración interactiva de red en Debian 12
# ==============================================================

# --- Validar ejecución como root ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root"
  exit 1
fi

# --- Valores predeterminados ---
DEF_IP="10.0.10.3/24"
DEF_GW="10.0.10.1"
DEF_DNS1="8.8.8.8"
DEF_DNS2="1.1.1.1"

# --- Mostrar resumen actual ---
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
  systemd-resolve --status | grep "DNS Servers" -A2 | sed 's/^/   /'
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

# --- Función para configurar una interfaz ---
configurar_interfaz() {
  # Listar interfaces disponibles
  IFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)'))
  DEF_IFACE="${IFACES[0]}"

  echo "Interfaces detectadas: ${IFACES[*]}"
  read -p "Seleccione interfaz a configurar [${DEF_IFACE}]: " IFACE
  IFACE=${IFACE:-$DEF_IFACE}

  if ! validar_iface "$IFACE"; then
    echo "❌ La interfaz $IFACE no existe."
    return
  fi

  # Seleccionar acción
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

    # Validar IP duplicada
    if ip_duplicada "$IP"; then
      echo "❌ La IP $IP ya está configurada en otra interfaz."
      return
    fi

    read -p "Gateway [${DEF_GW}]: " GW
    GW=${GW:-$DEF_GW}

    # Validar que no existan múltiples gateways
    if existe_gateway && [ -n "$GW" ]; then
      echo "❌ Ya existe un default gateway configurado."
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

  # Reiniciar servicios
  systemctl enable systemd-networkd --now
  systemctl restart systemd-networkd
  systemctl restart systemd-resolved

  echo "--------------------------------------------------------------"
  echo "✅ Verificación de red para $IFACE:"
  ip addr show dev $IFACE
  ip route show
  systemd-resolve --status | grep "DNS Servers" -A2
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



