"""
日志清理器核心实现
"""

import os
import time
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Tuple, Optional
from dataclasses import dataclass

from .config import CleanerConfig, CleanStrategy


@dataclass
class CleanResult:
    """清理结果"""
    total_files: int = 0        # 扫描的文件总数
    deleted_files: int = 0      # 删除的文件数
    freed_space_mb: float = 0   # 释放的空间（MB）
    errors: List[str] = None    # 错误列表
    
    def __post_init__(self):
        if self.errors is None:
            self.errors = []


class LogCleaner:
    """日志清理器"""
    
    def __init__(self, config: CleanerConfig):
        self.config = config
        self.result = CleanResult()
    
    def clean(self, strategy: CleanStrategy = CleanStrategy.BY_AGE) -> CleanResult:
        """
        执行清理
        
        Args:
            strategy: 清理策略
            
        Returns:
            清理结果
        """
        self.result = CleanResult()
        
        if not self.config.log_root.exists():
            self.result.errors.append(f"日志目录不存在: {self.config.log_root}")
            return self.result
        
        # 根据策略执行清理
        if strategy == CleanStrategy.BY_AGE:
            self._clean_by_age()
        elif strategy == CleanStrategy.BY_SIZE:
            self._clean_by_size()
        elif strategy == CleanStrategy.BY_COUNT:
            self._clean_by_count()
        elif strategy == CleanStrategy.ALL:
            self._clean_all()
        
        return self.result
    
    def _clean_by_age(self):
        """按时间清理"""
        if self.config.max_age_days is None:
            return
        
        cutoff_time = time.time() - (self.config.max_age_days * 24 * 3600)
        
        for log_file in self._scan_log_files():
            try:
                # 检查文件修改时间
                mtime = log_file.stat().st_mtime
                
                # 如果是最新文件且配置了保留，则跳过
                if self.config.keep_latest and self._is_latest_log(log_file):
                    continue
                
                if mtime < cutoff_time:
                    self._delete_file(log_file)
            except Exception as e:
                self.result.errors.append(f"处理文件 {log_file} 失败: {e}")
    
    def _clean_by_size(self):
        """按大小清理"""
        # 1. 清理超过单文件大小限制的文件
        if self.config.max_file_size_mb:
            max_size = self.config.max_file_size_mb * 1024 * 1024
            for log_file in self._scan_log_files():
                try:
                    if log_file.stat().st_size > max_size:
                        if not (self.config.keep_latest and self._is_latest_log(log_file)):
                            self._delete_file(log_file)
                except Exception as e:
                    self.result.errors.append(f"处理文件 {log_file} 失败: {e}")
        
        # 2. 如果总大小超限，删除最旧的文件
        if self.config.max_total_size_mb:
            self._clean_by_total_size()
    
    def _clean_by_total_size(self):
        """按总大小清理"""
        max_total = self.config.max_total_size_mb * 1024 * 1024
        
        # 获取所有日志文件并按修改时间排序（旧的在前）
        files_with_time = []
        for log_file in self._scan_log_files():
            try:
                mtime = log_file.stat().st_mtime
                size = log_file.stat().st_size
                files_with_time.append((log_file, mtime, size))
            except Exception as e:
                self.result.errors.append(f"读取文件信息失败 {log_file}: {e}")
        
        files_with_time.sort(key=lambda x: x[1])  # 按时间排序
        
        # 计算当前总大小
        current_total = sum(size for _, _, size in files_with_time)
        
        # 从最旧的文件开始删除，直到总大小低于限制
        for log_file, _, size in files_with_time:
            if current_total <= max_total:
                break
            
            # 保留最新的文件
            if self.config.keep_latest and self._is_latest_log(log_file):
                continue
            
            if self._delete_file(log_file):
                current_total -= size
    
    def _clean_by_count(self):
        """按备份数量清理"""
        if self.config.max_backup_count is None:
            return
        
        # 按模块分组
        module_files = {}
        for log_file in self._scan_log_files():
            # 识别基础日志名（去除 .1, .2 等后缀）
            base_name = self._get_base_log_name(log_file)
            if base_name not in module_files:
                module_files[base_name] = []
            module_files[base_name].append(log_file)
        
        # 对每个模块的备份文件进行清理
        for base_name, files in module_files.items():
            # 按修改时间排序（新的在前）
            files_with_time = []
            for f in files:
                try:
                    mtime = f.stat().st_mtime
                    files_with_time.append((f, mtime))
                except Exception as e:
                    self.result.errors.append(f"读取文件信息失败 {f}: {e}")
            
            files_with_time.sort(key=lambda x: x[1], reverse=True)
            
            # 保留最新的N个，删除其余的
            for i, (log_file, _) in enumerate(files_with_time):
                if i >= self.config.max_backup_count:
                    self._delete_file(log_file)
    
    def _clean_all(self):
        """清理所有日志文件"""
        for log_file in self._scan_log_files():
            # 如果配置了保留最新，则跳过最新的文件
            if self.config.keep_latest and self._is_latest_log(log_file):
                continue
            self._delete_file(log_file)
    
    def _scan_log_files(self) -> List[Path]:
        """扫描所有符合条件的日志文件"""
        log_files = []
        
        for root, dirs, files in os.walk(self.config.log_root):
            root_path = Path(root)
            
            for file in files:
                file_path = root_path / file
                
                # 检查文件类型
                if not self._should_clean_file(file_path):
                    continue
                
                # 检查模块过滤（基于文件所在的相对路径）
                relative_path = file_path.relative_to(self.config.log_root)
                module_name = relative_path.parts[0] if len(relative_path.parts) > 1 else None
                
                if self.config.include_modules and module_name not in self.config.include_modules:
                    continue
                if self.config.exclude_modules and module_name in self.config.exclude_modules:
                    continue
                
                log_files.append(file_path)
                self.result.total_files += 1
        
        return log_files
    
    def _should_clean_file(self, file_path: Path) -> bool:
        """判断文件是否应该被清理"""
        name = file_path.name
        
        # 检查是否是日志文件
        if not (name.endswith('.log') or '.log.' in name):
            return False
        
        # 检查彩色日志
        if not self.config.clean_colored and not '_plain' in name:
            return False
        
        # 检查纯文本日志
        if not self.config.clean_plain and '_plain' in name:
            return False
        
        # 检查备份文件
        if not self.config.clean_backups and '.log.' in name:
            return False
        
        return True
    
    def _is_latest_log(self, file_path: Path) -> bool:
        """判断是否是最新的日志文件（不是备份文件）"""
        name = file_path.name
        # 如果文件名包含 .log.1, .log.2 等，说明是备份文件
        return name.endswith('.log')
    
    def _get_base_log_name(self, file_path: Path) -> str:
        """获取日志的基础名称（去除备份后缀）"""
        name = file_path.name
        # 移除 .1, .2 等备份后缀
        if '.log.' in name:
            return name.split('.log.')[0] + '.log'
        return name
    
    def _delete_file(self, file_path: Path) -> bool:
        """删除文件"""
        try:
            size = file_path.stat().st_size
            
            if self.config.dry_run:
                print(f"[演习模式] 将删除: {file_path} ({size / 1024 / 1024:.2f} MB)")
                self.result.deleted_files += 1
                self.result.freed_space_mb += size / 1024 / 1024
                return True
            
            # 确认删除
            if self.config.confirm_before_delete:
                response = input(f"确认删除 {file_path}? (y/n): ")
                if response.lower() != 'y':
                    return False
            
            file_path.unlink()
            self.result.deleted_files += 1
            self.result.freed_space_mb += size / 1024 / 1024
            return True
            
        except Exception as e:
            self.result.errors.append(f"删除文件失败 {file_path}: {e}")
            return False
    
    def get_statistics(self) -> dict:
        """获取日志目录统计信息"""
        stats = {
            'total_files': 0,
            'total_size_mb': 0,
            'by_module': {},
            'by_type': {
                'colored': 0,
                'plain': 0,
                'backup': 0
            }
        }
        
        for log_file in self._scan_log_files():
            try:
                size = log_file.stat().st_size
                stats['total_files'] += 1
                stats['total_size_mb'] += size / 1024 / 1024
                
                # 按模块统计
                module = log_file.parent.name
                if module not in stats['by_module']:
                    stats['by_module'][module] = {'count': 0, 'size_mb': 0}
                stats['by_module'][module]['count'] += 1
                stats['by_module'][module]['size_mb'] += size / 1024 / 1024
                
                # 按类型统计
                name = log_file.name
                if '_plain' in name:
                    stats['by_type']['plain'] += 1
                elif '.log.' in name:
                    stats['by_type']['backup'] += 1
                else:
                    stats['by_type']['colored'] += 1
                    
            except Exception as e:
                pass
        
        return stats
