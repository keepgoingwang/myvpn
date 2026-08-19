#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="/opt/my-vpn"
ENV_FILE="${PROJECT_DIR}/server.env"
CLIENT_DIR="${PROJECT_DIR}/clients"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: ${ENV_FILE} not found."
    exit 1
fi

source "${ENV_FILE}"

mkdir -p "${CLIENT_DIR}"


echo "======================================"
echo "     GENERATE CLIENT CONFIGURATION"
echo "======================================"


echo
echo "[1/6] Validating configuration..."

if [[ -z "${PUBLIC_IP}" ]]; then

    PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me)"

fi

if [[ -z "${SS_PASSWORD}" ]]; then

    echo "ERROR: SS_PASSWORD is empty."

    exit 1

fi


echo
echo "[2/6] Generating Shadowsocks URI..."

SS_USERINFO="$(printf '%s' "${SS_METHOD}:${SS_PASSWORD}" | base64 -w 0)"

SS_URI="ss://${SS_USERINFO}@${PUBLIC_IP}:${SERVER_PORT}#${NODE_NAME}"

printf '%s\n' "${SS_URI}" \
    > "${CLIENT_DIR}/ss.txt"


echo
echo "[3/6] Generating Shadowsocks JSON..."

cat > "${CLIENT_DIR}/ss.json" <<EOF
{
  "server": "${PUBLIC_IP}",
  "server_port": ${SERVER_PORT},
  "method": "${SS_METHOD}",
  "password": "${SS_PASSWORD}"
}
EOF

chmod 600 "${CLIENT_DIR}/ss.json"


echo
echo "[4/6] Generating Clash configuration..."

cat > "${CLIENT_DIR}/clash.yaml" <<EOF
proxies:
  - name: "${NODE_NAME}"
    type: ss
    server: ${PUBLIC_IP}
    port: ${SERVER_PORT}
    cipher: ${SS_METHOD}
    password: "${SS_PASSWORD}"

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - "${NODE_NAME}"
      - DIRECT

rules:
  - MATCH,PROXY
EOF

chmod 600 "${CLIENT_DIR}/clash.yaml"


echo
echo "[5/6] Generating sing-box client configuration..."

cat > "${CLIENT_DIR}/sing-box.json" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 2080
    }
  ],
  "outbounds": [
    {
      "type": "shadowsocks",
      "tag": "proxy",
      "server": "${PUBLIC_IP}",
      "server_port": ${SERVER_PORT},
      "method": "${SS_METHOD}",
      "password": "${SS_PASSWORD}"
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "proxy"
  }
}
EOF

chmod 600 "${CLIENT_DIR}/sing-box.json"


echo
echo "[6/6] Generating subscription and QR code..."

printf '%s\n' "${SS_URI}" \
    > "${CLIENT_DIR}/subscribe.txt"

chmod 600 "${CLIENT_DIR}/subscribe.txt"


if command -v qrencode >/dev/null 2>&1; then

    qrencode \
        -o "${CLIENT_DIR}/ss.png" \
        "${SS_URI}"

    chmod 600 "${CLIENT_DIR}/ss.png"

fi


echo
echo "======================================"
echo " CLIENT CONFIGURATION READY"
echo "======================================"

echo
echo "Clash:"
echo "  ${CLIENT_DIR}/clash.yaml"

echo
echo "Shadowsocks URI:"
echo "  ${CLIENT_DIR}/ss.txt"

echo
echo "Shadowsocks JSON:"
echo "  ${CLIENT_DIR}/ss.json"

echo
echo "sing-box:"
echo "  ${CLIENT_DIR}/sing-box.json"

echo
echo "Subscription:"
echo "  ${CLIENT_DIR}/subscribe.txt"

echo
echo "QR Code:"
echo "  ${CLIENT_DIR}/ss.png"

echo