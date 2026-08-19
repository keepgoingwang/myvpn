#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="/opt/my-vpn"
CONFIG_DIR="/etc/sing-box"
ENV_FILE="${PROJECT_DIR}/server.env"
CONFIG_FILE="${CONFIG_DIR}/config.json"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: ${ENV_FILE} not found."
    exit 1
fi

source "${ENV_FILE}"


echo "======================================"
echo "       APPLY VPN SERVER CONFIG"
echo "======================================"


echo
echo "[1/6] Validating configuration..."

if [[ -z "${SERVER_PORT}" ]]; then
    echo "ERROR: SERVER_PORT is empty."
    exit 1
fi

if [[ -z "${SS_METHOD}" ]]; then
    echo "ERROR: SS_METHOD is empty."
    exit 1
fi

if [[ -z "${SS_PASSWORD}" ]]; then

    echo "Generating Shadowsocks password..."

    SS_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"

    sed -i \
        "s|^SS_PASSWORD=.*|SS_PASSWORD=${SS_PASSWORD}|" \
        "${ENV_FILE}"

fi


if [[ -z "${NODE_NAME}" ]]; then
    NODE_NAME="US-Aliyun"
fi


echo
echo "[2/6] Detecting public IP..."

if [[ -z "${PUBLIC_IP}" ]]; then

    PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me)"

    sed -i \
        "s|^PUBLIC_IP=.*|PUBLIC_IP=${PUBLIC_IP}|" \
        "${ENV_FILE}"

fi

echo "Public IP: ${PUBLIC_IP}"


echo
echo "[3/6] Generating sing-box server config..."

cat > "${CONFIG_FILE}" <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "shadowsocks-in",
      "listen": "::",
      "listen_port": ${SERVER_PORT},
      "method": "${SS_METHOD}",
      "password": "${SS_PASSWORD}"
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

chmod 600 "${CONFIG_FILE}"


echo
echo "[4/6] Formatting configuration..."

sing-box format \
    -w \
    -c "${CONFIG_FILE}"


echo
echo "[5/6] Checking configuration..."

sing-box check \
    -c "${CONFIG_FILE}"


echo
echo "[6/6] Restarting sing-box..."

systemctl enable sing-box
systemctl restart sing-box

sleep 2

if ! systemctl is-active --quiet sing-box; then

    echo
    echo "ERROR: sing-box failed to start."

    systemctl status sing-box --no-pager || true

    exit 1

fi


echo
echo "======================================"
echo " VPN SERVER CONFIG APPLIED"
echo "======================================"

echo
echo "Server:"
echo "  ${PUBLIC_IP}:${SERVER_PORT}"

echo
echo "Method:"
echo "  ${SS_METHOD}"

echo
echo "Node:"
echo "  ${NODE_NAME}"

echo
echo "sing-box:"
echo "  RUNNING"

echo