#!/bin/bash
# MonBot 环境删除脚本 (Linux)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$PROJECT_ROOT"

PATHS_TO_REMOVE=(".venv" ".python-version" "uv.lock")
REMOVED=0

for item in "${PATHS_TO_REMOVE[@]}"; do
    if [ -e "$item" ]; then
        rm -rf "$item"
        echo "✓ 已删除: $item"
        ((REMOVED++))
    fi
done

find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

if [ $REMOVED -gt 0 ]; then
    echo "[REMOVE_STATUS:SUCCESS]"
else
    echo "[REMOVE_STATUS:NOTHING]"
fi
