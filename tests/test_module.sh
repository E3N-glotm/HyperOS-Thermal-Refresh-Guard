#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"
for f in "$MOD"/*.sh "$MOD"/bin/*.sh; do sh -n "$f"; done
grep -q '^version=1.5.0$' "$MOD/module.prop"
grep -q '^id=hyperos_thermal_refresh_guard$' "$MOD/module.prop"

# Device IDs are never gating installation/boot; interface discovery is.
! grep -REn 'EXPECTED_DEVICE|ro.product.device.*pudding|abort_compat|reinstall to reprobe' "$MOD"/*.sh
grep -q '^  xml)' "$MOD/post-fs-data.sh"
grep -q 'FRAMEWORK_ONLY:' "$MOD/post-fs-data.sh"
grep -q 'UNSUPPORTED:' "$MOD/post-fs-data.sh"
grep -q 'apply_source_context' "$MOD/post-fs-data.sh"
grep -q 'source_sha256=' "$MOD/customize.sh"
grep -q 'ro.vendor.fps.switch.thermal' "$MOD/post-fs-data.sh"
! grep -REn 'thermal.shutdown|DisableThermal|remove_temp_limit|cpu.*thermal|gpu.*thermal' "$MOD"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/xiaomi.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Display>
  <Other fps="144" key="keep-me" />
  <ThermalLevelMap state="1" fps="144" />
  <ThermalLevelMap state="4" fps="90" />
  <ThermalLevelMap state="9" fps="60" />
  <ThermalLevelMap state="3" fps="30" />
</Display>
EOF
cat > "$TMP/90hz.xml" <<'EOF'
<Display>
  <ThermalLevelMap state="1" fps="90" />
  <ThermalLevelMap state="9" fps="60" />
</Display>
EOF
cat > "$TMP/invalid.xml" <<'EOF'
<Display>
  <ThermalLevelMap state="1" fps="120" fps="60" />
</Display>
EOF
cat > "$TMP/no-schema.xml" <<'EOF'
<Display><Other fps="90" /></Display>
EOF

(
  . "$MOD/bin/capability.sh"
  validate_map "$TMP/xiaomi.xml"
  [ "$TG_COUNT" -eq 4 ]
  [ "$TG_TARGET_FPS" -eq 120 ]
  generate_map "$TMP/xiaomi.xml" "$TMP/new.xml" "$TG_TARGET_FPS"
  [ "$(grep -c 'ThermalLevelMap.*fps="120"' "$TMP/new.xml")" -eq 4 ]
  grep -q 'Other fps="144" key="keep-me"' "$TMP/new.xml"
  validate_map "$TMP/90hz.xml"
  [ "$TG_TARGET_FPS" -eq 90 ]
  ! validate_map "$TMP/invalid.xml"
  ! validate_map "$TMP/no-schema.xml"
)

# Test the installer with a fake device ID and no vendor display XML:
# installation may report unsupported but must not abort or touch protected
# thermal settings. Paths are mocked in a dedicated temporary directory.
mkdir -p "$TMP/bin" "$TMP/module"
cp -R "$MOD/." "$TMP/module/"
cat > "$TMP/bin/getprop" <<'EOF'
#!/bin/sh
case "$1" in
  ro.product.device) echo haotian;;
  ro.product.model) echo 'Xiaomi 15 Pro';;
  ro.vendor.fps.switch.thermal) echo true;;
esac
EOF
chmod +x "$TMP/bin/getprop"
(
  export PATH="$TMP/bin:$PATH"
  export MODPATH="$TMP/module"
  set_perm() { :; }
  set_perm_recursive() { :; }
  ui_print() { :; }
  . "$MOD/customize.sh"
  [ -r "$TMP/module/compatibility.txt" ]
  grep -q '^device=haotian$' "$TMP/module/compatibility.txt"
  grep -q '^framework_thermal_switch=1$' "$TMP/module/compatibility.txt"
)
echo 'PASS: cross-device capabilities, model-independent install, XML-only transformation'
