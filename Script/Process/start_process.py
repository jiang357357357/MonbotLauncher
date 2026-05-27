"""
MonBot 后台进程启动工具
在后台启动 MonBot Launcher 服务。
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
LAUNCHER_SCRIPT = PROJECT_ROOT / "launcher.py"
VENV_PYTHON = PROJECT_ROOT / ".venv" / "Scripts" / "python.exe"
LOG_DIR = PROJECT_ROOT / "logs"
LOG_FILE = LOG_DIR / "monbot_process.log"


def main() -> int:
    parser = argparse.ArgumentParser(description="MonBot 后台进程启动工具")
    parser.add_argument("--force", action="store_true", help="即使已有进程也强制重启")
    args = parser.parse_args()

    print("=" * 48)
    print("MonBot 后台进程启动工具")
    print("=" * 48)
    print(f"项目根目录: {PROJECT_ROOT}")
    print()

    if not LAUNCHER_SCRIPT.exists():
        print(f"[✗] 未找到启动脚本: {LAUNCHER_SCRIPT}")
        return 1

    log_dir = LOG_DIR
    log_dir.mkdir(parents=True, exist_ok=True)

    python_exe = VENV_PYTHON if VENV_PYTHON.exists() else Path("python")

    print(f"[i] Python: {python_exe}")
    print(f"[i] 启动脚本: {LAUNCHER_SCRIPT}")
    print(f"[i] 日志文件: {LOG_FILE}")
    print()

    log_file = open(LOG_FILE, "a", encoding="utf-8")
    log_file.write(f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] 启动 MonBot...\n")
    log_file.flush()

    process = subprocess.Popen(
        [str(python_exe), str(LAUNCHER_SCRIPT)],
        stdout=log_file,
        stderr=log_file,
        cwd=str(PROJECT_ROOT),
        creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
    )

    time.sleep(2)

    if process.poll() is not None:
        print(f"[✗] 进程启动后立即退出 (PID: {process.pid})")
        log_file.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] 进程启动失败\n")
        log_file.close()
        return 1

    print(f"[✓] MonBot 已在后台启动 (PID: {process.pid})")
    print(f"    日志: {LOG_FILE}")
    print()
    print("管理命令:")
    print("  查看状态: python Script/Process/status_process.py")
    print("  停止服务: python Script/Process/stop_process.py")

    log_file.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] MonBot 进程启动 - PID: {process.pid}\n")
    log_file.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
