#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

ensure_pm2

kind="$(detect_napcat_launch_kind)"

echo "================================================"
echo "NapCat PM2 状态查看"
echo "================================================"
echo "应用名称: $NAPCAT_PM2_NAME"
echo "部署目录: $NAPCAT_HOME"
echo "运行模式: $kind"
echo

status="$(pm2_named_status "$NAPCAT_PM2_NAME")"
pm2_process_summary "$NAPCAT_PM2_NAME"
echo
if [[ "$status" != "missing" ]]; then
  echo "日志命令:"
  echo "  pm2 logs $NAPCAT_PM2_NAME"
  echo
fi
echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
if [[ "$status" == "online" ]]; then
  echo "[NAPCAT_STATUS:RUNNING]"
elif [[ "$kind" == "missing" ]]; then
  echo "[NAPCAT_STATUS:NOT_INSTALLED]"
else
  echo "[NAPCAT_STATUS:NOT_RUNNING]"
fi
