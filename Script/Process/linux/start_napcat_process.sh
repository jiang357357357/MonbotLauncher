#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/napcat_common.sh"
[[ "$(detect_napcat_launch_kind)" != "missing" ]] || { echo "[x] 未发现可启动的 NapCat 运行时" >&2; exit 1; }
exec "$MONPM_MODULE" napcat start "$@"
