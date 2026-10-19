# On-device acceptance: HyperOS 4 / Android 17 — 2026-10-19

- Device: Xiaomi 25113PN0EC / pudding, HyperOS OS4.0.4.0.XPCCNXM, Android 17 / API 37.
- OEM thermal FPS XML (before mount): SHA256 `49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e`.
- Guard private XML: SHA256 `8b036f3cbfb210ad69ac6cdca78036ff82aec8bbe99e3f862f27217169a487d8`.
- Before adaptation: `SKIPPED: device or ROM changed` and observed DisplayModeDirector `PRIORITY_THERMAL_LIMIT_REFRESH_RATE` limiting render to 60 Hz.
- After v1.3.0 guard adaptation and reboot: `MOUNTED: thermal XML active; PowerKeeper framework thermal setting writes gated`; `READY: framework thermal FPS cap is zero`. Mounted XML SHA matched private XML. `ro.vendor.fps.switch.thermal=false`; `thermal_limit_refresh_rate=0`; display active mode 120Hz and no thermal 60Hz framework vote in sampled dumpsys.
- Guard is one-shot, without a resident watcher, no global CPU/GPU thermal disable, preserves Scene profile directory. Other application-specific and vendor FPS limiters still exist.
- Compatibility conditions: exact device `pudding`, build `OS4.0.4.0.XPCCNXM`, SDK 37 and known source/vendor SHA256. If mismatch, module refuses to override.
- No artificial high-temperature torture test or comprehensive app matrix was run. Disable module and reboot for stock behavior.
