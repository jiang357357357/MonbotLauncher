# MonBot - QQ 机器人

基于 NoneBot2 的 QQ 机器人，通过 NapCat 协议与 QQ 通信，通过 WebSocket 与 MonCore 后端交互。

## 源码工作区位置

Mon 工作区中的源码位于 `DLC/BotLauncher/`，机器人核心仍是其内部子模块 `BotCore/`。以下开发命令从 `DLC/BotLauncher` 目录执行。启动、进程管理和离线维护脚本向上寻找 `.monworkspace` 定位 Mon 根目录，不依赖固定目录层数；独立仓库及现有 QQBot 便携布局继续兼容。

工作区凭据仍位于根目录 `Config/ENV/bot.env`，设备绑定状态仍位于根目录 `.run/qqbot`；模块内 `BotCore/Config`、`BotCore/data`、`Logs` 和可选 NapCat 运行目录随模块保留。这里的 `DLC/` 是源码分类，源码目录本身不是客户可安装的 DLC 包。

## Windows 客户 DLC

QQBot 是独立交付的付费 DLC。客户将主包与 DLC 分别解压为同级的 `EDEN-portable/EDEN_win` 和 `EDEN-portable/QQBot`，从主包 `启动EDEN.vbs` 打开配置管理和 Web，在“机器人设置 → 接入 → QQBot”扫码登录并一键绑定。

当前 Windows DLC 内含编译后的 BotCore 与获商用授权的 NapCat，客户无需安装 Python、Node.js 或 NapCat，只需安装官方 Windows QQ。未购买客户只交付主包。后续客户交付不再使用 GitCode Release、私有运行时仓库或稳定清单；安装与升级说明见 [QQBot DLC 安装与使用](../../文档/发布/QQBot%20DLC安装与使用.md)。以下依赖和启动命令适用于源码开发环境。

## 特性

- 🤖 基于 NoneBot2 框架，稳定可靠
- 🔌 支持 OneBot v11 协议（NapCat）
- 🌐 与 MonCore 后端实时通信
- 🎯 智能消息过滤和关键词触发
- 🔊 支持语音回复（TTS）
- 📱 支持群聊和私聊
- 🔄 自动重连和错误恢复
- 🎨 丰富的日志和渲染系统

## 源码开发要求

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

本地运行配置为 `BotCore/Config/bot.json`；源码首次启动会从 `BotCore/src/plugins/BotCore/config/config.json` 建立配置。非敏感连接设置放在模块 `.monconfig`，凭据由 Web 写入工作区 `Config/ENV/bot.env`。机器人身份由 NapCat 和 Core 提供，不用本地字段冒充账号绑定：

```json
{
  "enable_mention_reply": true,
  "enable_name_mention": true
}
```

### 3. 启动机器人

```bash
# 方式1：直接运行
python BotCore/bot.py

# 方式2：使用 uv
uv run python BotCore/bot.py
```

### Linux MonPM 启动

Linux 环境先安装依赖，再交给 MonPM 托管 QQBot 进程：

```bash
Script/EnvTools/linux/install_env.sh
Script/Cmd/linux/start.sh
```

常用管理命令：

```bash
Script/Process/linux/status_process.sh
Script/Process/linux/stop_process.sh
Script/Process/linux/restart_process.sh
Script/Process/linux/logs_process.sh
```

当前 Linux MonPM 脚本会先尝试启动 NapCat，再启动 `BotCore/bot.py`。NapCat 和 MonBot 是两个独立应用，分别是 `napcat` 与 `bot`。

### NapCat 外置运行时

NapCat 的源码、二进制和解压后的运行时目录不进入 Mon 或子模块源码历史。项目持有人已确认取得作者商用授权，当前 Windows 客户所需的 NapCat 随独立 QQBot DLC 交付，包内保留官方来源、上游版本、完整许可证、校验值和授权说明，不分发腾讯 QQ。

默认源码部署目录是 `DLC/BotLauncher/napcat`，该目录已被 Git 忽略。旧 Linux 安装器仍包含从 GitCode 私有运行时仓库恢复离线包的代码，仅作为历史维护工具；目录迁移没有改变该安装器的下载来源，不能把它作为后续客户 DLC 的下载入口。

参考：

- NapCatQQ 许可证：https://github.com/NapNeko/NapCatQQ/blob/main/LICENSE
- NapCat 官方安装器：https://github.com/NapNeko/NapCat-Installer

历史 GitCode 私有运行时仓库结构（不再用于后续客户交付）：

```text
MonNapCatRuntime
└── napcat/
    └── linux-x64/
        └── v4.18.7/
            ├── manifest.json
            ├── checksums.sha256
            ├── NapCat-Linux-x64-offline.tar.gz.part001
            ├── NapCat-Linux-x64-offline.tar.gz.part002
            └── restore-napcat-offline.sh
```

历史分发清单曾指向上述私有仓库。当前 DLC 的 `BUILD-INFO.json` 与 `dlc-manifest.json` 直接记录所含 NapCat 的上游版本、来源和校验信息。

