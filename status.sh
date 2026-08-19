#!/usr/bin/env bash

echo "======================================"
echo "VPN STATUS"
echo "======================================"

systemctl status sing-box --no-pager

echo
echo "PORT:"
ss -lntup | grep 18188 || true

echo
echo "PUBLIC IP:"
curl -4 -fsSL ifconfig.me

echo
echo "======================================"