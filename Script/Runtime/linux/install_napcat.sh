#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
NAPCAT_HOME="${MON_NAPCAT_HOME:-$PROJECT_ROOT/napcat}"
INSTALLER_ROOT="${MON_NAPCAT_INSTALLER_ROOT:-$NAPCAT_HOME/.installer}"
INSTALLER_URL="${MON_NAPCAT_INSTALLER_URL:-https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh}"
INSTALLER_FILE="$INSTALLER_ROOT/install.sh"

RUN_INSTALLER=1
ACCEPT_LICENSE=1
DEFAULT_INSTALLER_ARGS=1
INSTALLER_ARGS=(--docker n --cli n)

print_usage() {
  cat <<'EOF'
用法:
  bash Script/Runtime/linux/install_napcat.sh [选项] [-- 安装器参数...]

选项:
  --download-only          只下载官方 NapCat 安装器，不执行安装器
  --run-installer          下载后执行官方 NapCat 安装器（默认）
  --accept-napcat-license  确认已阅读并接受 NapCatQQ 当前许可证约束
  -h, --help               显示帮助

示例:
  bash Script/Runtime/linux/install_napcat.sh
  bash Script/Runtime/linux/install_napcat.sh --download-only
  bash Script/Runtime/linux/install_napcat.sh --run-installer --accept-napcat-license -- --docker n --cli n

说明:
  本脚本默认把 NapCat 部署到 BotLauncher/napcat，本目录已被 Git 忽略。
  无参数执行时默认运行官方安装器，并使用 Shell/Rootless 模式：--docker n --cli n。
  不固定 --proxy，让官方安装器按客户机网络自动选择 GitHub 下载代理。
  NapCatQQ 当前许可证包含非商业使用限制，分发前请确认你已获得所需授权。
EOF
}

download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --connect-timeout 20 -o "$output" "$url"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
    return 0
  fi

  echo "[x] 未找到 curl 或 wget，无法下载官方安装器"
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --download-only)
      RUN_INSTALLER=0
      shift
      ;;
    --run-installer)
      RUN_INSTALLER=1
      shift
      ;;
    --accept-napcat-license)
      ACCEPT_LICENSE=1
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
echo "NapCat 外置运行时安装器 (Linux)"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "部署目录: $NAPCAT_HOME"
echo "安装器目录: $INSTALLER_ROOT"
echo "官方安装器: $INSTALLER_URL"
echo
echo "[!] NapCatQQ 本体不应进入 Mon 的 Gitee 分发仓库。"
echo "[!] 如需商业或客户分发，请先取得 NapCatQQ 主作者明确授权。"
echo

mkdir -p "$NAPCAT_HOME" "$INSTALLER_ROOT"
download_file "$INSTALLER_URL" "$INSTALLER_FILE"
chmod +x "$INSTALLER_FILE"

echo
echo "[OK] 官方安装器已下载: $INSTALLER_FILE"

if [[ "$RUN_INSTALLER" -eq 0 ]]; then
  echo
  echo "[NAPCAT_STATUS:INSTALLER_DOWNLOADED]"
  echo "执行安装:"
  echo "  bash Script/Runtime/linux/install_napcat.sh --run-installer --accept-napcat-license -- <安装器参数>"
  exit 0
fi

if [[ "$ACCEPT_LICENSE" -ne 1 ]]; then
  echo
  echo "[x] 执行安装器前需要显式确认 NapCatQQ 许可证"
  echo "    参数: --accept-napcat-license"
  echo
  echo "[NAPCAT_STATUS:LICENSE_NOT_ACCEPTED]"
  exit 2
fi

echo
echo "[*] 开始执行官方 NapCat 安装器..."
echo "安装器参数: ${INSTALLER_ARGS[*]:-(无)}"
(
  cd "$NAPCAT_HOME"
  HOME="$NAPCAT_HOME" bash "$INSTALLER_FILE" "${INSTALLER_ARGS[@]}"
)

echo
echo "[NAPCAT_STATUS:INSTALLER_FINISHED]"
