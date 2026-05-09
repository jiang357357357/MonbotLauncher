from .config import LoggerConfig, configure, get_config
from .logger import ColoredLogger, get_logger
from .handlers import shutdown
from .format.color import ColorFormatter

# 快捷获取日志器的别名，为了兼容标准库的使用习惯
getLogger = get_logger

__all__ = [
    "LoggerConfig",
    "configure",
    "get_config",
    "ColoredLogger",
    "get_logger",
    "getLogger",
    "shutdown",
    "ColorFormatter",
]
