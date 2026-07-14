#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MON_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
MODULE_LAUNCHER="$MON_ROOT/Script/launch/linux/monpm-module.sh"

args=("$@")
skip_napcat=0
for arg in "$@"; do
  [[ "$arg" == "--skip-napcat" ]] && skip_napcat=1
done

echo "================================================"
echo "MonBot MonPM 启动工具 (Linux)"
echo "================================================"
if [[ "$skip_napcat" -eq 0 ]]; then
  "$MODULE_LAUNCHER" napcat start "${args[@]}"
fi
"$MODULE_LAUNCHER" bot start "${args[@]}"
"$MODULE_LAUNCHER" bot status
"$MODULE_LAUNCHER" napcat status
