#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

ensure_pm2

line_count="${1:-80}"
export NAPCAT_PM2_NAME

paths="$(pm2_cmd jlist | node -e '
const fs = require("fs");
const name = process.env.NAPCAT_PM2_NAME;
const apps = JSON.parse(fs.readFileSync(0, "utf8") || "[]");
const app = apps.find((item) => item.name === name);
if (!app) process.exit(2);
const env = app.pm2_env || {};
[env.pm_out_log_path, env.pm_err_log_path].filter(Boolean).forEach((path) => console.log(path));
')"

if [[ -z "$paths" ]]; then
  echo "[x] 未找到 PM2 日志文件: $NAPCAT_PM2_NAME" >&2
  exit 1
fi

echo "[i] 使用 tail -F 跟随 PM2 日志: $NAPCAT_PM2_NAME"
echo "$paths" | sed 's/^/    /'
echo
tail -n "$line_count" -F $paths
