# v1.1.0 on-device acceptance (2026-09-20, pudding)

## Scope and baseline

- Device/ROM: `pudding`, `OS3.0.319.0.WPCCNXM`.
- Scene installed, and `/data/vendor/thermal/config` was empty before the A/B. No pre-existing custom profile needed restoration.
- The user reports having switched off HyperCeiler's global `DisableThermal`. Its CE and DE preference copies disagree; this test does not attribute any behavior to that Hook.
- No thermal stress was induced, no kernel thermal protection was modified and neither Scene's `extreme` nor `danger` profile was tested.

## Cold boot and actual overlay

The device's installed Magisk module reported `version=1.1.0`. Its boot status was:

`MOUNTED: private thermal map bound before SurfaceFlinger startup`

SHA256 of `/vendor/etc/display/thermallevel_to_fps.xml`, the module's private source and SurfaceFlinger's `/proc/<pid>/root/vendor/etc/display/thermallevel_to_fps.xml` all matched:

`8b036f3cbfb210ad69ac6cdca78036ff82aec8bbe99e3f862f27217169a487d8`

PID 1 and SurfaceFlinger's `mountinfo` exposed the Magisk module's private XML bind-mounted over the vendor XML. All 13 thermal-map entries had `fps="120"`. This verifies the v1.1.0 **actual cold-boot mount** that was missing in v1.0.0; it does not establish a high-temperature A/B of a real Thermal AIDL callback.

## Scene profile switching A/B

Using the installed Scene `kr-script/miui/thermal_conf3/config.sh` rather than substituting a different implementation, a durable root shell applied `thermal_cool`, then `thermal_pro`, then restored `default` in an EXIT trap. Each applied profile had 98 `thermal*.conf` files in `/data/vendor/thermal/config`. The selected-profile marker read back as `thermal_cool` and `thermal_pro`, respectively. The representative `thermal-normal.conf` hash differed between the two profiles:

- cool: `187ef07bdf9d760f10424af6624d8619599652a768dca3a838320ce5832eac0a`
- pro: `c6a113ee07645b31662f31bc5e952ad7789dfc2092e9c362931022c9da5a57af`

`mi_thermald` reported `running` following both Scene switching operations. Scene's module collision check did not reject the Guard's private XML. Throughout the A/B, the display map retained the Guard hash above.

**Limitations:** Successful profile writes and daemon availability do not independently prove that the daemon parsed all 98 new configs or that their actual CPU/GPU thermal policies changed at runtime. Because Guard intentionally fixes the *separate display thermal-FPS ceiling* to 120, any Scene profile setting that relies on lowering **that same ceiling** is not expected to take effect while Guard is enabled. This does not amount to Scene's entire thermal profile switch being broken.

## Post-test restore

The EXIT trap invoked Scene's `default` selection. Verified afterward: `/data/vendor/thermal/config` was empty, `thermal.current.ini` was absent, `mi_thermald` and `vendor.thermal-hal` were running, and SurfaceFlinger still saw the Guard overlay. No other system settings were changed by this A/B.

The installed DevSpace Mobile version was `1.1.44-android.7-network-health`; the device successfully accepted MCP requests over Wi-Fi during parts of this verification, including while `dumpsys power` reported Dozing. This is not a multi-hour screen-off/Wi-Fi outage regression result.

## Open questions

1. An actual temperature-driven display-FPS mitigation transition and corresponding thermal-protection consequences were not reproduced; no proof of total elimination of temperature-based FPS caps is claimed.
2. Scene's on-screen picker and daemon's actual live profile application under sustained workloads were not separately instrumented.
3. A prolonged Wi-Fi-to-cellular/screen-off MCP connectivity test remains independent of this module's Scene A/B.
