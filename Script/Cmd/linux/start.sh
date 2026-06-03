#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROCESS_SCRIPT="$PROJECT_ROOT/Script/Process/linux/start_process.sh"
NAPCAT_PROCESS_SCRIPT="$PROJECT_ROOT/Script/Process/linux/start_napcat_process.sh"

FORCE_ARGS=()
START_NAPCAT=1
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE_ARGS+=("--force")
      ;;
    --skip-napcat)
      START_NAPCAT=0
      ;;
  esac
done

echo
echo "================================================"
echo "MonBot PM2 启动工具 (Linux)"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo

NAPCAT_STATUS=0
if [[ "$START_NAPCAT" -eq 1 ]]; then
  echo "[1/2] 启动 NapCat..."
  if [[ ! -f "$NAPCAT_PROCESS_SCRIPT" ]]; then
    echo "[x] NapCat PM2 启动脚本不存在: $NAPCAT_PROCESS_SCRIPT"
    NAPCAT_STATUS=1
  else
    (
      cd "$PROJECT_ROOT"
      MON_PM2_PARENT=1 bash "$NAPCAT_PROCESS_SCRIPT" "${FORCE_ARGS[@]}"
    ) || NAPCAT_STATUS=$?
  fi
  echo
else
  echo "[1/2] 跳过 NapCat 启动"
  echo
fi

if [[ ! -f "$PROCESS_SCRIPT" ]]; then
  echo "[x] PM2 启动脚本不存在: $PROCESS_SCRIPT"
  exit 1
fi

echo "[2/2] 启动 MonBot..."
(
  cd "$PROJECT_ROOT"
  MON_PM2_PARENT=1 bash "$PROCESS_SCRIPT" "${FORCE_ARGS[@]}"
)

echo
echo "================================================"
echo "PM2 进程列表"
echo "================================================"
pm2 list

echo
echo "管理命令:"
echo "  启动全部: bash Script/Cmd/linux/start.sh"
echo "  跳过NapCat: bash Script/Cmd/linux/start.sh --skip-napcat"
echo "  查看NapCat: bash Script/Process/linux/status_napcat_process.sh"
echo "  查看MonBot: bash Script/Process/linux/status_process.sh"
echo "  查看日志: pm2 logs"
echo "  停止NapCat: bash Script/Process/linux/stop_napcat_process.sh"
echo "  停止MonBot: bash Script/Process/linux/stop_process.sh"

if [[ "$NAPCAT_STATUS" -ne 0 ]]; then
  echo
  echo "[!] NapCat 未启动，通常是尚未安装运行时。MonBot 启动流程已继续执行。"
fi
