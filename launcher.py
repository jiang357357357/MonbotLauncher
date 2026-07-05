"""
MonBot 启动器
同时启动 NapCat 和 MonBot 两个独立终端窗口
"""

import sys
import time
import subprocess
import os
from pathlib import Path

from Script.Process.log_paths import begin_start_log, log_root


def configure_stdio() -> None:
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        if stream is None or not hasattr(stream, "reconfigure"):
            continue
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


configure_stdio()

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


def resolve_log_start_dir() -> Path:
    existing = os.environ.get("MON_LOG_START_DIR")
    if existing:
        return Path(existing)

    start_dir = begin_start_log(PROJECT_ROOT)
    os.environ["MON_PROJECT_ROOT"] = str(PROJECT_ROOT)
    os.environ["MON_LOG_ROOT"] = str(log_root(PROJECT_ROOT))
    os.environ["MON_LOG_START_DIR"] = str(start_dir)
    os.environ["PYTHONIOENCODING"] = "utf-8"
    os.environ["PYTHONUTF8"] = "1"
    os.environ["PYTHONUNBUFFERED"] = "1"
    return start_dir


def pause(message: str) -> None:
    try:
        input(message)
    except EOFError:
        return


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
    env = os.environ.copy()
    proc = subprocess.Popen(
        ["cmd", "/k", f"title MonBot && {VENV_PYTHON} {MONBOT_ENTRY}"],
        creationflags=subprocess.CREATE_NEW_CONSOLE,
        cwd=str(PROJECT_ROOT),
        env=env,
    )
    print(f"    PID: {proc.pid}")
    return proc


def main():
    print("=" * 40)
    print("    MonBot + NapCat 启动器")
    print("=" * 40)
    print()

    if not check_env():
        pause("\n按 Enter 退出...")
        sys.exit(1)

    start_dir = resolve_log_start_dir()
    print(f"[i] 日志根目录: {log_root(PROJECT_ROOT)}")
    print(f"[i] 本次启动目录: {start_dir}")
    print()

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
    pause("按 Enter 退出启动器...")


if __name__ == "__main__":
    main()
