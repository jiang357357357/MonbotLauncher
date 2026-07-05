#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROCESS_SCRIPT="$PROJECT_ROOT/Script/Process/linux/start_process.sh"
NAPCAT_PROCESS_SCRIPT="$PROJECT_ROOT/Script/Process/linux/start_napcat_process.sh"
MON_PM2_START_LOCK_DIR="${MON_PM2_START_LOCK_DIR:-/tmp/mon-pm2-start.lock.d}"

# shellcheck source=../../Process/linux/log_paths.sh
source "$PROJECT_ROOT/Script/Process/linux/log_paths.sh"

acquire_start_lock() {
  local lock_dir="$MON_PM2_START_LOCK_DIR"
  local pid_file="$lock_dir/pid"

  while ! mkdir "$lock_dir" 2>/dev/null; do
    local owner_pid=""
    if [[ -f "$pid_file" ]]; then
      owner_pid="$(cat "$pid_file" 2>/dev/null || true)"
    fi

    if [[ -z "$owner_pid" || ! "$owner_pid" =~ ^[0-9]+$ || ! -d "/proc/$owner_pid" ]]; then
      rm -rf "$lock_dir"
      continue
    fi

    echo "[i] 另一个 Mon PM2 启动流程正在运行，等待 PID $owner_pid..."
    sleep 1
  done

  printf '%s\n' "$$" > "$pid_file"
  trap 'rm -rf "$MON_PM2_START_LOCK_DIR"' EXIT
}

acquire_start_lock

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
LOG_START_DIR="$(ensure_log_start_dir)"
export MON_LOG_START_DIR="$LOG_START_DIR"
echo "日志根目录: $MON_LOG_ROOT"
echo "本次启动目录: $MON_LOG_START_DIR"
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
echo "PM2 进程摘要"
echo "================================================"
bash "$PROJECT_ROOT/Script/Process/linux/status_all_process.sh"

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
