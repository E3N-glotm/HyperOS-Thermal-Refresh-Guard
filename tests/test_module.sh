#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"
for f in "$MOD"/*.sh "$MOD"/bin/*.sh; do sh -n "$f"; done
grep -q '^version=1.5.2$' "$MOD/module.prop"
grep -q '^id=hyperos_thermal_refresh_guard$' "$MOD/module.prop"
grep -Fq 'description=状态: 待重启 | 显示热限帧优化' "$MOD/module.prop"
! grep -Eq '绝不|固定封顶|不允许|我说|你说' "$MOD/module.prop"
grep -Fq '状态: 未生效 | 请点击操作查看兼容性诊断' "$MOD/service.sh"
grep -Fq '系统限制: 已处理' "$MOD/service.sh"
! grep -Fq 'sed -i "s|^description=' "$MOD/service.sh"

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
  [ "$TG_MAP_MAX_FPS" -eq 144 ]
  [ "$TG_TARGET_FPS" -eq 144 ]
  generate_map "$TMP/xiaomi.xml" "$TMP/new.xml" "$TG_TARGET_FPS"
  [ "$(grep -c 'ThermalLevelMap.*fps="144"' "$TMP/new.xml")" -eq 4 ]
  grep -q 'Other fps="144" key="keep-me"' "$TMP/new.xml"
  validate_map "$TMP/90hz.xml"
  [ "$TG_TARGET_FPS" -eq 90 ]
  ! validate_map "$TMP/invalid.xml"
  ! validate_map "$TMP/no-schema.xml"
)

# Mode inventory, not XML stages or the 360Hz panel VSYNC, is authoritative.
cat > "$TMP/display" <<'EOF'
  mSfDisplayModes=
    DisplayMode{id=0, peakRefreshRate=144.00001, vsyncRate=360.0001}
    DisplayMode{id=1, peakRefreshRate=90.0, vsyncRate=90.0}
  mActiveSfDisplayMode=DisplayMode{id=0, peakRefreshRate=144.00001}
EOF
cat > "$TMP/bin_display" <<'EOF'
#!/bin/sh
cat "$TEST_DISPLAY"
EOF
mkdir -p "$TMP/bin"
cp "$TMP/bin_display" "$TMP/bin/dumpsys"
chmod +x "$TMP/bin/dumpsys"
(
  export TEST_DISPLAY="$TMP/display" PATH="$TMP/bin:$PATH"
  . "$MOD/bin/capability.sh"
  [ "$(detect_panel_max_fps)" = 144 ]
  sed -i 's/144.00001/165.0/g' "$TMP/display"
  [ "$(detect_panel_max_fps)" = 165 ]
  sed -i 's/165.0/240.0/g' "$TMP/display"
  [ "$(detect_panel_max_fps)" = 240 ]
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
  export PATH="$TMP/bin:$PATH" TEST_DISPLAY="$TMP/display"
  export MODPATH="$TMP/module"
  set_perm() { :; }
  set_perm_recursive() { :; }
  ui_print() { :; }
  . "$MOD/customize.sh"
  [ -r "$TMP/module/compatibility.txt" ]
  grep -q '^device=haotian$' "$TMP/module/compatibility.txt"
  grep -q '^framework_thermal_switch=1$' "$TMP/module/compatibility.txt"
)

# Reproduce the real incident: boot-status and Framework verification succeed,
# but a literal '|' in the Magisk description previously broke sed -i.
mkdir -p "$TMP/live"
cp "$MOD/service.sh" "$TMP/live/service.sh"
cat > "$TMP/live/module.prop" <<'EOF'
id=hyperos_thermal_refresh_guard
name=HyperOS Thermal Refresh Guard
version=1.5.2
description=状态: 待重启 | 显示热限帧优化
EOF
echo 'thermal_fps_target=144' > "$TMP/live/compatibility.txt"
echo 'MOUNTED: 144Hz OEM XML map active; PowerKeeper property gated' > "$TMP/live/boot-status.txt"
cat > "$TMP/bin/settings" <<'EOF'
#!/bin/sh
case "$*" in
  'get system thermal_limit_refresh_rate') echo 0;;
  *) exit 1;;
esac
EOF
cat >> "$TMP/bin/getprop" <<'EOF'
EOF
# Ensure boot state is available without using a real Android daemon.
sed -i '/ro.vendor.fps.switch.thermal)/i\  sys.boot_completed) echo 1;;' "$TMP/bin/getprop"
chmod +x "$TMP/bin/settings" "$TMP/bin/getprop"
PATH="$TMP/bin:$PATH" sh "$TMP/live/service.sh"
grep -Fq 'description=状态: 已生效 | 热控映射: 144Hz | 系统限制: 已处理' "$TMP/live/module.prop"
grep -q '^READY:' "$TMP/live/framework-status.txt"
echo 'PASS: physical panel mode selection at 144/165/240Hz, uncapped XML, model-independent installation'
