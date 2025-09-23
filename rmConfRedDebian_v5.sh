#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v5.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v5.sh && bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v5.sh"

cat << 'SHELL' > "${rmCMD}"
#!/usr/bin/env bash
# ==============================================================
# Script: rmConfRedDebian_v5.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250923-2140
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

# --- Submenú de configuración ---
submenu_interfaz() {
  CFG_MODE="static"
  CFG_IP="$DEF_IP"
  CFG_GW="$DEF_GW"
  CFG_DNS1="$DEF_DNS1"
  CFG_DNS2="$DEF_DNS2"

  while true; do
    echo
    echo "⚙️ Configuración temporal para $IFACE:"
    echo "  1) Modo (actual: $CFG_MODE)"
    echo "  2) IP     (actual: $CFG_IP)"
    echo "  3) GW     (actual: $CFG_GW)"
    echo "  4) DNS1   (actual: $CFG_DNS1)"
    echo "  5) DNS2   (actual: $CFG_DNS2)"
    echo "  6) Guardar cambios"
    echo "  7) Salir (sin guardar)"
    read -p "Seleccione opción [6]: " OPT
    OPT=${OPT:-6}

    case $OPT in
      1) read -p "Modo (static/dhcp) [$CFG_MODE]: " TMP; CFG_MODE=${TMP:-$CFG_MODE} ;;
      2) read -p "Dirección IP (con máscara) [$CFG_IP]: " TMP; CFG_IP=${TMP:-$CFG_IP} ;;
      3) read -p "Gateway [$CFG_GW]: " TMP; CFG_GW=${TMP:-$CFG_GW} ;;
      4) read -p "DNS1 [$CFG_DNS1]: " TMP; CFG_DNS1=${TMP:-$CFG_DNS1} ;;
      5) read -p "DNS2 [$CFG_DNS2]: " TMP; CFG_DNS2=${TMP:-$CFG_DNS2} ;;
      6) aplicar_config; return ;;
      7) echo "❌ Saliendo sin guardar cambios."; return ;;
      *) echo "❌ Opción inválida" ;;
    esac
  done
}

# --- Aplicar configuración ---
aplicar_config() {
  NET_CONF="/etc/systemd/network/10-$IFACE.network"

  if [ "$CFG_MODE" = "dhcp" ]; then
    cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
DHCP=yes
EOF
    echo "✅ Configuración DHCP aplicada a $IFACE"
  else
    if ip_duplicada "$CFG_IP"; then
      echo "❌ La IP $CFG_IP ya está configurada en otra interfaz."
      return
    fi
    if existe_gateway && [ -n "$CFG_GW" ]; then
      echo "❌ Ya existe un default gateway configurado. Este no será aplicado."
      CFG_GW=""
    fi

    cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
Address=$CFG_IP
EOF
    [ -n "$CFG_GW" ] && echo "Gateway=$CFG_GW" >> "$NET_CONF"
    echo "DNS=$CFG_DNS1" >> "$NET_CONF"
    echo "DNS=$CFG_DNS2" >> "$NET_CONF"

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
  elegir_iface
  if validar_iface "$IFACE"; then
    submenu_interfaz
  else
    echo "❌ Interfaz inválida."
  fi
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



