#!/system/bin/sh

# Runs once during Magisk's early boot stage, before SurfaceFlinger loads the
# thermal FPS map. Does not change Scene's /data/vendor/thermal/config files.
MODDIR="${0%/*}"
TARGET="/vendor/etc/display/thermallevel_to_fps.xml"
SOURCE="$MODDIR/private/thermallevel_to_fps.xml"
STATUS="$MODDIR/boot-status.txt"
STOCK_SHA="49c0a52abc0453d7f2345439f7e411282bab7c6a8196720d5277a12759d76d7e"

report() {
  printf '%s\n' "$1" > "$STATUS"
}

if [ "$(getprop ro.product.device)" != pudding ] ||
   [ "$(getprop ro.build.version.incremental)" != OS3.0.319.0.WPCCNXM ] ||
   [ "$(getprop ro.build.version.sdk)" != 36 ]; then
  report 'SKIPPED: device or ROM changed; stock display configuration retained'
  exit 0
fi

if [ ! -r "$TARGET" ] || [ ! -r "$SOURCE" ]; then
  report 'SKIPPED: stock or private thermal map unavailable'
  exit 0
fi

# Refuse to stack on a ROM update, another active display-map modification or
# a partially written private map. Guard never edits the vendor partition.
if [ "$(sha256sum "$TARGET" | cut -d ' ' -f 1)" != "$STOCK_SHA" ] ||
   [ "$(grep -c '<ThermalLevelMap ' "$SOURCE")" != 13 ] ||
   grep '<ThermalLevelMap ' "$SOURCE" | grep -qv 'fps="120"'; then
  report 'SKIPPED: incompatible or modified thermal map; stock retained'
  exit 0
fi

SOURCE_SHA="$(sha256sum "$SOURCE" | cut -d ' ' -f 1)"
if mount -o bind "$SOURCE" "$TARGET"; then
  if [ "$(sha256sum "$TARGET" | cut -d ' ' -f 1)" = "$SOURCE_SHA" ]; then
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
    umount "$TARGET" 2>/dev/null || true
    report 'FAILED: bind verification mismatch; stock retained'
  fi
else
  report 'FAILED: early bind mount failed; stock retained'
fi

exit 0
