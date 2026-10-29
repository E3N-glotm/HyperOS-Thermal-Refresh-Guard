#!/system/bin/sh
# Cross-device capability probing. Installation must not fail because one
# OEM interface or model code is absent. Never edit kernel/thermal protection.
MODDIR="$MODPATH"
. "$MODDIR/bin/capability.sh"
META="$MODDIR/compatibility.txt"
STATUS="$MODDIR/install-status.txt"
mkdir -p "$MODDIR/private"

mode=none
source_path=
source_sha=
overlay_sha=
entry_count=0
target_fps=0
framework=0
reason='No verified display thermal FPS interface'

# Prefer the real mounted vendor/odm interface, not a codename allowlist.
for candidate in /vendor/etc/display/thermallevel_to_fps.xml \
                 /odm/etc/display/thermallevel_to_fps.xml \
                 /product/etc/display/thermallevel_to_fps.xml; do
  [ -r "$candidate" ] || continue
  current="$candidate"
  # During an update, the pathname may be the previous *mounted* overlay.
  # Its original provenance must be taken from the previous module metadata.
  ACTIVE=/data/adb/modules/hyperos_thermal_refresh_guard
  original_sha=
  if [ -r "$ACTIVE/compatibility.txt" ] &&
     [ -r "$ACTIVE/private/thermallevel_to_fps.xml" ] &&
     grep -Fq " $candidate " /proc/1/mountinfo 2>/dev/null; then
    old_overlay_sha=$(sha256sum "$ACTIVE/private/thermallevel_to_fps.xml" | cut -d' ' -f1)
    current_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
    if [ "$current_sha" = "$old_overlay_sha" ]; then
      old_source=$(sed -n 's/^source=//p' "$ACTIVE/compatibility.txt")
      old_stock_sha=$(sed -n 's/^source_sha256=//p' "$ACTIVE/compatibility.txt")
      if [ "$old_source" = "$candidate" ] && valid_sha "$old_stock_sha"; then
        original_sha="$old_stock_sha"
      fi
    fi
  fi
  if validate_map "$current"; then
    source_path="$candidate"
    source_sha="${original_sha:-$(sha256sum "$current" | cut -d' ' -f1)}"
    entry_count="$TG_COUNT"
    target_fps="$TG_TARGET_FPS"
    if generate_map "$current" "$MODDIR/private/thermallevel_to_fps.xml" "$TG_TARGET_FPS" &&
       apply_source_context "$current" "$MODDIR/private/thermallevel_to_fps.xml"; then
      overlay_sha=$(sha256sum "$MODDIR/private/thermallevel_to_fps.xml" | cut -d' ' -f1)
      mode=xml
      reason='Verified ThermalLevelMap schema'
      break
    else
      reason='Thermal map generation/SELinux labeling unsupported'
    fi
  fi
done

if [ -n "$(getprop ro.vendor.fps.switch.thermal)" ]; then
  # A writable PowerKeeper thermal vote is optional and independent of XML.
  framework=1
  [ "$mode" != none ] || { mode=framework; reason='Framework FPS switch detected; vendor XML unavailable'; }
fi

# No overlay is an entirely valid installed diagnostic state.
if [ "$mode" != xml ]; then
  rm -f "$MODDIR/private/thermallevel_to_fps.xml"
fi
cat > "$META" <<EOF
schema=3
device=$(getprop ro.product.device)
mode=$mode
source=$source_path
source_sha256=$source_sha
overlay_sha256=$overlay_sha
thermal_map_entries=$entry_count
thermal_fps_target=$target_fps
framework_thermal_switch=$framework
reason=$reason
EOF

# Restore the original mounting scheme without writing into Scene's thermal
# config profiles. Keep private only; post-fs-data owns the early bind.
rm -f "$MODDIR/vendor/etc/display/thermallevel_to_fps.xml" \
      "$MODDIR/system/vendor/etc/display/thermallevel_to_fps.xml"
[ "$mode" != xml ] || set_perm "$MODDIR/private/thermallevel_to_fps.xml" 0 0 0644
set_perm "$META" 0 0 0644
set_perm_recursive "$MODDIR/bin" 0 0 0755 0755
set_perm "$MODDIR/post-fs-data.sh" 0 0 0755
set_perm "$MODDIR/service.sh" 0 0 0755
set_perm "$MODDIR/action.sh" 0 0 0755
echo "INSTALLED: mode=$mode; $reason" > "$STATUS"
ui_print "- Device: $(getprop ro.product.device); capability mode: $mode"
ui_print "- $reason"
ui_print "- Thermal XML target: ${target_fps}Hz; entries: $entry_count"
ui_print "- Interface missing = installed diagnostics, not installation failure"
ui_print "- CPU/GPU, battery and charging thermal protections untouched"
ui_print "- The module rechecks vendor XML after every reboot/OTA"
ui_print "- Reboot to activate; inspect the Magisk module description/status"
