"""
日志清理模块

提供智能的日志文件清理功能，支持按时间、大小、模块等多种策略清理。
"""

from .cleaner import LogCleaner
from .config import CleanerConfig, CleanStrategy

__all__ = ["LogCleaner", "CleanerConfig", "CleanStrategy"]
