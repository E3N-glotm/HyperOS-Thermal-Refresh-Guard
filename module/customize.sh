#!/system/bin/sh

# HyperOS Thermal Refresh Guard
#
# There is no boot script and no resident process. Installation verifies the
# exact tested ROM/vendor map, then generates a Magisk systemless replacement
# from the device's own thermallevel_to_fps.xml. Only the FPS values are
# changed; the XML structure and device-version layout remain stock-derived.

TARGET="/vendor/etc/display/thermallevel_to_fps.xml"
OVERLAY="$MODPATH/vendor/etc/display/thermallevel_to_fps.xml"
META="$MODPATH/compatibility.txt"

EXPECTED_DEVICE="pudding"
EXPECTED_INCREMENTAL="OS3.0.319.0.WPCCNXM"
EXPECTED_SDK="36"
EXPECTED_VENDOR_SHA="49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e"
EXPECTED_MAP_COUNT="13"

abort_compat() {
  ui_print "! Unsupported device / ROM thermal map"
  ui_print "! $1"
  ui_print "! No systemless override was generated"
  abort "$1"
}

DEVICE="$(getprop ro.product.device)"
INCREMENTAL="$(getprop ro.build.version.incremental)"
SDK="$(getprop ro.build.version.sdk)"

[ "$DEVICE" = "$EXPECTED_DEVICE" ] || abort_compat "device=$DEVICE, expected=$EXPECTED_DEVICE"
[ "$INCREMENTAL" = "$EXPECTED_INCREMENTAL" ] || abort_compat "ROM=$INCREMENTAL, expected=$EXPECTED_INCREMENTAL"
[ "$SDK" = "$EXPECTED_SDK" ] || abort_compat "SDK=$SDK, expected=$EXPECTED_SDK"
[ -r "$TARGET" ] || abort_compat "$TARGET is missing"

VENDOR_SHA="$(sha256sum "$TARGET" 2>/dev/null | awk '{print $1}')"
[ "$VENDOR_SHA" = "$EXPECTED_VENDOR_SHA" ] || abort_compat "vendor thermal map SHA256 mismatch"

MAP_COUNT="$(grep -c '<ThermalLevelMap ' "$TARGET" 2>/dev/null)"
[ "$MAP_COUNT" = "$EXPECTED_MAP_COUNT" ] || abort_compat "thermal map entry count=$MAP_COUNT, expected=$EXPECTED_MAP_COUNT"

mkdir -p "${OVERLAY%/*}" || abort "Unable to create Magisk vendor overlay directory"

# Keep the vendor XML itself as the source of truth and change only its FPS
# attributes. This removes the display-fps thermal ceiling while leaving the
# Thermal HAL callback path and HyperOS/SurfaceFlinger dynamic scheduler alive.
sed 's/fps="[0-9][0-9]*"/fps="120"/g' "$TARGET" > "$OVERLAY" || \
  abort "Unable to generate thermal FPS overlay"

[ -s "$OVERLAY" ] || abort "Generated overlay is empty"
[ "$(grep -c '<ThermalLevelMap ' "$OVERLAY" 2>/dev/null)" = "$EXPECTED_MAP_COUNT" ] || \
  abort "Generated overlay entry count mismatch"

if grep '<ThermalLevelMap ' "$OVERLAY" | grep -vq 'fps="120"'; then
  abort "Generated overlay contains a non-120 thermal FPS target"
fi

OVERLAY_SHA="$(sha256sum "$OVERLAY" 2>/dev/null | awk '{print $1}')"
cat > "$META" <<EOF
device=$DEVICE
incremental=$INCREMENTAL
sdk=$SDK
source=$TARGET
source_sha256=$VENDOR_SHA
overlay=$OVERLAY
overlay_sha256=$OVERLAY_SHA
thermal_map_entries=$MAP_COUNT
thermal_fps_target=120
architecture=magisk-systemless-xml-only
EOF

set_perm "$OVERLAY" 0 0 0644
set_perm "$META" 0 0 0644
chcon u:object_r:vendor_configs_file:s0 "$OVERLAY" 2>/dev/null || true

ui_print "- Device: $DEVICE"
ui_print "- ROM: $INCREMENTAL"
ui_print "- Vendor thermal map SHA256 verified"
ui_print "- Generated $MAP_COUNT-entry systemless thermal FPS map"
ui_print "- Thermal FPS ceiling normalized to 120 Hz"
ui_print "- HyperOS dynamic refresh scheduling remains enabled"
ui_print "- No ELF/OAT patch, daemon, logcat watcher, polling or wakelock"
ui_print "- Reboot is required"

