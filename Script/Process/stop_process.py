"""
MonBot 进程停止工具
停止后台运行的 MonBot 及相关进程（NapCat）。
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
LOG_DIR = PROJECT_ROOT / "logs"
LOG_FILE = LOG_DIR / "monbot_process.log"


def _find_python_processes(name_filter: str = ""):
    """查找 Python 进程"""
    import psutil
    results = []
    for proc in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            cmdline = proc.info.get("cmdline") or []
            cmd_str = " ".join(cmdline)
            if "python" in proc.info.get("name", "").lower() and name_filter in cmd_str:
                results.append(proc)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return results


def _find_napcat_processes():
    """查找 NapCat 进程"""
    import psutil
    results = []
    for proc in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            name = proc.info.get("name", "").lower()
            cmdline = proc.info.get("cmdline") or []
            cmd_str = " ".join(cmdline)
            if "napcat" in name or "napcat" in cmd_str:
                results.append(proc)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="MonBot 进程停止工具")
    parser.add_argument("--force", action="store_true", help="强制停止进程")
    args = parser.parse_args()

    print("=" * 48)
    print("MonBot 进程停止工具")
    print("=" * 48)
    print()

    # 停止 MonBot
    print("[1/2] 查找 MonBot 进程...")
    monbot_procs = _find_python_processes("launcher.py")
    if not monbot_procs:
        print("  [!] 未找到运行中的 MonBot 进程")
    else:
        for proc in monbot_procs:
            try:
                print(f"  [→] 停止 MonBot (PID: {proc.info['pid']})...")
                if args.force:
                    proc.kill()
                else:
                    proc.terminate()
                print(f"  [✓] 已停止")
            except Exception as e:
                print(f"  [✗] 停止失败: {e}")
    print()

    # 停止 NapCat
    print("[2/2] 查找 NapCat 进程...")
    napcat_procs = _find_napcat_processes()
    if not napcat_procs:
        print("  [!] 未找到运行中的 NapCat 进程")
    else:
        for proc in napcat_procs:
            try:
                print(f"  [→] 停止 NapCat (PID: {proc.info['pid']})...")
                if args.force:
                    proc.kill()
                else:
                    proc.terminate()
                print(f"  [✓] 已停止")
            except Exception as e:
                print(f"  [✗] 停止失败: {e}")

    print()
    if monbot_procs or napcat_procs:
        print("[✓] 进程已停止")
    else:
        print("[!] 无进程需要停止")
    return 0


if __name__ == "__main__":
    sys.exit(main())
