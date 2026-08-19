#!/usr/bin/env bash

set -u

PROJECT_DIR="/opt/my-vpn"
ENV_FILE="${PROJECT_DIR}/server.env"

echo "======================================"
echo "       VPN NETWORK BENCHMARK V2"
echo "======================================"
echo

# ============================================================
# 0. Load environment
# ============================================================

if [[ -f "${ENV_FILE}" ]]; then
    sed -i 's/\r$//' "${ENV_FILE}"
    source "${ENV_FILE}"
fi

SERVER_PORT="${SERVER_PORT:-18188}"
PUBLIC_IP="${PUBLIC_IP:-}"
DOMAIN="${DOMAIN:-}"
NODE_NAME="${NODE_NAME:-VPN}"

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP="$(curl -4 -fsSL --max-time 5 https://ifconfig.me 2>/dev/null || true)"
fi

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP="UNKNOWN"
fi

# ============================================================
# Functions
# ============================================================

section() {
    echo
    echo "--------------------------------------"
    echo "$1"
    echo "--------------------------------------"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_cmd() {
    "$@" 2>/dev/null
}

# ============================================================
# 1. Server information
# ============================================================

section "1. SERVER INFORMATION"

echo "Node:"
echo "${NODE_NAME}"

echo

echo "Public IPv4:"
echo "${PUBLIC_IP}"

echo

echo "Hostname:"
hostname

echo

echo "OS:"
if [[ -f /etc/os-release ]]; then
    grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2-
fi

echo

echo "Kernel:"
uname -r

echo

echo "Architecture:"
uname -m

echo

echo "Timezone:"
timedatectl 2>/dev/null | grep "Time zone:" || date +%Z

echo

echo "Current time:"
date

# ============================================================
# 2. IP information
# ============================================================

section "2. IP INFORMATION"

echo "IPv4:"
echo "${PUBLIC_IP}"

echo

echo "IPv6:"

if command_exists curl; then

    IPV6="$(curl -6 -fsSL --max-time 5 https://ifconfig.me 2>/dev/null || true)"

    if [[ -n "${IPV6}" ]]; then
        echo "${IPV6}"
    else
        echo "NOT AVAILABLE"
    fi

else

    echo "curl not installed"

fi

# ============================================================
# 3. Cloudflare latency
# ============================================================

section "3. CLOUDFLARE LATENCY"

if command_exists ping; then

    ping -c 10 -W 2 1.1.1.1

else

    echo "ping command not available"

fi

# ============================================================
# 4. Google latency
# ============================================================

section "4. GOOGLE LATENCY"

if command_exists ping; then

    ping -c 10 -W 2 8.8.8.8

else

    echo "ping command not available"

fi

# ============================================================
# 5. DNS benchmark
# ============================================================

section "5. DNS BENCHMARK"

if command_exists dig; then

    echo
    echo "[Local Resolver]"
    dig google.com +stats | grep "Query time"

    echo
    echo "[Cloudflare]"
    dig @1.1.1.1 google.com +stats | grep "Query time"

    echo
    echo "[Google DNS]"
    dig @8.8.8.8 google.com +stats | grep "Query time"

    echo
    echo "[Quad9]"
    dig @9.9.9.9 google.com +stats | grep "Query time"

else

    echo "dig not installed"

fi

# ============================================================
# 6. DNS domain resolution
# ============================================================

section "6. DNS RESOLUTION"

DOMAINS=(
    google.com
    youtube.com
    github.com
    cloudflare.com
    amazon.com
)

if command_exists dig; then

    for DOMAIN_TEST in "${DOMAINS[@]}"; do

        RESULT="$(dig +short "${DOMAIN_TEST}" | head -n 1)"

        if [[ -n "${RESULT}" ]]; then
            echo "${DOMAIN_TEST} -> ${RESULT}"
        else
            echo "${DOMAIN_TEST} -> FAILED"
        fi

    done

else

    echo "dig not installed"

fi

# ============================================================
# 7. TCP / UDP listening
# ============================================================

section "7. VPN PORT STATUS"

echo "Configured port:"
echo "${SERVER_PORT}"

echo

echo "[TCP]"

if command_exists ss; then

    ss -lntp 2>/dev/null | grep ":${SERVER_PORT}" || \
        echo "TCP ${SERVER_PORT}: NOT LISTENING"

else

    echo "ss not installed"

fi

echo

echo "[UDP]"

if command_exists ss; then

    ss -lunp 2>/dev/null | grep ":${SERVER_PORT}" || \
        echo "UDP ${SERVER_PORT}: NOT LISTENING"

else

    echo "ss not installed"

fi

# ============================================================
# 8. Sing-box status
# ============================================================

section "8. SING-BOX STATUS"

if command_exists systemctl; then

    STATUS="$(systemctl is-active sing-box 2>/dev/null || true)"

    echo "Service:"
    echo "${STATUS}"

    echo

    if [[ "${STATUS}" == "active" ]]; then
        echo "sing-box: OK"
    else
        echo "sing-box: FAILED"
    fi

else

    echo "systemctl not available"

fi

# ============================================================
# 9. Sing-box configuration
# ============================================================

section "9. SING-BOX CONFIGURATION"

CONFIG_FILE="/etc/sing-box/config.json"

if [[ -f "${CONFIG_FILE}" ]] && command_exists sing-box; then

    sing-box check -c "${CONFIG_FILE}"

else

    echo "Configuration not found."

fi

# ============================================================
# 10. Nginx status
# ============================================================

section "10. NGINX STATUS"

if command_exists nginx; then

    NGINX_STATUS="$(systemctl is-active nginx 2>/dev/null || true)"

    echo "Service:"
    echo "${NGINX_STATUS}"

    echo

    nginx -t 2>&1

else

    echo "Nginx not installed."

fi

# ============================================================
# 11. Firewall
# ============================================================

section "11. FIREWALL"

if command_exists ufw; then

    ufw status

else

    echo "UFW not installed."

fi

# ============================================================
# 12. HTTP connectivity
# ============================================================

section "12. HTTP CONNECTIVITY"

URLS=(
    "https://www.google.com"
    "https://www.cloudflare.com"
    "https://github.com"
    "https://www.youtube.com"
)

for URL in "${URLS[@]}"; do

    if command_exists curl; then

        RESULT="$(curl \
            -o /dev/null \
            -s \
            -w "%{http_code} %{time_connect}s %{time_starttransfer}s %{time_total}s" \
            --max-time 10 \
            "${URL}" 2>/dev/null || true)"

        echo "${URL}"
        echo "  ${RESULT}"

    fi

done

# ============================================================
# 13. HTTPS TLS benchmark
# ============================================================

section "13. HTTPS TLS"

if command_exists curl; then

    curl \
        -o /dev/null \
        -s \
        -w "Google HTTPS: %{http_code} total=%{time_total}s\n" \
        --max-time 10 \
        https://www.google.com

    curl \
        -o /dev/null \
        -s \
        -w "Cloudflare HTTPS: %{http_code} total=%{time_total}s\n" \
        --max-time 10 \
        https://www.cloudflare.com

    curl \
        -o /dev/null \
        -s \
        -w "GitHub HTTPS: %{http_code} total=%{time_total}s\n" \
        --max-time 10 \
        https://github.com

fi

# ============================================================
# 14. Download speed
# ============================================================

section "14. DOWNLOAD SPEED"

if command_exists curl; then

    echo "Testing 100MB download..."
    echo

    curl \
        -L \
        -o /dev/null \
        -s \
        -w "Download speed: %{speed_download} bytes/sec\n" \
        --max-time 30 \
        https://speed.hetzner.de/100MB.bin || \
        echo "Download test failed."

else

    echo "curl not installed"

fi

# ============================================================
# 15. Network interface
# ============================================================

section "15. NETWORK INTERFACE"

if command_exists ip; then

    ip -br addr

    echo

    ip route

fi

# ============================================================
# 16. Packet loss
# ============================================================

section "16. PACKET LOSS"

if command_exists ping; then

    echo "[Cloudflare]"
    ping -c 20 -W 2 1.1.1.1 2>/dev/null | tail -n 2

    echo

    echo "[Google]"
    ping -c 20 -W 2 8.8.8.8 2>/dev/null | tail -n 2

fi

# ============================================================
# 17. Network stability
# ============================================================

section "17. NETWORK STABILITY"

if command_exists ping; then

    ping -c 50 -W 2 1.1.1.1 2>/dev/null | tail -n 3

else

    echo "ping not available"

fi

# ============================================================
# 18. Resource information
# ============================================================

section "18. SERVER RESOURCE"

echo "CPU:"
nproc

echo

echo "Memory:"
free -h

echo

echo "Disk:"
df -h /

echo

echo "Load:"
uptime

# ============================================================
# 19. Public VPN endpoint
# ============================================================

section "19. VPN ENDPOINT"

echo "Server:"
echo "${PUBLIC_IP}"

echo

echo "Port:"
echo "${SERVER_PORT}"

echo

echo "TCP:"
if command_exists nc; then

    nc -zvw 5 "${PUBLIC_IP}" "${SERVER_PORT}" 2>&1 || true

else

    echo "nc not installed"

fi

# ============================================================
# 20. Subscription
# ============================================================

section "20. SUBSCRIPTION"

if [[ "${ENABLE_SUBSCRIPTION:-false}" == "true" ]]; then

    if [[ -n "${SUBSCRIBE_TOKEN:-}" ]]; then

        if [[ -n "${DOMAIN}" ]]; then

            SUBSCRIBE_URL="http://${DOMAIN}/${SUBSCRIBE_TOKEN}/subscribe.txt"

        else

            SUBSCRIBE_URL="http://${PUBLIC_IP}/${SUBSCRIBE_TOKEN}/subscribe.txt"

        fi

        echo "Subscription:"
        echo "${SUBSCRIBE_URL}"

        echo

        echo "Local test:"

        curl \
            -fsS \
            --max-time 5 \
            "http://127.0.0.1/${SUBSCRIBE_TOKEN}/subscribe.txt" \
            >/dev/null 2>&1 && \
            echo "Subscription: OK" || \
            echo "Subscription: FAILED"

    else

        echo "SUBSCRIBE_TOKEN not configured."

    fi

else

    echo "Subscription disabled."

fi

# ============================================================
# 21. Summary
# ============================================================

section "21. BENCHMARK SUMMARY"

echo
echo "Server IP:"
echo "${PUBLIC_IP}"

echo

echo "VPN Port:"
echo "${SERVER_PORT}"

echo

echo "Cloudflare:"
if command_exists ping; then
    ping -c 5 -W 2 1.1.1.1 2>/dev/null | tail -n 2
fi

echo

echo "VPN Service:"
systemctl is-active sing-box 2>/dev/null || true

echo

echo "Nginx:"
systemctl is-active nginx 2>/dev/null || true

echo

echo "======================================"
echo "       BENCHMARK COMPLETE"
echo "======================================"
echo