#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/modules/backend" "$TMP/live/private" "$TMP/live/bin" "$TMP/bin"
. "$ROOT/module/bin/capability.sh"
! has_metamodule "$TMP/modules"
echo 'metamodule=1' > "$TMP/modules/backend/module.prop"
has_metamodule "$TMP/modules"
touch "$TMP/modules/backend/disable"
! has_metamodule "$TMP/modules"
rm -f "$TMP/modules/backend/disable"
touch "$TMP/modules/backend/remove"
! has_metamodule "$TMP/modules"
rm -f "$TMP/modules/backend/remove"
echo 'metamodule=true' > "$TMP/modules/backend/module.prop"
has_metamodule "$TMP/modules"

cat > "$TMP/bin/nsenter" <<'EOF'
#!/bin/sh
echo invoked >> "$TEST_MOUNT_LOG"
shift 4
case "$1" in
  /system/bin/mount) cp "$3" "$4";;
  *) exit 1;;
esac
EOF
cat > "$TMP/bin/getprop" <<'EOF'
#!/bin/sh
echo false
EOF
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/chcon"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/resetprop"
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" TEST_MOUNT_LOG="$TMP/mount.log"
sed "s|/data/adb/modules|$TMP/modules|g" "$ROOT/module/bin/capability.sh" > "$TMP/live/bin/capability.sh"
for script in post-fs-data.sh post-mount.sh; do
  sed -e "s|/vendor/etc/display/thermallevel_to_fps.xml|$TMP/stock.xml|g" \
      -e "s|/system/bin/nsenter|$TMP/bin/nsenter|g" \
      "$ROOT/module/$script" > "$TMP/live/$script"
done
cat > "$TMP/original.xml" <<'EOF'
<Display>
  <ThermalLevelMap level="1" fps="144"/>
  <ThermalLevelMap level="2" fps="60"/>
</Display>
EOF
cp "$TMP/original.xml" "$TMP/stock.xml"
cat > "$TMP/live/compatibility.txt" <<EOF
mode=xml
source=$TMP/stock.xml
source_sha256=outdated
overlay_sha256=outdated
thermal_fps_target=120
target_origin=panel
framework_thermal_switch=1
EOF

# Enabled backend: stage XML and never invoke the legacy mount.
sh "$TMP/live/post-fs-data.sh"
grep -q '^PREPARED:' "$TMP/live/boot-status.txt"
[ ! -e "$TMP/live/skip_mount" ]
[ ! -e "$TEST_MOUNT_LOG" ]
cmp "$TMP/stock.xml" "$TMP/original.xml"
managed="$TMP/live/system$TMP/stock.xml"
[ "$(grep -c 'fps="120"' "$managed")" = 2 ]
cp "$managed" "$TMP/stock.xml" # Simulate the backend publishing the map.
sh "$TMP/live/post-mount.sh"
grep -q '^MOUNTED:.*via metamodule;' "$TMP/live/boot-status.txt"

# A backend that fails to mount must not cause a second bind mount.
cp "$TMP/original.xml" "$TMP/stock.xml"
sh "$TMP/live/post-fs-data.sh"
sh "$TMP/live/post-mount.sh"
grep -q '^FRAMEWORK_ONLY: managed XML not active;' "$TMP/live/boot-status.txt"
[ ! -e "$TEST_MOUNT_LOG" ]

# No enabled backend: the existing bind branch remains in use.
touch "$TMP/modules/backend/disable"
sh "$TMP/live/post-fs-data.sh"
grep -q '^MOUNTED: 120Hz OEM XML map active;' "$TMP/live/boot-status.txt"
[ -e "$TMP/live/skip_mount" ]
[ -s "$TEST_MOUNT_LOG" ]
cmp "$TMP/stock.xml" "$TMP/live/private/thermallevel_to_fps.xml"
echo 'PASS: metamodule detection, managed staging/verification, bind branch, no double mounting'
