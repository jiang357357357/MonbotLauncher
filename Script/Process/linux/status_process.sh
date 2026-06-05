#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_pm2

echo "================================================"
echo "MonBot PM2 状态查看"
echo "================================================"
echo "应用名称: $PM2_APP_NAME"
echo

status="$(pm2_app_status)"
pm2_process_summary "$PM2_APP_NAME"
echo
if [[ "$status" != "missing" ]]; then
  echo "日志命令:"
  echo "  pm2 logs $PM2_APP_NAME"
  echo
fi
echo "[PROCESS_NAME:$PM2_APP_NAME]"
if [[ "$status" == "online" ]]; then
  echo "[SERVER_STATUS:RUNNING]"
else
  echo "[SERVER_STATUS:NOT_RUNNING]"
fi
