# MonBot - QQ 机器人

基于 NoneBot2 的 QQ 机器人，通过 NapCat 协议与 QQ 通信，通过 WebSocket 与 MonCore 后端交互。

## 特性

- 🤖 基于 NoneBot2 框架，稳定可靠
- 🔌 支持 OneBot v11 协议（NapCat）
- 🌐 与 MonCore 后端实时通信
- 🎯 智能消息过滤和关键词触发
- 🔊 支持语音回复（TTS）
- 📱 支持群聊和私聊
- 🔄 自动重连和错误恢复
- 🎨 丰富的日志和渲染系统

## 系统要求

- Python 3.12.6+
- NapCat（QQ 协议实现）
- MonCore 后端服务

## 快速开始

### 1. 安装依赖

使用 uv（推荐）：

```bash
# 安装 uv
pip install uv

# 安装项目依赖
uv pip install -e .
```

或使用 pip：

```bash
pip install nonebot2[fastapi] nonebot-adapter-onebot websockets aiohttp aiofiles rich
```

### 2. 配置机器人

编辑 `MonQQBotCore/MonBot/src/plugins/BotCore/config/config.json`：

```json
{
  "bot_name": "你的机器人名字",
  "bot_nicknames": ["昵称1", "昵称2"],
  "command_prefix": "/",
  "enable_mention_reply": true,
  "enable_name_mention": true
}
```

### 3. 启动机器人

```bash
# 方式1：直接运行
python MonQQBotCore/MonBot/bot.py

# 方式2：使用 uv
uv run python MonQQBotCore/MonBot/bot.py

# 方式3：使用启动器（如果有 GUI 界面）
python main_launcher.py
```

### Linux PM2 启动

Linux 环境先安装依赖，再交给 PM2 托管 QQBot 进程：

```bash
Script/EnvTools/linux/install_env.sh
Script/Cmd/linux/start.sh
```

常用管理命令：

```bash
Script/Process/linux/status_process.sh
Script/Process/linux/stop_process.sh
Script/Process/linux/restart_process.sh
pm2 logs MonBot-Service
```

当前 Linux PM2 脚本会先尝试启动 NapCat，再启动 `BotCore/bot.py`。NapCat 和 MonBot 是两个 PM2 应用，分别是 `NapCat-Service` 与 `MonBot-Service`。

### NapCat 外置运行时

NapCatQQ 当前许可证包含非商业使用限制；Gitee 分发仓库不要提交 NapCat 源码、二进制或解压后的运行时目录。仓库只提供外置安装脚本，实际部署时由使用者从 NapCat 官方安装器拉取到本机。默认本机部署目录是 `BotLauncher/napcat`，该目录已被 Git 忽略。

参考：

- NapCatQQ 许可证：https://github.com/NapNeko/NapCatQQ/blob/main/LICENSE
- NapCat 官方安装器：https://github.com/NapNeko/NapCat-Installer

Linux：

```bash
# 检查本机是否已有 NapCat
Script/Runtime/linux/check_napcat.sh

# 默认执行官方安装器，安装到 BotLauncher/napcat
Script/Runtime/linux/install_napcat.sh

# 只下载官方安装器到 napcat/.installer，不执行安装
Script/Runtime/linux/install_napcat.sh --download-only

# 显式确认许可证后在 BotLauncher/napcat 中执行官方安装器
Script/Runtime/linux/install_napcat.sh --run-installer --accept-napcat-license -- --docker n --cli n

# 由 PM2 启动 NapCat
Script/Process/linux/start_napcat_process.sh

# 查看/停止/重启 NapCat
Script/Process/linux/status_napcat_process.sh
Script/Process/linux/stop_napcat_process.sh
Script/Process/linux/restart_napcat_process.sh

# 给 ConfigAppReact 读取 WebUI token 与登录二维码
Script/Runtime/linux/napcat_info.sh --pretty
Script/Runtime/linux/napcat_info.sh --no-image
```

Windows：

```powershell
# 检查本机是否已有 NapCat
powershell -ExecutionPolicy Bypass -File Script/Runtime/win/check_napcat.ps1

# 只下载官方安装器到 napcat/.installer，不执行安装
powershell -ExecutionPolicy Bypass -File Script/Runtime/win/install_napcat.ps1

# 显式确认许可证后在 BotLauncher/napcat 中执行官方安装器
powershell -ExecutionPolicy Bypass -File Script/Runtime/win/install_napcat.ps1 -RunInstaller -AcceptNapCatLicense
```

如已获得 NapCatQQ 主作者对商业分发的明确授权，再单独调整分发脚本；默认流程保持外置运行时，不把 NapCat 本体推送到 Gitee。

`napcat_info` 脚本会输出 JSON，字段包含：

- `status` / `pm2Status` / `launchKind`
- `webui.url` / `webui.token` / `webui.configPath`
- `qrcode.path` / `qrcode.dataUrl` / `qrcode.modifiedAt`

其中 `webui.token` 和 `qrcode.dataUrl` 属于敏感信息，只应在本机管理界面展示，不要写入远程日志。

NapCat PM2 管理读取 `.monconfig` 的 `[napcat_process]`：

