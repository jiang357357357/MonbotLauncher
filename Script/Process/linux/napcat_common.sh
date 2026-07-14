#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MON_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.monconfig"
MONPM_MODULE="$MON_ROOT/Script/launch/linux/monpm-module.sh"
MONPM_LAUNCHER="$MON_ROOT/Script/launch/linux/monpm.sh"

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

monpm_named_status() {
  local app_name="$1"
  export MONPM_STATUS_APP="$app_name"
  "$MONPM_LAUNCHER" list -json | node -e '
    const fs = require("fs");
    const apps = JSON.parse(fs.readFileSync(0, "utf8") || "[]");
    const app = apps.find((item) => item.name === process.env.MONPM_STATUS_APP);
    process.stdout.write(app ? app.state : "missing");
  '
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

NAPCAT_MONPM_NAME="napcat"
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

export NAPCAT_MONPM_NAME
export NAPCAT_MODE
export NAPCAT_HOME
export NAPCAT_INSTALL_BASE_DIR
export NAPCAT_DOCKER_CONTAINER
export NAPCAT_QQ_ACCOUNT
export NAPCAT_EXTRA_ARGS
export NAPCAT_CUSTOM_COMMAND
export NAPCAT_QQ_EXECUTABLE
export NAPCAT_APPIMAGE
export MONPM_MODULE
export MONPM_LAUNCHER
