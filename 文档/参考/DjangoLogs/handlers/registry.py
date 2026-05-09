import sys
import threading
from typing import TextIO, Optional, Dict, Tuple, List
from pathlib import Path

from ..config import get_config
from .base import BaseHandler
from .console import ConsoleHandler
from .file import FileHandler


_console_handler: Optional[ConsoleHandler] = None
_colored_file_handlers: Dict[Tuple[str, str], FileHandler] = {}
_plain_file_handlers: Dict[Tuple[str, str], FileHandler] = {}
_lock = threading.Lock()


def get_handlers(main: str, sub: str, stream: Optional[TextIO]) -> List[BaseHandler]:
    handlers: List[BaseHandler] = []
    config = get_config()
    global _console_handler
    
    if stream is not None:
        handlers.append(ConsoleHandler(stream))
        return handlers

    with _lock:
        if config.console_enabled:
            if _console_handler is None:
                _console_handler = ConsoleHandler(sys.stdout)
            handlers.append(_console_handler)
        
        if config.file_enabled:
            # 根据main确定日志目录
            if main == "MonCore":
                log_dir = config.moncore_log_dir
                base_filename = "MonCore"
            elif main == "Django":
                log_dir = config.django_log_dir
                base_filename = "django"
            elif main == "Table" or main == "Render":
                log_dir = config.render_log_dir
                base_filename = "render"
            else:
                # 其他模块默认放在MonCore目录
                log_dir = config.moncore_log_dir
                base_filename = main
            
            if log_dir is not None:
                log_dir.mkdir(parents=True, exist_ok=True)
                key = (main,)
                
                # 创建彩色文件处理器
                colored_handler = _colored_file_handlers.get(key)
                if colored_handler is None:
                    colored_file = log_dir / f"{base_filename}.log"
                    colored_handler = FileHandler(colored_file, colored=True)
                    _colored_file_handlers[key] = colored_handler
                handlers.append(colored_handler)
                
                # 创建纯文本文件处理器
                if config.dual_file_enabled:
                    plain_handler = _plain_file_handlers.get(key)
                    if plain_handler is None:
                        plain_file = log_dir / f"{base_filename}_plain.log"
                        plain_handler = FileHandler(plain_file, colored=False)
                        _plain_file_handlers[key] = plain_handler
                    handlers.append(plain_handler)
                
    return handlers


def shutdown() -> None:
    global _console_handler
    with _lock:
        if _console_handler is not None:
            _console_handler.close()
            _console_handler = None
        for handler in list(_colored_file_handlers.values()):
            handler.close()
        _colored_file_handlers.clear()
        for handler in list(_plain_file_handlers.values()):
            handler.close()
        _plain_file_handlers.clear()