- `MODE=auto`：自动探测 Shell、AppImage、Docker 或自定义命令。
- `HOME=napcat`：NapCat 的本机部署根目录。
- `INSTALL_BASE_DIR=napcat/Napcat`：官方 Shell 安装器生成的主安装目录。
- `COMMAND=`：当 `MODE=custom` 时由 PM2 直接执行。

## 项目结构

```
├── MonQQBotCore/           # 机器人核心
│   ├── MonBot/            # NoneBot2 机器人
│   │   ├── bot.py         # 机器人入口
│   │   └── src/
│   │       ├── plugins/   # NoneBot 插件
│   │       │   └── BotCore/  # 核心业务插件
│   │       └── System/    # 系统工具库
│   └── main_launcher.py   # 简化启动器
├── interface/             # GUI 界面（可选）
├── pyproject.toml         # 项目配置
└── README.md             # 项目说明
```

## 核心功能

### 消息处理

- **命令处理**：支持 `/帮助`、`/角色`、`/语音`、`/好感`、`/好感排行` 等命令
- **关键词触发**：@机器人、提到机器人名字或后端配置的关键词
- **白名单过滤**：私聊按联系人授权；群聊按群号或发言人 QQ 任一授权放行
- **智能回复**：调用 MonCore 后端生成 AI 回复

### 语音功能

- **TTS 支持**：将文本回复转换为语音
- **自动降级**：语音生成失败时自动回退到文本
- **语音开关**：可通过 `/语音 开启/关闭` 命令控制，修改类命令仅 superuser 可用
- **好感查询**：可通过 `/好感` 查看自己的四维好感值，通过 `/好感排行` 查看好感总值排行

### 后端通信

- **UDP 服务发现**：自动发现 MonCore 服务器
- **WebSocket 连接**：建立专用通信通道
- **实时同步**：接收后端推送的白名单和关键词更新
- **自动重连**：连接断开时自动重连

## 配置说明

### 机器人配置

位置：`MonQQBotCore/MonBot/src/plugins/BotCore/config/config.json`

```json
{
  "bot_name": "机器人名字",
  "bot_nicknames": ["昵称列表"],
  "bot_description": "机器人描述",
  "command_prefix": "/",
  "enable_mention_reply": true,
  "enable_name_mention": true,
  "default_reply": "默认回复",
  "error_reply": "错误回复",
  "private_reply": "私聊回复模板"
}
```

### NapCat 配置

位置：`MonQQBotCore/MonBot/config/napcat.json`

```json
{
  "host": "127.0.0.1",
  "port": 3001,
  "access_token": "your_access_token"
}
```

### 环境变量

```bash
# MonCore 后端配置
MONCORE_IP=192.168.1.100          # 手动指定后端 IP（可选）
MONCORE_HTTP_HOST=localhost       # HTTP 访问地址（可选）

# 日志配置
LOG_LEVEL=INFO                    # 日志级别
```

## 开发指南

### 添加新命令

1. 在 `core/router/commands.py` 中注册命令
2. 在 `core/business/command/command_service.py` 中实现业务逻辑

### 添加新的消息处理

1. 在 `core/business/message/` 下的服务中添加方法
2. 在 `message_handlers.py` 中调用

### 调用后端 API

```python
from ....app import get_moncore_api

moncore_api = get_moncore_api()
if moncore_api:
    result = await moncore_api.store_message(event)
```

### 系统工具

项目包含独立的系统工具库：

- **Logs**：彩色日志系统
- **Rendering**：终端渲染和 SVG 导出
- **LogCleaner**：日志文件清理

详见各模块的 README 文档。

## 部署

### Docker 部署（推荐）

```dockerfile
FROM python:3.12.6-slim

WORKDIR /app
COPY . .

RUN pip install uv && uv pip install -e .

CMD ["python", "MonQQBotCore/MonBot/bot.py"]
```

### 系统服务

创建 systemd 服务文件：

```ini
[Unit]
Description=MonBot QQ Robot
After=network.target

[Service]
Type=simple
User=monbot
WorkingDirectory=/path/to/monbot
ExecStart=/usr/bin/python MonQQBotCore/MonBot/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## 故障排除

### 常见问题

1. **ModuleNotFoundError: No module named 'nonebot'**
   ```bash
   pip install nonebot2[fastapi] nonebot-adapter-onebot
   ```

2. **连接 MonCore 失败**
   - 检查 MonCore 服务是否启动
   - 检查网络连接和防火墙设置
   - 查看日志中的详细错误信息

3. **语音功能不工作**
   - 检查 `/语音` 命令是否开启
   - 确认后端返回了 `audio_url`
   - 检查音频下载权限和网络

### 日志查看

```bash
# 查看实时日志
tail -f logs/monbot.log

# 查看错误日志
grep ERROR logs/monbot.log
```

## 贡献

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 相关链接

- [NoneBot2 官方文档](https://nonebot.dev/)
- [OneBot 标准](https://onebot.dev/)
- [NapCat 项目](https://github.com/NapNeko/NapCatQQ)

## 更新日志

### v0.1.0

- 初始版本发布
- 基础消息处理功能
- MonCore 后端集成
- 语音回复支持
- 系统工具库

---

如有问题或建议，欢迎提交 Issue 或 Pull Request！
