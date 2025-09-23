#!/bin/bash

# LIc. Ricardo MONLA (https://github.com/ricardomonla)
#
# rmConfRedDebian_v1.sh - v250923-1824
#
# rmCMD=rmConfRedDebian_v1.sh && sh -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/${rmCMD})"

rmCMD="rmConfRedDebian_v1.sh"

cat << 'SHELL' > "${rmCMD}"
#!/bin/bash
# ==============================================================
# Script: rmConfRedDebian_v1.sh
# Objetivo: Configurar IP estática en Debian 12 (interactivo)
# ==============================================================

# Valores predeterminados
DEF_IP="10.0.10.3/24"
DEF_GW="10.0.10.1"
DEF_DNS1="8.8.8.8"
DEF_DNS2="1.1.1.1"

# Detectar la primera interfaz de red física activa
DEF_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)' | head -n1)

echo "=============================================================="
echo " Configuración de Red - Debian 12"
echo "=============================================================="

# Preguntar interfaz
read -p "Interfaz de red [${DEF_IFACE}]: " IFACE
IFACE=${IFACE:-$DEF_IFACE}

if [ -z "$IFACE" ]; then
    echo "❌ No se especificó ninguna interfaz válida."
    exit 1
fi

# Preguntar parámetros de red
read -p "Dirección IP (con máscara) [${DEF_IP}]: " IP
IP=${IP:-$DEF_IP}

read -p "Gateway [${DEF_GW}]: " GW
GW=${GW:-$DEF_GW}

read -p "DNS1 [${DEF_DNS1}]: " DNS1
DNS1=${DNS1:-$DEF_DNS1}

read -p "DNS2 [${DEF_DNS2}]: " DNS2
DNS2=${DNS2:-$DEF_DNS2}

echo
echo "⚙️ Aplicando configuración..."
echo "   Interfaz : $IFACE"
echo "   IP       : $IP"
echo "   Gateway  : $GW"
echo "   DNS      : $DNS1, $DNS2"
echo

# Crear archivo de configuración para systemd-networkd
NET_CONF="/etc/systemd/network/10-$IFACE.network"

cat > $NET_CONF <<EOF
[Match]
Name=$IFACE

[Network]
Address=$IP
Gateway=$GW
DNS=$DNS1
DNS=$DNS2
EOF

echo "✅ Archivo de configuración generado en: $NET_CONF"

# Habilitar y reiniciar servicios
systemctl enable systemd-networkd --now
systemctl restart systemd-networkd
systemctl restart systemd-resolved

echo "✅ Configuración aplicada. Verificando..."
echo "--------------------------------------------------------------"
ip addr show dev $IFACE
echo "--------------------------------------------------------------"
ip route show
echo "--------------------------------------------------------------"
systemd-resolve --status | grep "DNS Servers" -A2

SHELL

# Dar permisos de ejecución al script
chmod +x "${rmCMD}"

# Ejecutar el script
./"${rmCMD}"



