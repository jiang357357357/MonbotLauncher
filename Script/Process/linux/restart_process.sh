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
  pm2 start "$ECOSYSTEM_FILE" --only "$PM2_APP_NAME"
else
  pm2 restart "$PM2_APP_NAME" --update-env
fi

echo
echo "[PROCESS_NAME:$PM2_APP_NAME]"
echo "[SERVER_STATUS:RESTARTED]"
