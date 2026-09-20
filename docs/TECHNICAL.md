# Technical notes

## Verified target

- device: Xiaomi `pudding` / 25113PN0EC
- ROM: HyperOS `OS3.0.319.0.WPCCNXM`
- Android: 16 / API 36
- stock map: `/vendor/etc/display/thermallevel_to_fps.xml`
- stock map SHA256: `49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e`
- thermal map entries: 13

## Actual thermal refresh path

`libcomposerextn.qti.so`, loaded by SurfaceFlinger, contains the following
thermal-FPS functions and the literal vendor XML path:

```text
DisplayExtnImpl::LoadThermalToFpsFromFile
DisplayExtnImpl::GetFpsValueFromThermal
DisplayExtnImpl::SetDesiredFpsByThermalLevel
DisplayExtnImpl::SetFpsMitigationCallback
/vendor/etc/display/thermallevel_to_fps.xml
```

The Thermal HAL also exposes a `display-fps` cooling device. The relevant
runtime model is therefore:

```text
Thermal HAL cooling callback (display-fps)
  -> SurfaceFlinger / QTI composer extension
  -> thermallevel_to_fps.xml
  -> maximum FPS allowed by thermal mitigation
```

The stock XML contains two device-version maps. Version 1 maps levels 1..10
to `144, 144, 120, 120, 90, 90, 90, 60, 60, 60`; version 2 maps levels 1..3
to `60, 40, 30`.

The release installer verifies the exact stock XML hash and entry count, then
copies the device's own XML into the Magisk module tree while replacing only
`fps="<number>"` with `fps="120"`. No vendor partition file is written.

## Why this does not force constant 120 Hz

The XML is a thermal ceiling, not the complete refresh-rate scheduler. With a
120-Hz ceiling, normal HyperOS/SurfaceFlinger logic can still request lower
rates for static content, video, per-app policy, power policy, idle behavior or
other non-thermal reasons. The module does not change those votes or settings.

## PowerKeeper / DisplayFeature investigation

PowerKeeper contains this dedicated call path:

```text
ThermalManager.displayControl(fps)
  -> DisplayFrameSetting.setScreenEffect(fps, 253)
  -> DisplayFeatureManager.setScreenEffect(mode=24, value=fps, cookie=253)
```

That initially looked like the correct interception point. It is not the
effective limiter on the tested ROM.

The active HyperOS 3 path is the AIDL HAL process
`vendor.xiaomi.hardware.displayfeature_aidl-service`, which loads
`/odm/lib64/hw/displayfeature.default.so`. `setFeatureEnable` case 24 forwards
the FPS value and cookie through vtable slot `0x1b0`.

Runtime-relocated vtables for `DisplayEffect`, `DisplayEffectBase` and
`DisplayEffectPlatform` all resolve this slot to
`DisplayEffectBase::HandleFpsSwitch(int,int)`. On the supported build that
function is exactly:

```asm
bti c
mov w0, wzr
ret
```

A direct Binder A/B request using `mode=24`, `value=60`, `cookie=253` reached
the AIDL HAL and logged `FPS_SWITCH_STATE`, but the desired/current display
state remained 120 Hz. This is consistent with the no-op handler.

Consequently, the formal release does **not** patch PowerKeeper OAT and does
**not** patch DisplayFeature ELF code.

## Why a direct sysfs write is not a valid end-to-end test

Writing a different value to `/sys/class/thermal/cooling_device*/cur_state`
for the `display-fps` cooling device changes the sysfs state but does not by
itself reproduce the QTI refresh change. QTI registers a Thermal AIDL cooling
device callback; it does not simply poll `cur_state`. A real thermal callback,
or a SurfaceFlinger restart after installing the map followed by a genuine
thermal state transition, is needed for end-to-end mitigation testing.

## Runtime footprint

The v1.1.0 module has no `service.sh`, daemon, watcher, polling loop or
wakelock. `customize.sh` runs only during installation and generates:

```text
$MODPATH/private/thermallevel_to_fps.xml
$MODPATH/compatibility.txt
$MODPATH/post-fs-data.sh
```

The early `post-fs-data.sh` checks ROM, stock/vendor hash and the private map,
bind-mounts the private file onto the vendor XML before SurfaceFlinger starts,
writes a one-line `boot-status.txt` and exits. This avoids v1.0.0's inactive
`$MODPATH/vendor` path and avoids a `system/thermal*` file that Scene's current
thermal profile script rejects. Disabling or uninstalling and rebooting
restores the original vendor file because the vendor partition is not edited.
This boot path needs a real reboot A/B before claiming a completed device
regression; a successful temporary bind mount is not equivalent.

## Scope that remains untouched

The module does not change CPU/GPU thermal throttling, battery or charging
protection, other cooling devices, kernel thermal zones, PMIC protections,
PowerKeeper package code, DisplayFeature binaries, refresh-rate settings,
Touch Boost, Smart DFPS, video/camera policy or app-specific refresh policy.