Linux 源码与历史维护命令（含旧下载入口）：

```bash
# 检查本机是否已有 NapCat
Script/Runtime/linux/check_napcat.sh

# 旧安装器：从 GitCode 私有运行时仓库恢复，不用于后续客户交付
Script/Runtime/linux/install_napcat.sh

# 旧安装器：只拉取并恢复历史 GitCode 离线包，不执行安装
Script/Runtime/linux/install_napcat.sh --download-only

# 指定运行时版本，并透传 NapCat 官方安装器参数
Script/Runtime/linux/install_napcat.sh --version v4.18.7 -- --docker n --cli n --proxy 0

# 由 MonPM 启动 NapCat
Script/Process/linux/start_napcat_process.sh

# 查看/停止/重启 NapCat
Script/Process/linux/status_napcat_process.sh
Script/Process/linux/stop_napcat_process.sh
Script/Process/linux/restart_napcat_process.sh

# 给 ConfigAppReact 读取 WebUI token 与登录二维码
Script/Runtime/linux/napcat_info.sh --pretty
Script/Runtime/linux/napcat_info.sh --no-image

# 在线机器构建 NapCat Linux 离线包，输出到 Mon/.release/napcat-offline
Script/Runtime/linux/build_napcat_offline_bundle.sh --version latest --platform linux-x64

# 本地产物可用于独立 DLC 组装；后续不向 GitCode 发布运行时
```

Windows 源码开发时的官方运行时安装命令（便携 DLC 客户无需执行）：

```powershell
# 检查本机是否已有 NapCat
powershell -ExecutionPolicy Bypass -File Script/Runtime/win/check_napcat.ps1

# 只下载并校验官方 NapCat.Shell.zip，不执行安装
powershell -ExecutionPolicy Bypass -File Script/Runtime/win/install_napcat.ps1

# 显式确认许可证后安装到 DLC/BotLauncher/napcat/Napcat，并复用系统 QQ
powershell -ExecutionPolicy Bypass -File Script/Runtime/win/install_napcat.ps1 -RunInstaller -AcceptNapCatLicense
```

Windows 源码安装脚本从 NapCat 官方 GitHub Release 获取 `NapCat.Shell.zip`，验证 Release 提供的 SHA-256 后安装；本机必须已安装官方 QQ。维护端制作 Windows DLC 时执行同样的上游完整性校验，并把完整运行时放入 DLC。

商用授权适用于独立 DLC 交付，不改变上游许可证，也不将 NapCat 写入源码仓库或恢复 GitCode 客户发布。重新交付使用干净原始归档，不能把已登录后的账号状态、Token 或配置文件打包给其他客户。

`napcat_info` 脚本会输出 JSON，字段包含：

- `status` / `monpmStatus` / `launchKind`
- `webui.url` / `webui.token` / `webui.configPath`
- `qrcode.path` / `qrcode.dataUrl` / `qrcode.modifiedAt`

其中 `webui.token` 和 `qrcode.dataUrl` 属于敏感信息，只应在本机管理界面展示，不要写入远程日志。

NapCat MonPM 前台运行器读取 `.monconfig` 的 `[napcat_process]`：

- `MODE=auto`：自动探测 Shell、AppImage、Docker 或自定义命令。
- `HOME=napcat`：NapCat 的本机部署根目录。
- `INSTALL_BASE_DIR=napcat/Napcat`：官方 Shell 安装器生成的主安装目录。
- `COMMAND=`：当 `MODE=custom` 时由 MonPM 直接执行。

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

### NapCat 扩展能力

已加入受限 QQ 操作目录、持久事件收件箱和智能体工具，覆盖语音转写、消息转发/历史、表情包管理、好友与入群申请、群高级管理/群文件、资料修改、受限名片/小程序卡片、空间发布/删除、群相册/待办及在线文件/文件夹/闪传。群聊智能体、事件自动响应和角色资料同步由所有者或个人超级管理员按目标显式开启。

超级管理员私聊使用 `/QQ能力`、`/QQ能力 操作名`、`/QQ事件 request`、`/QQ操作 操作名 JSON参数`、`/QQ自动化`。私聊智能体操作沿用已有审批机制。需要同步更新 BotCore、MonCore 和 AgentServer，并应用新增数据库迁移；接口按 NapCat v4.18.28 核对，旧运行时可能不支持部分操作。

