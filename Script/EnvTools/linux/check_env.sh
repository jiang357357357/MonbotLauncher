#!/bin/bash
# MonBot 环境检查脚本 (Linux)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"

echo ""
echo "================================================"
echo "  MonBot 环境检查工具"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo ""

check_passed=true

echo "[1/4] 检查项目配置..."
if [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    echo "  ✓ pyproject.toml 存在"
else
    echo "  ✗ 未找到 pyproject.toml"
    check_passed=false
fi
echo ""

echo "[2/4] 检查虚拟环境..."
if [ ! -d "$PROJECT_ROOT/.venv" ]; then
    echo "  ✗ 虚拟环境不存在 (.venv)"
    check_passed=false
else
    echo "  ✓ 虚拟环境存在"
    if [ -f "$VENV_PYTHON" ]; then
        echo "  ✓ Python: $($VENV_PYTHON --version)"
    else
        echo "  ✗ 虚拟环境损坏 (未找到 python)"
        check_passed=false
    fi
fi
echo ""

echo "[3/4] 检查关键依赖..."
if [ -f "$VENV_PYTHON" ]; then
    packages=(
        "nonebot2"
        "websockets"
        "aiohttp"
        "psutil"
    )
    for pkg in "${packages[@]}"; do
        if $VENV_PYTHON -c "from importlib.metadata import version; print(version('$pkg'))" 2>/dev/null; then
            echo "  ✓ $pkg"
        else
            echo "  ✗ $pkg 未安装"
            check_passed=false
        fi
    done
fi
echo ""

echo "[4/4] 检查日志目录..."
if [ -d "$PROJECT_ROOT/logs" ]; then
    echo "  ✓ logs 目录存在"
else
    echo "  ⚠ logs 目录不存在"
fi
echo ""

if [ "$check_passed" = true ]; then
    echo "[ENV_STATUS:INSTALLED]"
else
    echo "[ENV_STATUS:NOT_INSTALLED]"
    exit 1
fi
