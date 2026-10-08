#!/usr/bin/env bash

# Shared by source entry points and the optional QQBot runtime scripts.
find_mon_workspace_root() {
  local current
  current="$(cd "${1:?Missing BotLauncher root}" && pwd)" || return
  while :; do
    if [[ -f "$current/.monworkspace" ]]; then
      printf '%s\n' "$current"
      return 0
    fi
    [[ "$current" == "/" ]] && break
    current="$(dirname "$current")"
  done
  return 1
}

resolve_mon_workspace_root() {
  local project_root="${1:?Missing BotLauncher root}" discovered
  if [[ -n "${MON_WORKSPACE_ROOT:-}" ]]; then
    (cd "$MON_WORKSPACE_ROOT" && pwd)
  elif discovered="$(find_mon_workspace_root "$project_root")"; then
    printf '%s\n' "$discovered"
  else
    # Retain the standalone/legacy layout when no workspace marker exists.
    (cd "$project_root/.." && pwd)
  fi
}
