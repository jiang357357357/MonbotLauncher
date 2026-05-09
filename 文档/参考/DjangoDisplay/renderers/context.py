from typing import Any, Dict, List, Optional
import json
from rich.markup import escape
from rich import box
from .table import render_table

def render_context(
    context_materials: Dict[str, Any], 
    character_name: str = "未知",
    user_name: str = "用户",
    system_prompt: Optional[str] = None,
    messages: Optional[List[Dict[str, Any]]] = None,
    stage_name: str = "上下文预览",
    width: Optional[int] = None
) -> None:
    """专门渲染上下文材质的函数，将格式化逻辑集中在面板模块"""
    
    # 这里的逻辑是从 ContextVisualizer 迁移过来的，确保面板渲染与 AI 注入内容一致
    
    # 从枚举中获取权重标签映射
    try:
        from Application.System.AiService.Context.Adapters.Django.Persistence.enums import ContextWeight
        label_map = {
            ContextWeight.DECORATIVE.value: ContextWeight.DECORATIVE.label,
            ContextWeight.BACKGROUND.value: ContextWeight.BACKGROUND.label,
            ContextWeight.CONTEXT.value: ContextWeight.CONTEXT.label,
            ContextWeight.IMPORTANT.value: ContextWeight.IMPORTANT.label,
            ContextWeight.MANDATORY.value: ContextWeight.MANDATORY.label,
        }
    except:
        # 如果导入失败，使用硬编码的映射表作为后备
        label_map = {
            "decorative": "装饰级",
            "background": "背景级",
            "context": "上下文级",
            "important": "重要级",
            "mandatory": "硬约束级",
        }

    def get_display_label(block: Any) -> str:
        """获取用于拼块显示的标签文字 (如 '硬约束级')"""
        if not isinstance(block, dict): return "上下文级"
        weight = block.get("weight")
        if not weight: return "上下文级"
        weight_str = str(weight)
        return label_map.get(weight_str, weight_str)

    def get_weight_column_text(block: Any) -> str:
        """获取显示在 '权重' 列的文字"""
        if not isinstance(block, dict): return "上下文级"
        weight = block.get("weight")
        if not weight: return "上下文级"
        weight_str = str(weight)
        return label_map.get(weight_str, weight_str)

    headers = ["类型", "角色", "权重", "内容"]
    rows: List[List[str]] = []

    if messages is not None:
        for i, m in enumerate(messages, 1):
            role = m.get("role") or ""
            content = m.get("content") or ""
            
            # [WYSIWYG] 处理工具调用显示
            tool_calls = m.get("tool_calls")
            if tool_calls:
                tool_info = []
                for tc in tool_calls:
                    t_func = tc.get("function") or {}
                    t_name = t_func.get("name") or "未知工具"
                    t_args = t_func.get("arguments") or "{}"
                    tool_info.append(f"▶ 调用工具: {t_name}\n参数: {t_args}")
                
                if content:
                    content = f"{content}\n\n" + "\n".join(tool_info)
                else:
                    content = "\n".join(tool_info)

            rows.append([f"消息-{i}", str(role), "", escape(str(content))])

        if not rows:
            rows.append(["-", "-", "-", "当前无可用上下文"])

        title = f"{stage_name} - {character_name}"
        # 直接使用 print_direct，指定面板类型为 CONTEXT
        from Application.Tools.DjangoDisplay.core.printer import print_direct
        from .table import _prepare_table
        table = _prepare_table(headers, rows, title)
        print_direct(table, title=title, width=width, panel_type="CONTEXT")
        return
    
    # 0. 意图识别/对话指令 (如果提供)
    if system_prompt:
        rows.append(["指令模板", "系统", "[bold red]硬约束级[/]", escape(system_prompt)])
    
    # 特殊类型（不作为单一内容块渲染，单独处理）
    special_keys = {"长期记忆", "短期记忆", "历史", "tools", 
                    "world_name", "character_name", "user_name"}
    
    # 1. 自动渲染所有单一内容类型（完全动态，type 直接作为显示名称）
    for key, value in context_materials.items():
        # 跳过特殊类型
        if key in special_keys:
            continue
        # 只处理字典类型且有内容的
        if not isinstance(value, dict) or not value.get("content"):
            continue
            
        content = value.get("content")
        label_text = get_display_label(value)
        weight_text = get_weight_column_text(value)
        # 直接使用 key 作为显示名称（Loader 已经用中文了）
        display_name = key
        display_content = f"[[{label_text}] {display_name}]\n{content}"
        rows.append([display_name, "系统", weight_text, escape(display_content)])

    # 2. 可用工具
    tools = context_materials.get("tools") or []
    if tools:
        tools_str = ""
        for t in tools:
            if isinstance(t, dict):
                func = t.get("function", {})
                name = func.get("name", "未知工具")
                desc = func.get("description", "无描述")
                tools_str += f"- [bold green]{escape(name)}[/]: {escape(desc)}\n"
            else:
                tools_str += f"- {escape(str(t))}\n"
        rows.append(["可用工具", "系统", "[bold red]原生协议[/]", tools_str.strip()])

    # 3. 长期记忆
    long_term_memories = context_materials.get("长期记忆") or []
    for idx, m in enumerate(long_term_memories, 1):
        t, c = m.get("title", ""), m.get("content", "")
        w = m.get("weight")
        l = label_map.get(str(w) if w is not None else "", str(w) if w is not None else "")
        rows.append([f"长期记忆-{idx}", "助手", l, f"[bold cyan]{escape(t)}[/]\n{escape(c)}"])
        
    # 4. 短期记忆
    short_term_memories = context_materials.get("短期记忆") or []
    for idx, m in enumerate(short_term_memories, 1):
        t, c = m.get("title", ""), m.get("content", "")
        w = m.get("weight")
        l = label_map.get(str(w) if w is not None else "", str(w) if w is not None else "")
        rows.append([f"短期记忆-{idx}", "助手", l, f"[bold cyan]{escape(t)}[/]\n{escape(c)}"])
        
    # 5. 对话历史 (过滤逻辑：只保留最后一次工具结果)
    history_entries = context_materials.get("历史") or []
    
    # [NEW] 确定哪些工具消息是“有效的” (与 Assembler 逻辑对齐)
    allowed_tool_call_ids = set()
    last_assistant_idx = -1
    for i in range(len(history_entries) - 1, -1, -1):
        e = history_entries[i]
        st = e.get("sender_type") or e.get("role")
        if st == "character" or st == "assistant":
            last_assistant_idx = i
            t_calls = e.get("tool_calls") or []
            for tc in t_calls:
                tid = tc.get("id")
                if tid:
                    allowed_tool_call_ids.add(tid)
            break
            
    if history_entries:
        display_idx = 1
        for idx, entry in enumerate(history_entries, 1):
            st = entry.get("sender_type") or entry.get("role")
            
            # 如果是工具结果，但不是关联到最后一条助手消息的，则跳过
            if st == "tool":
                tool_call_id = entry.get("tool_call_id")
                if tool_call_id not in allowed_tool_call_ids:
                    continue
            
            c = entry.get("content") or ""
            
            # 处理 Tool 角色 (与 Assembler 逻辑对齐)
            if st == "tool":
                tool_name = entry.get("name") or entry.get("tool_name") or "task_finish"
                tool_args = entry.get("tool_args") or {}
                tool_call_id = entry.get("tool_call_id") or "unknown"
                
                # 完全模拟 Assembler 的 formatted_content
                display_content = (
                    f"[任务执行结果]\n"
                    f"ID: {tool_call_id}\n"
                    f"{c}\n"
                    f"▶ 调用工具: {tool_name}\n"
                    f"参数: {json.dumps(tool_args, ensure_ascii=False)}"
                )
                
                prefix = "[bold cyan]工具结果[/]"
                # 确定是否是最后一个有效工具结果
                is_last_valid_tool = False
                if idx == len(history_entries): # 简单判断，Assembler 逻辑更复杂
                    is_last_valid_tool = True
                
                weight_label = "[上下文级]"
                rows.append([f"历史-{display_idx}", "系统" if is_last_valid_tool else "助手", weight_label, escape(display_content)])
                display_idx += 1
                continue

            escaped_c = escape(c)
            # 处理 Tool Calls
            tool_calls = entry.get("tool_calls")
            if tool_calls:
                t_str = ""
                for t in tool_calls:
                    f = t.get("function", {})
                    n = f.get("name", "未知")
                    a = f.get("arguments", "{}")
                    t_str += f"\n[bold yellow]▶ 呼叫工具: {escape(n)}[/]\n[dim]参数: {escape(str(a))}[/]"
                escaped_c += t_str
            
            if st == "user": 
                prefix = "[bold green]用户[/]"
                rows.append([f"历史-{display_idx}", "用户", "[上下文级]", escaped_c])
            else:
                prefix = "[bold magenta]助手[/]"
                rows.append([f"历史-{display_idx}", "助手", "[上下文级]", escaped_c])
            
            display_idx += 1
        
    if not rows:
        rows.append(["-", "-", "-", "当前无可用上下文"])
        
    title = f"{stage_name} - {character_name}"
    # 直接使用 print_direct，指定面板类型为 CONTEXT
    from Application.Tools.DjangoDisplay.core.printer import print_direct
    from .table import _prepare_table
    table = _prepare_table(headers, rows, title)
    print_direct(table, title=title, width=width, panel_type="CONTEXT")
    # 注意：render_table 内部会调用 print_direct，并自动设置 panel_type="TABLE"
