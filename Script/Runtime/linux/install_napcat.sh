#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
NAPCAT_HOME="${MON_NAPCAT_HOME:-$PROJECT_ROOT/napcat}"

RUNTIME_REPO_URL="${MON_NAPCAT_RUNTIME_REPO_URL:-https://gitee.com/shopownerjiang/MonNapCatRuntime.git}"
RUNTIME_REPO_BRANCH="${MON_NAPCAT_RUNTIME_REPO_BRANCH:-master}"
RUNTIME_PLATFORM="${MON_NAPCAT_RUNTIME_PLATFORM:-linux-x64}"
RUNTIME_VERSION="${MON_NAPCAT_RUNTIME_VERSION:-latest}"
RUNTIME_CACHE_ROOT="${MON_NAPCAT_RUNTIME_CACHE_ROOT:-$PROJECT_ROOT/.runtime/napcat-gitee}"
RUNTIME_REPO_DIR="$RUNTIME_CACHE_ROOT/MonNapCatRuntime"

DOWNLOAD_ONLY=0
FORCE_DOWNLOAD=0
INSTALLER_ARGS=(--docker n --cli n --proxy 0)
DEFAULT_INSTALLER_ARGS=1
SUDO_WRAPPER_DIR=""
SUDO_PASSWORD_FILE=""
REAL_SUDO=""

cleanup_privilege_helper() {
  if [[ -n "$SUDO_PASSWORD_FILE" && -f "$SUDO_PASSWORD_FILE" ]]; then
    rm -f "$SUDO_PASSWORD_FILE"
  fi
  if [[ -n "$SUDO_WRAPPER_DIR" && -d "$SUDO_WRAPPER_DIR" ]]; then
    rm -rf "$SUDO_WRAPPER_DIR"
  fi
}

trap cleanup_privilege_helper EXIT

print_usage() {
  cat <<'EOF'
用法:
  bash Script/Runtime/linux/install_napcat.sh [选项] [-- 安装器参数...]

选项:
  --download-only          只拉取并恢复 Gitee 离线包，不执行安装
  --run-installer          拉取离线包后执行安装（默认，兼容旧参数）
  --accept-napcat-license  兼容旧参数；离线包发布前已确认授权边界
  --version VERSION        NapCat 运行时版本，默认 latest
  --platform PLATFORM      运行时平台，默认 linux-x64
  --runtime-repo URL       Gitee 运行时仓库地址
  --runtime-branch BRANCH  Gitee 运行时仓库分支，默认 master
  --cache-root PATH        离线包缓存目录，默认 BotLauncher/.runtime/napcat-gitee
  --force                  重新拉取运行时仓库
  -h, --help               显示帮助

示例:
  bash Script/Runtime/linux/install_napcat.sh
  bash Script/Runtime/linux/install_napcat.sh --download-only
  bash Script/Runtime/linux/install_napcat.sh --version v4.18.7 -- --docker n --cli n --proxy 0

说明:
  本脚本默认从 Gitee 私有运行时仓库拉取 NapCat 离线包，并安装到 BotLauncher/napcat。
  NapCat 本体不进入 Mon 主仓库、BotLauncher 源码仓库或客户端 dist 仓库。
EOF
}

need_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[x] 缺少命令: $cmd"
    echo "[NAPCAT_STATUS:DEPENDENCY_MISSING]"
    return 1
  fi
}

create_sudo_wrapper() {
  local mode="$1"

  SUDO_WRAPPER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mon-napcat-sudo.XXXXXX")"
  cat >"$SUDO_WRAPPER_DIR/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" == "0" ]]; then
  exec "$@"
fi

if [[ "${MON_SUDO_MODE:-}" == "pkexec" ]]; then
  exec pkexec "$@"
fi

real_sudo="${MON_REAL_SUDO:-/usr/bin/sudo}"
if "$real_sudo" -n true 2>/dev/null; then
  exec "$real_sudo" -n "$@"
fi

