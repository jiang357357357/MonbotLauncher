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

LOG_START_DIR="$(ensure_log_start_dir)"
export MON_LOG_START_DIR="$LOG_START_DIR"
append_process_log "MonBot PM2 重启流程开始"
echo "日志根目录: $MON_LOG_ROOT"
echo "本次启动目录: $MON_LOG_START_DIR"
echo

status="$(pm2_app_status)"
if [[ "$status" == "missing" ]]; then
  run_pm2_quiet start "$ECOSYSTEM_FILE" --only "$PM2_APP_NAME"
else
  run_pm2_quiet restart "$PM2_APP_NAME" --update-env
fi

append_process_log "MonBot PM2 进程重启 - $PM2_APP_NAME"

echo
pm2_process_summary "$PM2_APP_NAME"
echo
echo "[PROCESS_NAME:$PM2_APP_NAME]"
echo "[SERVER_STATUS:RESTARTED]"
