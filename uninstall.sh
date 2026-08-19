#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="/opt/my-vpn"
NGINX_CONFIG="/etc/nginx/sites-available/my-vpn-subscription"
NGINX_LINK="/etc/nginx/sites-enabled/my-vpn-subscription"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

echo "======================================"
echo "       MY VPN SERVER UNINSTALLER"
echo "======================================"

echo
read -r -p "This will remove VPN configuration. Continue? [y/N]: " CONFIRM

if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then

    echo "Cancelled."

    exit 0

fi


echo
echo "[1/5] Stopping sing-box..."

systemctl stop sing-box 2>/dev/null || true
systemctl disable sing-box 2>/dev/null || true


echo
echo "[2/5] Removing Nginx configuration..."

rm -f "${NGINX_LINK}"
rm -f "${NGINX_CONFIG}"

nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true


echo
echo "[3/5] Removing sing-box configuration..."

rm -rf /etc/sing-box


echo
echo "[4/5] Removing project..."

rm -rf "${PROJECT_DIR}"


echo
echo "[5/5] Uninstall complete."

echo
echo "NOTE:"
echo "sing-box / nginx packages were not removed."
echo "You can remove them manually with apt if required."

echo
echo "======================================"
echo "       UNINSTALL COMPLETE"
echo "======================================"