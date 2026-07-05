from __future__ import annotations

import shutil
from pathlib import Path
from typing import Optional


START_DIR_PREFIX = "start_"
KEEP_START_COUNT = 10
CURRENT_START_FILE_NAME = "current_start.txt"
START_COUNTER_FILE_NAME = "startup_counter.txt"
PROCESS_LOG_NAME = "monbot_process.log"
TEXT_LOG_NAME = "monbot.log"
PROCESS_CATEGORY = "Process"
TEXT_CATEGORY = "Text"


def log_root(project_root: Path) -> Path:
    return project_root / "Logs"


def current_start_file(project_root: Path) -> Path:
    return log_root(project_root) / CURRENT_START_FILE_NAME


def start_counter_file(project_root: Path) -> Path:
    return log_root(project_root) / START_COUNTER_FILE_NAME


def parse_start_index(path: Path) -> int:
    if not path.name.startswith(START_DIR_PREFIX):
        return -1
    try:
        return int(path.name[len(START_DIR_PREFIX) :])
    except ValueError:
        return -1


def start_dirs(project_root: Path) -> list[Path]:
    root = log_root(project_root)
    if not root.exists():
        return []
    dirs = [
        path
        for path in root.iterdir()
        if path.is_dir() and path.name.startswith(START_DIR_PREFIX)
    ]
    return sorted(
        dirs,
        key=lambda path: (
            parse_start_index(path),
            path.stat().st_mtime if path.exists() else 0,
        ),
    )


def read_start_counter(project_root: Path) -> int:
    try:
        return int(start_counter_file(project_root).read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return 0


def write_start_counter(project_root: Path, value: int) -> None:
    start_counter_file(project_root).write_text(str(value), encoding="utf-8")


def latest_start_dir(project_root: Path) -> Optional[Path]:
    root = log_root(project_root)
    try:
        current = current_start_file(project_root).read_text(encoding="utf-8").strip()
    except OSError:
        current = ""

    if current:
        candidate = Path(current)
        if not candidate.is_absolute():
            candidate = root / candidate
        if candidate.is_dir():
            return candidate

    dirs = start_dirs(project_root)
    return dirs[-1] if dirs else None


def prune_old_start_dirs(project_root: Path, keep: int = KEEP_START_COUNT) -> None:
    dirs = start_dirs(project_root)
    stale_dirs = dirs[: max(0, len(dirs) - keep)]
    for path in stale_dirs:
        shutil.rmtree(path, ignore_errors=True)


def begin_start_log(project_root: Path) -> Path:
    root = log_root(project_root)
    root.mkdir(parents=True, exist_ok=True)

    highest_existing = max((parse_start_index(path) for path in start_dirs(project_root)), default=0)
    next_index = max(read_start_counter(project_root), highest_existing) + 1
    for index in range(next_index, next_index + 1000):
        start_dir = root / f"{START_DIR_PREFIX}{index:06d}"
        try:
            (start_dir / PROCESS_CATEGORY).mkdir(parents=True)
            (start_dir / TEXT_CATEGORY).mkdir(parents=True)
        except FileExistsError:
            continue

        write_start_counter(project_root, index)
        current_start_file(project_root).write_text(start_dir.name, encoding="utf-8")
        prune_old_start_dirs(project_root)
        return start_dir

    raise RuntimeError("无法创建新的启动日志目录")


def process_log_file(start_dir: Path) -> Path:
    return start_dir / PROCESS_CATEGORY / PROCESS_LOG_NAME


def text_log_file(start_dir: Path) -> Path:
    return start_dir / TEXT_CATEGORY / TEXT_LOG_NAME
