#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROCESS_DIR="$PROJECT_ROOT/Script/Process/linux"

INCLUDE_IMAGE=1
PRETTY=0

print_usage() {
  cat <<'EOF'
用法:
  bash Script/Runtime/linux/napcat_info.sh [选项]

选项:
  --no-image  不输出 qrcodeDataUrl，仅输出二维码路径
  --pretty    格式化 JSON
  -h, --help  显示帮助

说明:
  输出 JSON 给 ConfigAppReact 读取。包含 WebUI 地址、token、二维码路径、二维码 data URL 和 PM2 状态。
  token 与二维码是敏感信息，请只在本机管理界面展示，不要写入远程日志。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-image)
      INCLUDE_IMAGE=0
      shift
      ;;
    --pretty)
      PRETTY=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "[x] 未知参数: $1" >&2
      print_usage >&2
      exit 2
      ;;
  esac
done

# shellcheck source=../../Process/linux/napcat_common.sh
source "$PROCESS_DIR/napcat_common.sh"

PM2_STATUS="unknown"
if command -v pm2 >/dev/null 2>&1; then
  PM2_STATUS="$(pm2_named_status "$NAPCAT_PM2_NAME" 2>/dev/null || printf 'unknown')"
fi

LAUNCH_KIND="$(detect_napcat_launch_kind)"
PLUGIN_ENTRY="$(napcat_shell_plugin_entry 2>/dev/null || true)"
if [[ -n "$PLUGIN_ENTRY" ]]; then
  NAPCAT_PLUGIN_DIR="$(cd "$(dirname "$PLUGIN_ENTRY")" && pwd)"
else
  NAPCAT_PLUGIN_DIR="$NAPCAT_INSTALL_BASE_DIR/opt/QQ/resources/app/app_launcher/napcat"
fi

WEBUI_CONFIG="$NAPCAT_PLUGIN_DIR/config/webui.json"
QRCODE_PATH="$NAPCAT_PLUGIN_DIR/cache/qrcode.png"

export PROJECT_ROOT
export NAPCAT_PM2_NAME
export NAPCAT_HOME
export NAPCAT_INSTALL_BASE_DIR
export NAPCAT_PLUGIN_DIR
export NAPCAT_QQ_EXECUTABLE
export NAPCAT_MODE
export PM2_STATUS
export LAUNCH_KIND
export WEBUI_CONFIG
export QRCODE_PATH
export INCLUDE_IMAGE
export PRETTY

python3 - <<'PY'
import base64
import json
import mimetypes
import os
from datetime import datetime
from pathlib import Path


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def path_info(value: str) -> str:
    return str(Path(value).expanduser()) if value else ""


def modified_at(path: Path) -> str | None:
    if not path.exists():
        return None
    return datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds")


def read_webui(path: Path) -> tuple[dict, str | None]:
    if not path.exists():
        return {}, "webui.json 不存在"
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except Exception as exc:
        return {}, f"读取 webui.json 失败: {exc}"


