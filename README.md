# HyperOS Thermal Refresh Guard

**简体中文 | [English](README_EN.md)**

**当前版本：v1.5.0** · [下载 Release](https://github.com/E3N-glotm/HyperOS-Thermal-Refresh-Guard/releases) · [技术说明](docs/TECHNICAL.md)

## 跨机型兼容

旧版 v1.4.0 只接受 Xiaomi `pudding`，小米 15 Pro (`haotian`) 会在接口探测前直接报 `battery/display hardware not validated`。v1.5.0 **移除机型和 ROM 白名单**，根据设备真实接口选择工作模式，无接口也能安装并报告原因。

| 检测结果 | 实际执行及显示 |
|---|---|
| 发现有效 `ThermalLevelMap` XML | 从原机 XML 生成单独覆盖，启动时尝试挂载，仅修改其 `fps` 属性 |
| 同时检测到 PowerKeeper FPS 属性 | 除 XML 外，一次性处理 Framework 的 `thermal_limit_refresh_rate` 限制 |
| 只有 PowerKeeper 属性 | **部分支持**，只处理经过识别的 Framework 路径 |
| 都没有 | **安装成功但不生效**，提供操作页诊断，保留原厂行为 |
| OTA 更换厂商 XML | 下次启动重新检查格式并生成新覆盖；格式未知时跳过，而不是套用过期内容 |

候选 XML 路径：
`/vendor/etc/display/thermallevel_to_fps.xml`、
`/odm/etc/display/thermallevel_to_fps.xml`、
`/product/etc/display/thermallevel_to_fps.xml`。只处理实际存在、结构通过校验、SELinux 标签可用的文件。

热控目标 FPS 最多取 `120`，若原厂热控表最大值不足 120，则不超过原厂最大值；**不会强制屏幕持续 120Hz**。不修改用户动态刷新率、CPU/GPU 温控、电池与充电保护、Scene 配置或内核热区。

## 兼容性证据

| 机型 / 系列 | 证据 | 验证程度 |
|---|---|---|
| Xiaomi `pudding` | 先前版本实机验证了 XML/PowerKeeper 路径 | 旧版实机基线；v1.5.0 需冷启动复核 |
| Xiaomi 15 Pro `haotian` | 旧版用户截图证实是机型检测拦截，新安装器使用模拟 `haotian` 检测通过 | **尚未取得 15 Pro 原机 XML 和重启效果** |
| 小米 SM8550 系列、Redmi Note 13 Pro 5G `garnet`、POCO F5 系列 `marble` | 开源设备树显示厂商 XML 路径 | 路径证据，不代表完成真机验收 |
| 其他 Xiaomi / Redmi / POCO / Pad | 安装时动态检测 | 未验证设备将显示接口状态 |

更多参考：[SM8550 设备树](https://github.com/LineageOS/android_device_xiaomi_sm8550-common)、[garnet 厂商文件](https://github.com/xiaomi-sm7435/android_vendor_xiaomi_garnet)、[marble 厂商文件](https://github.com/adithya2306/proprietary_vendor_xiaomi_marble)。

## 安装、诊断和回退

在 Magisk / KernelSU / 兼容的 SterSU 中安装 ZIP，重启后查看模块描述或点击**操作**。也可以读取：

```sh
su -c 'cat /data/adb/modules/hyperos_thermal_refresh_guard/compatibility.txt'
su -c 'cat /data/adb/modules/hyperos_thermal_refresh_guard/boot-status.txt'
su -c 'cat /data/adb/modules/hyperos_thermal_refresh_guard/framework-status.txt'
```

安装成功不代表显示温控已经修改。正常 LTPO 空闲低刷、特定应用的刷新率限制、游戏内部 FPS 和热控刷新率是不同机制。

如果显示异常，禁用或卸载该模块并**重启**，原厂 XML 的 bind mount 会随重启恢复。模块没有常驻轮询或后台进程。改变热限帧上限可能增加高温场景功耗和机身温度。

建议 Issues 提供设备代号、ROM 版本及上述三个状态文件内容（注意隐藏私密信息）。**不要提供或执行关闭整体 CPU/GPU、电池/充电温控的脚本。**
