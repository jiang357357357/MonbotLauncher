#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

ensure_pm2

echo "================================================"
echo "NapCat PM2 重启工具"
echo "================================================"
echo "应用名称: $NAPCAT_PM2_NAME"
echo

"$SCRIPT_DIR/start_napcat_process.sh" --force

echo
echo "[PROCESS_NAME:$NAPCAT_PM2_NAME]"
echo "[NAPCAT_STATUS:RESTARTED]"
