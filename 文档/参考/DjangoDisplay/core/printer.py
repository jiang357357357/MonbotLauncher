"""
核心输出模块

负责将 Rich 可渲染对象输出到终端，并同时生成 SVG 文件
"""

from pathlib import Path
import sys
import shutil
from typing import Any, Optional
from datetime import datetime
from io import StringIO
import json
from rich.console import Console
from Application.Tools.DjangoDisplay.config import moncore_theme
from .canvas import create_terminal_svg

# 从项目配置中导入渲染日志目录
try:
    from Config.core.logging import RENDER_LOGS_DIR
    print(f"✅ [DjangoDisplay] RENDER_LOGS_DIR 导入成功: {RENDER_LOGS_DIR}", file=sys.stderr)
except ImportError as e:
    print(f"❌ [DjangoDisplay] 无法导入 RENDER_LOGS_DIR: {e}", file=sys.stderr)
    # 使用备用路径
    RENDER_LOGS_DIR = Path(__file__).resolve().parent.parent.parent.parent / 'Data' / 'Logs' / 'Render'
    print(f"⚠️ [DjangoDisplay] 使用备用路径: {RENDER_LOGS_DIR}", file=sys.stderr)

# 渲染日志文件路径
RENDER_INDEX_FILE = RENDER_LOGS_DIR / 'panels.json'
SVG_OUTPUT_DIR = RENDER_LOGS_DIR / 'svg'
try:
    SVG_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"✅ [DjangoDisplay] SVG 输出目录已创建: {SVG_OUTPUT_DIR}", file=sys.stderr)
except Exception as e:
    print(f"❌ [DjangoDisplay] 无法创建 SVG 输出目录: {e}", file=sys.stderr)


def print_direct(
    renderable: Any, 
    title: Optional[str] = None, 
    width: Optional[int] = None,
    save_to_file: bool = True,
    panel_type: Optional[str] = None,
    export_html: bool = True,
    output_dir: Optional[Path] = None
):
    """直接将 Rich 可渲染对象输出到终端，并生成 SVG 文件
    
    Args:
        renderable: Rich 可渲染对象
        title: 标题（可选）
        width: 渲染宽度（可选）
        save_to_file: 是否同时保存到文件（默认True）
        panel_type: 面板类型标识
        export_html: 是否导出 SVG
        output_dir: SVG 输出目录（可选，默认使用 RENDER_LOGS_DIR/svg）
    """
    print(f"🔍 [DjangoDisplay] print_direct 被调用: title={title}, panel_type={panel_type}, save_to_file={save_to_file}, output_dir={output_dir}", file=sys.stderr)
    # 自动计算宽度
    terminal_width = 100
    max_width = 80
    try:
        terminal_size = shutil.get_terminal_size()
        if terminal_size.columns > 40:
            terminal_width = terminal_size.columns
    except OSError:
        pass
    
    final_width = width or min(terminal_width, max_width) if terminal_width > max_width else terminal_width

    # 1. 输出到终端（带颜色）
    console = Console(
        theme=moncore_theme,
        force_terminal=True,
        width=final_width,
        file=sys.stdout
    )
    
    sys.stdout.flush()
    console.print(renderable)
    sys.stdout.flush()
    
    # 2. 同时保存到文件
    if save_to_file:
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
            
            panel_id = panel_type or "UNKNOWN"
            
            stage_info = ""
            if title:
                import re
                stage_match = re.search(r'\[(AGENT-[^\]]+)\]', title)
                if stage_match:
                    stage_info = stage_match.group(1)
            
            base_filename = f"panel_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')[:-3]}"
            svg_filename = f"{base_filename}.svg"
            
            # 使用指定的输出目录，或默认使用 SVG_OUTPUT_DIR
            target_output_dir = Path(output_dir) if output_dir else SVG_OUTPUT_DIR
            target_output_dir.mkdir(parents=True, exist_ok=True)
            svg_file_path = target_output_dir / svg_filename
            
            panel_data = {
                "type": panel_id,
                "stage": stage_info,
                "timestamp": timestamp,
                "title": title or "",
                "svg": svg_filename
            }
            
            # 保存索引信息到 JSON 文件
            panels = []
            if RENDER_INDEX_FILE.exists():
                try:
                    with open(RENDER_INDEX_FILE, 'r', encoding='utf-8') as f:
                        panels = json.load(f)
                except json.JSONDecodeError:
                    panels = []
            
            panels.append(panel_data)
            
            with open(RENDER_INDEX_FILE, 'w', encoding='utf-8') as f:
                json.dump(panels, f, ensure_ascii=False, indent=2)
            
            # 导出 SVG 版本到独立文件
            if export_html:
                try:
                    # 捕获带 ANSI 颜色码的文本
                    buffer_text = StringIO()
                    console_text = Console(
                        theme=moncore_theme,
                        width=final_width,
                        file=buffer_text,
                        force_terminal=True,
                        legacy_windows=False,
                        no_color=False
                    )
                    console_text.print(renderable)
                    
                    ansi_text = buffer_text.getvalue()
                    
                    # 使用 SVG 渲染
                    svg_content = create_terminal_svg(ansi_text, final_width, title, panel_id, stage_info, timestamp)
                    
                    # 保存到 SVG 文件
                    with open(svg_file_path, 'w', encoding='utf-8') as f:
                        f.write(svg_content)
                    print(f"✅ [DjangoDisplay] SVG 已保存: {svg_file_path}", file=sys.stderr)
                        
                except Exception as e:
                    import traceback
                    print(f"\n⚠️ [DjangoDisplay] 无法导出SVG: {e}", file=sys.stderr)
                    traceback.print_exc(file=sys.stderr)
                
        except Exception as e:
            print(f"\n⚠️ [DjangoDisplay] 无法写入渲染日志: {e}", file=sys.stderr)
