#!/system/bin/sh

# HyperOS Thermal Refresh Guard
#
# Installation verifies the tested ROM/vendor map and generates a private
# replacement. A one-shot post-fs-data hook mounts it before SurfaceFlinger
# starts, then exits. No resident process and no system/thermal* module file
# that would trigger Scene's thermal-file collision checker.

TARGET="/vendor/etc/display/thermallevel_to_fps.xml"
OVERLAY="$MODPATH/private/thermallevel_to_fps.xml"
META="$MODPATH/compatibility.txt"

EXPECTED_DEVICE="pudding"
EXPECTED_MAP_MAX="64"
EXPECTED_FRAMEWORK_PROPERTY="ro.vendor.fps.switch.thermal"

abort_compat() {
  ui_print "! Unsupported device / ROM thermal map"
  ui_print "! $1"
  ui_print "! No systemless override was generated"
  abort "$1"
}

DEVICE="$(getprop ro.product.device)"
[ "$DEVICE" = "$EXPECTED_DEVICE" ] || abort_compat "battery/display hardware not validated"
[ -x /system/bin/nsenter ] || abort_compat "PID1 mount namespace capability unavailable"
[ -r "$TARGET" ] || abort_compat "vendor ThermalLevelMap interface missing"
[ -n "$(getprop "$EXPECTED_FRAMEWORK_PROPERTY")" ] || abort_compat "PowerKeeper thermal FPS switch property absent"

SOURCE_SHA="$(sha256sum "$TARGET" 2>/dev/null | awk '{print $1}')"
MAP_INPUT="$TARGET"
ACTIVE="/data/adb/modules/hyperos_thermal_refresh_guard"
if [ -r "$ACTIVE/compatibility.txt" ] && [ -r "$ACTIVE/private/thermallevel_to_fps.xml" ]; then
  PREV_SHA="$(sha256sum "$ACTIVE/private/thermallevel_to_fps.xml" | awk '{print $1}')"
  if [ "$SOURCE_SHA" = "$PREV_SHA" ]; then
    grep -E ' /vendor/etc/display/thermallevel_to_fps.xml ' /proc/1/mountinfo |
      grep -q 'hyperos_thermal_refresh_guard/private/thermallevel_to_fps.xml' ||
      abort_compat "cannot verify old mounted source"
    MAP_INPUT="$ACTIVE/private/thermallevel_to_fps.xml"
    SOURCE_SHA="$(sed -n 's/^source_sha256=//p' "$ACTIVE/compatibility.txt")"
    ui_print "- Verified previous Guard overlay; preserve OEM provenance"
  fi
fi
printf '%s' "$SOURCE_SHA" |grep -Eq '^[0-9a-f]{64}$' || abort_compat "source SHA invalid"
MAP_COUNT="$(grep -c '<ThermalLevelMap[[:space:]]' "$MAP_INPUT" 2>/dev/null)"
[ "$MAP_COUNT" -ge 1 ] && [ "$MAP_COUNT" -le "$EXPECTED_MAP_MAX" ] ||
  abort_compat "ThermalLevelMap capability mismatch: count=$MAP_COUNT"
TAGS="$(grep '<ThermalLevelMap[[:space:]]' "$MAP_INPUT")"
[ "$(printf '%s\n' "$TAGS" |grep -c 'fps="[0-9][0-9]*"')" = "$MAP_COUNT" ] ||
  abort_compat "one numeric fps field required for each thermal level"
[ "$(printf '%s\n' "$TAGS" |sed 's/fps="[0-9][0-9]*"/@FPS@/g' |grep -c '@FPS@.*@FPS@')" = 0 ] ||
  abort_compat "duplicate fps attributes"
mkdir -p "${OVERLAY%/*}" || abort "Unable to create private thermal map directory"

# Remove old v1.0.0 paths from an in-place module update. Never leave a
# system/vendor thermal file that Scene would interpret as a competing
# replacement of its /data/vendor/thermal/config profiles.
rm -f "$MODPATH/vendor/etc/display/thermallevel_to_fps.xml" \
      "$MODPATH/system/vendor/etc/display/thermallevel_to_fps.xml"

# Keep the vendor XML itself as the source of truth and change only its FPS
# attributes. This removes the display-fps thermal ceiling while leaving the
# Thermal HAL callback path and HyperOS/SurfaceFlinger dynamic scheduler alive.
sed -E '/<ThermalLevelMap[[:space:]]/s/fps="[0-9]+"/fps="120"/g' "$MAP_INPUT" > "$OVERLAY" || \
  abort "Unable to generate thermal FPS overlay"

[ -s "$OVERLAY" ] || abort "Generated overlay is empty"
[ "$(grep -c '<ThermalLevelMap ' "$OVERLAY" 2>/dev/null)" = "$MAP_COUNT" ] || \
  abort "Generated overlay entry count mismatch"

if grep '<ThermalLevelMap ' "$OVERLAY" | grep -vq 'fps="120"'; then
  abort "Generated overlay contains a non-120 thermal FPS target"
fi

OVERLAY_SHA="$(sha256sum "$OVERLAY" 2>/dev/null | awk '{print $1}')"
cat > "$META" <<EOF
device=$DEVICE
source=$TARGET
source_sha256=$VENDOR_SHA
overlay=$OVERLAY
overlay_sha256=$OVERLAY_SHA
thermal_map_entries=$MAP_COUNT
framework_thermal_switch=1
interface_mode=feature-probed
thermal_fps_target=120
architecture=one-shot-post-fs-data-private-bind
scene_profile_directory=/data/vendor/thermal/config
EOF

set_perm "$OVERLAY" 0 0 0644
set_perm "$META" 0 0 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
chcon u:object_r:vendor_configs_file:s0 "$OVERLAY" 2>/dev/null || true

ui_print "- Device: $DEVICE"
ui_print "- OEM thermal capability: ThermalLevelMap supported"
ui_print "- Vendor XML schema and original-source fingerprint validated"
ui_print "- Generated $MAP_COUNT-entry private thermal FPS map"
ui_print "- Thermal FPS ceiling normalized to 120 Hz"
ui_print "- HyperOS dynamic refresh scheduling remains enabled"
ui_print "- One-shot early mount and framework thermal vote cleanup; no daemon or polling"
ui_print "- Reboot is required"

