#!/system/bin/sh

# Runs once during Magisk's early boot stage, before SurfaceFlinger loads the
# thermal FPS map. Does not change Scene's /data/vendor/thermal/config files.
MODDIR="${0%/*}"
TARGET="/vendor/etc/display/thermallevel_to_fps.xml"
SOURCE="$MODDIR/private/thermallevel_to_fps.xml"
STATUS="$MODDIR/boot-status.txt"
META="$MODDIR/compatibility.txt"
report() { printf '%s\n' "$1" > "$STATUS"; }
sha() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f1; }
valid() { [ "$(expr "$1" : '[a-f0-9]*$')" = 64 ]; }
[ "$(getprop ro.product.device)" = pudding ] || { report 'SKIPPED: display hardware profile changed'; exit 0; }
[ -x /system/bin/nsenter ] && [ -r "$META" ] ||
  { report 'SKIPPED: mount interface or install metadata missing'; exit 0; }
SOURCE_SHA="$(sed -n 's/^source_sha256=//p' "$META")"
OVERLAY_SHA="$(sed -n 's/^overlay_sha256=//p' "$META")"
COUNT="$(sed -n 's/^thermal_map_entries=//p' "$META")"
valid "$SOURCE_SHA" && valid "$OVERLAY_SHA" ||
  { report 'SKIPPED: invalid source/overlay SHA metadata'; exit 0; }
[ "$COUNT" -ge 1 ] && [ "$COUNT" -le 64 ] 2>/dev/null ||
  { report 'SKIPPED: unsupported XML entry count'; exit 0; }
[ -r "$TARGET" ] && [ -r "$SOURCE" ] &&
[ -n "$(getprop ro.vendor.fps.switch.thermal)" ] &&
[ "$(sha "$TARGET")" = "$SOURCE_SHA" ] &&
[ "$(sha "$SOURCE")" = "$OVERLAY_SHA" ] &&
[ "$(grep -c '<ThermalLevelMap[[:space:]]' "$SOURCE")" = "$COUNT" ] &&
[ "$(grep '<ThermalLevelMap[[:space:]]' "$SOURCE" | grep -c 'fps="120"')" = "$COUNT" ] ||
  { report 'SKIPPED: thermal API changed or source fingerprint invalid; reinstall to reprobe'; exit 0; }
if /system/bin/nsenter -t 1 -m -- /system/bin/mount --bind "$SOURCE" "$TARGET"; then
  if [ "$(sha "$TARGET")" = "$OVERLAY_SHA" ]; then
    # PowerKeeper independently writes Settings.System thermal_limit_refresh_rate
    # on this exact ROM. The XML alone cannot neutralize that framework vote.
    # This property gates only the PowerKeeper write to that key; the vendor
    # DisplayFeature request and ordinary dynamic scheduling still execute.
    # Set it before PowerKeeper constructs DisplayFrameSetting.
    if command -v resetprop >/dev/null 2>&1 &&
       resetprop ro.vendor.fps.switch.thermal false &&
       [ "$(getprop ro.vendor.fps.switch.thermal)" = false ]; then
      report 'MOUNTED: thermal XML active; PowerKeeper framework thermal setting writes gated'
    else
      report 'PARTIAL: thermal XML active but PowerKeeper thermal property override failed'
    fi
  else
    /system/bin/nsenter -t 1 -m -- /system/bin/umount "$TARGET" 2>/dev/null || true
    report 'FAILED: bind verification mismatch; stock retained'
  fi
else
  report 'FAILED: early bind mount failed; stock retained'
fi

exit 0
