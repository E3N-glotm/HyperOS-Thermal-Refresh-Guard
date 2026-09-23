# HyperOS Thermal Refresh Guard

[中文](README.md) | [English](README_EN.md)

一个尽量窄范围的 Magisk 模块：**同时处理 QTI display-fps 映射与 PowerKeeper 写入的 framework 热限帧设置，不强制系统常驻 120 Hz，也不关闭整套温控。**

**v1.2.0 的修复依据：** 2026-09-23 真机确认 v1.1.0 已在 SurfaceFlinger 中成功挂载 13 项 `fps=120`，但系统 `thermal_limit_refresh_rate` 仍曾为 `60`，显示管理器历史记录出现独立的 `PRIORITY_THERMAL_LIMIT_REFRESH_RATE` 60 Hz 投票。PowerKeeper 日志明确出现对该设置的写入。v1.2.0 新增一次性开机 PowerKeeper 设置写入门控与遗留设置清理。**它仍需重启后的真机复测，不应因为 ZIP 安装成功就声称高温时一定保持 120 FPS。**

**v1.1.0 历史更正：** v1.0.0 安装器生成的 `$MODPATH/vendor/...` 文件在实际冷启动后未正确挂载。v1.1.0 改为 Magisk `post-fs-data.sh` 一次性 bind-mount 私有 XML，并在 2026-09-23 的冷启动状态中确认 SurfaceFlinger 确实看到该映射；后续高温 60 FPS 的问题来自 XML 之外的独立设置，见上文 v1.2.0 修复依据。

## 设计目标

系统原有刷新率调度保持不变，例如：

- 静止界面：仍可由 HyperOS 自动降到 60 Hz 或更低；
- 触摸、滑动：仍可正常升到 120 Hz；
- 视频、相机、应用特定策略：继续由原系统决定；
- CPU/GPU、电池、充电、内核 thermal zone、PMIC 保护：完全不修改；
- 处理的是 SurfaceFlinger/QTI composer 的 **display-fps thermal ceiling** 与 PowerKeeper 的 **framework 热限帧设置**。

## 为什么不是“强制 120 Hz”

对 `pudding / OS3.0.319.0.WPCCNXM` 的实际链路核查后，确认 QTI composer 和 PowerKeeper 的 framework 设置均可能对显示热限帧产生影响：

```text
Thermal AIDL cooling-device callback (display-fps)
  -> SurfaceFlinger / libcomposerextn.qti.so
  -> /vendor/etc/display/thermallevel_to_fps.xml
  -> thermal maximum FPS
```

系统原始 XML 在较高 thermal level 会把上限降到 90/60 Hz，另一组 device-version 映射还包含 40/30 Hz。本模块安装时先严格校验原始 XML 的 SHA256，然后从**设备自己的 XML**生成 systemless 副本，仅把 13 个 `ThermalLevelMap` 的 `fps` 属性统一改成 `120`。

这只是把 thermal ceiling 变为 120 Hz；Touch Boost、Smart DFPS、静止降刷、视频/相机/应用策略仍由原来的 SurfaceFlinger/HyperOS 调度，因此屏幕仍可在非 thermal 原因下降到 60 Hz 或更低。

PowerKeeper 另有 `ro.vendor.fps.switch.thermal` 所门控的 `Settings.System.thermal_limit_refresh_rate` 写入路径。v1.2.0 在 `post-fs-data.sh` 阶段仅将这一个属性暂时设为 `false`，以便 PowerKeeper 初始化时读到；随后 `service.sh` 在 SettingsProvider 就绪后清除遗留的 framework 热限帧设置。两个脚本均执行一次即退出。卸载模块并重启后，`ro.vendor.fps.switch.thermal` 从原厂启动属性恢复；模块不修改应用场景或用户首选刷新率设置。

此前调查过 PowerKeeper `cookie=253` 路径，但当前 ROM 的 AIDL DisplayFeature HAL 最终 FPS handler 是 no-op，真机 transaction A/B 也没有改变 120 Hz，因此正式版**不包含 PowerKeeper OAT patch，也不包含 DisplayFeature ELF patch**。

## 续航与后台行为

v1.2.0 的 `post-fs-data.sh` 和 `service.sh` 都只在开机阶段各执行一次，然后退出；没有常驻 shell、`logcat`、轮询或 wakelock。安装阶段生成 `private/thermallevel_to_fps.xml`，而不是放置在可能被 Scene 判定冲突的模块 `system/` 目录。

这与早期 v0.1.0 原型不同；v0.1.0 使用 filtered `logcat` 捕获 thermal display 请求，仅用于验证思路，不作为正式架构保留。

## 当前兼容性

v1.2.0 延续 fail-closed 策略，只允许以下已验证的设备、ROM 与原始配置组合。v1.1.0 冷启动挂载已确认成功；**v1.2.0 新增的 framework 修复仍需重启后实测。**

| 项目 | 值 |
| --- | --- |
| 设备 | Xiaomi `pudding` / 25113PN0EC |
| 系统 | HyperOS `OS3.0.319.0.WPCCNXM` |
| Android | 16 / API 36 |
| 原始 thermal FPS XML SHA256 | `49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e` |
| ThermalLevelMap 条目 | 13 |

任何一项不匹配，安装器都会直接拒绝安装；系统更新后不要强刷旧版本。

## 安装

1. 使用 Magisk 安装 Release 中的 ZIP；
2. 安装器会从本机 vendor XML 生成 120 Hz thermal ceiling 的私有副本，不修改 `/vendor` 原文件；
3. 重启手机；
4. 重启后检查模块中的 `boot-status.txt` 是否为 `MOUNTED`、`framework-status.txt` 是否为 `READY` 或 `CLEARED`，确认 `getprop ro.vendor.fps.switch.thermal` 为 `false`、`settings get system thermal_limit_refresh_rate` 为 `0`，并确认 SurfaceFlinger 所见 XML 的 13 项映射均为 `fps="120"`。以上验证仍不代表其他应用策略或硬件温控不会请求 60 FPS。

### Scene 兼容性边界

Scene 的本地温控配置位于 `/data/vendor/thermal/config`。v1.2.0 不修改该目录，也不在模块 `system/` 目录放置名称含 `thermal` 的文件。**Guard 会覆盖温度触发的显示 FPS 上限，因此 Scene 配置中涉及同一显示上限的效果不会同时保留**；Scene 对 CPU/GPU 等其他温控策略的完整兼容性仍需真机 A/B 验证。

## 卸载与恢复

在 Magisk 中禁用或卸载模块后**重启手机**。原始 `/vendor/etc/display/thermallevel_to_fps.xml` 从未被修改；Magisk overlay 消失后自动恢复厂商映射。

## 与 HyperCeiler 的关系

建议关闭 HyperCeiler 中会重复修改同一领域的全局温控/刷新率 Hook，例如 `DisableThermal`、`ThermalBrightness`、`LockMaxFps`。本模块的目标正是避免“为了刷新率而关闭整套 Android 上层温控”。

## 风险说明

高温时允许显示系统继续使用较高刷新率会增加显示子系统功耗和发热。本模块不主动修改 CPU/GPU 降频、电池/充电保护、其它 cooling device、内核 thermal zone 或 PMIC 最终保护；但无法保证厂商其他代码不共享被修改的 PowerKeeper 属性或所有温控路径都相互独立。设备温度较高时请停止高负载测试，不要通过主动升温验收模块。

## License

MIT

