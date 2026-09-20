# HyperOS Thermal Refresh Guard

[中文](README.md) | [English](README_EN.md)

A narrowly scoped Magisk module that **neutralizes only the QTI display-fps thermal ceiling**, without forcing the system to stay at 120 Hz and without disabling the rest of the thermal stack.

**v1.1.0 correction:** The v1.0.0 `$MODPATH/vendor/...` file did not appear at the actual `/vendor` path after a cold boot on the tested device. v1.1.0 generates the XML under `private/` and uses a single early `post-fs-data.sh` bind mount; the script verifies the stock map and then exits. A completed post-install reboot and Scene switching A/B are still required before claiming that the new version is fully validated on-device.

## Goal

Keep HyperOS' normal dynamic refresh scheduler intact:

- static UI may still drop to 60 Hz or lower;
- touch and scrolling may still boost to 120 Hz;
- video, camera and per-app policies remain stock-controlled;
- CPU/GPU, battery, charging, kernel thermal zones and PMIC protection are untouched;
- only the SurfaceFlinger/QTI composer display-fps thermal ceiling is neutralized.

## Implementation

The verified thermal-refresh path on `pudding / OS3.0.319.0.WPCCNXM` is:

```text
Thermal AIDL cooling-device callback (display-fps)
  -> SurfaceFlinger / libcomposerextn.qti.so
  -> /vendor/etc/display/thermallevel_to_fps.xml
  -> thermal maximum FPS
```

The stock map reduces the thermal ceiling to 90/60 Hz at higher levels; a second device-version map also contains 40/30 Hz. During installation the module fail-closes on the exact stock XML SHA256, copies the device's own XML into the Magisk module tree, and changes only the 13 `ThermalLevelMap` `fps` attributes to `120`.

That raises only the thermal ceiling. Touch boost, Smart DFPS, static-content downshift, video/camera behavior and per-app policies remain under the stock SurfaceFlinger/HyperOS scheduler, so non-thermal logic may still select 60 Hz or lower.

The PowerKeeper `cookie=253` path was also investigated. On this ROM its AIDL DisplayFeature FPS handler resolves to a no-op, and direct transaction A/B did not change the 120 Hz display state. The release therefore contains **no PowerKeeper OAT patch and no DisplayFeature ELF patch**.

## Battery / background overhead

v1.1.0 has **one short-lived `post-fs-data.sh` boot script** for its verified bind mount, which exits immediately. There is no `service.sh`, resident shell, `logcat` listener, polling loop or wakelock. The source file is under the module's `private/` directory, not `system/` or `vendor/`.

The earlier v0.1.0 proof-of-concept used a filtered `logcat` listener. That architecture is intentionally not used in the formal release.

## Compatibility

v1.1.0 is fail-closed and currently supports only the tested ROM baseline:

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
4. After reboot, confirm the module's `boot-status.txt` reports `MOUNTED` and that SurfaceFlinger's actual view of `/vendor/etc/display/thermallevel_to_fps.xml` contains 13 entries of `fps="120"`. Having only the private file on disk does **not** establish that the module is active.

## Scene compatibility

Scene switches its thermal profiles under `/data/vendor/thermal/config`. This module does not modify that directory and deliberately has no `system/*thermal*` file which would trigger Scene's current "another module modifies thermal files" check. It does, however, maintain a constant 120-Hz ceiling for the **display-fps** cooling map, so any Scene profile's request to lower that particular ceiling cannot be preserved at the same time. Other Scene profile changes must be verified on-device; full Scene compatibility is not yet established.

## Uninstall / restore

Disable or uninstall the module in Magisk and **reboot**. The stock vendor XML is never modified; removing the Magisk overlay restores the OEM map automatically.

## HyperCeiler

It is recommended to disable overlapping global thermal/refresh hooks such as `DisableThermal`, `ThermalBrightness` and `LockMaxFps`. This module deliberately avoids disabling the full Android thermal framework just to preserve refresh rate.

## Safety note

Allowing the display stack to keep a higher refresh ceiling at elevated temperatures can increase display power and heat. This module changes only the display-fps cooling map; CPU/GPU throttling, battery/charging protection, other cooling devices, kernel thermal zones and PMIC safeguards remain intact. It still changes an OEM thermal-management policy, so use it with appropriate caution.

## License

MIT

