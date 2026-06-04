#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONBOT_STOP_SCRIPT="$SCRIPT_DIR/stop_process.sh"
NAPCAT_STOP_SCRIPT="$SCRIPT_DIR/stop_napcat_process.sh"

echo "================================================"
echo "MonBot/NapCat PM2 停止工具"
echo "================================================"
echo

failed_count=0

if [[ -f "$NAPCAT_STOP_SCRIPT" ]]; then
  set +e
  napcat_output="$(bash "$NAPCAT_STOP_SCRIPT" 2>&1)"
  napcat_exit=$?
  set -e
  echo "$napcat_output"
  if [[ "$napcat_exit" -ne 0 ]]; then
    failed_count=$((failed_count + 1))
  fi
else
  echo "[x] NapCat 停止脚本不存在: $NAPCAT_STOP_SCRIPT"
  failed_count=$((failed_count + 1))
fi

echo

if [[ -f "$MONBOT_STOP_SCRIPT" ]]; then
  set +e
  monbot_output="$(bash "$MONBOT_STOP_SCRIPT" 2>&1)"
  monbot_exit=$?
  set -e
  echo "$monbot_output"
  if [[ "$monbot_exit" -ne 0 ]]; then
    failed_count=$((failed_count + 1))
  fi
else
  echo "[x] MonBot 停止脚本不存在: $MONBOT_STOP_SCRIPT"
  failed_count=$((failed_count + 1))
fi

echo
if [[ "$failed_count" -eq 0 ]]; then
  echo "[SERVER_STATUS:STOPPED]"
else
  echo "[SERVER_STATUS:FAILED]"
  exit 1
fi
