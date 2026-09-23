# HyperOS Thermal Refresh Guard

[中文](README.md) | [English](README_EN.md)

A narrowly scoped Magisk module targeting both the QTI display-fps thermal ceiling and PowerKeeper's independent framework thermal FPS setting, without forcing constant 120 Hz or disabling the entire thermal stack.

**v1.2.0 finding:** On September 23 the v1.1.0 XML overlay was confirmed active in SurfaceFlinger (all 13 FPS targets set to 120), but the phone still temporarily reported `Settings.System.thermal_limit_refresh_rate=60` and the display director's history contained an independent 60-Hz `PRIORITY_THERMAL_LIMIT_REFRESH_RATE` vote. PowerKeeper log messages confirmed it modifies the setting. v1.2.0 adds an early-boot gate for that setting and one-shot cleanup of the prior value. A cold-boot follow-up and natural-condition A/B are still required; an installed ZIP alone does not prove that all high-temperature 60-FPS behavior is resolved.

**Historical v1.1.0 correction:** The v1.0.0 `$MODPATH/vendor/...` file did not appear at the actual `/vendor` path after cold boot. The v1.1.0 private-file bind mount was confirmed in SurfaceFlinger's own view on September 23; the remaining 60-FPS thermal behavior was traced to an independent framework setting rather than an absent XML mount. Full Scene profile compatibility is still unverified.

## Goal

Keep HyperOS' normal dynamic refresh scheduler intact:

- static UI may still drop to 60 Hz or lower;
- touch and scrolling may still boost to 120 Hz;
- video, camera and per-app policies remain stock-controlled;
- CPU/GPU, battery, charging, kernel thermal zones and PMIC protection are untouched;
- the targeted thermal refresh inputs are the SurfaceFlinger/QTI display-fps ceiling and PowerKeeper's framework thermal refresh-rate setting.

## Implementation

One of two observed thermal-refresh paths on `pudding / OS3.0.319.0.WPCCNXM` is:

```text
Thermal AIDL cooling-device callback (display-fps)
  -> SurfaceFlinger / libcomposerextn.qti.so
  -> /vendor/etc/display/thermallevel_to_fps.xml
  -> thermal maximum FPS
```

The stock map reduces the thermal ceiling to 90/60 Hz at higher levels; a second device-version map also contains 40/30 Hz. During installation the module fail-closes on the exact stock XML SHA256, copies the device's own XML into the Magisk module tree, and changes only the 13 `ThermalLevelMap` `fps` attributes to `120`.

That raises only the thermal ceiling. Touch boost, Smart DFPS, static-content downshift, video/camera behavior and per-app policies remain under the stock SurfaceFlinger/HyperOS scheduler, so non-thermal logic may still select 60 Hz or lower.

Separately, PowerKeeper uses `ro.vendor.fps.switch.thermal` to gate writes to `Settings.System.thermal_limit_refresh_rate`. The early `post-fs-data.sh` sets only that property to `false` before PowerKeeper initializes; `service.sh` runs once when SettingsProvider is ready and resets a leftover thermal limit to zero. Neither script changes `peak_refresh_rate`, `min_refresh_rate`, or Scene's `/data/vendor/thermal/config` profiles. The property override is runtime-only and returns to the stock boot value after disabling/uninstalling the module and rebooting.

The PowerKeeper `cookie=253` path was also investigated. On this ROM its AIDL DisplayFeature FPS handler resolves to a no-op, and direct transaction A/B did not change the 120 Hz display state. The release therefore contains **no PowerKeeper OAT patch and no DisplayFeature ELF patch**.

## Battery / background overhead

v1.2.0 runs **two short-lived one-shot scripts** (`post-fs-data.sh` and `service.sh`) during boot, then exits. There is no resident shell, `logcat` listener, polling loop or wakelock. The source file is under the module's `private/` directory, not `system/` or `vendor/`.

The earlier v0.1.0 proof-of-concept used a filtered `logcat` listener. That architecture is intentionally not used in the formal release.

## Compatibility

v1.2.0 is fail-closed and currently supports only the tested ROM baseline. The v1.1.0 cold-boot XML mount was confirmed; **the v1.2.0 framework-setting change still requires a reboot test**:

| Item | Value |
| --- | --- |
| Device | Xiaomi `pudding` / 25113PN0EC |
| ROM | HyperOS `OS3.0.319.0.WPCCNXM` |
| Android | 16 / API 36 |
| Stock thermal FPS XML SHA256 | `49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e` |
| ThermalLevelMap entries | 13 |

The installer aborts on any mismatch. Do not force-install this build after an OTA.

## Install

1. Install the ZIP from GitHub Releases in Magisk.
2. The installer generates a private 120 Hz thermal-ceiling XML from the device's own vendor file.
3. Reboot.
4. After reboot, confirm `boot-status.txt` reports `MOUNTED`, `framework-status.txt` reports `READY` or `CLEARED`, `getprop ro.vendor.fps.switch.thermal` is `false`, `settings get system thermal_limit_refresh_rate` is `0`, and SurfaceFlinger's actual view of the vendor XML contains 13 entries of `fps="120"`. These conditions do not rule out independent app or hardware FPS limits.

## Scene compatibility

Scene switches its thermal profiles under `/data/vendor/thermal/config`. This module does not modify that directory and deliberately has no `system/*thermal*` file which would trigger Scene's current "another module modifies thermal files" check. However, it overrides thermal display FPS limits, so any Scene profile's display-FPS mitigation cannot remain intact at the same time. Other Scene profile changes require on-device A/B; full Scene compatibility is not established.

## Uninstall / restore

Disable or uninstall the module in Magisk and **reboot**. The stock vendor XML is never modified; removing the Magisk overlay restores the OEM map automatically.

## HyperCeiler

It is recommended to disable overlapping global thermal/refresh hooks such as `DisableThermal`, `ThermalBrightness` and `LockMaxFps`. This module deliberately avoids disabling the full Android thermal framework just to preserve refresh rate.

## Safety note

Allowing higher refresh rates at elevated temperatures can increase display power and heat. This module does not intentionally change CPU/GPU throttling, battery/charging protection, other cooling devices, kernel thermal zones or PMIC safeguards. We cannot guarantee that no other vendor component shares the overridden PowerKeeper property or that all thermal subsystems are independent. Avoid deliberately heating the device for validation; disable the module and reboot if the device overheats.

## License

MIT

