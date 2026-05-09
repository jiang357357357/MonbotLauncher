# MonConfig 配置加载器

基于 Mon 项目环境变量规范 v1.0.0 的配置加载器。

## 功能特性

- ✅ 自动查找 `.monconfig` 文件（向上最多 10 层）
- ✅ 多层配置继承（近层覆盖远层）
- ✅ 配置节分组管理
- ✅ 类型自动转换（bool, int, float, list）
- ✅ 工作区根目录识别
- ✅ 单例模式支持

## 快速开始

### 1. 基础使用

```python
from Public.LoadConfig import MonConfig

# 创建配置实例
config = MonConfig()

# 读取单个配置
port = config.get("server", "PORT", default=8000, cast=int)
debug = config.get("django", "DEBUG", default=False, cast=bool)
hosts = config.get("django", "ALLOWED_HOSTS", cast=list)

# 读取整个配置节
server_config = config.section("server")
# {"HOST": "0.0.0.0", "PORT": "6020", ...}

# 获取工作区根目录
workspace = config.workspace_root()
print(f"工作区: {workspace}")

# 查看加载的配置文件
files = config.loaded_files()
for file in files:
    print(f"已加载: {file}")
```

### 2. 便捷函数（推荐）

```python
from Public.LoadConfig.helpers import get_config, get_section

# 读取单个配置（自动使用单例）
port = get_config('server', 'PORT', default=8000, cast=int)
debug = get_config('django', 'DEBUG', default=False, cast=bool)

# 读取整个配置节
server_config = get_section('server')
```

### 3. Django 集成示例

```python
# settings.py
from Public.LoadConfig.helpers import get_config

# 服务器配置
SERVER_HOST = get_config('server', 'HOST', default='127.0.0.1')
SERVER_PORT = get_config('server', 'PORT', default=8000, cast=int)

# Django 配置
DEBUG = get_config('django', 'DEBUG', default=True, cast=bool)
SECRET_KEY = get_config('django', 'SECRET_KEY', default='unsafe-secret-key')
ALLOWED_HOSTS = get_config('django', 'ALLOWED_HOSTS', default='*', cast=list)

# 数据库配置
DB_NAME = get_config('django', 'DB_NAME', default='db.sqlite3')
DB_ENGINE = get_config('django', 'DB_ENGINE', default='django.db.backends.sqlite3')
```

### 4. NoneBot2 集成示例

```python
# bot.py
from Public.LoadConfig.helpers import get_config

# NoneBot2 配置
DRIVER = get_config('nonebot', 'DRIVER', default='~aiohttp')
HOST = get_config('nonebot', 'HOST', default='127.0.0.1')
PORT = get_config('nonebot', 'PORT', default=8080, cast=int)

# OneBot 配置
ONEBOT_WS_URLS = get_config('onebot', 'WS_URLS', cast=list)
ONEBOT_ACCESS_TOKEN = get_config('onebot', 'ACCESS_TOKEN', default='')

# MonCore 配置
MONCORE_IP = get_config('moncore', 'IP', default='')
MONCORE_WS_PORT = get_config('moncore', 'WS_PORT', default=8000, cast=int)
```

## 类型转换

### 布尔值

支持的格式：
- 真值: `true`, `yes`, `1`, `on`
- 假值: `false`, `no`, `0`, `off`

```python
debug = config.get("django", "DEBUG", cast=bool)
```

### 整数和浮点数

```python
port = config.get("server", "PORT", cast=int)
timeout = config.get("network", "TIMEOUT", cast=float)
```

### 列表

逗号分隔的字符串会自动转换为列表：

```ini
[django]
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
```

```python
hosts = config.get("django", "ALLOWED_HOSTS", cast=list)
# ['localhost', '127.0.0.1', '0.0.0.0']
```

## 配置继承

### 查找规则

从当前目录向上查找最多 10 层 `.monconfig` 文件：

```
当前目录/.monconfig          ← 优先级最高（覆盖下层）
  ↓ 合并
父目录/.monconfig            ← 优先级中等
  ↓ 合并  
祖父目录/.monconfig          ← 优先级最低（提供默认值）
```

### 合并规则

- **同名变量**：近层覆盖远层
- **不同配置节**：自动合并
- **未定义变量**：继承上层

### 示例

```
# 全局配置 (项目根/.monconfig)
[server]
HOST=127.0.0.1
PORT=8000
DEBUG=false

# 模块配置 (MonBot/.monconfig)  
[server]
HOST=0.0.0.0        # 覆盖全局的 127.0.0.1
PORT=6020           # 覆盖全局的 8000
# DEBUG 继承全局的 false

# 最终合并结果：
[server]
HOST=0.0.0.0        # 来自模块配置
PORT=6020           # 来自模块配置  
DEBUG=false         # 来自全局配置
```

## API 参考

### MonConfig 类

#### `__init__(start_path=None)`
创建配置实例

#### `get(section, key, default=None, cast=None)`
获取配置值

#### `section(section)`
获取整个配置节

#### `sections()`
获取所有配置节名称

#### `has_section(section)`
检查配置节是否存在

#### `has_option(section, key)`
检查配置项是否存在

#### `workspace_root()`
获取工作区根目录

#### `loaded_files()`
获取已加载的配置文件列表

#### `to_dict()`
将所有配置转换为字典

### 辅助函数

#### `get_config(section, key, default=None, cast=None)`
便捷函数：获取配置值（使用单例）

#### `get_section(section)`
便捷函数：获取整个配置节（使用单例）

#### `reload_config()`
重新加载配置（清除缓存）

## 异常处理

```python
from Public.LoadConfig import MonConfig, ConfigNotFoundError, ConfigParseError

try:
    config = MonConfig()
    port = config.get("server", "PORT", cast=int)
except ConfigNotFoundError as e:
    print(f"配置文件未找到: {e}")
except ConfigParseError as e:
    print(f"配置解析失败: {e}")
```

## 最佳实践

### 1. 使用单例模式

```python
# 推荐：使用辅助函数（自动单例）
from Public.LoadConfig.helpers import get_config

port = get_config('server', 'PORT', cast=int)
```

### 2. 提供默认值

```python
# 总是提供合理的默认值
debug = get_config('django', 'DEBUG', default=False, cast=bool)
```

### 3. 类型转换

```python
# 明确指定类型转换
port = get_config('server', 'PORT', default=8000, cast=int)
```

### 4. 配置验证

```python
# 启动时验证关键配置
config = MonConfig()

if not config.has_option('server', 'PORT'):
    raise ValueError("缺少必需的配置项: server.PORT")

port = config.get('server', 'PORT', cast=int)
if not (1 <= port <= 65535):
    raise ValueError(f"无效的端口号: {port}")
```

## 注意事项

1. 配置文件必须使用 UTF-8 编码
2. 配置节名称和键名区分大小写
3. 空值会返回默认值
4. 布尔值转换严格遵循规范格式
5. 列表使用逗号分隔，自动去除空白

## 版本

- **当前版本**: 1.0.0
- **规范版本**: Mon 项目环境变量规范 v1.0.0
