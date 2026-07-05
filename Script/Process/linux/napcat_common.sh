#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.monconfig"
NAPCAT_ECOSYSTEM_FILE="$SCRIPT_DIR/napcat.ecosystem.config.cjs"

# shellcheck source=log_paths.sh
source "$SCRIPT_DIR/log_paths.sh"

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

resolve_project_path() {
  local value="$1"
  local fallback="$2"

  if [[ -z "$value" ]]; then
    value="$fallback"
  fi

  case "$value" in
    /*)
      printf '%s\n' "$value"
      ;;
    ~/*)
      printf '%s\n' "${HOME}${value:1}"
      ;;
    *)
      printf '%s\n' "$PROJECT_ROOT/$value"
      ;;
  esac
}

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

pm2_named_status() {
  local app_name="$1"
  export PM2_APP_NAME="$app_name"
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

find_first_executable() {
  local candidate
  for candidate in "$@"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_first_appimage() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return 1
  fi

  find "$root" -maxdepth 4 -type f -iname '*.AppImage' -perm -u+x -print -quit 2>/dev/null
}

napcat_shell_plugin_entry() {
  if [[ -z "${NAPCAT_QQ_EXECUTABLE:-}" ]]; then
    return 1
  fi

  local qq_base
  qq_base="$(cd "$(dirname "$NAPCAT_QQ_EXECUTABLE")" && pwd)"
  local plugin_entry="$qq_base/resources/app/app_launcher/napcat/napcat.mjs"

  if [[ -f "$plugin_entry" ]]; then
    printf '%s\n' "$plugin_entry"
    return 0
  fi

  return 1
}

napcat_shell_ready() {
  [[ -x "${NAPCAT_QQ_EXECUTABLE:-}" ]] && napcat_shell_plugin_entry >/dev/null 2>&1
}

docker_container_exists() {
  local container="$1"
  command -v docker >/dev/null 2>&1 && docker inspect "$container" >/dev/null 2>&1
}

NAPCAT_PM2_NAME="${MON_NAPCAT_PM2_NAME:-$(read_monconfig_value napcat_process NAME)}"
NAPCAT_PM2_NAME="${NAPCAT_PM2_NAME:-napcat}"
NAPCAT_MODE="${MON_NAPCAT_MODE:-$(read_monconfig_value napcat_process MODE)}"
NAPCAT_MODE="${NAPCAT_MODE:-auto}"
NAPCAT_HOME="$(resolve_project_path "${MON_NAPCAT_HOME:-$(read_monconfig_value napcat_process HOME)}" "napcat")"
NAPCAT_INSTALL_BASE_DIR="$(resolve_project_path "${MON_NAPCAT_INSTALL_BASE_DIR:-$(read_monconfig_value napcat_process INSTALL_BASE_DIR)}" "napcat/Napcat")"
NAPCAT_DOCKER_CONTAINER="${MON_NAPCAT_DOCKER_CONTAINER:-$(read_monconfig_value napcat_process DOCKER_CONTAINER)}"
NAPCAT_DOCKER_CONTAINER="${NAPCAT_DOCKER_CONTAINER:-napcat}"
NAPCAT_QQ_ACCOUNT="${MON_NAPCAT_QQ_ACCOUNT:-$(read_monconfig_value napcat_process QQ_ACCOUNT)}"
NAPCAT_EXTRA_ARGS="${MON_NAPCAT_EXTRA_ARGS:-$(read_monconfig_value napcat_process EXTRA_ARGS)}"
NAPCAT_CUSTOM_COMMAND="${MON_NAPCAT_COMMAND:-$(read_monconfig_value napcat_process COMMAND)}"
NAPCAT_QQ_EXECUTABLE="${MON_NAPCAT_EXECUTABLE:-$(read_monconfig_value napcat_process EXECUTABLE)}"
NAPCAT_APPIMAGE="${MON_NAPCAT_APPIMAGE:-$(read_monconfig_value napcat_process APPIMAGE)}"

if [[ -n "$NAPCAT_QQ_EXECUTABLE" ]]; then
  NAPCAT_QQ_EXECUTABLE="$(resolve_project_path "$NAPCAT_QQ_EXECUTABLE" "")"
fi
if [[ -n "$NAPCAT_APPIMAGE" ]]; then
  NAPCAT_APPIMAGE="$(resolve_project_path "$NAPCAT_APPIMAGE" "")"
fi

if [[ -z "$NAPCAT_QQ_EXECUTABLE" ]]; then
  NAPCAT_QQ_EXECUTABLE="$(find_first_executable \
    "$NAPCAT_INSTALL_BASE_DIR/opt/QQ/qq" \
    "$NAPCAT_HOME/Napcat/opt/QQ/qq" || true)"
fi

if [[ -z "$NAPCAT_APPIMAGE" ]]; then
  NAPCAT_APPIMAGE="$(find_first_appimage "$NAPCAT_HOME" || true)"
fi

detect_napcat_quick_login_account() {
  local login_dir="$NAPCAT_HOME/.config/QQ/nt_qq/global/nt_data/Login"
  [[ -d "$login_dir" ]] || return 0

  find "$login_dir" -maxdepth 1 -type f -name '.[0-9]*' -printf '%f\n' 2>/dev/null \
    | sed 's/^\\.//' \
    | sort -n \
    | tail -n 1
}

if [[ -z "$NAPCAT_QQ_ACCOUNT" ]]; then
  NAPCAT_QQ_ACCOUNT="$(detect_napcat_quick_login_account || true)"
fi

detect_napcat_launch_kind() {
  case "$NAPCAT_MODE" in
    custom)
      [[ -n "$NAPCAT_CUSTOM_COMMAND" ]] && { echo custom; return 0; }
      ;;
    shell)
      napcat_shell_ready && { echo shell; return 0; }
      ;;
    appimage)
      [[ -x "$NAPCAT_APPIMAGE" ]] && { echo appimage; return 0; }
      ;;
    docker)
      docker_container_exists "$NAPCAT_DOCKER_CONTAINER" && { echo docker; return 0; }
      ;;
    auto)
      if [[ -n "$NAPCAT_CUSTOM_COMMAND" ]]; then
        echo custom
      elif napcat_shell_ready; then
        echo shell
      elif [[ -x "$NAPCAT_APPIMAGE" ]]; then
        echo appimage
      elif docker_container_exists "$NAPCAT_DOCKER_CONTAINER"; then
        echo docker
      else
        echo missing
      fi
      return 0
      ;;
  esac

  echo missing
}

export NAPCAT_PM2_NAME
export NAPCAT_MODE
export NAPCAT_HOME
export NAPCAT_INSTALL_BASE_DIR
export NAPCAT_DOCKER_CONTAINER
export NAPCAT_QQ_ACCOUNT
export NAPCAT_EXTRA_ARGS
export NAPCAT_CUSTOM_COMMAND
export NAPCAT_QQ_EXECUTABLE
export NAPCAT_APPIMAGE
export NAPCAT_ECOSYSTEM_FILE
