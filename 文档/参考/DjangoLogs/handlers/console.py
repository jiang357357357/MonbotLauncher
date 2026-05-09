import threading
from typing import TextIO

from .base import BaseHandler, LogRecord
from ..format.color import (
    DIM,
    RESET,
    LEVEL_COLORS,
    get_dynamic_color,
    supports_color,
)


class ConsoleHandler(BaseHandler):
    def __init__(self, stream: TextIO) -> None:
        self.stream = stream
        self.use_color = supports_color(stream)
        self._lock = threading.Lock()

    def emit(self, record: LogRecord) -> None:
        ts = record.timestamp.strftime("%H:%M:%S")
        ctx = f"[{record.filename}:{record.lineno}]" if record.filename else ""
        plain = f"[{ts}][{record.main}][{record.sub}][{record.level_name}]{ctx} {record.message}"
        
        with self._lock:
            if not self.use_color:
                if record.exc_info:
                    plain += f"\n{record.exc_info}"
                self.stream.write(plain + "\n")
                self.stream.flush()
                return
            
            dim = DIM
            reset = RESET
            level_color = LEVEL_COLORS.get(record.level_name, "")
            main_color = get_dynamic_color(record.main)
            sub_color = get_dynamic_color(record.sub)
            ctx_color = "\033[37m"  # White for the code location box
            
            out = (
                f"{dim}[{ts}]{reset}"
                f"{main_color}[{record.main}]{reset}"
                f"{sub_color}[{record.sub}]{reset}"
                f"{level_color}[{record.level_name}]{reset}"
                f"{ctx_color}{ctx}{reset} {record.message}"
            )
            if record.exc_info:
                out += f"\n{dim}{record.exc_info}{reset}"
            self.stream.write(out + "\n")
            self.stream.flush()

    def close(self) -> None:
        pass

