import threading
import os
import sys
import time
import re
from pathlib import Path
from typing import Optional

# Windows 平台下的文件锁支持
try:
    import msvcrt
    HAS_MSVCRT = True
except ImportError:
    HAS_MSVCRT = False

from .base import BaseHandler, LogRecord
from ..config import get_config


class FileHandler(BaseHandler):
    def __init__(self, path: Path, colored: bool = False) -> None:
        self.path = path
        self.colored = colored  # 是否保留ANSI颜色码
        self.stream = None
        self._lock = threading.Lock()
        self._open()

    def _strip_ansi(self, text: str) -> str:
        """移除ANSI转义码"""
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        return ansi_escape.sub('', text)

    def _open(self) -> None:
        """打开日志文件，确保目录存在"""
        if self.stream and not self.stream.closed:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.stream = self.path.open("a", encoding="utf-8")

    def _lock_file(self):
        """跨进程锁定文件 (Windows 特供)"""
        if HAS_MSVCRT and self.stream:
            try:
                # 锁定文件起始位置，防止其他进程同时进行翻滚或写入错乱
                # LK_NBLCK 表示非阻塞模式，如果锁不住就抛异常
                fd = self.stream.fileno()
                msvcrt.locking(fd, msvcrt.LK_LOCK, 1)
                return True
            except (IOError, OSError):
                return False
        return True

    def _unlock_file(self):
        """释放跨进程锁"""
        if HAS_MSVCRT and self.stream:
            try:
                fd = self.stream.fileno()
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            except (IOError, OSError):
                pass

    def _should_rotate(self, record_len: int) -> bool:
        config = get_config()
        if config.max_bytes <= 0:
            return False
        try:
            # 检查当前文件大小
            if not self.path.exists():
                return False
            return self.path.stat().st_size + record_len >= config.max_bytes
        except Exception:
            return False

    def _rotate(self) -> None:
        config = get_config()
        if config.backup_count <= 0:
            return

        # 1. 关闭当前流
        if self.stream:
            self.stream.close()
            self.stream = None

        try:
            # 2. 只有拿到命名的权利才能执行翻滚
            # 在 Windows 上，rename 是原子的，但如果文件被占用会失败
            
            # 翻滚旧文件
            for i in range(config.backup_count - 1, 0, -1):
                sfn = self.path.with_name(f"{self.path.name}.{i}")
                dfn = self.path.with_name(f"{self.path.name}.{i+1}")
                if sfn.exists():
                    if dfn.exists():
                        try:
                            dfn.unlink()
                        except OSError: pass
                    try:
                        sfn.rename(dfn)
                    except OSError: pass

            # 当前文件变 .1
            dfn = self.path.with_name(f"{self.path.name}.1")
            if self.path.exists():
                if dfn.exists():
                    try:
                        dfn.unlink()
                    except OSError: pass
                try:
                    self.path.rename(dfn)
                except OSError:
                    # 如果 rename 失败（通常是因为其他进程还开着句柄），
                    # 我们就暂时放弃翻滚，让下一个尝试写的进程去处理
                    pass
        finally:
            # 3. 重新打开（如果是翻滚成功了，这就是新文件；失败了，就继续追加）
            self._open()

    def emit(self, record: LogRecord) -> None:
        ts = record.timestamp.strftime("%Y-%m-%d %H:%M:%S")
        ctx = f" {record.filename}:{record.lineno} {record.func_name}()" if record.filename else ""
        
        # 如果需要彩色输出，添加ANSI颜色码
        if self.colored:
            from ..format.color import DIM, RESET, LEVEL_COLORS, get_dynamic_color
            
            dim = DIM
            reset = RESET
            level_color = LEVEL_COLORS.get(record.level_name, "")
            main_color = get_dynamic_color(record.main)
            sub_color = get_dynamic_color(record.sub)
            ctx_color = "\033[37m"  # White for the code location
            
            plain = (
                f"{dim}[{ts}]{reset}"
                f"{main_color}[{record.main}]{reset}"
                f"{sub_color}[{record.sub}]{reset}"
                f"{level_color}[{record.level_name}]{reset}"
                f"{ctx_color}{ctx}{reset} {record.message}"
            )
            if record.exc_info:
                plain += f"\n{dim}{record.exc_info}{reset}"
            plain += "\n"
        else:
            # 纯文本输出
            plain = f"[{ts}][{record.main}][{record.sub}][{record.level_name}]{ctx} {record.message}"
            if record.exc_info:
                plain += f"\n{record.exc_info}"
            plain += "\n"
        
        encoded_msg = plain.encode("utf-8")
        
        with self._lock:
            # 尝试获取进程锁，获取不到说明其他进程正在操作（比如正在翻滚）
            # 我们稍微等一下或者直接写，因为 "a" 模式在系统层是原子的
            try:
                self._open()
                
                # 检查是否需要翻滚
                if self._should_rotate(len(encoded_msg)):
                    # 在翻滚前尝试锁定，确保不会有多个进程同时翻滚
                    if self._lock_file():
                        try:
                            # 再次检查，防止在等待锁的过程中已经被别的进程翻滚过了
                            if self._should_rotate(len(encoded_msg)):
                                self._rotate()
                        finally:
                            self._unlock_file()
                
                # 写入日志
                self.stream.write(plain)
                self.stream.flush()
            except Exception as e:
                # 即使出错了也别崩，但现在根据哥哥的要求，要把错误打印出来
                import sys
                print(f"\n❌ [DjangoLogs] 无法写入日志文件: {self.path}", file=sys.stderr)
                print(f"❌ 错误原因: {str(e)}", file=sys.stderr)
                # 如果是权限问题或者文件被占用，打印更详细的提示
                if isinstance(e, PermissionError):
                    print(f"💡 提示: 请检查文件是否被其他程序（如 Excel 或记事本）占用，或者目录权限是否正确。", file=sys.stderr)

    def close(self) -> None:
        with self._lock:
            try:
                if self.stream and not self.stream.closed:
                    self.stream.close()
            except Exception:
                pass

