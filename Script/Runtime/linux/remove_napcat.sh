#!/usr/bin/env bash

set -euo pipefail

unset PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROCESS_DIR="$PROJECT_ROOT/Script/Process/linux"

# shellcheck source=../../Process/linux/napcat_common.sh
source "$PROCESS_DIR/napcat_common.sh"

echo "================================================"
echo "NapCat 外置运行时卸载工具 (Linux)"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "部署目录: $NAPCAT_HOME"
echo "PM2 应用: $NAPCAT_PM2_NAME"
echo

safe_removable_path() {
  local target="$1"

  [[ -n "$target" ]] || return 1
  [[ "$target" = /* ]] || return 1
  [[ "$target" != "/" ]] || return 1
  [[ "$target" != "$HOME" ]] || return 1
  [[ "$target" != "$PROJECT_ROOT" ]] || return 1

  case "$target" in
    "$PROJECT_ROOT"/*)
      return 0
      ;;
  esac

  [[ "${MON_NAPCAT_ALLOW_EXTERNAL_REMOVE:-0}" == "1" ]]
}

remove_path() {
  local target="$1"

  if [[ ! -e "$target" ]]; then
    echo "[i] 跳过不存在的路径: $target"
    return 0
  fi

  if ! safe_removable_path "$target"; then
    echo "[x] 拒绝删除不安全路径: $target"
    echo "    如确需删除工作区外路径，请设置 MON_NAPCAT_ALLOW_EXTERNAL_REMOVE=1"
    echo "[NAPCAT_STATUS:REMOVE_REFUSED]"
    return 2
  fi

  echo "[*] 删除运行时目录: $target"
  if rm -rf -- "$target" 2>/tmp/mon-napcat-remove.err; then
    echo "[OK] 已删除: $target"
    rm -f /tmp/mon-napcat-remove.err
    return 0
  fi

  echo "[!] 普通删除失败，尝试 sudo 删除..."
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo rm -rf -- "$target"
    echo "[OK] sudo 已删除: $target"
    rm -f /tmp/mon-napcat-remove.err
    return 0
  fi

  if [[ "${MON_STDIN_SECRET_PROVIDED:-0}" == "1" ]] && command -v sudo >/dev/null 2>&1; then
    sudo -S -p "" rm -rf -- "$target"
    echo "[OK] sudo 已删除: $target"
    rm -f /tmp/mon-napcat-remove.err
    return 0
  fi

  echo "[x] 删除失败: $target"
  cat /tmp/mon-napcat-remove.err 2>/dev/null || true
  rm -f /tmp/mon-napcat-remove.err
  echo "[NAPCAT_STATUS:REMOVE_NEEDS_SUDO]"
  return 3
}

if command -v pm2 >/dev/null 2>&1; then
  pm2_status="$(pm2_named_status "$NAPCAT_PM2_NAME" 2>/dev/null || printf 'missing')"
  if [[ "$pm2_status" != "missing" ]]; then
    echo "[*] 停止并移除 PM2 应用: $NAPCAT_PM2_NAME ($pm2_status)"
    run_pm2_quiet delete "$NAPCAT_PM2_NAME" || true
    pm2_cmd save --force >/dev/null 2>&1 || true
  else
    echo "[i] PM2 中未找到 NapCat 应用"
  fi
else
  echo "[i] 未找到 pm2，跳过 PM2 清理"
fi

if docker_container_exists "$NAPCAT_DOCKER_CONTAINER"; then
  echo "[*] 删除 Docker 容器: $NAPCAT_DOCKER_CONTAINER"
  docker rm -f "$NAPCAT_DOCKER_CONTAINER" || true
fi

remove_path "$NAPCAT_HOME"

echo
echo "[NAPCAT_STATUS:REMOVED]"
echo "NapCat 外置运行时已卸载。"
