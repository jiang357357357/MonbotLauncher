"""
MonConfig 辅助函数
提供便捷的配置读取函数
"""

from typing import Any, Optional
from .loader import MonConfig

# 全局配置实例（单例模式）
_config_instance: Optional[MonConfig] = None


def get_config_instance() -> MonConfig:
    """
    获取全局配置实例（单例模式）
    
    Returns:
        MonConfig 实例
    """
    global _config_instance
    if _config_instance is None:
        _config_instance = MonConfig()
    return _config_instance


def get_config(
    section: str,
    key: str,
    default: Any = None,
    cast: Optional[type] = None
) -> Any:
    """
    便捷函数：获取配置值
    
    Args:
        section: 配置节名称
        key: 配置键名
        default: 默认值
        cast: 类型转换函数
    
    Returns:
        配置值
    
    示例：
        from Public.LoadConfig.helpers import get_config
        
        port = get_config('server', 'PORT', default=8000, cast=int)
        debug = get_config('django', 'DEBUG', default=False, cast=bool)
    """
    config = get_config_instance()
    return config.get(section, key, default, cast)


def get_section(section: str) -> dict:
    """
    便捷函数：获取整个配置节
    
    Args:
        section: 配置节名称
    
    Returns:
        配置节字典
    
    示例：
        from Public.LoadConfig.helpers import get_section
        
        server_config = get_section('server')
    """
    config = get_config_instance()
    return config.section(section)


def reload_config():
    """
    重新加载配置（清除缓存的配置实例）
    
    示例：
        from Public.LoadConfig.helpers import reload_config
        
        reload_config()  # 重新加载配置
    """
    global _config_instance
    _config_instance = None
