# LogCleaner - 日志清理模块

MonCore 的智能日志清理工具，支持多种清理策略和灵活的配置选项。

## 功能特性

- 🕐 按时间清理：保留最近N天的日志
- 📦 按大小清理：限制总大小或单文件大小
- 🔢 按数量清理：控制备份文件数量
- 🎯 模块过滤：选择性清理特定模块
- 🎨 类型过滤：分别控制彩色/纯文本/备份文件
- 🛡️ 安全保护：演习模式、保留最新、确认删除
- 📊 统计信息：查看日志目录使用情况

## 快速开始

### 命令行使用

```bash
# 查看统计信息
python Application/Tools/LogCleaner/cli.py --stats

# 清理7天前的日志（演习模式）
python Application/Tools/LogCleaner/cli.py --dry-run

# 清理7天前的日志（实际执行）
python Application/Tools/LogCleaner/cli.py

# 清理30天前的日志
python Application/Tools/LogCleaner/cli.py --days 30

# 按大小清理（总大小不超过100MB）
python Application/Tools/LogCleaner/cli.py --strategy size --max-size 100

# 只清理MonCore模块的日志
python Application/Tools/LogCleaner/cli.py --modules MonCore

# 清理所有日志（保留最新）
python Application/Tools/LogCleaner/cli.py --strategy all
```

### Python API 使用

```python
from pathlib import Path
from Application.Tools.LogCleaner import LogCleaner, CleanerConfig, CleanStrategy

# 创建配置
config = CleanerConfig(
    log_root=Path("Data/Logs"),
    max_age_days=7,
    dry_run=True,  # 演习模式
    keep_latest=True
)

# 创建清理器
cleaner = LogCleaner(config)

# 查看统计信息
stats = cleaner.get_statistics()
print(f"总文件数: {stats['total_files']}")
print(f"总大小: {stats['total_size_mb']:.2f} MB")

# 执行清理
result = cleaner.clean(CleanStrategy.BY_AGE)
print(f"删除了 {result.deleted_files} 个文件")
print(f"释放了 {result.freed_space_mb:.2f} MB 空间")
```

## 清理策略

### 1. 按时间清理 (BY_AGE)

删除超过指定天数的日志文件。

```bash
python cli.py --strategy age --days 7
```

### 2. 按大小清理 (BY_SIZE)

- 删除超过单文件大小限制的文件
- 如果总大小超限，删除最旧的文件直到低于限制

```bash
# 限制总大小
python cli.py --strategy size --max-size 100

# 限制单文件大小
python cli.py --strategy size --max-file-size 10

# 同时限制
python cli.py --strategy size --max-size 100 --max-file-size 10
```

### 3. 按数量清理 (BY_COUNT)

每个日志文件最多保留N个备份（.1, .2等）。

```bash
python cli.py --strategy count --max-backups 5
```

### 4. 清理所有 (ALL)

清理所有日志文件（如果启用了keep_latest，会保留最新的）。

```bash
python cli.py --strategy all
```

## 配置选项

### CleanerConfig 参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| log_root | Path | 必填 | 日志根目录 |
| dry_run | bool | False | 演习模式，不实际删除 |
| max_age_days | int | 7 | 保留最近N天 |
| max_total_size_mb | int | 100 | 总大小限制（MB） |
| max_file_size_mb | int | 10 | 单文件大小限制（MB） |
| max_backup_count | int | 5 | 最大备份数量 |
| include_modules | list | None | 只清理指定模块 |
| exclude_modules | list | None | 排除指定模块 |
| clean_colored | bool | True | 清理彩色日志 |
| clean_plain | bool | True | 清理纯文本日志 |
| clean_backups | bool | True | 清理备份文件 |
| keep_latest | bool | True | 保留最新文件 |
| confirm_before_delete | bool | False | 删除前确认 |

## 命令行参数

```
使用方法: cli.py [选项]

清理策略:
  --strategy, -s {age,size,count,all}
                        清理策略 (默认: age)

时间相关:
  --days, -d DAYS       保留最近N天的日志 (默认: 7)

大小相关:
  --max-size MB         总大小限制 (MB)
  --max-file-size MB    单文件大小限制 (MB)

数量相关:
  --max-backups N       每个日志最多保留N个备份 (默认: 5)

模块过滤:
  --modules M1 M2 ...   只清理指定模块
  --exclude M1 M2 ...   排除指定模块

文件类型:
  --no-colored          不清理彩色日志
  --no-plain            不清理纯文本日志
  --no-backups          不清理备份文件

安全选项:
  --dry-run             演习模式，不实际删除
  --confirm             删除前需要确认
  --no-keep-latest      不保留最新的日志文件

其他:
  --stats               只显示统计信息
```

## 使用示例

### 示例1：日常维护

每周清理一次，保留最近7天的日志：

```bash
python cli.py --days 7
```

### 示例2：空间紧张

限制日志总大小不超过50MB：

```bash
python cli.py --strategy size --max-size 50
```

### 示例3：只清理特定模块

只清理Render模块的日志：

```bash
python cli.py --modules Render
```

### 示例4：安全清理

先演习，确认无误后再执行：

```bash
# 1. 演习模式查看会删除什么
python cli.py --dry-run

# 2. 确认无误后实际执行
python cli.py
```

### 示例5：清理备份文件

只清理备份文件（.1, .2等），保留主日志：

```bash
python cli.py --strategy count --max-backups 3 --no-colored --no-plain
```

## 集成到项目

### 在 start_server.py 中使用

```python
from Application.Tools.LogCleaner import LogCleaner, CleanerConfig, CleanStrategy
from Config.core.logging import LOGS_ROOT

def clean_logs_smart(self):
    """智能清理日志"""
    config = CleanerConfig(
        log_root=LOGS_ROOT,
        max_age_days=7,
        keep_latest=True,
        dry_run=False
    )
    
    cleaner = LogCleaner(config)
    result = cleaner.clean(CleanStrategy.BY_AGE)
    
    print(f"✅ 清理完成: 删除 {result.deleted_files} 个文件, "
          f"释放 {result.freed_space_mb:.2f} MB")
```

### 定时任务

可以配合系统的定时任务（如 Windows 任务计划程序）定期执行清理：

```bash
# 每天凌晨2点清理7天前的日志
python Application/Tools/LogCleaner/cli.py --days 7
```

## 注意事项

1. 首次使用建议先用 `--dry-run` 演习模式查看效果
2. `keep_latest=True` 会保护最新的日志文件不被删除
3. 清理过程中如果文件被占用（如正在写入），会跳过并记录错误
4. 建议定期清理，避免日志文件占用过多磁盘空间
5. 重要日志建议先备份再清理

## 故障排除

### 文件被占用无法删除

如果日志文件正在被使用（如Django服务正在运行），清理器会跳过这些文件并记录错误。建议在服务停止时执行清理。

### 权限不足

确保运行清理工具的用户有删除日志文件的权限。

### 误删文件

如果启用了 `keep_latest=True`，最新的日志文件会被保护。如果需要恢复，可以从备份文件（.1, .2等）中恢复。

## 开发者

星晚 ✨ - 为哥哥精心打造的日志清理工具
