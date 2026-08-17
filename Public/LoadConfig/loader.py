"""
MonConfig 模块配置加载器
只加载最近的模块 .monconfig，并识别 Mon 双锚点工作区
"""

from pathlib import Path
from typing import Optional, Dict, Any, List, Union
from configparser import ConfigParser

from .exceptions import ConfigNotFoundError, ConfigParseError


class MonConfig:
    """
    MonConfig 配置加载器
    
    功能：
    - 从当前目录向上查找最近的 .monconfig 文件
    - 不进行父目录配置继承
    - 支持配置节分组
    - 支持类型转换（bool, int, float, list）
    
    示例：
        config = MonConfig()
        
        # 读取单个变量
        port = config.get("server", "PORT", cast=int)
        debug = config.get("django", "DEBUG", cast=bool)
        
        # 读取整个配置节
        server_config = config.section("server")
        
        # 获取工作区根目录
        workspace = config.workspace_root()
    """
    
    CONFIG_FILENAME = ".monconfig"
    WORKSPACE_FILENAME = ".monworkspace"
    
    def __init__(self, start_path: Optional[Union[str, Path]] = None):
        """
        初始化配置加载器
        
        Args:
            start_path: 开始查找的路径（默认为当前工作目录）
        """
        self.start_path = Path(start_path) if start_path else Path.cwd()
        self._config = ConfigParser(interpolation=None)
        self._loaded_files: List[Path] = []
        self._workspace_root: Optional[Path] = None
        self._mon_root: Optional[Path] = None
        
        # 加载配置
        self._load_configs()
    
    def _find_config_files(self) -> List[Path]:
        """
        从当前目录向上查找 .monconfig 文件
        
        Returns:
            找到的配置文件路径列表（从远到近排序）
        """
        config_files = []
        current_path = self.start_path.resolve()
        if current_path.is_file():
            current_path = current_path.parent

        while True:
            config_file = current_path / self.CONFIG_FILENAME
            if self._mon_root is None and config_file.is_file() and (current_path / self.WORKSPACE_FILENAME).is_file():
                self._mon_root = current_path
            if not config_files and config_file.is_file():
                config_files.append(config_file)
                self._workspace_root = current_path

            parent = current_path.parent
            if parent == current_path:
                break
            current_path = parent

        if self._mon_root is None:
            self._mon_root = self._workspace_root
        return config_files
    
    def _load_configs(self):
        """加载所有找到的配置文件"""
        config_files = self._find_config_files()
        
        if not config_files:
            raise ConfigNotFoundError(
                f"未找到 {self.CONFIG_FILENAME} 配置文件 "
                f"(从 {self.start_path} 向上查找)"
            )
        
        for config_file in config_files:
            try:
                normalized_lines = []
                for line_number, raw_line in enumerate(config_file.read_text(encoding="utf-8").splitlines(), start=1):
                    line = self._strip_inline_comment(raw_line).strip()
                    if not line:
                        continue
                    if line.startswith("["):
                        if not line.endswith("]") or not line[1:-1].strip():
                            raise ValueError(f"{config_file}:{line_number}: 无效的配置节")
                        normalized_lines.append(f"[{line[1:-1].strip().lower()}]")
                    elif "=" in line and line.split("=", 1)[0].strip():
                        normalized_lines.append(line)
                    else:
                        raise ValueError(f"{config_file}:{line_number}: 配置项必须使用 KEY=VALUE")
                self._config.read_string("\n".join(normalized_lines), source=str(config_file))
                self._loaded_files.append(config_file)
            except Exception as e:
                raise ConfigParseError(
                    f"解析配置文件失败: {config_file}\n错误: {e}"
                )
    
    def get(
        self,
        section: str,
        key: str,
        default: Any = None,
        cast: Optional[type] = None
    ) -> Any:
        """
        获取配置值
        
        Args:
            section: 配置节名称
            key: 配置键名
            default: 默认值（如果配置不存在）
            cast: 类型转换函数（bool, int, float, str, list）
        
        Returns:
            配置值
        
        示例：
            port = config.get("server", "PORT", default=8000, cast=int)
            debug = config.get("django", "DEBUG", default=False, cast=bool)
            hosts = config.get("django", "ALLOWED_HOSTS", cast=list)
        """
        try:
            value = self._config.get(section, key)
        except Exception:
            return default
        
        # 清理值：去除行尾注释和空白
        value = self._clean_value(value)
        
        # 如果值为空字符串，返回默认值
        if value == "":
            return default
        
        # 类型转换
        if cast is not None:
            return self._cast_value(value, cast)
        
        return value
    
    def _clean_value(self, value: str) -> str:
        """
        清理配置值：去除行尾注释和多余空白
        
        Args:
            value: 原始值
        
        Returns:
            清理后的值
        """
        return value.strip()

    @staticmethod
    def _strip_inline_comment(line: str) -> str:
        in_single_quote = False
        in_double_quote = False
        for index, character in enumerate(line):
            if character == "'" and not in_double_quote:
                in_single_quote = not in_single_quote
            elif character == '"' and not in_single_quote:
                in_double_quote = not in_double_quote
            elif character in "#;" and not in_single_quote and not in_double_quote:
                if index == 0 or line[index - 1].isspace():
                    return line[:index]
        return line
    
    def _cast_value(self, value: str, cast_type: type) -> Any:
        """
        类型转换
        
        Args:
            value: 原始字符串值
            cast_type: 目标类型
        
        Returns:
            转换后的值
        """
        # 布尔值转换
        if cast_type == bool:
            return self._parse_bool(value)
        
        # 列表转换（逗号分隔）
        if cast_type == list:
            return [item.strip() for item in value.split(',') if item.strip()]
        
        # 其他类型直接转换
        try:
            return cast_type(value)
        except (ValueError, TypeError) as e:
            raise ConfigParseError(
                f"类型转换失败: 无法将 '{value}' 转换为 {cast_type.__name__}\n错误: {e}"
            )
    
    def _parse_bool(self, value: str) -> bool:
        """
        解析布尔值
        
        支持的格式：
        - 真值: true, yes, 1, on
        - 假值: false, no, 0, off
        
        Args:
            value: 字符串值
        
        Returns:
            布尔值
        """
        value_lower = value.strip().lower()
        
        if value_lower in ('true', 'yes', '1', 'on'):
            return True
        elif value_lower in ('false', 'no', '0', 'off'):
            return False
        else:
            raise ConfigParseError(
                f"无效的布尔值: '{value}' "
                f"(支持: true/false, yes/no, 1/0, on/off)"
            )
    
    def section(self, section: str) -> Dict[str, str]:
        """
        获取整个配置节的所有键值对
        
        Args:
            section: 配置节名称
        
        Returns:
            配置节的字典
        
        示例：
            server_config = config.section("server")
            # {"HOST": "0.0.0.0", "PORT": "6020", ...}
        """
        if not self._config.has_section(section):
            return {}
        
        return dict(self._config.items(section))
    
    def sections(self) -> List[str]:
        """
        获取所有配置节名称
        
        Returns:
            配置节名称列表
        """
        return self._config.sections()
    
    def has_section(self, section: str) -> bool:
        """
        检查配置节是否存在
        
        Args:
            section: 配置节名称
        
        Returns:
            是否存在
        """
        return self._config.has_section(section)
    
    def has_option(self, section: str, key: str) -> bool:
        """
        检查配置项是否存在
        
        Args:
            section: 配置节名称
            key: 配置键名
        
        Returns:
            是否存在
        """
        return self._config.has_option(section, key)
    
    def workspace_root(self) -> Optional[Path]:
        """
        获取工作区根目录（第一个找到的 .monconfig 所在目录）
        
        Returns:
            工作区根目录路径
        """
        return self._workspace_root

    def module_root(self) -> Optional[Path]:
        return self._workspace_root

    def mon_root(self) -> Optional[Path]:
        return self._mon_root
    
    def loaded_files(self) -> List[Path]:
        """
        获取已加载的配置文件列表
        
        Returns:
            配置文件路径列表（从远到近排序）
        """
        return self._loaded_files.copy()
    
    def to_dict(self) -> Dict[str, Dict[str, str]]:
        """
        将所有配置转换为字典
        
        Returns:
            配置字典 {section: {key: value}}
        """
        result = {}
        for section in self.sections():
            result[section] = self.section(section)
        return result
    
    def __repr__(self) -> str:
        """字符串表示"""
        return (
            f"MonConfig("
            f"workspace={self._workspace_root}, "
            f"loaded_files={len(self._loaded_files)}, "
            f"sections={len(self.sections())}"
            f")"
        )