if [[ -n "${MON_SUDO_PASSWORD_FILE:-}" && -r "$MON_SUDO_PASSWORD_FILE" ]]; then
  exec "$real_sudo" -S -p "" "$@" <"$MON_SUDO_PASSWORD_FILE"
fi

echo "sudo 授权不可用：请在安装弹窗输入 sudo 密码，或在终端运行安装脚本。" >&2
exit 1
EOF
  chmod 700 "$SUDO_WRAPPER_DIR/sudo"
  export PATH="$SUDO_WRAPPER_DIR:$PATH"
  export MON_SUDO_MODE="$mode"
  export MON_REAL_SUDO="$REAL_SUDO"
  if [[ -n "$SUDO_PASSWORD_FILE" ]]; then
    export MON_SUDO_PASSWORD_FILE="$SUDO_PASSWORD_FILE"
  fi
}

read_sudo_password_from_stdin() {
  local password=""
  IFS= read -r password || true
  if [[ -z "$password" ]]; then
    return 1
  fi

  SUDO_PASSWORD_FILE="$(mktemp "${TMPDIR:-/tmp}/mon-napcat-sudo-pass.XXXXXX")"
  chmod 600 "$SUDO_PASSWORD_FILE"
  printf '%s\n' "$password" >"$SUDO_PASSWORD_FILE"
  printf '%s\n' "$password"
}

prepare_sudo_for_runtime() {
  if [[ "$(id -u)" = "0" ]]; then
    REAL_SUDO="$(command -v sudo 2>/dev/null || true)"
    create_sudo_wrapper root
    echo "[OK] 当前已是 root 用户，已启用 root sudo 兼容包装器"
    return 0
  fi

  REAL_SUDO="$(command -v sudo 2>/dev/null || true)"

  if [[ -n "$REAL_SUDO" ]] && timeout 5s "$REAL_SUDO" -n true 2>/dev/null; then
    create_sudo_wrapper nopass
    echo "[OK] sudo 免密授权可用"
    return 0
  fi

  if [[ "${MON_STDIN_SECRET_PROVIDED:-0}" == "1" ]]; then
    if [[ -z "$REAL_SUDO" ]]; then
      echo "[x] 离线安装需要安装系统依赖，但当前系统未找到 sudo"
      echo "[NAPCAT_STATUS:SUDO_UNAVAILABLE]"
      return 3
    fi

    echo "[*] 正在验证 sudo 密码..."
    local sudo_password
    if ! sudo_password="$(read_sudo_password_from_stdin)"; then
      echo "[x] sudo 密码为空，无法完成授权"
      echo "[NAPCAT_STATUS:SUDO_REQUIRED]"
      return 3
    fi
    if printf '%s\n' "$sudo_password" | timeout 20s "$REAL_SUDO" -S -p "" -v; then
      unset sudo_password
      create_sudo_wrapper password
      echo "[OK] sudo 验证通过，已启用受控 sudo 包装器"
      return 0
    fi
    unset sudo_password
    echo "[x] sudo 密码验证失败"
    echo "[NAPCAT_STATUS:SUDO_AUTH_FAILED]"
    return 3
  fi

  if [[ -n "$REAL_SUDO" && -t 0 ]]; then
    echo "[*] 正在请求 sudo 授权..."
    if "$REAL_SUDO" -v; then
      create_sudo_wrapper nopass
      echo "[OK] sudo 授权通过，已启用受控 sudo 包装器"
      return 0
    fi
    echo "[x] sudo 授权失败"
    echo "[NAPCAT_STATUS:SUDO_AUTH_FAILED]"
    return 3
  fi

  if command -v pkexec >/dev/null 2>&1 && [[ -n "${DISPLAY:-${WAYLAND_DISPLAY:-}}" ]]; then
    create_sudo_wrapper pkexec
    echo "[OK] 将通过 pkexec 图形授权执行系统依赖安装"
    return 0
  fi

  if [[ -z "$REAL_SUDO" ]]; then
    echo "[x] 离线安装需要安装系统依赖，但当前系统未找到 sudo"
    echo "[NAPCAT_STATUS:SUDO_UNAVAILABLE]"
    return 3
  fi

  echo "[x] NapCat 安装器包含系统依赖安装步骤，需要 sudo 密码"
  echo "    请在 ConfigApp 的安装弹窗中输入 sudo 密码后重试，或在终端运行："
  echo "    bash $PROJECT_ROOT/Script/Runtime/linux/install_napcat.sh"
  echo "[NAPCAT_STATUS:SUDO_REQUIRED]"
  return 3
}

