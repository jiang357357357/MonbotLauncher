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

pm2_cmd() {
  local lock_file="${MON_PM2_CLI_LOCK_FILE:-/tmp/mon-pm2-cli.lock}"
  local lock_timeout="${MON_PM2_CLI_LOCK_TIMEOUT:-60}"

  if command -v flock >/dev/null 2>&1; then
    (
      flock -w "$lock_timeout" 9 || {
        echo "[x] 等待 PM2 全局锁超时: $lock_file" >&2
        exit 1
      }
      pm2 "$@"
    ) 9>"$lock_file"
    return $?
  fi

  pm2 "$@"
}

acquire_pm2_start_lock() {
  if [[ "${MON_PM2_PARENT:-0}" == "1" ]]; then
    return 0
  fi

  local lock_dir="${MON_PM2_START_LOCK_DIR:-/tmp/mon-pm2-start.lock.d}"
  local pid_file="$lock_dir/pid"

  while ! mkdir "$lock_dir" 2>/dev/null; do
    local owner_pid=""
    if [[ -f "$pid_file" ]]; then
      owner_pid="$(cat "$pid_file" 2>/dev/null || true)"
    fi

    if [[ -z "$owner_pid" || ! "$owner_pid" =~ ^[0-9]+$ || ! -d "/proc/$owner_pid" ]]; then
      rm -rf "$lock_dir"
      continue
    fi

    echo "[i] 另一个 Mon PM2 启动流程正在运行，等待 PID $owner_pid..."
    sleep 1
  done

  printf '%s\n' "$$" > "$pid_file"
  MON_PM2_HELD_START_LOCK_DIR="$lock_dir"
  trap 'rm -rf "$MON_PM2_HELD_START_LOCK_DIR"' EXIT
}

pm2_app_status() {
  export PM2_APP_NAME
  pm2_cmd jlist | node -e '
    const fs = require("fs");
    const name = process.env.PM2_APP_NAME;
    const input = fs.readFileSync(0, "utf8");
    const apps = JSON.parse(input || "[]");
    const app = apps.find((item) => item.name === name);
    process.stdout.write(app ? app.pm2_env.status : "missing");
  '
}

pm2_process_summary() {
  local app_names_text
  app_names_text="$(printf '%s\n' "$@")"
  export PM2_APP_NAMES="$app_names_text"
  pm2_cmd jlist | node -e '
    const fs = require("fs");
    const names = (process.env.PM2_APP_NAMES || "").split(/\n/).map((item) => item.trim()).filter(Boolean);
    const apps = JSON.parse(fs.readFileSync(0, "utf8") || "[]");
    const rows = names.map((name) => {
      const app = apps.find((item) => item.name === name);
      if (!app) return { id: "-", name, status: "missing", pid: "-", cpu: "-", mem: "-" };
      const env = app.pm2_env || {};
      const monit = app.monit || {};
      return {
        id: String(app.pm_id ?? env.pm_id ?? "-"),
        name,
        status: env.status || "unknown",
        pid: String(app.pid || env.pm_pid || "-"),
        cpu: Number.isFinite(monit.cpu) ? `${monit.cpu}%` : "-",
        mem: monit.memory ? `${(monit.memory / 1024 / 1024).toFixed(1)}MB` : "-",
      };
    });
    const fields = [["id", "id"], ["name", "name"], ["status", "status"], ["pid", "pid"], ["cpu", "cpu"], ["mem", "mem"]];
    const widths = {
      field: Math.max("field".length, ...fields.map(([, label]) => label.length)),
      value: Math.max("value".length, ...rows.flatMap((row) => fields.map(([key]) => String(row[key]).length))),
    };
    const border = (left, middle, right) =>
      left + ["field", "value"].map((key) => "─".repeat(widths[key] + 2)).join(middle) + right;
    const line = (field, value) =>
      `│ ${String(field).padEnd(widths.field)} │ ${String(value).padEnd(widths.value)} │`;
    console.log(border("┌", "┬", "┐"));
    console.log(line("field", "value"));
    console.log(border("├", "┼", "┤"));
    rows.forEach((row, index) => {
      if (index > 0) console.log(border("├", "┼", "┤"));
      fields.forEach(([key, label]) => console.log(line(label, row[key])));
    });
    console.log(border("└", "┴", "┘"));
  '
}

run_pm2_quiet() {
  local output
  if ! output="$(pm2_cmd "$@" 2>&1)"; then
    printf '%s\n' "$output"
    return 1
  fi
}

export MON_PM2_NAME="$PM2_APP_NAME"
export MON_PROCESS_TAG="$PROCESS_TAG"
export MON_SERVER_PORT="$SERVER_PORT"
export MON_BOT_ENTRY="$BOT_ENTRY"
export PYTHONUNBUFFERED=1
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1
export NO_COLOR=1
export FORCE_COLOR=0
