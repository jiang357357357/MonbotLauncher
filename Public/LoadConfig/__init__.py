"""
MonConfig 配置加载器
支持 .monconfig 格式的多层配置继承
"""

from .loader import MonConfig
from .exceptions import MonConfigError, ConfigNotFoundError, ConfigParseError

__all__ = [
    'MonConfig',
    'MonConfigError',
    'ConfigNotFoundError',
    'ConfigParseError',
]

__version__ = '1.0.0'
