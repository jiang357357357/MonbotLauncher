#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=1
      ;;
  esac
done

ensure_pm2

echo "================================================"
echo "MonBot PM2 启动工具"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "应用名称: $PM2_APP_NAME"
echo "配置文件: $ECOSYSTEM_FILE"
echo "QQBot入口: $BOT_ENTRY"
echo

if [[ ! -f "$BOT_ENTRY" ]]; then
  echo "[x] QQBot 入口不存在: $BOT_ENTRY"
  echo
  echo "[PROCESS_NAME:$PM2_APP_NAME]"
  echo "[SERVER_STATUS:FAILED]"
  exit 1
fi

status="$(pm2_app_status)"
if [[ "$status" == "online" && "$FORCE" -eq 0 ]]; then
  echo "[!] MonBot 已由 PM2 管理并处于运行中"
  if [[ "${MON_PM2_PARENT:-0}" != "1" ]]; then
    pm2_process_summary "$PM2_APP_NAME"
    echo
  fi
  echo "[PROCESS_NAME:$PM2_APP_NAME]"
  echo "[SERVER_STATUS:ALREADY_RUNNING]"
  exit 0
fi

if [[ "$status" == "missing" ]]; then
  run_pm2_quiet start "$ECOSYSTEM_FILE" --only "$PM2_APP_NAME"
else
  run_pm2_quiet restart "$PM2_APP_NAME" --update-env
fi

echo
pm2_process_summary "$PM2_APP_NAME"
echo
echo "[PROCESS_NAME:$PM2_APP_NAME]"
echo "[SERVER_STATUS:STARTED]"
if [[ "${MON_PM2_PARENT:-0}" != "1" ]]; then
  echo
  echo "管理命令:"
  echo "  查看状态: bash Script/Process/linux/status_process.sh"
  echo "  停止服务: bash Script/Process/linux/stop_process.sh"
  echo "  重启服务: bash Script/Process/linux/restart_process.sh"
fi
