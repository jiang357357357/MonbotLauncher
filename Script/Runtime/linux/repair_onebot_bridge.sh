#!/usr/bin/env bash

set -euo pipefail

unset PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROCESS_DIR="$PROJECT_ROOT/Script/Process/linux"

HOST="${MON_ONEBOT_HOST:-127.0.0.1}"
PORT="${MON_ONEBOT_PORT:-3001}"
FORCE=0
ROTATE_TOKEN=0

usage() {
  cat <<'EOF'
用法:
  bash Script/Runtime/linux/repair_onebot_bridge.sh [选项]

选项:
  --host HOST     OneBot WS 监听地址，默认 127.0.0.1
  --port PORT     OneBot WS 监听端口，默认 3001
  --force         即使检测到端口占用，也继续写入配置
  --rotate-token  生成新令牌并使历史令牌立即失效
  -h, --help      显示帮助

说明:
  通过 NapCat WebUI API 创建或修复 OneBot WS 服务端，并同步工作区私有 bot.env。
  NapCat 未安装、未运行或 WebUI 不可用时会跳过，不阻断整次项目更新。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --rotate-token)
      ROTATE_TOKEN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[x] 未知参数: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# shellcheck source=../../Process/linux/napcat_common.sh
source "$PROCESS_DIR/napcat_common.sh"

kind="$(detect_napcat_launch_kind)"
if [[ "$kind" == "missing" ]]; then
  echo "[i] 未发现 NapCat 运行时，跳过 OneBot 接入修复"
  echo "[ONEBOT_BRIDGE_STATUS:SKIPPED_NOT_INSTALLED]"
  exit 0
fi

MONPM_STATUS="$(monpm_named_status "$NAPCAT_MONPM_NAME" 2>/dev/null || printf 'unknown')"
if [[ "$MONPM_STATUS" != "running" ]]; then
  echo "[i] NapCat 未运行，跳过 OneBot 接入修复: $MONPM_STATUS"
  echo "[ONEBOT_BRIDGE_STATUS:SKIPPED_NOT_RUNNING]"
  exit 0
fi

PLUGIN_ENTRY="$(napcat_shell_plugin_entry 2>/dev/null || true)"
if [[ -n "$PLUGIN_ENTRY" ]]; then
  NAPCAT_PLUGIN_DIR="$(cd "$(dirname "$PLUGIN_ENTRY")" && pwd)"
else
  NAPCAT_PLUGIN_DIR="$NAPCAT_INSTALL_BASE_DIR/opt/QQ/resources/app/app_launcher/napcat"
fi

WEBUI_CONFIG="$NAPCAT_PLUGIN_DIR/config/webui.json"
BOTCORE_CONFIG="$PROJECT_ROOT/BotCore/.monconfig"
BOT_ENV="$PROJECT_ROOT/../Config/ENV/bot.env"

export PROJECT_ROOT
export WEBUI_CONFIG
export BOTCORE_CONFIG
export BOT_ENV
export ONEBOT_HOST="$HOST"
export ONEBOT_PORT="$PORT"
export ONEBOT_FORCE="$FORCE"
export ONEBOT_ROTATE_TOKEN="$ROTATE_TOKEN"

python3 - <<'PY'
import hashlib
import json
import os
import socket
import sys
from pathlib import Path
from urllib import request


DEFAULT_WS_NAME = "MonBotWsServer"


def status(value: str) -> None:
    print(f"[ONEBOT_BRIDGE_STATUS:{value}]")


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def post_json(base_url: str, path: str, payload: dict | None = None, credential: str | None = None) -> dict:
    body = json.dumps(payload or {}).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if credential:
        headers["Authorization"] = f"Bearer {credential}"
    req = request.Request(base_url + path, data=body, headers=headers, method="POST")
    with request.urlopen(req, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def api_data(value: dict):
    if value.get("code") != 0:
        raise RuntimeError(value.get("message") or "NapCat WebUI API 返回失败")
    return value.get("data")


def login_webui(base_url: str, token: str) -> str:
    digest = hashlib.sha256(f"{token}.napcat".encode("utf-8")).hexdigest()
    data = api_data(post_json(base_url, "/api/auth/login", {"hash": digest}))
    credential = (data or {}).get("Credential")
    if not credential:
        raise RuntimeError("NapCat WebUI 未返回 Credential")
    return credential


def monconfig_value(path: Path, section: str, key: str) -> str:
    if not path.exists():
        return ""
    current = ""
    wanted_section = section.lower()
    wanted_key = key.upper()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].strip().lower()
            continue
        if current == wanted_section and "=" in line:
            raw_key, value = line.split("=", 1)
            if raw_key.strip().upper() == wanted_key:
                return value.split("#", 1)[0].strip()
    return ""


