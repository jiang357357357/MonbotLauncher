#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.monconfig"
ECOSYSTEM_FILE="$SCRIPT_DIR/ecosystem.config.cjs"
BOT_ENTRY="$PROJECT_ROOT/BotCore/bot.py"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"

read_monconfig_value() {
  local section="$1"
  local key="$2"

  awk -F= -v section="[$section]" -v key="$key" '
    $0 ~ /^\[/ { in_section = ($0 == section); next }
    in_section && $1 == key {
      value = $2
      sub(/[[:space:]]+#.*/, "", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$CONFIG_FILE" 2>/dev/null || true
}

PM2_APP_NAME="${MON_PM2_NAME:-$(read_monconfig_value process NAME)}"
PM2_APP_NAME="${PM2_APP_NAME:-MonBot-Service}"
PROCESS_TAG="${MON_PROCESS_TAG:-$(read_monconfig_value process PROCESS_TAG)}"
PROCESS_TAG="${PROCESS_TAG:-monbot-main}"
SERVER_PORT="${MON_SERVER_PORT:-$(read_monconfig_value nonebot PORT)}"
SERVER_PORT="${SERVER_PORT:-8080}"

ensure_pm2() {
  if command -v pm2 >/dev/null 2>&1; then
    return 0
  fi

  echo "[x] 未找到 pm2"
  echo "    安装命令: npm install -g pm2"
  return 1
}

pm2_app_status() {
  export PM2_APP_NAME
  pm2 jlist | node -e '
    const fs = require("fs");
    const name = process.env.PM2_APP_NAME;
    const input = fs.readFileSync(0, "utf8");
    const apps = JSON.parse(input || "[]");
    const app = apps.find((item) => item.name === name);
    process.stdout.write(app ? app.pm2_env.status : "missing");
  '
}

export MON_PM2_NAME="$PM2_APP_NAME"
export MON_PROCESS_TAG="$PROCESS_TAG"
export MON_SERVER_PORT="$SERVER_PORT"
export MON_BOT_ENTRY="$BOT_ENTRY"
export PYTHONUNBUFFERED=1
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1
