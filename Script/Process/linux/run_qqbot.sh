#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOT_ENTRY="$PROJECT_ROOT/BotCore/bot.py"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"

NO_CLEAN=0
for arg in "$@"; do
  case "$arg" in
    --no-clean)
      NO_CLEAN=1
      ;;
  esac
done

if [[ ! -f "$BOT_ENTRY" ]]; then
  echo "[x] QQBot 入口不存在: $BOT_ENTRY"
  exit 1
fi

if [[ -x "$VENV_PYTHON" ]]; then
  PYTHON_EXE="$VENV_PYTHON"
else
  PYTHON_EXE="python3"
fi

mkdir -p "$PROJECT_ROOT/logs"

echo "================================================"
echo "MonBot QQBot 前台启动"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "Python:   $PYTHON_EXE"
echo "脚本:     $BOT_ENTRY"
echo

if [[ "$NO_CLEAN" -eq 0 ]]; then
  find "$PROJECT_ROOT" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
  find "$PROJECT_ROOT" -type f -name "*.pyc" -delete 2>/dev/null || true
fi

export PYTHONUNBUFFERED=1
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1

exec "$PYTHON_EXE" "$BOT_ENTRY"
