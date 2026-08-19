#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="/opt/my-vpn"
CONFIG_DIR="/etc/sing-box"
ENV_FILE="${PROJECT_DIR}/server.env"

echo "======================================"
echo "       MY VPN SERVER INSTALLER"
echo "======================================"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi


echo
echo "[1/10] Installing dependencies..."

apt update

apt install -y \
    curl \
    wget \
    jq \
    openssl \
    ca-certificates \
    unzip \
    iproute2 \
    iputils-ping \
    dnsutils \
    lsof \
    qrencode \
    nginx \
    ufw


echo
echo "[2/10] Creating directories..."

mkdir -p "${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}/clients"
mkdir -p "${CONFIG_DIR}"

chmod 700 "${PROJECT_DIR}"
chmod 700 "${PROJECT_DIR}/clients"


echo
echo "[3/10] Installing sing-box..."

if ! command -v sing-box >/dev/null 2>&1; then

    curl -fsSL https://sing-box.app/install.sh | sh

fi

if ! command -v sing-box >/dev/null 2>&1; then

    echo "ERROR: sing-box installation failed."
    exit 1

fi

echo
sing-box version


echo
echo "[4/10] Creating server.env..."

if [[ ! -f "${ENV_FILE}" ]]; then

    cat > "${ENV_FILE}" <<'EOF'
SERVER_PORT=18188

SS_METHOD=aes-256-gcm
SS_PASSWORD=
NODE_NAME=US-Aliyun

PUBLIC_IP=

ENABLE_SUBSCRIPTION=true
SUBSCRIBE_TOKEN=

DOMAIN=

ENABLE_HTTPS=false
ACME_EMAIL=

NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

ENABLE_UFW=true
SSH_PORT=22
EOF

    chmod 600 "${ENV_FILE}"

    echo "Created:"
    echo "${ENV_FILE}"

else

    echo "Existing server.env found."
    echo "Keeping existing configuration."

fi


echo
echo "[5/10] Checking Nginx..."

if ! command -v nginx >/dev/null 2>&1; then

    echo "ERROR: Nginx installation failed."
    exit 1

fi

systemctl enable nginx

systemctl start nginx

nginx -t


echo
echo "[6/10] Applying VPN configuration..."

if [[ ! -x "${PROJECT_DIR}/apply-config.sh" ]]; then

    echo "ERROR:"
    echo "${PROJECT_DIR}/apply-config.sh not found."

    exit 1

fi

"${PROJECT_DIR}/apply-config.sh"


echo
echo "[7/10] Generating client configurations..."

if [[ ! -x "${PROJECT_DIR}/generate-config.sh" ]]; then

    echo "ERROR:"
    echo "${PROJECT_DIR}/generate-config.sh not found."

    exit 1

fi

"${PROJECT_DIR}/generate-config.sh"


echo
echo "[8/10] Configuring Nginx subscription..."

if [[ ! -x "${PROJECT_DIR}/nginx-setup.sh" ]]; then

    echo "ERROR:"
    echo "${PROJECT_DIR}/nginx-setup.sh not found."

    exit 1

fi

"${PROJECT_DIR}/nginx-setup.sh"


echo
echo "[9/10] Configuring firewall..."

source "${ENV_FILE}"

if [[ "${ENABLE_UFW}" == "true" ]]; then

    ufw allow "${SSH_PORT}/tcp"
    ufw allow "${SERVER_PORT}/tcp"
    ufw allow "${NGINX_HTTP_PORT}/tcp"

    if [[ "${ENABLE_HTTPS}" == "true" ]]; then
        ufw allow "${NGINX_HTTPS_PORT}/tcp"
    fi

    ufw --force enable

fi


echo
echo "[10/10] Running health checks..."

echo
echo "----- sing-box -----"

if systemctl is-active --quiet sing-box; then
    echo "OK: sing-box is running."
else
    echo "ERROR: sing-box is not running."
    systemctl status sing-box --no-pager || true
    exit 1
fi


echo
echo "----- nginx -----"

if systemctl is-active --quiet nginx; then
    echo "OK: nginx is running."
else
    echo "ERROR: nginx is not running."
    systemctl status nginx --no-pager || true
    exit 1
fi


echo
echo "----- Ports -----"

ss -lntp | grep -E \
    ":${SERVER_PORT}\b|:${NGINX_HTTP_PORT}\b|:${NGINX_HTTPS_PORT}\b" \
    || true


echo
echo "======================================"
echo "       VPN INSTALLATION COMPLETE"
echo "======================================"

echo
echo "Configuration:"
echo "  ${ENV_FILE}"

echo
echo "Client files:"
echo "  ${PROJECT_DIR}/clients/"

echo
echo "======================================"