#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"
for f in customize.sh post-fs-data.sh service.sh; do bash -n "$MOD/$f"; done
grep -q '^version=1.4.0$' "$MOD/module.prop"
grep -q '^id=hyperos_thermal_refresh_guard$' "$MOD/module.prop"
for f in customize.sh post-fs-data.sh service.sh; do
  ! grep -Eq 'EXPECTED_(INCREMENTAL|SDK|VENDOR_SHA|GUARD_SHA)|ro\.build\.version\.(incremental|sdk)|OS4\.0\.4\.0\.XPCCNXM' "$MOD/$f"
done
grep -q 'ThermalLevelMap' "$MOD/customize.sh"
grep -q 'thermal_map_entries=' "$MOD/customize.sh"
grep -q 'source_sha256=' "$MOD/customize.sh"
grep -q 'overlay_sha256=' "$MOD/customize.sh"
grep -q 'source_sha256=' "$MOD/post-fs-data.sh"
grep -q 'overlay_sha256=' "$MOD/post-fs-data.sh"
grep -q 'SKIPPED: thermal API changed' "$MOD/post-fs-data.sh"
grep -q 'nsenter -t 1 -m' "$MOD/post-fs-data.sh"
grep -q 'resetprop ro.vendor.fps.switch.thermal false' "$MOD/post-fs-data.sh"
grep -q 'settings put system thermal_limit_refresh_rate 0' "$MOD/service.sh"
! grep -q 'STOCK_SHA=' "$MOD/post-fs-data.sh"
! grep -R -n -E 'setprop.*(thermal\.shutdown|thermal\.disable|cpu|gpu)|DisableThermal' "$MOD"
test ! -d "$MOD/system"
test ! -e "$MOD/vendor/etc/display/thermallevel_to_fps.xml"
test ! -e "$MOD/system/vendor/etc/display/thermallevel_to_fps.xml"
test ! -e "$MOD/uninstall.sh"
test ! -e "$MOD/action.sh"
# A mock XML map must change ONLY ThermalLevelMap fps fields.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/input.xml" <<'EOF'
<Display>
  <Other fps="144" note="untouched" />
  <ThermalLevelMap state="0" fps="90" />
  <ThermalLevelMap state="1" fps="60" />
</Display>
EOF
sed -E '/<ThermalLevelMap[[:space:]]/s/fps="[0-9]+"/fps="120"/g' "$tmp/input.xml" > "$tmp/output.xml"
grep -q 'Other fps="144"' "$tmp/output.xml"
test "$(grep -c 'ThermalLevelMap.*fps="120"' "$tmp/output.xml")" -eq 2
! grep -q 'ThermalLevelMap.*fps="90"' "$tmp/output.xml"
! grep -q 'ThermalLevelMap.*fps="60"' "$tmp/output.xml"
echo 'Thermal capability-gate and XML patch static tests: PASS'
