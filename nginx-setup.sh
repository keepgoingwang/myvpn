#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="/opt/my-vpn"
ENV_FILE="${PROJECT_DIR}/server.env"
CLIENT_DIR="${PROJECT_DIR}/clients"

NGINX_CONFIG="/etc/nginx/sites-available/my-vpn-subscription"
NGINX_LINK="/etc/nginx/sites-enabled/my-vpn-subscription"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

source "${ENV_FILE}"


echo "======================================"
echo "       NGINX SUBSCRIPTION SETUP"
echo "======================================"


echo
echo "[1/7] Checking Nginx..."

if ! command -v nginx >/dev/null 2>&1; then

    echo "ERROR: Nginx is not installed."

    exit 1

fi

systemctl enable nginx
systemctl start nginx


echo
echo "[2/7] Checking subscription..."

if [[ "${ENABLE_SUBSCRIPTION}" != "true" ]]; then

    echo "Subscription is disabled."

    exit 0

fi

if [[ ! -f "${CLIENT_DIR}/subscribe.txt" ]]; then

    echo "ERROR: subscribe.txt not found."

    exit 1

fi


echo
echo "[3/7] Generating subscription token..."

if [[ -z "${SUBSCRIBE_TOKEN}" ]]; then

    SUBSCRIBE_TOKEN="$(openssl rand -hex 16)"

    sed -i \
        "s|^SUBSCRIBE_TOKEN=.*|SUBSCRIBE_TOKEN=${SUBSCRIBE_TOKEN}|" \
        "${ENV_FILE}"

fi

echo "Subscription token:"
echo "${SUBSCRIBE_TOKEN}"


echo
echo "[4/7] Creating Nginx configuration..."

cat > "${NGINX_CONFIG}" <<EOF
server {
    listen ${NGINX_HTTP_PORT};
    listen [::]:${NGINX_HTTP_PORT};

    server_name ${DOMAIN:-_};

    location = /${SUBSCRIBE_TOKEN}/subscribe.txt {
        alias ${CLIENT_DIR}/subscribe.txt;

        default_type text/plain;

        add_header Cache-Control "no-store";

        add_header Access-Control-Allow-Origin "*";
    }

    location / {
        return 404;
    }
}
EOF


echo
echo "[5/7] Enabling Nginx configuration..."

ln -sf \
    "${NGINX_CONFIG}" \
    "${NGINX_LINK}"

rm -f \
    /etc/nginx/sites-enabled/default


echo
echo "[6/7] Checking Nginx configuration..."

nginx -t

systemctl reload nginx


echo
echo "[7/7] Testing subscription..."

if [[ -n "${DOMAIN}" ]]; then

    SUBSCRIBE_URL="http://${DOMAIN}/${SUBSCRIBE_TOKEN}/subscribe.txt"

else

    SUBSCRIBE_URL="http://${PUBLIC_IP}/${SUBSCRIBE_TOKEN}/subscribe.txt"

fi

echo
echo "Subscription URL:"
echo
echo "${SUBSCRIBE_URL}"

echo
echo "======================================"
echo " NGINX SUBSCRIPTION READY"
echo "======================================"