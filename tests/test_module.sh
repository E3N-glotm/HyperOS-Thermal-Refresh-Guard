#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"

bash -n "$MOD/customize.sh"
bash -n "$MOD/post-fs-data.sh"

grep -q '^id=hyperos_thermal_refresh_guard$' "$MOD/module.prop"
grep -q '^version=1.1.0$' "$MOD/module.prop"
grep -q 'EXPECTED_VENDOR_SHA="49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e"' "$MOD/customize.sh"
grep -q 'EXPECTED_MAP_COUNT="13"' "$MOD/customize.sh"
grep -q 'thermallevel_to_fps.xml' "$MOD/customize.sh"
grep -q 'sed .*fps=' "$MOD/customize.sh"
grep -q 'vendor_configs_file' "$MOD/customize.sh"
grep -q 'private/thermallevel_to_fps.xml' "$MOD/customize.sh"
grep -q 'mount -o bind' "$MOD/post-fs-data.sh"
grep -q 'STOCK_SHA=' "$MOD/post-fs-data.sh"
grep -q 'MOUNTED:' "$MOD/post-fs-data.sh"

# Scene's installed config.sh aborts whenever another enabled Magisk module
# has a *thermal* file under its system/ tree. Keep the map in private/ and
# bind it once before SurfaceFlinger starts, without interfering with the
# user's /data/vendor/thermal/config profiles.
test ! -e "$MOD/vendor/etc/display/thermallevel_to_fps.xml"
test ! -e "$MOD/system/vendor/etc/display/thermallevel_to_fps.xml"
test ! -d "$MOD/system"
! grep -q 'rm -f .*thermal.current.ini' "$MOD/post-fs-data.sh"

# There must be no background daemon, logcat watcher, polling loop or
# global thermal policy/property hack.
test ! -e "$MOD/service.sh"
test ! -e "$MOD/uninstall.sh"
test ! -e "$MOD/action.sh"
! grep -R -n -E '^[[:space:]]*(logcat|while[[:space:]]+true|sleep[[:space:]]+[0-9])' "$MOD" --include='*.sh'
! grep -R -n 'resetprop' "$MOD"
! grep -R -n -E 'PowerKeeper\.classes|dalvik-cache|libdisplayfeatureservice|0x11a3e0' "$MOD"

echo "module static checks: OK"

