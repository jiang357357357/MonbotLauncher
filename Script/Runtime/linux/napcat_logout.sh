#!/usr/bin/env bash

set -euo pipefail

unset PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROCESS_DIR="$PROJECT_ROOT/Script/Process/linux"

# shellcheck source=../../Process/linux/napcat_common.sh
source "$PROCESS_DIR/napcat_common.sh"

ensure_pm2

kind="$(detect_napcat_launch_kind)"
PLUGIN_ENTRY="$(napcat_shell_plugin_entry 2>/dev/null || true)"
if [[ -n "$PLUGIN_ENTRY" ]]; then
  NAPCAT_PLUGIN_DIR="$(cd "$(dirname "$PLUGIN_ENTRY")" && pwd)"
else
  NAPCAT_PLUGIN_DIR="$NAPCAT_INSTALL_BASE_DIR/opt/QQ/resources/app/app_launcher/napcat"
fi

WEBUI_CONFIG="$NAPCAT_PLUGIN_DIR/config/webui.json"
export WEBUI_CONFIG

echo "================================================"
echo "NapCat QQ 退出工具"
echo "================================================"
echo "项目目录: $PROJECT_ROOT"
echo "应用名称: $NAPCAT_PM2_NAME"
echo "运行模式: $kind"
echo "WebUI配置: $WEBUI_CONFIG"
echo

if [[ "$kind" == "missing" ]]; then
  echo "[x] 未发现可管理的 NapCat 运行时"
  echo "[NAPCAT_LOGOUT:NOT_INSTALLED]"
  exit 1
fi

python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
from urllib import request


def post(base_url: str, credential: str, path: str, payload: dict | None = None) -> dict:
    req = request.Request(
        base_url + path,
        data=json.dumps(payload or {}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {credential}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=3) as response:
        return json.loads(response.read().decode("utf-8"))


config_path = Path(os.environ["WEBUI_CONFIG"])
if not config_path.exists():
    raise SystemExit(f"[x] WebUI 配置不存在: {config_path}")

config = json.loads(config_path.read_text(encoding="utf-8"))
host = str(config.get("host") or "127.0.0.1").strip("[]")
if host in ("", "::", "0.0.0.0"):
    host = "127.0.0.1"
port = config.get("port")
token = str(config.get("token") or "")

if not port or not token:
    raise SystemExit("[x] WebUI port/token 不完整，无法确认当前 QQ 登录态")

base_url = f"http://{host}:{port}"
digest = hashlib.sha256(f"{token}.napcat".encode("utf-8")).hexdigest()
auth_req = request.Request(
    base_url + "/api/auth/login",
    data=json.dumps({"hash": digest}).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with request.urlopen(auth_req, timeout=3) as response:
    auth = json.loads(response.read().decode("utf-8"))

if auth.get("code") != 0:
    raise SystemExit(f"[x] WebUI 鉴权失败: {auth.get('message')}")

credential = (auth.get("data") or {}).get("Credential")
if not credential:
    raise SystemExit("[x] WebUI 未返回 Credential")

status = post(base_url, credential, "/api/QQLogin/CheckLoginStatus")
info = post(base_url, credential, "/api/QQLogin/GetQQLoginInfo")
status_data = status.get("data") or {}
info_data = info.get("data") or {}

uin = str(info_data.get("uin") or "")
nick = str(info_data.get("nick") or "")
is_login = bool(status_data.get("isLogin"))

if is_login:
    print(f"[i] 当前登录 QQ: {nick or '未知昵称'} ({uin or '未知QQ'})")
else:
    print("[i] 当前没有在线 QQ，仍会清空自动快速登录账号")

result = post(base_url, credential, "/api/QQLogin/SetQuickLoginQQ", {"uin": ""})
if result.get("code") != 0:
    raise SystemExit(f"[x] 清空自动快速登录失败: {result.get('message')}")

print("[✓] 已清空 NapCat 自动快速登录账号")
PY

echo
echo "[1/2] 重启 NapCat，使其回到扫码登录入口..."
status="$(pm2_named_status "$NAPCAT_PM2_NAME")"
if [[ "$status" == "missing" ]]; then
  run_pm2_quiet start "$NAPCAT_ECOSYSTEM_FILE" --only "$NAPCAT_PM2_NAME"
else
  run_pm2_quiet restart "$NAPCAT_PM2_NAME" --update-env
fi

echo
echo "[2/2] PM2 状态"
pm2_process_summary "$NAPCAT_PM2_NAME"
echo
echo "[NAPCAT_LOGOUT:RESTARTED_FOR_LOGIN]"
