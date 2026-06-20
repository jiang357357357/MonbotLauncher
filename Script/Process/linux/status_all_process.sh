#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

ensure_pm2

napcat_kind="$(detect_napcat_launch_kind)"
monbot_status="$(pm2_app_status)"
napcat_status="$(pm2_named_status "$NAPCAT_PM2_NAME")"

echo "================================================"
echo "MonBot/NapCat PM2 状态查看"
echo "================================================"
echo "MonBot 应用名称: $PM2_APP_NAME"
echo "NapCat 应用名称: $NAPCAT_PM2_NAME"
echo "NapCat 部署目录: $NAPCAT_HOME"
echo "NapCat 运行模式: $napcat_kind"
echo

pm2_process_summary "$PM2_APP_NAME" "$NAPCAT_PM2_NAME"
echo

echo "日志命令:"
echo "  bash Script/Process/linux/logs_process.sh"
echo "  bash Script/Process/linux/logs_napcat_process.sh"
echo
echo "[PROCESS_NAME:$PM2_APP_NAME,$NAPCAT_PM2_NAME]"

if [[ "$monbot_status" == "online" ]]; then
  echo "[MONBOT_STATUS:RUNNING]"
else
  echo "[MONBOT_STATUS:NOT_RUNNING]"
fi

if [[ "$napcat_status" == "online" ]]; then
  echo "[NAPCAT_STATUS:RUNNING]"
elif [[ "$napcat_kind" == "missing" ]]; then
  echo "[NAPCAT_STATUS:NOT_INSTALLED]"
else
  echo "[NAPCAT_STATUS:NOT_RUNNING]"
fi

if [[ "$monbot_status" == "online" && "$napcat_status" == "online" ]]; then
  echo "[SERVER_STATUS:RUNNING]"
elif [[ "$monbot_status" != "online" && "$napcat_status" != "online" ]]; then
  echo "[SERVER_STATUS:NOT_RUNNING]"
else
  echo "[SERVER_STATUS:PARTIAL]"
fi
