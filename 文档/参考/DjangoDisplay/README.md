# DjangoDisplay - 统一终端渲染系统

DjangoDisplay 是 MonCore 的统一终端渲染模块，基于 Rich 库提供彩色终端输出、SVG 矢量图生成和 PNG 光栅图生成能力。

所有输出使用统一的主题配置，确保视觉风格一致。

## 核心特性

- 🎨 **彩色终端输出** - 基于 Rich 的美观终端渲染
- 📊 **SVG 矢量图** - 精确保留 ANSI 颜色码，生成可缩放的矢量图
- 🖼️ **PNG 光栅图** - 完美支持中文字体的高质量图片输出
- 📝 **自动索引** - JSON 格式的渲染历史记录
- 🎯 **统一 API** - 简洁的对外接口

## 架构设计

```
DjangoDisplay/
├── __init__.py              # 统一 API 入口
├── core/                    # 核心引擎
│   ├── __init__.py
│   ├── canvas.py           # SVG 渲染引擎（ANSI → SVG）
│   └── printer.py          # 核心输出逻辑（终端 + SVG + PNG）
├── components/             # 高级组件（面板、进度条、树等）
├── renderers/              # 渲染器（表格、上下文等）
├── config/                 # 主题和样式配置
└── README.md
```

### 模块职责

| 模块 | 职责 |
|------|------|
| `core/canvas.py` | 解析 ANSI 颜色码，生成 SVG 字符串 |
| `core/printer.py` | 输出到终端，捕获 ANSI 文本，调用 canvas 生成 SVG，调用 png_renderer 生成 PNG |
| `renderers/` | 创建 Rich 对象（Table、Panel 等），调用 `print_direct()` 输出 |
| `components/` | 高级组件（进度条、树形结构等） |
| `config/` | 主题定义和样式配置 |

## 对外 API

### 基础渲染函数

```python
from Application.Tools.DjangoDisplay import (
    render_table,
    render_panel,
    render_progress,
    render_tree,
    run_live,
    print_direct,
    moncore_theme,
    get_style
)
```

#### `render_table(headers, rows, title=None, box_style=..., styles=None, width=120)`

渲染表格到终端，并自动生成 SVG/PNG 文件。

**参数：**
- `headers`: 列标题列表
- `rows`: 数据行列表
- `title`: 表格标题
- `box_style`: 边框风格（默认 `box.SQUARE`）
- `styles`: 样式字典（`header_style`, `title_style`, `border_style`）
- `width`: 渲染宽度

**示例：**
```python
from Application.Tools.DjangoDisplay import render_table

headers = ["任务", "状态", "进度"]
rows = [
    ["加载配置", "✓", "100%"],
    ["启动内核", "✓", "100%"],
    ["连接数据库", "⏳", "50%"],
]

render_table(headers, rows, title="MonCore 启动检查")
```

#### `render_panel(content, title=None, subtitle=None, border_style="panel.border", box_style=..., width=None)`

渲染面板到终端，并自动生成 SVG/PNG 文件。

**参数：**
- `content`: 面板内容（字符串或 Rich 对象）
- `title`: 标题
- `subtitle`: 副标题
- `border_style`: 边框样式
- `box_style`: 边框形状
- `width`: 固定宽度

**示例：**
```python
from Application.Tools.DjangoDisplay import render_panel

render_panel("内核已启动，所有系统正常", title="MonCore 状态")
```

#### `render_progress(tasks, width=120)`

渲染进度条快照到终端。

**参数：**
- `tasks`: `(描述, 总量)` 的可迭代对象
- `width`: 渲染宽度

**示例：**
```python
from Application.Tools.DjangoDisplay import render_progress

tasks = [
    ("加载配置", 5),
    ("连接数据库", 3),
    ("初始化内核", 10),
]

render_progress(tasks)
```

#### `render_tree(label, children, width=120)`

渲染树形结构到终端。

**参数：**
- `label`: 根节点标签
- `children`: 子节点列表 `[(标签, 子节点列表或 None), ...]`
- `width`: 渲染宽度

