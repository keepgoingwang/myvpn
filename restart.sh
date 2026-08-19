#!/usr/bin/env bash

set -euo pipefail

sing-box check -c /etc/sing-box/config.json

systemctl restart sing-box

systemctl status sing-box --no-pager