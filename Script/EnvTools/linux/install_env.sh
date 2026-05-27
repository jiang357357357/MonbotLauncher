#!/bin/bash
# MonBot 环境安装脚本 (Linux)
# 使用 UV 自动安装 Python 3.12.x 和所有依赖

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/common.sh"

echo ""
echo "================================================"
echo "  MonBot 环境安装工具"
echo "================================================"
echo "项目根目录: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

echo "[0/5] 检查项目配置..."
if [ ! -f "pyproject.toml" ]; then
    log_error "未找到 pyproject.toml"
    echo "[INSTALL_STATUS:FAILED]"
    exit 1
fi
log_success "找到 pyproject.toml"
echo ""

echo "[1/5] 检查 UV 包管理器..."
if ! check_command uv; then
    log_info "UV 未安装，正在安装..."
    pip install uv
fi
log_success "UV 已安装: $(uv --version)"
echo ""

echo "[2/5] 安装 Python 3.12.x..."
uv python install 3.12.6
log_success "Python 3.12.6 安装成功"

uv python pin 3.12.6
log_success "Python 版本已固定为 3.12.6"
echo ""

echo "[3/5] 创建虚拟环境并安装依赖..."
if [ -d ".venv" ]; then
    rm -rf ".venv"
    log_success "旧虚拟环境已删除"
fi

uv sync
log_success "虚拟环境创建成功"
log_success "所有依赖已安装"
echo ""

VENV_PYTHON=".venv/bin/python"
echo "[4/5] 验证安装..."
if [ ! -f "$VENV_PYTHON" ]; then
    log_error "虚拟环境 Python 不存在"
    echo "[INSTALL_STATUS:FAILED]"
    exit 1
fi
log_success "Python 版本: $($VENV_PYTHON --version)"

packages=("nonebot2" "websockets" "aiohttp")
for pkg in "${packages[@]}"; do
    if $VENV_PYTHON -c "from importlib.metadata import version; print(version('$pkg'))" 2>/dev/null; then
        log_success "$pkg"
    else
        log_error "$pkg"
    fi
done
echo ""

echo "[5/5] 创建必要的目录..."
mkdir -p logs
log_success "日志目录已就绪: logs"
echo ""

echo "[INSTALL_STATUS:SUCCESS]"
echo "下一步操作:"
echo "  启动服务: ./Script/Cmd/linux/start.sh"
echo "  检查环境: ./Script/EnvTools/linux/check_env.sh"