**示例：**
```python
from Application.Tools.DjangoDisplay import render_tree

children = [
    ("语义任务", [
        ("加载配置", None),
        ("解析输入", None),
    ]),
    ("内核", [
        ("调度", None),
        ("监控", None),
    ]),
]

render_tree("MonCore", children)
```

#### `run_live(render_fn, width=120, refresh_per_second=4.0)`

创建动态刷新的终端区域。

**参数：**
- `render_fn`: 接收 `Console` 实例的函数
- `width`: 渲染宽度
- `refresh_per_second`: 刷新频率

**示例：**
```python
from rich.console import Console
from Application.Tools.DjangoDisplay import run_live

def render(console: Console) -> None:
    console.print("MonCore 心跳 ❤️")

run_live(render, refresh_per_second=2.0)
```

#### `print_direct(renderable, title=None, width=None, save_to_file=True, panel_type=None, export_html=True)`

直接输出 Rich 对象到终端，并自动生成 SVG/PNG 文件。

**参数：**
- `renderable`: Rich 可渲染对象
- `title`: 标题
- `width`: 渲染宽度
- `save_to_file`: 是否保存到文件（默认 True）
- `panel_type`: 面板类型标识（用于索引）
- `export_html`: 是否导出 SVG/PNG（默认 True）

**示例：**
```python
from rich.table import Table
from Application.Tools.DjangoDisplay import print_direct

table = Table(title="示例表格")
table.add_column("列1")
table.add_column("列2")
table.add_row("值1", "值2")

print_direct(table, title="我的表格", panel_type="Table")
```

## 输出文件

所有渲染输出会自动保存到 `RENDER_LOGS_DIR`（由 `Config.core.logging` 定义）：

```
RENDER_LOGS_DIR/
├── panels.json              # 渲染历史索引
└── svg/
    ├── panel_*.svg         # SVG 矢量图
    └── panel_*.png         # PNG 光栅图
```

### 索引文件格式

`panels.json` 包含所有渲染的元数据：

```json
[
  {
    "type": "Table",
    "stage": "AGENT-STEP-1",
    "timestamp": "2026-03-11 10:59:42.123",
    "title": "员工信息表",
    "svg": "panel_20260311_105942_123.svg",
    "png": "panel_20260311_105942_123.png"
  }
]
```

## 主题与样式

主题定义位于 `config/themes.py`，提供统一的样式键：

- **状态**: `status.ok`, `status.warn`, `status.fail`, `status.dim`
- **标签**: `tag.monos`, `tag.kernel`, `tag.core`, `tag.test`
- **表格**: `table.header`, `table.title`
- **面板**: `panel.border`, `panel.title`
- **消息**: `info`, `warning`, `error`, `critical`

通过 `get_style(name: str)` 获取样式字符串：

```python
from Application.Tools.DjangoDisplay import get_style

header_style = get_style("table.header")
```

## 工作流程

```
用户代码
    ↓
render_table() / render_panel() / ...
    ↓
print_direct()
    ↓
┌─────────────────────────────────────┐
│ 1. 输出到终端（带颜色）              │
│ 2. 捕获 ANSI 文本                   │
│ 3. 调用 canvas.create_terminal_svg()│
│ 4. 调用 png_renderer.create_terminal_png()
│ 5. 保存 SVG/PNG 文件                │
│ 6. 更新 panels.json 索引            │
└─────────────────────────────────────┘
```

## 常见问题

### Q: 为什么 SVG 中的颜色和终端不一样？

A: 确保使用 `print_direct()` 或 `render_*()` 函数。这些函数会自动捕获 ANSI 颜色码并转换为 SVG 颜色。

### Q: PNG 生成失败怎么办？

A: 检查是否安装了 PIL/Pillow 和中文字体。字体路径在 `Config.core.logging` 中配置。

### Q: 如何自定义样式？

A: 编辑 `config/themes.py` 中的主题定义，或在调用 `render_*()` 时传递 `styles` 参数。

## 依赖

- `rich>=13.9.4` - 终端渲染
- `pillow>=11.3.0` - PNG 生成
- `reportlab>=4.2.0` - SVG 支持（可选）
- `svglib>=1.5.1` - SVG 支持（可选）

## 许可证

MIT
