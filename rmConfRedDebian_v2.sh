#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v2.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v2.sh && sh -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v2.sh"

cat << 'SHELL' > "${rmCMD}"
#!/bin/bash
# ==============================================================
# Script: rmConfRedDebian_v1.sh
# Autor: Lic. Ricardo MONLA (https://github.com/ricardomonla)
# Versión: v250923-1930
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

# --- Función para configurar una interfaz ---
configurar_interfaz() {
  # Listar interfaces disponibles
  IFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)'))
  DEF_IFACE="${IFACES[0]}"

  echo "=============================================================="
  echo " Configuración de Red - Debian 12"
  echo "=============================================================="
  echo "Interfaces detectadas: ${IFACES[*]}"
  read -p "Seleccione interfaz a configurar [${DEF_IFACE}]: " IFACE
  IFACE=${IFACE:-$DEF_IFACE}

  if [ -z "$IFACE" ]; then
    echo "❌ No se especificó ninguna interfaz válida."
    return
  fi

  # Seleccionar modo de configuración
  read -p "Modo de configuración (static/dhcp) [static]: " MODE
  MODE=${MODE:-static}

  NET_CONF="/etc/systemd/network/10-$IFACE.network"

  if [ "$MODE" = "dhcp" ]; then
    # --- Configuración DHCP ---
    cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
DHCP=yes
EOF
    echo "✅ Configuración DHCP aplicada a $IFACE"
  else
    # --- Configuración STATIC ---
    read -p "Dirección IP (con máscara) [${DEF_IP}]: " IP
    IP=${IP:-$DEF_IP}

    read -p "Gateway [${DEF_GW}]: " GW
    GW=${GW:-$DEF_GW}

    read -p "DNS1 [${DEF_DNS1}]: " DNS1
    DNS1=${DNS1:-$DEF_DNS1}

    read -p "DNS2 [${DEF_DNS2}]: " DNS2
    DNS2=${DNS2:-$DEF_DNS2}

    cat > "$NET_CONF" <<EOF
[Match]
Name=$IFACE

[Network]
Address=$IP
Gateway=$GW
DNS=$DNS1
DNS=$DNS2
EOF
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
while true; do
  configurar_interfaz
  read -p "¿Desea configurar otra interfaz? (s/n): " RESP
  case $RESP in
    [Ss]*) continue ;;
    *) break ;;
  esac
done

echo "✅ Configuración finalizada."

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



