# 更新日志

本文件记录 MonbotLauncher 的显著变化。

## [Unreleased]


## [1.11.5] - 2026-10-08

- 将运行时目录忽略规则限制在仓库根目录，确保 `Script/Runtime/win/napcat_logout.ps1` 随确定提交进入完整 DLC 构建。
- 源码迁至 DLC/BotLauncher，统一源码和便携 MonPM 上下文、QQBot 冻结运行时及 NapCat 管理；保留用户绑定与授权运行时。

### Fixed

- 更新 QQ 命令开发与使用文档：所有命令由 Core 定义并通过统一通道执行，超级管理员继承管理员权限，Core 与 BotCore 需同步更新。
- 源码移至 `DLC/BotLauncher` 后，Windows/Linux 启动、NapCat 管理、OneBot 凭据维护和离线构建仍定位工作区根目录；保留旧源码与 QQBot 便携目录兼容。
- Windows NapCat 状态和进程管理支持与 `EDEN_win` 同级的 QQBot DLC，使用主包已有的 MonPM 配置。
- 补齐 Windows 退出登录脚本：WebUI 鉴权后清空快速登录账号，再通过 MonPM 重启 NapCat；接口或重启失败时报告失败。

## [1.11.1] - 2026-09-28

### Changed

- 同步 `1.11.1` 元数据，完善 Windows 便携 Bot 打包和 NapCat 启动路径。

## [1.10.1] - 2026-09-01

### Changed

- 启动器配置、Python 包和锁文件同步到 Eden `1.10.1`；NapCat 私有运行时仍使用独立版本。

## [1.10.0] - 2026-09-01

### Changed

- 启动器配置、Python 包和锁文件同步到 Eden `1.10.0`；NapCat 私有运行时继续使用独立版本。

## [1.9.2] - 2026-09-01

### Changed

- 同步 Eden `1.9.2` 产品版本；NapCat 私有运行时仍保持独立版本与授权安装流程。

## [1.9.1] - 2026-08-29

### Changed

- 同步 Eden `1.9.1` 产品版本，现有 OneBot、NapCat 和私有运行时版本保持独立。

## [1.9.0] - 2026-08-27

### Changed

- 脚本协议文档中的 MonCore 与 MonOs 路径切换为根目录 `Core/` 与 `BaseOs/`。
- OneBot 修复流程改为写入工作区私有 `Config/ENV/bot.env`，不再把访问令牌写回源码配置。
- NapCat 生命周期脚本兼容 MonPM 1.8 的 `lifecycle_state` 状态字段。

## [1.8.0] - 2026-08-05

### Changed

- 同步 BotLauncher 产品元数据并建立 `1.8.0` 完整发行源码基线。

## [1.7.5] - 2026-08-04

### Changed

- 启动器配置、Python 包和锁文件统一到 Mon `1.7.5` 产品版本基线。
