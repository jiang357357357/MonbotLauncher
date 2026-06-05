#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

ensure_pm2

kind="$(detect_napcat_launch_kind)"

echo "================================================"
echo "NapCat PM2 停止工具"
echo "================================================"
echo "应用名称: $NAPCAT_PM2_NAME"
echo "运行模式: $kind"
echo

status="$(pm2_named_status "$NAPCAT_PM2_NAME")"
if [[ "$status" == "missing" ]]; then
  echo "[!] PM2 中未找到 NapCat 应用"
  echo
  echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
  echo "[NAPCAT_STATUS:NOT_RUNNING]"
  exit 0
fi

run_pm2_quiet stop "$NAPCAT_PM2_NAME"
echo
pm2_process_summary "$NAPCAT_PM2_NAME"

if [[ "$kind" == "docker" ]] && docker_container_exists "$NAPCAT_DOCKER_CONTAINER"; then
  docker stop "$NAPCAT_DOCKER_CONTAINER" >/dev/null 2>&1 || true
fi

echo
echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
echo "[NAPCAT_STATUS:STOPPED]"
