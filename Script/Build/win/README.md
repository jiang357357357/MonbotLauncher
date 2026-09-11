# Windows QQBot 本地打包

在 Windows x64、Python 3.12 环境执行：

```powershell
powershell -ExecutionPolicy Bypass -File Script/Build/win/build.ps1
```

产物为 `dist/eden-bot/`，必须复制整个目录，不能只复制 EXE。本地打包不推进版本、不提交 Git、不发布 Release。NapCat 和官方 QQ 不包含在产物中。

运行前编辑产物根目录 `.monconfig`：OneBot 地址默认 `ws://127.0.0.1:3001`，MonCore 默认 `127.0.0.1:40011`。当前客户端 MonCore 登录使用 `ws://`，不宣称已经支持公网 HTTPS 网关。配置 `[permissions]` 中明确允许的私聊 QQ 或群号，后端联系人/群授权仍需同时满足。

在产物 `Config/bot.env` 中自行配置凭据（不要提交 Git或分发）：

```dotenv
MON_ONEBOT_ACCESS_TOKEN=你的NapCat令牌
MON_QQBOT_PAIRING_TOKEN=后端签发的一次性绑定令牌
```

`Config/bot.json` 保存运行开关，`Data/qqbot` 保存设备凭据，`Data/Logs` 保存日志。更新时保留这些目录及 `.monconfig`，不要将用户运行态带入安装包。

```powershell
.\eden-bot.exe --self-test
.\eden-bot.exe
```

自检仅验证框架、适配器和插件加载，不连接 QQ，不代表真实收发成功。真实验收需要启动 NapCat、登录指定 QQ、完成 MonCore 配对和授权，再由指定测试联系人发消息并核对机器人回复。不得使用随机好友或群做测试。