def env_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def update_env_values(path: Path, values: dict[str, str]) -> None:
    merged = env_values(path)
    merged.update(values)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(f"{key}={value}\n" for key, value in sorted(merged.items())),
        encoding="utf-8",
    )
    if os.name != "nt":
        path.chmod(0o600)


def port_open(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.6)
        return sock.connect_ex((host, port)) == 0


def is_monbot_ws_server(value: dict) -> bool:
    name = str(value.get("name") or "")
    return name == DEFAULT_WS_NAME or name.lower() == "monbot"


def main() -> int:
    webui_config = Path(os.environ["WEBUI_CONFIG"])
    botcore_config = Path(os.environ["BOTCORE_CONFIG"])
    bot_env = Path(os.environ["BOT_ENV"])
    host = os.environ.get("ONEBOT_HOST") or "127.0.0.1"
    port = int(os.environ.get("ONEBOT_PORT") or "3001")
    force = os.environ.get("ONEBOT_FORCE") == "1"
    rotate_token = os.environ.get("ONEBOT_ROTATE_TOKEN") == "1"

    print("================================================")
    print("NapCat OneBot 接入修复")
    print("================================================")
    print(f"WebUI 配置: {webui_config}")
    print(f"Bot 私有配置: {bot_env}")
    print(f"目标 WS: ws://{host}:{port}")

    if not webui_config.exists():
        print("[i] NapCat WebUI 配置不存在，跳过")
        status("SKIPPED_NO_WEBUI_CONFIG")
        return 0
    if not botcore_config.exists():
        print("[i] BotCore .monconfig 不存在，跳过")
        status("SKIPPED_NO_BOTCORE_CONFIG")
        return 0

    webui = load_json(webui_config)
    webui_port = webui.get("port")
    token = str(webui.get("token") or "")
    if not webui_port or not token:
        print("[i] NapCat WebUI 端口或 token 为空，跳过")
        status("SKIPPED_WEBUI_INCOMPLETE")
        return 0

    base_url = f"http://127.0.0.1:{int(webui_port)}"
    try:
        credential = login_webui(base_url, token)
        config = api_data(post_json(base_url, "/api/OB11Config/GetConfig", credential=credential))
    except Exception as exc:
        print(f"[i] NapCat WebUI API 不可用，跳过: {exc}")
        status("SKIPPED_WEBUI_UNAVAILABLE")
        return 0

    if not isinstance(config, dict):
        raise RuntimeError("NapCat OB11 配置不是 JSON 对象")

    network = config.setdefault("network", {})
    if not isinstance(network, dict):
        network = {}
        config["network"] = network
    for key in [
        "httpServers",
        "httpSseServers",
        "httpClients",
        "websocketServers",
        "websocketClients",
        "plugins",
    ]:
        if not isinstance(network.get(key), list):
            network[key] = []

    servers = network["websocketServers"]
    existing_index = next((index for index, item in enumerate(servers) if isinstance(item, dict) and is_monbot_ws_server(item)), None)
    existing = servers[existing_index] if existing_index is not None else None

    if port_open(host, port) and not (existing and existing.get("host") == host and int(existing.get("port") or 0) == port):
        if not force:
            print(f"[i] 目标端口已被占用，跳过写入: {host}:{port}")
            status("SKIPPED_PORT_BUSY")
            return 0

    access_token = "" if rotate_token else (
        str((existing or {}).get("token") or "").strip()
        or env_values(bot_env).get("MON_ONEBOT_ACCESS_TOKEN", "")
        or monconfig_value(botcore_config, "onebot", "ACCESS_TOKEN")
    )
    access_token = access_token or hashlib.sha256(os.urandom(32)).hexdigest()[:16]

    server_value = {
        "enable": True,
        "name": DEFAULT_WS_NAME,
        "host": host,
        "port": port,
        "messagePostFormat": "array",
        "reportSelfMessage": False,
        "token": access_token,
        "enableForcePushEvent": True,
        "debug": False,
        "heartInterval": 30000,
    }

    changed = existing != server_value
    if existing_index is None:
        servers.append(server_value)
    else:
        servers[existing_index] = server_value

    update_env_values(
        bot_env,
        {
            "MON_ONEBOT_WS_URLS": f"ws://{host}:{port}",
            "MON_ONEBOT_ACCESS_TOKEN": access_token,
        },
    )

    payload = {"config": json.dumps(config, ensure_ascii=False, separators=(",", ":"))}
    api_data(post_json(base_url, "/api/OB11Config/SetConfig", payload, credential))

    print(f"[OK] 已同步 NapCat OneBot WS 服务端: ws://{host}:{port}")
    print(f"[OK] 已同步 Bot 私有配置: {bot_env}")
    status("REPAIRED" if changed else "OK")
    return 0


try:
    raise SystemExit(main())
except Exception as exc:
    print(f"[x] OneBot 接入修复失败: {exc}", file=sys.stderr)
    status("FAILED")
    raise SystemExit(1)
PY
