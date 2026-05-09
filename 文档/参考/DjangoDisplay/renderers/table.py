from rich.table import Table
from rich import box
from typing import List, Optional, Dict, Any
from pathlib import Path
from Application.Tools.DjangoDisplay.core.printer import print_direct


def render_table(
    headers: List[str],
    rows: List[List[Any]],
    title: Optional[str] = None,
    box_style: Any = box.SQUARE,
    styles: Optional[Dict[str, str]] = None,
    width: Optional[int] = None,
    max_cell_length: Optional[int] = None,
    output_dir: Optional[Path] = None,
) -> None:
    """渲染并直接输出表格到终端
    
    Args:
        headers: 表格列标题
        rows: 表格行数据
        title: 表格标题
        box_style: 表格边框样式
        styles: 表格样式字典
        width: 渲染宽度
        max_cell_length: 单元格最大长度
        output_dir: SVG 输出目录（可选）
    """
    table = _prepare_table(headers, rows, title, box_style, styles, max_cell_length)
    print_direct(table, title=title, width=width, panel_type="TABLE", output_dir=output_dir)


def _prepare_table(
    headers: List[str],
    rows: List[List[Any]],
    title: Optional[str] = None,
    box_style: Any = box.SQUARE,
    styles: Optional[Dict[str, str]] = None,
    max_cell_length: Optional[int] = None,
) -> Table:
    styles = styles or {}
    table = Table(
        title=title,
        box=box_style,
        show_header=True,
        header_style=styles.get("header_style", "table.header"),
        title_style=styles.get("title_style", "table.title"),
        expand=False, 
        border_style=styles.get("border_style", "dim"),
        show_lines=True,
    )

    if headers == ["类型", "角色", "权重", "内容"]:
        table.add_column(headers[0], style=styles.get(headers[0], ""), width=10, no_wrap=True)
        table.add_column(headers[1], style=styles.get(headers[1], ""), width=10, no_wrap=True)
        table.add_column(headers[2], style=styles.get(headers[2], ""), width=10, no_wrap=True)
        table.add_column(headers[3], ratio=1, overflow="fold") 
    else:
        # 对于其他表格（如响应表格），也使用fold模式避免截断
        for header in headers:
            table.add_column(header, style=styles.get(header, ""), overflow="fold")

    for row in rows:
        str_row = []
        for item in row:
            s = str(item)
            if max_cell_length and len(s) > max_cell_length:
                s = s[:max_cell_length] + f"\n... [已截断，总长度: {len(s)}]"
            str_row.append(s)
        table.add_row(*str_row)
    
    return table
