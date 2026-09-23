#!/system/bin/sh

# One-shot Magisk late-start service; no daemon, polling or background watch.
# The framework may retain a thermal FPS cap from the previous boot. Clear it
# after SettingsProvider becomes available, but never force peak/min FPS.
MODDIR="${0%/*}"
STATUS="$MODDIR/boot-status.txt"
RESULT="$MODDIR/framework-status.txt"
if [ "$(getprop ro.product.device)" != pudding ] ||
   [ "$(getprop ro.build.version.incremental)" != OS3.0.319.0.WPCCNXM ] ||
   [ "$(getprop ro.vendor.fps.switch.thermal)" != false ] ||
   ! grep -q '^MOUNTED:' "$STATUS" 2>/dev/null; then
  printf '%s\n' 'SKIPPED: early boot verification/property gate was not successful' > "$RESULT"
  exit 0
fi

OLD="$(settings get system thermal_limit_refresh_rate 2>/dev/null)"
if [ "$OLD" = 0 ]; then
  printf '%s\n' 'READY: framework thermal FPS cap is already zero' > "$RESULT"
elif settings put system thermal_limit_refresh_rate 0 &&
     [ "$(settings get system thermal_limit_refresh_rate 2>/dev/null)" = 0 ]; then
  printf '%s\n' 'CLEARED: framework thermal FPS cap reset to zero' > "$RESULT"
else
  printf '%s\n' 'FAILED: could not clear framework thermal FPS cap' > "$RESULT"
fi
exit 0
