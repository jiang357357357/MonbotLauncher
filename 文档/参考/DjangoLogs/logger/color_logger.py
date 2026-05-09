import threading
import sys
import os
import traceback
from typing import TextIO, Optional, Dict, Tuple, Any
from dataclasses import dataclass
from datetime import datetime

from ..config import get_config, get_level_value
from ..handlers.base import LogRecord
from ..handlers.registry import get_handlers


@dataclass
class LoggerIdentity:
    main: str
    sub: str


class ColoredLogger:
    def __init__(self, main: str, sub: str = "", stream: Optional[TextIO] = None):
        self.identity = LoggerIdentity(main=main, sub=sub)
        self.handlers = get_handlers(main, sub, stream)
        self.name = f"{main}.{sub}" if sub else main

    def _log(self, level_name: str, message: str, exc_info: Any = None) -> None:
        config = get_config()
        current_level = get_level_value(level_name)
        global_level = get_level_value(config.level)
        if current_level < global_level:
            return

        # Capture caller info
        filename, lineno, func_name = None, None, None
        try:
            # frame 0 is _log, frame 1 is debug/info/etc, frame 2 is the actual caller
            frame = sys._getframe(2)
            filename = os.path.basename(frame.f_code.co_filename)
            lineno = frame.f_lineno
            func_name = frame.f_code.co_name
        except (ValueError, AttributeError):
            pass

        # Handle exception info
        formatted_exc = None
        if exc_info:
            if isinstance(exc_info, bool):
                exc_info = sys.exc_info()
            if isinstance(exc_info, tuple):
                formatted_exc = "".join(traceback.format_exception(*exc_info))
            elif isinstance(exc_info, Exception):
                formatted_exc = "".join(traceback.format_exception(type(exc_info), exc_info, exc_info.__traceback__))

        record = LogRecord(
            timestamp=datetime.now(),
            main=self.identity.main,
            sub=self.identity.sub,
            level_name=level_name,
            level_no=current_level,
            message=message,
            filename=filename,
            lineno=lineno,
            func_name=func_name,
            exc_info=formatted_exc,
        )
        for handler in self.handlers:
            handler.emit(record)

    def debug(self, message: str, *args, **kwargs) -> None:
        self._log("DEBUG", message, exc_info=kwargs.get('exc_info'))

    def info(self, message: str, *args, **kwargs) -> None:
        self._log("INFO", message, exc_info=kwargs.get('exc_info'))

    def warning(self, message: str, *args, **kwargs) -> None:
        self._log("WARNING", message, exc_info=kwargs.get('exc_info'))

    def error(self, message: str, *args, **kwargs) -> None:
        self._log("ERROR", message, exc_info=kwargs.get('exc_info'))

    def critical(self, message: str, *args, **kwargs) -> None:
        self._log("CRITICAL", message, exc_info=kwargs.get('exc_info'))


_logger_cache: Dict[Tuple[str, str, Optional[TextIO]], ColoredLogger] = {}
_cache_lock = threading.Lock()


def get_logger(main: str, sub: str = "", stream: Optional[TextIO] = None) -> ColoredLogger:
    key = (main, sub, stream)
    with _cache_lock:
        logger = _logger_cache.get(key)
        if logger is None:
            logger = ColoredLogger(main=main, sub=sub, stream=stream)
            _logger_cache[key] = logger
    return logger

