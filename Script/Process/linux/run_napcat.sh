#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=napcat_common.sh
source "$SCRIPT_DIR/napcat_common.sh"

kind="$(detect_napcat_launch_kind)"

mkdir -p "$NAPCAT_HOME"
export HOME="$NAPCAT_HOME"
export XDG_CONFIG_HOME="$NAPCAT_HOME/.config"
export XDG_CACHE_HOME="$NAPCAT_HOME/.cache"
export XDG_DATA_HOME="$NAPCAT_HOME/.local/share"

echo "================================================"
echo "NapCat PM2 前台运行器"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "部署目录: $NAPCAT_HOME"
echo "运行模式: $kind"
echo

case "$kind" in
  custom)
    echo "命令: $NAPCAT_CUSTOM_COMMAND"
    exec bash -lc "$NAPCAT_CUSTOM_COMMAND"
    ;;
  shell)
    args=(--no-sandbox)
    if [[ -n "$NAPCAT_QQ_ACCOUNT" ]]; then
      args+=(-q "$NAPCAT_QQ_ACCOUNT")
    fi
    if [[ -n "$NAPCAT_EXTRA_ARGS" ]]; then
      read -r -a extra_args <<< "$NAPCAT_EXTRA_ARGS"
      args+=("${extra_args[@]}")
    fi

    echo "QQ执行文件: $NAPCAT_QQ_EXECUTABLE"
    if command -v xvfb-run >/dev/null 2>&1; then
      exec xvfb-run -a "$NAPCAT_QQ_EXECUTABLE" "${args[@]}"
    fi

    echo "[!] 未找到 xvfb-run，将直接启动 QQ 可执行文件"
    exec "$NAPCAT_QQ_EXECUTABLE" "${args[@]}"
    ;;
  appimage)
    args=()
    if [[ -n "$NAPCAT_EXTRA_ARGS" ]]; then
      read -r -a extra_args <<< "$NAPCAT_EXTRA_ARGS"
      args+=("${extra_args[@]}")
    fi

    echo "AppImage: $NAPCAT_APPIMAGE"
    exec "$NAPCAT_APPIMAGE" "${args[@]}"
    ;;
  docker)
    echo "Docker容器: $NAPCAT_DOCKER_CONTAINER"
    if [[ "$(docker inspect -f '{{.State.Running}}' "$NAPCAT_DOCKER_CONTAINER")" == "true" ]]; then
      exec docker logs -f "$NAPCAT_DOCKER_CONTAINER"
    fi
    exec docker start -a "$NAPCAT_DOCKER_CONTAINER"
    ;;
  *)
    echo "[x] 未发现可由 PM2 启动的 NapCat 运行时"
    echo "    默认 Shell 路径: $NAPCAT_INSTALL_BASE_DIR/opt/QQ/qq"
    echo "    默认部署目录: $NAPCAT_HOME"
    echo "    安装命令: bash Script/Runtime/linux/install_napcat.sh --run-installer --accept-napcat-license -- --docker n --cli n --proxy 0"
    exit 1
    ;;
esac
