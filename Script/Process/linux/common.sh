#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MON_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
BOT_ENTRY="$PROJECT_ROOT/BotCore/bot.py"
MONPM_APP="bot"
MONPM_MODULE="$MON_ROOT/Script/launch/linux/monpm-module.sh"

[[ -x "$MONPM_MODULE" ]] || { echo "[x] MonPM 启动器不存在: $MONPM_MODULE" >&2; exit 1; }
