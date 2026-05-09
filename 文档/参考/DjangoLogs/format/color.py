import sys
import logging
from datetime import datetime
from typing import TextIO


RESET = "\033[0m"
DIM = "\033[90m"  # Gray / Bright Black
LEVEL_COLORS = {
    "DEBUG": "\033[36m",      # Cyan
    "INFO": "\033[32m",       # Green
    "WARNING": "\033[1;33m",  # Bold Yellow
    "ERROR": "\033[1;31m",    # Bold Red
    "CRITICAL": "\033[1;41;37m", # Bold White on Red Background
}
MAIN_DEFAULT_COLOR = "\033[1;34m" # Bold Blue for Main module
SUB_DEFAULT_COLOR = "\033[35m"   # Magenta for Sub module
CTX_DEFAULT_COLOR = "\033[90m"   # Gray for context


class ColorFormatter(logging.Formatter):
    """
    标准 logging 的彩色格式化器，供 Django 等框架使用
    """
    def format(self, record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created).strftime("%H:%M:%S")
        
        # 获取模块信息，支持从 record 属性获取或从 logger name 解析
        main = getattr(record, 'main', 'Django')
        sub = getattr(record, 'sub', record.name)
        
        # 简化 sub 名称，如果包含 '.' 只取最后一部分
        if '.' in sub and sub != record.name:
            sub = sub.split('.')[-1]
            
        level_name = record.levelname
        message = record.getMessage()
        ctx = f"[{record.filename}:{record.lineno}]"
        
        # 颜色处理
        dim = DIM
        reset = RESET
        level_color = LEVEL_COLORS.get(level_name, "")
        main_color = get_dynamic_color(main)
        sub_color = get_dynamic_color(sub)
        ctx_color = "\033[37m"  # White for the code location box
        
        return (
            f"{dim}[{ts}]{reset}"
            f"{main_color}[{main}]{reset}"
            f"{sub_color}[{sub}]{reset}"
            f"{level_color}[{level_name}]{reset}"
            f"{ctx_color}{ctx}{reset} {message}"
        )


# Predefined colors for specific modules (priority)
PREDEFINED_COLORS = {
    "MonOs": "\033[1;34m",      # Bold Blue
    "Kernel": "\033[1;36m",     # Bold Cyan
    "Core": "\033[1;35m",       # Bold Magenta
    "Test": "\033[1;32m",       # Bold Green
    "Scheduler": "\033[1;33m",  # Bold Yellow
    "Executor": "\033[1;31m",   # Bold Red
    "Bootstrap": "\033[1;37m",  # Bold White
}

# Available colors for dynamic assignment (fallback)
DYNAMIC_COLORS = [
    "\033[31m", "\033[32m", "\033[33m", "\033[34m", "\033[35m", "\033[36m",
    "\033[91m", "\033[92m", "\033[93m", "\033[94m", "\033[95m", "\033[96m"
]

def get_dynamic_color(name: str) -> str:
    """Get a predefined color if exists, otherwise fallback to consistent hash color."""
    if not name:
        return RESET
    
    # Check predefined first
    if name in PREDEFINED_COLORS:
        return PREDEFINED_COLORS[name]
        
    # Fallback to hash-based selection
    color_idx = sum(ord(c) for c in name) % len(DYNAMIC_COLORS)
    return DYNAMIC_COLORS[color_idx]


def supports_color(stream: TextIO) -> bool:
    if not hasattr(stream, "isatty") or not stream.isatty():
        return False
    if sys.platform == "win32":
        try:
            import ctypes

            handle = ctypes.windll.kernel32.GetStdHandle(-11)
            mode = ctypes.c_uint()
            if ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                ctypes.windll.kernel32.SetConsoleMode(handle, mode.value | 4)
            return True
        except Exception:
            return False
    return True
