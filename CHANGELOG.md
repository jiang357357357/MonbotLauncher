# 更新日志

本文件记录 MonbotLauncher 的显著变化。

## [Unreleased]

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
