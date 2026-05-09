"""
MonConfig 异常类定义
"""


class MonConfigError(Exception):
    """MonConfig 基础异常类"""
    pass


class ConfigNotFoundError(MonConfigError):
    """配置文件未找到异常"""
    pass


class ConfigParseError(MonConfigError):
    """配置文件解析异常"""
    pass
