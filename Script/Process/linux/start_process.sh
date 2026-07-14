#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
[[ -f "$BOT_ENTRY" ]] || { echo "[x] QQBot 入口不存在: $BOT_ENTRY" >&2; exit 1; }
exec "$MONPM_MODULE" "$MONPM_APP" start "$@"