fetch_runtime_repo() {
  need_cmd git
  mkdir -p "$RUNTIME_CACHE_ROOT"

  if [[ "$FORCE_DOWNLOAD" -eq 1 ]]; then
    rm -rf "$RUNTIME_REPO_DIR"
  fi

  if [[ -d "$RUNTIME_REPO_DIR/.git" ]]; then
    echo "[*] 更新 Gitee NapCat 运行时仓库..."
    git -C "$RUNTIME_REPO_DIR" remote set-url origin "$RUNTIME_REPO_URL"
    git -C "$RUNTIME_REPO_DIR" fetch --quiet --depth 1 origin "$RUNTIME_REPO_BRANCH"
    git -c advice.detachedHead=false -C "$RUNTIME_REPO_DIR" checkout -f --detach FETCH_HEAD >/dev/null 2>&1
    git -C "$RUNTIME_REPO_DIR" clean -fdq
    return 0
  fi

  echo "[*] 拉取 Gitee NapCat 运行时仓库..."
  echo "    $RUNTIME_REPO_URL ($RUNTIME_REPO_BRANCH)"
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --branch "$RUNTIME_REPO_BRANCH" "$RUNTIME_REPO_URL" "$RUNTIME_REPO_DIR"
}

resolve_runtime_package_dir() {
  need_cmd python3
  python3 - "$RUNTIME_REPO_DIR" "$RUNTIME_PLATFORM" "$RUNTIME_VERSION" <<'PY'
import json
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])
platform = sys.argv[2]
version = sys.argv[3]

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(2)

def version_key(path: Path):
    text = path.name.lstrip("v")
    parts = []
    for item in re.split(r"[.-]", text):
        parts.append(int(item) if item.isdigit() else item)
    return parts

if version == "latest":
    root_manifest_path = repo / "manifest.json"
    if root_manifest_path.is_file():
        root_manifest = json.loads(root_manifest_path.read_text(encoding="utf-8"))
        current = root_manifest.get("current") or {}
        manifest_path = current.get("manifestPath")
        if current.get("platform") == platform and manifest_path:
            package_dir = (repo / manifest_path).parent
            if package_dir.is_dir():
                print(package_dir.relative_to(repo))
                sys.exit(0)

    base = repo / "napcat" / platform
    candidates = [item for item in base.iterdir() if (item / "manifest.json").is_file()] if base.is_dir() else []
    if not candidates:
        fail(f"未找到平台 {platform} 的 NapCat 运行时包")
    print(sorted(candidates, key=version_key)[-1].relative_to(repo))
    sys.exit(0)

package_dir = repo / "napcat" / platform / version
if not (package_dir / "manifest.json").is_file():
    fail(f"未找到 NapCat 运行时包: napcat/{platform}/{version}")
print(package_dir.relative_to(repo))
PY
}

