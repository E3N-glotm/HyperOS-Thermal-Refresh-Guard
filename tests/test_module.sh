#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"

bash -n "$MOD/customize.sh"

grep -q '^id=hyperos_thermal_refresh_guard$' "$MOD/module.prop"
grep -q '^version=1.0.0$' "$MOD/module.prop"
grep -q 'EXPECTED_VENDOR_SHA="49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e"' "$MOD/customize.sh"
grep -q 'EXPECTED_MAP_COUNT="13"' "$MOD/customize.sh"
grep -q 'thermallevel_to_fps.xml' "$MOD/customize.sh"
grep -q 'sed .*fps=' "$MOD/customize.sh"
grep -q 'vendor_configs_file' "$MOD/customize.sh"

# The formal release must be installation-only. Magisk mounts the generated
# vendor overlay; no boot-stage or resident scripts are allowed.
test ! -e "$MOD/service.sh"
test ! -e "$MOD/post-fs-data.sh"
test ! -e "$MOD/uninstall.sh"
test ! -e "$MOD/action.sh"
! grep -R -n -E '^[[:space:]]*(logcat|while[[:space:]]+true|sleep[[:space:]]+[0-9])' "$MOD" --include='*.sh'
! grep -R -n 'resetprop' "$MOD"
! grep -R -n -E 'PowerKeeper\.classes|dalvik-cache|libdisplayfeatureservice|mount --bind|0x11a3e0' "$MOD"

echo "module static checks: OK"

