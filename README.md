# Thermal Refresh Guard · HyperOS 热控刷新率优化

**语言：简体中文（当前） | [English](README_EN.md)**

针对特定 Xiaomi `pudding` 显示硬件的 Magisk 模块，用于处理厂商 display-fps 映射及 PowerKeeper 额外写入的 framework 热限帧设置。

**当前版本：v1.4.0** · [下载 Release](https://github.com/E3N-glotm/HyperOS-Thermal-Refresh-Guard/releases) · [技术说明](docs/TECHNICAL.md)

> 本模块**不是锁定全局 120 FPS**，也不关闭 CPU/GPU/电池整体温控。屏幕静止时 60 FPS、应用主动限帧或其他原因造成的掉帧，不能直接据此判断模块未生效。

## 功能与原理

- 安装时检测原厂 `/vendor/etc/display/thermallevel_to_fps.xml` 的 `ThermalLevelMap` 元素和 `fps` 属性，并生成只改动对应热控 FPS 字段的私有覆盖文件。
- 从 PowerKeeper / SettingsProvider 路径处理额外的 `thermal_limit_refresh_rate` 设置，尽量避免它独立强制 60 Hz。
- 保留 SurfaceFlinger 的正常显示模式选择及 Scene、HyperCeiler 的其他刷新率策略；不锁 CPU/GPU 频率。
- v1.4.0 不再要求固定 ROM/SDK 字符串和特定 OEM 文件哈希，转而验证 **显示设备、接口、XML 结构和挂载能力**。
- 安装时保存原厂源文件 SHA-256；系统升级修改了 XML 内容时，开机**停止继续套用旧覆盖文件**，需要重新安装进行探测。

## 适用范围

已在 `pudding` 和相应 HyperOS 显示实现上验证。其他设备、不同显示 HAL 和极端高温场景未验证。模块保留原厂 CPU/GPU/电池热保护机制；改变显示热限帧可能提高温度和耗电。

## 安装、检查、回退

1. 下载 [v1.4.0](https://github.com/E3N-glotm/HyperOS-Thermal-Refresh-Guard/releases/tag/v1.4.0) 或更新版本 ZIP，在 Magisk 安装并重启。
2. 查看模块的启动状态文件及原厂热控 XML 挂载、PowerKeeper 属性和系统设置。
3. 需要回退时禁用或卸载并**重启**，让系统恢复自己的显示热控配置。

历史 v1.2/v1.3 的定版固件限制仅适用于**旧版本安装器**，不能用于解释当前 v1.4.0。历史冷启动验收文档保留在 [docs](docs/)，英文版保留详细时间线。
