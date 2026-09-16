# HyperOS Thermal Refresh Guard

[中文](README.md) | [English](README_EN.md)

一个尽量窄范围的 Magisk 模块：**只移除 QTI display-fps thermal ceiling，不强制系统常驻 120 Hz，也不关闭其它温控。**

## 设计目标

系统原有刷新率调度保持不变，例如：

- 静止界面：仍可由 HyperOS 自动降到 60 Hz 或更低；
- 触摸、滑动：仍可正常升到 120 Hz；
- 视频、相机、应用特定策略：继续由原系统决定；
- CPU/GPU、电池、充电、内核 thermal zone、PMIC 保护：完全不修改；
- 唯一去除的是 SurfaceFlinger/QTI composer 使用的 **display-fps thermal ceiling**。

## 为什么不是“强制 120 Hz”

对 `pudding / OS3.0.319.0.WPCCNXM` 的实际链路核查后，最终修改点位于 QTI composer 的 thermal FPS 映射，而不是 PowerKeeper：

```text
Thermal AIDL cooling-device callback (display-fps)
  -> SurfaceFlinger / libcomposerextn.qti.so
  -> /vendor/etc/display/thermallevel_to_fps.xml
  -> thermal maximum FPS
```

系统原始 XML 在较高 thermal level 会把上限降到 90/60 Hz，另一组 device-version 映射还包含 40/30 Hz。本模块安装时先严格校验原始 XML 的 SHA256，然后从**设备自己的 XML**生成 systemless 副本，仅把 13 个 `ThermalLevelMap` 的 `fps` 属性统一改成 `120`。

这只是把 thermal ceiling 变为 120 Hz；Touch Boost、Smart DFPS、静止降刷、视频/相机/应用策略仍由原来的 SurfaceFlinger/HyperOS 调度，因此屏幕仍可在非 thermal 原因下降到 60 Hz 或更低。

此前调查过 PowerKeeper `cookie=253` 路径，但当前 ROM 的 AIDL DisplayFeature HAL 最终 FPS handler 是 no-op，真机 transaction A/B 也没有改变 120 Hz，因此正式版**不包含 PowerKeeper OAT patch，也不包含 DisplayFeature ELF patch**。

## 续航与后台行为

正式版 **没有 `service.sh`、`post-fs-data.sh` 或任何开机脚本**，因此没有常驻 shell、没有 `logcat`、没有轮询、没有 wakelock。安装阶段只生成 `vendor/etc/display/thermallevel_to_fps.xml`，之后由 Magisk 的 systemless mount 机制处理。

这与早期 v0.1.0 原型不同；v0.1.0 使用 filtered `logcat` 捕获 thermal display 请求，仅用于验证思路，不作为正式架构保留。

## 当前兼容性

v1.0.0 使用 fail-closed 策略，只允许以下已验证组合：

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
2. 安装器会从本机 vendor XML 生成 120 Hz thermal ceiling 的 systemless 副本，不修改 `/vendor` 原文件；
3. 重启手机；
4. 重启后 `/vendor/etc/display/thermallevel_to_fps.xml` 应由 Magisk overlay 显示为 13 个 `fps="120"` 条目。

## 卸载与恢复

在 Magisk 中禁用或卸载模块后**重启手机**。原始 `/vendor/etc/display/thermallevel_to_fps.xml` 从未被修改；Magisk overlay 消失后自动恢复厂商映射。

## 与 HyperCeiler 的关系

建议关闭 HyperCeiler 中会重复修改同一领域的全局温控/刷新率 Hook，例如 `DisableThermal`、`ThermalBrightness`、`LockMaxFps`。本模块的目标正是避免“为了刷新率而关闭整套 Android 上层温控”。

## 风险说明

高温时允许显示系统继续使用较高刷新率会增加显示子系统功耗和发热。本模块只中和 display-fps cooling 映射，不会移除 CPU/GPU 降频、电池和充电保护、其它 cooling device、内核 thermal zone 或 PMIC 最终保护，但这仍属于修改厂商热管理策略，请自行评估使用环境。

## License

MIT

