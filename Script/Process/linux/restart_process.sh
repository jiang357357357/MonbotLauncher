#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_pm2

echo "================================================"
echo "MonBot PM2 重启工具"
echo "================================================"
echo "应用名称: $PM2_APP_NAME"
echo

status="$(pm2_app_status)"
if [[ "$status" == "missing" ]]; then
  run_pm2_quiet start "$ECOSYSTEM_FILE" --only "$PM2_APP_NAME"
else
  run_pm2_quiet restart "$PM2_APP_NAME" --update-env
fi

echo
pm2_process_summary "$PM2_APP_NAME"
echo
echo "[PROCESS_NAME:$PM2_APP_NAME]"
echo "[SERVER_STATUS:RESTARTED]"
