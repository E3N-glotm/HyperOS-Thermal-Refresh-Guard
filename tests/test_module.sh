#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"

bash -n "$MOD/customize.sh"
bash -n "$MOD/post-fs-data.sh"
bash -n "$MOD/service.sh"

grep -q '^id=hyperos_thermal_refresh_guard$' "$MOD/module.prop"
grep -q '^version=1.2.1$' "$MOD/module.prop"
grep -q 'EXPECTED_VENDOR_SHA="49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e"' "$MOD/customize.sh"
grep -q 'EXPECTED_MAP_COUNT="13"' "$MOD/customize.sh"
grep -q 'thermallevel_to_fps.xml' "$MOD/customize.sh"
grep -q 'sed .*fps=' "$MOD/customize.sh"
grep -q 'vendor_configs_file' "$MOD/customize.sh"
grep -q 'private/thermallevel_to_fps.xml' "$MOD/customize.sh"
grep -q 'mount -o bind' "$MOD/post-fs-data.sh"
grep -q 'STOCK_SHA=' "$MOD/post-fs-data.sh"
grep -q 'MOUNTED:' "$MOD/post-fs-data.sh"
grep -q 'resetprop ro.vendor.fps.switch.thermal false' "$MOD/post-fs-data.sh"
grep -q 'settings put system thermal_limit_refresh_rate 0' "$MOD/service.sh"
grep -q 'READY:' "$MOD/service.sh"
grep -Fq '"$attempt" -lt 20' "$MOD/service.sh"
grep -q 'sys.boot_completed' "$MOD/service.sh"

# Scene's installed config.sh aborts whenever another enabled Magisk module
# has a *thermal* file under its system/ tree. Keep the map in private/ and
# bind it once before SurfaceFlinger starts, without interfering with the
# user's /data/vendor/thermal/config profiles.
test ! -e "$MOD/vendor/etc/display/thermallevel_to_fps.xml"
test ! -e "$MOD/system/vendor/etc/display/thermallevel_to_fps.xml"
test ! -d "$MOD/system"
! grep -q 'rm -f .*thermal.current.ini' "$MOD/post-fs-data.sh"

# There must be no resident daemon, logcat watcher, polling loop or
# CPU/GPU/global thermal policy override. service.sh runs and exits once.
test ! -e "$MOD/uninstall.sh"
test ! -e "$MOD/action.sh"
! grep -R -n -E '^[[:space:]]*(logcat|while[[:space:]]+true)' "$MOD" --include='*.sh'
! grep -R -n -E 'setprop.*(thermal\.shutdown|thermal\.disable|cpu|gpu)|DisableThermal|millet' "$MOD"
! grep -R -n -E 'PowerKeeper\.classes|dalvik-cache|libdisplayfeatureservice|0x11a3e0' "$MOD"

echo "module static checks: OK"