具体参数、规则示例、文件限制和已知边界见 [BotCore 接入说明](BotCore/README.md#napcat-扩展能力)。事件断线补发并按持久化回执去重；修改操作结果不明时不会自动重试。流式传输和上游尚无实际结果的频道/在线客户端接口明确标记不可用。

### QQ 空间动态（说说）

BotCore 与 MonCore 均更新后，可通过管理员私聊命令或后端接口发布说说。
要求 **NapCat v4.18.14 或更新版本**；文档中的旧 `v4.18.7` 离线运行时不支持此功能。
使用 NapCat 官方 [`send_qzone_msg`](https://github.com/NapNeko/NapCatQQ/blob/v4.18.14/packages/napcat-onebot/action/extends/SendQzoneMsg.ts)，无需额外配置 QQ 空间 Cookie。

```text
/说说 今天的开发进展已完成。
/说说 --公开 今天的开发进展已完成。
/说说 --仅自己 这是一条个人记录。
```

- 默认好友可见，也可显式使用 `--好友`；别名为 `/发动态`、`/发说说`。
- 仅在私聊中接受命令。发布权限由 MonCore 中当前 Bot 的个人超级管理员规则决定，显式拉黑优先。
- 命令目前只接受文字。后端接口另外支持 HTTP(S) 图片 URL；本项目限制正文 1 至 2000 字、图片最多 9 张。
- 必须收到说说 ID 才显示发布成功。超时、连接异常或回执不完整会提示结果未确认，请先查看 QQ 空间，勿立即重复发布。
- 发布不自动重试；当前 BotCore API 实例会缓存最近 256 个请求的结果，避免同一请求重复执行。这不保证跨重启去重。

后端接口：`POST /api/devices/qq_bot/<数据库ID>/qzone/publish/`。使用 MonCore 现有登录认证，仅机器人所有者或全局管理员可调用；路径中的 ID 不是 QQ 号码。

```json
{
  "content": "今天的开发进展已完成。",
  "images": ["https://example.com/photo.jpg"],
  "ugc_right": 4
}
```

`ugc_right` 支持 `1`（公开）、`4`（好友，默认）、`64`（仅自己）。`images` 可省略，不接受本地文件路径或内嵌图片数据。接口返回 `published`、`failed` 或 `unknown`；HTTP 202 表示结果未确认，不表示发布成功。多进程部署时，该请求须路由到持有 BotCore WebSocket 的进程；本接口不会广播到多个连接执行发布。

### 消息处理

- **命令处理**：支持 `/帮助`、`/角色`、`/语音`、`/好感`、`/好感排行` 等命令
- **关键词触发**：@机器人、提到机器人名字或后端配置的关键词
- **白名单过滤**：私聊按联系人授权；群聊按群号或发言人 QQ 任一授权放行
- **智能回复**：调用 MonCore 后端生成 AI 回复

### 语音功能

- **TTS 支持**：将文本回复转换为语音
- **自动降级**：语音生成失败时自动回退到文本
- **语音开关**：可通过 `/语音 开启/关闭` 命令控制，管理员和超级管理员可在群聊或私聊中修改，权限取自 Core
- **历史命令**：`/好感`、`/好感排行` 保留停用提示，QQBot 不再维护好感度

### 后端通信

- **UDP 服务发现**：自动发现 MonCore 服务器
- **WebSocket 连接**：建立专用通信通道
- **实时同步**：接收后端推送的白名单和关键词更新
- **自动重连**：连接断开时自动重连

## 统一命令机制

Core 与 BotCore 必须同步更新。所有 QQ 命令由 Core 的 `command_registry.py` 定义，经同一个 `qqCommand` 协议 1 完成鉴权、参数校验和执行；BotCore 只提取消息前缀及参数，发送结果，并落实 Core 授权的语音开关。命令支持 `/`、`!`、`！`，群聊可先 @机器人；用 `/帮助` 查看当前 Core 的完整命令目录。

权限以 Web 中当前 Bot 的 QQ 授权为准。个人超级管理员包含管理员能力，修改 `/语音 开启`、`/语音 关闭` 可在群聊或私聊执行；群管理员规则不会把群成员提升为机器人管理员，显式个人或群拉黑优先。状态、模式、权限、审批、说说和 QQ 管理命令仅供个人超级管理员在私聊使用。

未知命令、参数错误和权限拒绝都直接返回命令结果，不再进入 AI 聊天。未连接时提示未执行；发送中断或回执超时提示结果未确认，不自动重试。旧独立命令通道停止执行，版本不匹配时提示同步更新。

## 配置说明

### 机器人配置

位置：`MonQQBotCore/MonBot/src/plugins/BotCore/config/config.json`

```json
{
  "bot_name": "机器人名字",
  "bot_nicknames": ["昵称列表"],
  "bot_description": "机器人描述",
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

1. 在 `Core/Application/Domain/BOT/Core/command_registry.py` 登记命令名称、别名、用法、权限和会话范围。
2. 在同目录 `command_service.py` 实现参数处理和执行，返回统一结果；帮助自动引用目录。
3. 添加 Core 权限和执行测试；BotCore 使用现有 `qqCommand` 通道，不再注册独立 matcher 或本地命令名单。

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

遵循根工作区 [AGENTS.md](../../AGENTS.md)：在默认 `master` 分支完成修改和必要验证，通过根统一推送脚本提交、推送 GitHub，并更新父仓库 submodule 指针。普通推送不自动构建或交付 DLC。

## 许可证

本项目沿用 README 中的 MIT 许可声明；当前源码目录未附独立 `LICENSE` 文件。NapCat 和其他第三方组件的许可证及商用授权分别记录在交付包的 `THIRD-PARTY-NOTICES.md` 和 `licenses/`。

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