restore_runtime_package() {
  local package_dir="$1"
  local restore_script="$package_dir/restore-napcat-offline.sh"
  local restore_output
  local bundle_dir

  if [[ ! -f "$restore_script" ]]; then
    echo "[x] 缺少离线包恢复脚本: $restore_script"
    echo "[NAPCAT_STATUS:RUNTIME_INVALID]"
    return 2
  fi

  echo "[*] 恢复 NapCat 离线包..."
  if ! restore_output="$(bash "$restore_script" 2>&1)"; then
    printf '%s\n' "$restore_output"
    echo "[NAPCAT_STATUS:RUNTIME_RESTORE_FAILED]"
    return 2
  fi
  printf '%s\n' "$restore_output"

  bundle_dir="$(printf '%s\n' "$restore_output" | sed -n 's/^\\[NAPCAT_OFFLINE_BUNDLE:\\(.*\\)\\]$/\\1/p' | tail -n 1)"
  if [[ -z "$bundle_dir" || ! -d "$bundle_dir" ]]; then
    bundle_dir="$(find "$package_dir" -maxdepth 1 -type d -name '*offline' -print -quit)"
  fi

  if [[ -z "$bundle_dir" || ! -f "$bundle_dir/install-offline.sh" ]]; then
    echo "[x] 未找到恢复后的 install-offline.sh"
    echo "[NAPCAT_STATUS:RUNTIME_RESTORE_FAILED]"
    return 2
  fi

  printf '%s\n' "$bundle_dir"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --download-only)
      DOWNLOAD_ONLY=1
      shift
      ;;
    --run-installer|--accept-napcat-license)
      shift
      ;;
    --version)
      RUNTIME_VERSION="${2:-}"
      shift 2
      ;;
    --platform)
      RUNTIME_PLATFORM="${2:-}"
      shift 2
      ;;
    --runtime-repo)
      RUNTIME_REPO_URL="${2:-}"
      shift 2
      ;;
    --runtime-branch)
      RUNTIME_REPO_BRANCH="${2:-}"
      shift 2
      ;;
    --cache-root)
      RUNTIME_CACHE_ROOT="${2:-}"
      RUNTIME_REPO_DIR="$RUNTIME_CACHE_ROOT/MonNapCatRuntime"
      shift 2
      ;;
    --force)
      FORCE_DOWNLOAD=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      if [[ "$DEFAULT_INSTALLER_ARGS" -eq 1 ]]; then
        DEFAULT_INSTALLER_ARGS=0
        INSTALLER_ARGS=()
      fi
      INSTALLER_ARGS+=("$@")
      break
      ;;
    *)
      if [[ "$DEFAULT_INSTALLER_ARGS" -eq 1 ]]; then
        DEFAULT_INSTALLER_ARGS=0
        INSTALLER_ARGS=()
      fi
      INSTALLER_ARGS+=("$1")
      shift
      ;;
  esac
done

echo "================================================"
echo "NapCat Gitee 离线运行时安装器 (Linux)"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "部署目录: $NAPCAT_HOME"
echo "运行时仓库: $RUNTIME_REPO_URL"
echo "运行时分支: $RUNTIME_REPO_BRANCH"
echo "运行时平台: $RUNTIME_PLATFORM"
echo "运行时版本: $RUNTIME_VERSION"
echo "缓存目录: $RUNTIME_CACHE_ROOT"
echo
echo "[!] NapCat 本体不进入 Mon 主仓库或客户端 dist 仓库。"
echo "[!] 当前脚本从单独的 Gitee 运行时仓库恢复离线包。"
echo

fetch_runtime_repo

package_rel="$(resolve_runtime_package_dir)"
package_dir="$RUNTIME_REPO_DIR/$package_rel"
echo "[OK] 选择运行时包: $package_rel"

bundle_output="$(restore_runtime_package "$package_dir")"
printf '%s\n' "$bundle_output"
bundle_dir="$(printf '%s\n' "$bundle_output" | tail -n 1)"

if [[ "$DOWNLOAD_ONLY" -eq 1 ]]; then
  echo
  echo "[NAPCAT_STATUS:RUNTIME_DOWNLOADED]"
  echo "离线包已准备: $bundle_dir"
  echo "执行安装:"
  echo "  $bundle_dir/install-offline.sh --botlauncher $PROJECT_ROOT"
  exit 0
fi

echo "[*] NapCat 安装器可能安装系统依赖，将进行 sudo 预授权..."
prepare_sudo_for_runtime

mkdir -p "$NAPCAT_HOME"

echo
echo "[*] 开始执行 NapCat 离线安装..."
echo "安装器参数: ${INSTALLER_ARGS[*]:-(无)}"
"$bundle_dir/install-offline.sh" --botlauncher "$PROJECT_ROOT" -- "${INSTALLER_ARGS[@]}"

echo
echo "[NAPCAT_STATUS:OFFLINE_INSTALLED]"
