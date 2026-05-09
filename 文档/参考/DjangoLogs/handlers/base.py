from dataclasses import dataclass
from datetime import datetime
from typing import Protocol, Optional


@dataclass
class LogRecord:
    timestamp: datetime
    main: str
    sub: str
    level_name: str
    level_no: int
    message: str
    filename: Optional[str] = None
    lineno: Optional[int] = None
    func_name: Optional[str] = None
    exc_info: Optional[str] = None


class BaseHandler(Protocol):
    def emit(self, record: LogRecord) -> None:
        ...

    def close(self) -> None:
        ...