def qrcode_data_url(path: Path, include_image: bool) -> str | None:
    if not include_image or not path.exists():
        return None
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def webui_request(base_url: str, credential: str, path: str, payload: dict | None = None) -> dict:
    from urllib import request

    body = json.dumps(payload or {}).encode("utf-8")
    req = request.Request(
        base_url + path,
        data=body,
        headers={
            "Authorization": f"Bearer {credential}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=2.5) as response:
        return json.loads(response.read().decode("utf-8"))


def webui_credential(base_url: str, token: str) -> str:
    import hashlib
    from urllib import request

    digest = hashlib.sha256(f"{token}.napcat".encode("utf-8")).hexdigest()
    body = json.dumps({"hash": digest}).encode("utf-8")
    req = request.Request(
        base_url + "/api/auth/login",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=2.5) as response:
        result = json.loads(response.read().decode("utf-8"))
    if result.get("code") != 0:
        raise RuntimeError(result.get("message") or "WebUI 鉴权失败")
    credential = (result.get("data") or {}).get("Credential")
    if not credential:
        raise RuntimeError("WebUI 未返回 Credential")
    return credential


def read_login_info(webui_url: str, token: str) -> dict:
    empty = {
        "apiAvailable": False,
        "isLogin": False,
        "isOffline": False,
        "uid": "",
        "uin": "",
        "nick": "",
        "online": None,
        "avatarUrl": None,
        "loginError": None,
        "qrcodeUrl": None,
        "error": None,
    }
    if not webui_url:
        return {**empty, "error": "WebUI 地址未生成"}
    if not token:
        return {**empty, "error": "WebUI token 未生成"}
    try:
        base_url = webui_url.split("/webui", 1)[0]
        credential = webui_credential(base_url, token)
        status = webui_request(base_url, credential, "/api/QQLogin/CheckLoginStatus")
        info = webui_request(base_url, credential, "/api/QQLogin/GetQQLoginInfo")
        status_data = status.get("data") or {}
        info_data = info.get("data") or {}
        return {
            **empty,
            "apiAvailable": True,
            "isLogin": bool(status_data.get("isLogin")),
            "isOffline": bool(status_data.get("isOffline")),
            "uid": str(info_data.get("uid") or ""),
            "uin": str(info_data.get("uin") or ""),
            "nick": str(info_data.get("nick") or ""),
            "online": info_data.get("online"),
            "avatarUrl": info_data.get("avatarUrl"),
            "loginError": status_data.get("loginError"),
            "qrcodeUrl": status_data.get("qrcodeurl"),
        }
    except Exception as exc:
        return {**empty, "error": str(exc)}


webui_config = Path(env("WEBUI_CONFIG"))
qrcode_path = Path(env("QRCODE_PATH"))
include_image = env("INCLUDE_IMAGE") == "1"
pretty = env("PRETTY") == "1"
webui, webui_error = read_webui(webui_config)

host = str(webui.get("host") or "")
port = webui.get("port")
token = str(webui.get("token") or "")

if host in ("", "::", "0.0.0.0", "[::]"):
    browser_host = "127.0.0.1"
else:
    browser_host = host.strip("[]")

webui_url = ""
if port:
    webui_url = f"http://{browser_host}:{port}/webui"
    if token:
        webui_url += f"?token={token}"

pm2_status = env("PM2_STATUS", "unknown")
launch_kind = env("LAUNCH_KIND", "missing")

if launch_kind == "missing":
    status = "notInstalled"
elif webui_error:
    status = "missingConfig"
elif pm2_status == "online":
    status = "running"
elif pm2_status == "missing":
    status = "notRunning"
else:
    status = "unknown"

payload = {
    "status": status,
    "pm2Name": env("NAPCAT_PM2_NAME"),
    "pm2Status": pm2_status,
    "launchKind": launch_kind,
    "runtimeRoot": path_info(env("NAPCAT_HOME")),
    "installBaseDir": path_info(env("NAPCAT_INSTALL_BASE_DIR")),
    "pluginDir": path_info(env("NAPCAT_PLUGIN_DIR")),
    "qqExecutable": path_info(env("NAPCAT_QQ_EXECUTABLE")),
    "webui": {
        "configPath": str(webui_config),
        "configExists": webui_config.exists(),
        "host": host,
        "port": port,
        "token": token,
        "url": webui_url,
        "modifiedAt": modified_at(webui_config),
        "error": webui_error,
    },
    "qrcode": {
        "path": str(qrcode_path),
        "exists": qrcode_path.exists(),
        "modifiedAt": modified_at(qrcode_path),
        "dataUrl": qrcode_data_url(qrcode_path, include_image),
    },
    "login": read_login_info(webui_url, token),
}

print(json.dumps(payload, ensure_ascii=False, indent=2 if pretty else None))
PY
