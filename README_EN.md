# HyperOS Thermal Refresh Guard

**[简体中文](README.md) | English**

**v1.5.1** is an experimental cross-device, feature-probed Xiaomi thermal *display refresh ceiling* guard. Prior releases were hard-blocked to device code `pudding`, so Xiaomi 15 Pro (`haotian`) could not install even when a compatible display interface might be available.

**v1.5.1 removes the unrequested hard 120Hz ceiling.** Prefer the highest physical refresh mode reported by DisplayManager (120/144/165/240Hz as available). If DisplayManager cannot report its modes, fall back to the vendor thermal XML's maximum with an explicit provenance flag; do not conflate an OEM throttling map's highest value with the actual display hardware's maximum.

The installer now **always completes** and reports one of the following capabilities, rather than treating a different device model as a fatal error:

| Interface detected | Behavior |
|---|---|
| Valid display `ThermalLevelMap` XML | Generate a privately stored map changing only the matching `fps` attributes; verify and bind-mount at early boot |
| XML plus PowerKeeper thermal FPS property | Also handle the independent Framework `thermal_limit_refresh_rate` cap |
| Only the PowerKeeper property | Partial support; no vendor XML patch |
| Neither interface | Diagnostic-only, original vendor thermal behavior preserved |
| OEM XML changes after OTA | Revalidate and regenerate from the newly booted OEM XML; unknown schemas fail closed without mounting |

Candidate XML paths: `/vendor/etc/display/thermallevel_to_fps.xml`, `/odm/etc/display/thermallevel_to_fps.xml`, and `/product/etc/display/thermallevel_to_fps.xml`. Candidate paths alone are not proof that a device uses them. Each must pass schema and SELinux checks.

There is **no hardcoded 120Hz cap** and no device-specific refresh-rate allowlist. The normal LTPO/idle, video, app and game-refresh policies remain unchanged. CPU/GPU, battery, charging, kernel thermal zones and Scene thermal profiles are not disabled or patched.

### Verification status

- **pudding:** previously validated real QTI XML and PowerKeeper behavior; v1.5.1 cold-boot tests still needed.
- **haotian (Xiaomi 15 Pro):** reported v1.4 installation failure was caused by the device whitelist. The new installer passes a simulated `haotian` model test, but its actual vendor XML and high-temperature behavior have **not** been verified.
- **SM8550 family / garnet / marble:** open device trees advertise related vendor display files; no production behavior claim.
- **Other Xiaomi/Redmi/POCO:** diagnostics only until actual interfaces have been proven.

Install the ZIP via Magisk, KernelSU or compatible SterSU, reboot, then use Magisk's module Action to inspect live and saved statuses. An installed module is **not** necessarily an active module. Disable or uninstall and reboot to restore stock bind mounts. This module has no resident daemon or polling process; removing a thermal FPS ceiling may increase heat and battery usage during sustained load.

For technical history, see [docs/TECHNICAL.md](docs/TECHNICAL.md). Issues should include device model, OS version and redacted compatibility/boot/framework status files.
