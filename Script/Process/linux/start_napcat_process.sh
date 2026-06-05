#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=1
      ;;
  esac
done

ensure_pm2

kind="$(detect_napcat_launch_kind)"

echo "================================================"
echo "NapCat PM2 启动工具"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "应用名称: $NAPCAT_PM2_NAME"
echo "部署目录: $NAPCAT_HOME"
echo "运行模式: $kind"
echo "配置文件: $NAPCAT_ECOSYSTEM_FILE"
echo

if [[ "$kind" == "missing" ]]; then
  echo "[x] 未发现可启动的 NapCat 运行时"
  echo "    Shell路径: $NAPCAT_INSTALL_BASE_DIR/opt/QQ/qq"
  echo "    AppImage: ${NAPCAT_APPIMAGE:-未发现}"
  echo "    Docker容器: $NAPCAT_DOCKER_CONTAINER"
  echo
  echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
  echo "[NAPCAT_STATUS:NOT_INSTALLED]"
  exit 1
fi

status="$(pm2_named_status "$NAPCAT_PM2_NAME")"
if [[ "$status" == "online" && "$FORCE" -eq 0 ]]; then
  echo "[!] NapCat 已由 PM2 管理并处于运行中"
  if [[ "${MON_PM2_PARENT:-0}" != "1" ]]; then
    pm2_process_summary "$NAPCAT_PM2_NAME"
    echo
  fi
  echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
  echo "[NAPCAT_STATUS:ALREADY_RUNNING]"
  exit 0
fi

if [[ "$status" == "missing" ]]; then
  run_pm2_quiet start "$NAPCAT_ECOSYSTEM_FILE" --only "$NAPCAT_PM2_NAME"
else
  run_pm2_quiet restart "$NAPCAT_PM2_NAME" --update-env
fi

echo
pm2_process_summary "$NAPCAT_PM2_NAME"
echo
echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
echo "[NAPCAT_STATUS:STARTED]"
