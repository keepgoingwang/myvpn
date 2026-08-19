#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo "VPN NETWORK BENCHMARK"
echo "======================================"

echo
echo "[Server]"
echo "Public IP:"
curl -4 -fsSL ifconfig.me

echo
echo
echo "Location:"
curl -4 -fsSL https://ipinfo.io/country || true

echo
echo
echo "Latency to Cloudflare:"
ping -c 10 1.1.1.1 || true

echo
echo
echo "DNS:"
dig google.com

echo
echo
echo "TCP status:"
ss -lntup | grep 18188 || true

echo
echo "======================================"