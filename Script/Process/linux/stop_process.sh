#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_pm2

echo "================================================"
echo "MonBot PM2 停止工具"
echo "================================================"
echo "应用名称: $PM2_APP_NAME"
echo

status="$(pm2_app_status)"
if [[ "$status" == "missing" ]]; then
  echo "[!] PM2 中未找到 MonBot 应用"
  echo
  echo "[PROCESS_NAME:$PM2_APP_NAME]"
  echo "[SERVER_STATUS:NOT_RUNNING]"
  exit 0
fi

pm2 stop "$PM2_APP_NAME"
echo
echo "[PROCESS_NAME:$PM2_APP_NAME]"
echo "[SERVER_STATUS:STOPPED]"
