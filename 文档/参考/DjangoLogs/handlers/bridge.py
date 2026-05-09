import logging

class DjangoLogBridgeHandler(logging.Handler):
    """
    桥接器：将 Django 标准 logging 系统的日志转发到我们自研的 DjangoLogs 模块中。
    这样可以统一日志格式、颜色输出，并利用自研模块的句柄管理机制。
    """
    def __init__(self):
        super().__init__()
        # 获取一个名为 'Django' 的自研 logger
        from ..logger import get_logger
        self.custom_logger = get_logger("Django")

    def emit(self, record):
        try:
            # 将标准的 LogRecord 转换为我们自研 logger 的调用
            msg = self.format(record)
            level = record.levelname.upper()
            
            if level == 'DEBUG':
                self.custom_logger.debug(msg)
            elif level == 'INFO':
                self.custom_logger.info(msg)
            elif level == 'WARNING':
                self.custom_logger.warning(msg)
            elif level == 'ERROR':
                self.custom_logger.error(msg)
            elif level == 'CRITICAL':
                self.custom_logger.critical(msg)
            else:
                self.custom_logger.info(msg)
        except Exception:
            self.handleError(record)
