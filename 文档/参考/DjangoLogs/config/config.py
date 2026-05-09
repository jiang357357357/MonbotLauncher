from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .levels import normalize_level


@dataclass
class LoggerConfig:
    console_enabled: bool = True
    file_enabled: bool = True  # 默认开启文件日志
    moncore_log_dir: Optional[Path] = None  # MonCore日志目录
    django_log_dir: Optional[Path] = None   # Django日志目录
    render_log_dir: Optional[Path] = None   # Render日志目录
    level: str = "INFO"
    max_bytes: int = 10 * 1024 * 1024  # 10MB
    backup_count: int = 5
    dual_file_enabled: bool = True  # 是否同时输出彩色和纯文本文件


_config = LoggerConfig()


def _init_from_project_config():
    """从项目的 Config.core.logging 中初始化配置"""
    try:
        import sys
        from pathlib import Path
        
        # 寻找 MonCore 根目录
        current_path = Path(__file__).resolve()
        project_root = None
        for parent in current_path.parents:
            if (parent / 'Config').exists() and (parent / 'Application').exists():
                project_root = parent
                break
        
        if project_root and str(project_root) not in sys.path:
            sys.path.insert(0, str(project_root))
            
        from Config.core.logging import (
            MONCORE_LOGS_DIR, DJANGO_LOGS_DIR, RENDER_LOGS_DIR,
            LOGGING_LEVEL, LOGGING_ROTATION, LOGGING_OUTPUT
        )
        
        _config.moncore_log_dir = MONCORE_LOGS_DIR
        _config.django_log_dir = DJANGO_LOGS_DIR
        _config.render_log_dir = RENDER_LOGS_DIR
        _config.level = normalize_level(LOGGING_LEVEL)
        _config.max_bytes = LOGGING_ROTATION.get('MAX_BYTES', 10 * 1024 * 1024)
        _config.backup_count = LOGGING_ROTATION.get('BACKUP_COUNT', 5)
        _config.console_enabled = LOGGING_OUTPUT.get('CONSOLE_ENABLED', True)
        _config.file_enabled = LOGGING_OUTPUT.get('FILE_ENABLED', True)
        _config.dual_file_enabled = LOGGING_OUTPUT.get('DUAL_FILE_ENABLED', True)
        
    except Exception as e:
        pass

# 执行初始化
_init_from_project_config()


def configure(
    log_dir: Optional[str] = None,
    console_enabled: bool = True,
    file_enabled: bool = False,
    level: str = "INFO",
    max_bytes: int = 10 * 1024 * 1024,
    backup_count: int = 5,
) -> None:
    _config.console_enabled = console_enabled
    _config.file_enabled = file_enabled
    _config.log_dir = Path(log_dir) if log_dir is not None else None
    _config.level = normalize_level(level)
    _config.max_bytes = max_bytes
    _config.backup_count = backup_count


def get_config() -> LoggerConfig:
    return _config

