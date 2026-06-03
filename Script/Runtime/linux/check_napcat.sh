#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

candidate_paths=()
if [[ -n "${MON_NAPCAT_HOME:-}" ]]; then
  candidate_paths+=("$MON_NAPCAT_HOME")
fi
candidate_paths+=(
  "$PROJECT_ROOT/napcat"
  "$HOME/Napcat"
  "$HOME/NapCat"
  "$PROJECT_ROOT/.runtime/napcat"
  "/opt/QQ/resources/app/app_launcher/napcat"
)

echo "================================================"
echo "NapCat 外置运行时检查 (Linux)"
echo "================================================"

found_path=""
for path in "${candidate_paths[@]}"; do
  if [[ -d "$path" ]] && find "$path" -mindepth 1 -maxdepth 2 ! -path "$path/.installer" ! -path "$path/.installer/*" -print -quit | grep -q .; then
    found_path="$path"
    break
  fi
done

if [[ -z "$found_path" ]]; then
  if [[ -d "$PROJECT_ROOT/napcat" ]]; then
    echo "[!] NapCat 部署目录已创建，但尚未发现运行时文件"
    echo "    部署目录: $PROJECT_ROOT/napcat"
  else
    echo "[!] 未发现 NapCat 运行时目录"
  fi
  echo
  echo "[NAPCAT_STATUS:NOT_INSTALLED]"
  echo "[NAPCAT_HOME:$PROJECT_ROOT/napcat]"
  exit 0
fi

echo "[OK] NapCat 运行时目录: $found_path"
echo
echo "[NAPCAT_STATUS:INSTALLED]"
echo "[NAPCAT_HOME:$found_path]"
