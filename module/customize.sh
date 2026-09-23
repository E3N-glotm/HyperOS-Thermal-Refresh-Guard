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
EXPECTED_INCREMENTAL="OS3.0.319.0.WPCCNXM"
EXPECTED_SDK="36"
EXPECTED_VENDOR_SHA="49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e"
EXPECTED_GUARD_SHA="8b036f3cbfb210ad69ac6cdca78036ff82aec8bbe99e3f862f27217169a487d8"
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
MAP_INPUT="$TARGET"
if [ "$VENDOR_SHA" = "$EXPECTED_VENDOR_SHA" ]; then
  ui_print "- Found stock vendor thermal FPS map"
elif [ "$VENDOR_SHA" = "$EXPECTED_GUARD_SHA" ]; then
  # Magisk can install the next ZIP while the previous Guard is still
  # bind-mounted. Accept only our exact mounted map and the recorded stock
  # provenance, never an arbitrary third-party vendor XML modification.
  ACTIVE="/data/adb/modules/hyperos_thermal_refresh_guard"
  COMPAT="$ACTIVE/compatibility.txt"
  OLD_MAP="$ACTIVE/private/thermallevel_to_fps.xml"
  grep -q "^source_sha256=$EXPECTED_VENDOR_SHA$" "$COMPAT" 2>/dev/null || \
    abort_compat "guard upgrade provenance does not match stock vendor map"
  grep -q "^overlay_sha256=$EXPECTED_GUARD_SHA$" "$COMPAT" 2>/dev/null || \
    abort_compat "guard upgrade provenance does not match mounted map"
  [ "$(sha256sum "$OLD_MAP" 2>/dev/null | awk '{print $1}')" = "$EXPECTED_GUARD_SHA" ] || \
    abort_compat "installed guard source file has changed"
  grep -E " /vendor/etc/display/thermallevel_to_fps.xml " /proc/1/mountinfo 2>/dev/null | \
    grep -q 'hyperos_thermal_refresh_guard/private/thermallevel_to_fps.xml' || \
    abort_compat "vendor map is not mounted by the existing guard"
  MAP_INPUT="$OLD_MAP"
  VENDOR_SHA="$EXPECTED_VENDOR_SHA"
  ui_print "- Verified existing Guard mount; safe in-place upgrade"
else
  abort_compat "vendor thermal map SHA256 mismatch"
fi

MAP_COUNT="$(grep -c '<ThermalLevelMap ' "$MAP_INPUT" 2>/dev/null)"
[ "$MAP_COUNT" = "$EXPECTED_MAP_COUNT" ] || abort_compat "thermal map entry count=$MAP_COUNT, expected=$EXPECTED_MAP_COUNT"

mkdir -p "${OVERLAY%/*}" || abort "Unable to create private thermal map directory"

# Remove old v1.0.0 paths from an in-place module update. Never leave a
# system/vendor thermal file that Scene would interpret as a competing
# replacement of its /data/vendor/thermal/config profiles.
rm -f "$MODPATH/vendor/etc/display/thermallevel_to_fps.xml" \
      "$MODPATH/system/vendor/etc/display/thermallevel_to_fps.xml"

# Keep the vendor XML itself as the source of truth and change only its FPS
# attributes. This removes the display-fps thermal ceiling while leaving the
# Thermal HAL callback path and HyperOS/SurfaceFlinger dynamic scheduler alive.
sed 's/fps="[0-9][0-9]*"/fps="120"/g' "$MAP_INPUT" > "$OVERLAY" || \
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
architecture=one-shot-post-fs-data-private-bind
scene_profile_directory=/data/vendor/thermal/config
EOF

set_perm "$OVERLAY" 0 0 0644
set_perm "$META" 0 0 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
chcon u:object_r:vendor_configs_file:s0 "$OVERLAY" 2>/dev/null || true

ui_print "- Device: $DEVICE"
ui_print "- ROM: $INCREMENTAL"
ui_print "- Vendor thermal map SHA256 verified"
ui_print "- Generated $MAP_COUNT-entry private thermal FPS map"
ui_print "- Thermal FPS ceiling normalized to 120 Hz"
ui_print "- HyperOS dynamic refresh scheduling remains enabled"
ui_print "- One-shot early mount and framework thermal vote cleanup; no daemon or polling"
ui_print "- Reboot is required"

