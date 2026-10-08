#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/workspace_root.sh"
MON_ROOT="$(resolve_mon_workspace_root "$PROJECT_ROOT")"
BOT_ENTRY="$PROJECT_ROOT/BotCore/bot.py"
MONPM_APP="bot"
MONPM_MODULE="$MON_ROOT/Script/launch/linux/monpm-module.sh"

[[ -x "$MONPM_MODULE" ]] || { echo "[x] MonPM 启动器不存在: $MONPM_MODULE" >&2; exit 1; }
