#!/usr/bin/env bash

set -euo pipefail

LOG_ROOT="${MON_LOG_ROOT:-$PROJECT_ROOT/Logs}"
START_DIR_PREFIX="start_"
KEEP_START_COUNT="${MON_LOG_KEEP_START_COUNT:-10}"
CURRENT_START_FILE="$LOG_ROOT/current_start.txt"
START_COUNTER_FILE="$LOG_ROOT/startup_counter.txt"

start_dirs() {
  [[ -d "$LOG_ROOT" ]] || return 0
  find "$LOG_ROOT" -maxdepth 1 -type d -name "${START_DIR_PREFIX}[0-9]*" -printf '%p\n' 2>/dev/null | sort
}

parse_start_index() {
  local name
  name="$(basename "$1")"
  name="${name#"$START_DIR_PREFIX"}"
  if [[ "$name" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$((10#$name))"
  else
    printf '0\n'
  fi
}

latest_start_dir() {
  if [[ -f "$CURRENT_START_FILE" ]]; then
    local current
    current="$(cat "$CURRENT_START_FILE" 2>/dev/null || true)"
    if [[ -n "$current" ]]; then
      if [[ "$current" = /* ]]; then
        [[ -d "$current" ]] && printf '%s\n' "$current" && return 0
      elif [[ -d "$LOG_ROOT/$current" ]]; then
        printf '%s\n' "$LOG_ROOT/$current" && return 0
      fi
    fi
  fi

  start_dirs | tail -n 1
}

prune_old_start_dirs() {
  mapfile -t dirs < <(start_dirs)
  local count="${#dirs[@]}"
  if (( count <= KEEP_START_COUNT )); then
    return 0
  fi

  local remove_count=$((count - KEEP_START_COUNT))
  local index
  for ((index = 0; index < remove_count; index++)); do
    rm -rf "${dirs[$index]}"
  done
}

begin_start_log() {
  mkdir -p "$LOG_ROOT"

  local counter=0
  if [[ -f "$START_COUNTER_FILE" ]]; then
    local raw_counter
    raw_counter="$(cat "$START_COUNTER_FILE" 2>/dev/null || true)"
    [[ "$raw_counter" =~ ^[0-9]+$ ]] && counter="$raw_counter"
  fi

  local highest=0
  local dir index
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    index="$(parse_start_index "$dir")"
    (( index > highest )) && highest="$index"
  done < <(start_dirs)

  local next=$((counter > highest ? counter + 1 : highest + 1))
  for ((index = next; index < next + 1000; index++)); do
    local start_dir
    start_dir="$LOG_ROOT/$(printf '%s%06d' "$START_DIR_PREFIX" "$index")"
    if mkdir "$start_dir" 2>/dev/null; then
      mkdir -p "$start_dir/Process" "$start_dir/Text"
      printf '%s\n' "$index" > "$START_COUNTER_FILE"
      basename "$start_dir" > "$CURRENT_START_FILE"
      prune_old_start_dirs
      printf '%s\n' "$start_dir"
      return 0
    fi
  done

  echo "[x] 无法创建新的启动日志目录" >&2
  return 1
}

ensure_log_start_dir() {
  if [[ -n "${MON_LOG_START_DIR:-}" ]]; then
    mkdir -p "$MON_LOG_START_DIR/Process" "$MON_LOG_START_DIR/Text"
    printf '%s\n' "$MON_LOG_START_DIR"
    return 0
  fi

  begin_start_log
}

append_process_log() {
  local message="$1"
  local start_dir
  start_dir="$(latest_start_dir || true)"
  [[ -n "$start_dir" ]] || return 0
  mkdir -p "$start_dir/Process"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$start_dir/Process/monbot_process.log"
}

export MON_LOG_ROOT="$LOG_ROOT"
