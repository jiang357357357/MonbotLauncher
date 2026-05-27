"""
MonBot 启动器
同时启动 NapCat 和 MonBot 两个独立终端窗口
"""

import sys
import time
import subprocess
from pathlib import Path

# ──────────────────────────────────────────
# 路径配置（自动检测，通常无需修改）
# ──────────────────────────────────────────

PROJECT_ROOT = Path(__file__).parent

# NapCat 启动脚本
NAPCAT_LAUNCHER = PROJECT_ROOT / "napcat" / "launcher.bat"

# MonBot 入口文件
MONBOT_ENTRY = PROJECT_ROOT / "BotCore" / "bot.py"

# 虚拟环境 Python 解释器
VENV_PYTHON = PROJECT_ROOT / ".venv" / "Scripts" / "python.exe"

# NapCat 启动后等待时间（秒），等待 NapCat 初始化完成再启动 MonBot
NAPCAT_WAIT = 5

# ──────────────────────────────────────────


def check_env() -> bool:
    ok = True

    if not VENV_PYTHON.exists():
        print(f"[x] 虚拟环境不存在: {VENV_PYTHON}")
        print("    请先运行: uv sync")
        ok = False

    if not MONBOT_ENTRY.exists():
        print(f"[x] MonBot 入口文件不存在: {MONBOT_ENTRY}")
        ok = False

    if not NAPCAT_LAUNCHER.exists():
        print(f"[x] NapCat 启动脚本不存在: {NAPCAT_LAUNCHER}")
        ok = False

    return ok


def start_napcat() -> subprocess.Popen:
    """在新终端窗口中启动 NapCat"""
    print("[*] 启动 NapCat...")
    proc = subprocess.Popen(
        ["cmd", "/k", f"title NapCat && {NAPCAT_LAUNCHER}"],
        creationflags=subprocess.CREATE_NEW_CONSOLE,
        cwd=str(NAPCAT_LAUNCHER.parent),
    )
    print(f"    PID: {proc.pid}")
    return proc


def start_monbot() -> subprocess.Popen:
    """在新终端窗口中启动 MonBot"""
    print("[*] 启动 MonBot...")
    proc = subprocess.Popen(
        ["cmd", "/k", f"title MonBot && {VENV_PYTHON} {MONBOT_ENTRY}"],
        creationflags=subprocess.CREATE_NEW_CONSOLE,
        cwd=str(PROJECT_ROOT),
    )
    print(f"    PID: {proc.pid}")
    return proc


def main():
    print("=" * 40)
    print("    MonBot + NapCat 启动器")
    print("=" * 40)
    print()

    if not check_env():
        input("\n按 Enter 退出...")
        sys.exit(1)

    napcat_proc = start_napcat()

    print(f"[~] 等待 NapCat 初始化 ({NAPCAT_WAIT}s)...")
    time.sleep(NAPCAT_WAIT)

    monbot_proc = start_monbot()

    print()
    print("[ok] 启动完成！")
    print(f"     NapCat PID : {napcat_proc.pid}")
    print(f"     MonBot PID : {monbot_proc.pid}")
    print()
    print("关闭此窗口不会影响服务运行")
    input("按 Enter 退出启动器...")


if __name__ == "__main__":
    main()
