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

- **命令处理**：支持 `/帮助`、`/角色`、`/语音` 等命令
- **关键词触发**：@机器人、提到机器人名字或后端配置的关键词
- **白名单过滤**：只处理后端配置的联系人和群聊消息
- **智能回复**：调用 MonCore 后端生成 AI 回复

### 语音功能

- **TTS 支持**：将文本回复转换为语音
- **自动降级**：语音生成失败时自动回退到文本
- **语音开关**：可通过 `/语音 开启/关闭` 命令控制

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