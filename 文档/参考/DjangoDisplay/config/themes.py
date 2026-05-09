from rich.theme import Theme

MONCORE_THEME = {
    "info": "green",
    "warning": "yellow",
    "error": "red",
    "critical": "bold white on red",
    "tag.monos": "bold blue",
    "tag.kernel": "bold cyan",
    "tag.core": "bold magenta",
    "tag.test": "bold green",
    "table.header": "bold cyan",
    "table.title": "bold white",
    "panel.border": "dim blue",
    "panel.title": "bold",
    "status.ok": "green",
    "status.warn": "yellow",
    "status.fail": "red",
    "status.dim": "dim white",
}

moncore_theme = Theme(MONCORE_THEME)


def get_style(name: str) -> str:
    return MONCORE_THEME.get(name, "")

