#!/bin/bash
# MonBot 环境通用函数 (Linux)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export PROJECT_ROOT

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[✓] $*"
}

log_error() {
    echo "[✗] $*"
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "$1 未安装"
        return 1
    fi
    return 0
}
