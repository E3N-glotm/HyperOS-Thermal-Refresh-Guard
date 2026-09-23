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

# On this ROM Magisk late_start service can run before SettingsProvider has
# finished publishing its System table. v1.2.0 wrote a false FAILED status at
# that point even though the key later became 0. Wait only during this single
# boot invocation (maximum 40 seconds), then exit; never leave a watcher.
attempt=0
while [ "$attempt" -lt 20 ]; do
  attempt=$((attempt + 1))
  if [ "$(getprop sys.boot_completed)" = 1 ]; then
    OLD="$(settings get system thermal_limit_refresh_rate 2>/dev/null)"
    if [ "$OLD" = 0 ]; then
      printf '%s\n' 'READY: framework thermal FPS cap is zero' > "$RESULT"
      exit 0
    fi
    if [ "$OLD" = null ] && settings list system >/dev/null 2>&1; then
      printf '%s\n' 'READY: no framework thermal FPS cap is set' > "$RESULT"
      exit 0
    fi
    if settings put system thermal_limit_refresh_rate 0 2>/dev/null &&
       [ "$(settings get system thermal_limit_refresh_rate 2>/dev/null)" = 0 ]; then
      printf '%s\n' 'CLEARED: framework thermal FPS cap reset to zero' > "$RESULT"
      exit 0
    fi
  fi
  sleep 2
done
printf '%s\n' 'FAILED: SettingsProvider was not ready or framework cap could not be cleared within 40 seconds' > "$RESULT"
exit 0
