#!/system/bin/sh
# Shell-only XML schema checks shared by installer and early boot. Never
# generalize this XML transformation to arbitrary thermal or charging files.
valid_sha() {
  printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{64}$'
}
validate_map() {
  TG_COUNT=0
  TG_TARGET_FPS=0
  file="$1"
  [ -r "$file" ] && [ -s "$file" ] || return 1
  # Only one-line, attribute-form ThermalLevelMap nodes are supported.
  TG_COUNT=$(grep -c '<ThermalLevelMap[[:space:]]' "$file" 2>/dev/null) || return 1
  [ "$TG_COUNT" -ge 1 ] && [ "$TG_COUNT" -le 128 ] || return 1
  tags=$(grep '<ThermalLevelMap[[:space:]]' "$file") || return 1
  [ "$(printf '%s\n' "$tags" | grep -c 'fps="[0-9][0-9]*"')" = "$TG_COUNT" ] || return 1
  # Every line must have exactly one numeric fps field, with a bounded value.
  [ "$(printf '%s\n' "$tags" | grep -Eo 'fps="[0-9]+"' | wc -l)" = "$TG_COUNT" ] || return 1
  top=$(printf '%s\n' "$tags" | sed -n 's/.*fps="\([0-9][0-9]*\)".*/\1/p' | sort -nr | head -n 1)
  case "$top" in ''|*[!0-9]*) return 1;; esac
  [ "$top" -ge 60 ] && [ "$top" -le 240 ] || return 1
  # Avoid requesting a mode higher than the OEM map ever mentions.
  if [ "$top" -ge 120 ]; then TG_TARGET_FPS=120; else TG_TARGET_FPS=$top; fi
  return 0
}
generate_map() {
  input=$1 output=$2 fps=$3
  [ -n "$output" ] && [ "$input" != "$output" ] || return 1
  validate_map "$input" || return 1
  sed -E '/<ThermalLevelMap[[:space:]]/s/fps="[0-9]+"/fps="'$fps'"/' "$input" > "$output" || return 1
  [ -s "$output" ] &&
    [ "$(grep -c '<ThermalLevelMap[[:space:]]' "$output")" = "$TG_COUNT" ] &&
    [ "$(grep '<ThermalLevelMap[[:space:]]' "$output" | grep -c "fps=\"$fps\"")" = "$TG_COUNT" ]
}
apply_source_context() {
  original=$1
  newfile=$2
  # A bind source needs a display-readable SELinux label, not the default
  # Magisk-private-file label. Mirror the actual OEM source when possible.
  original_context=$(ls -Z "$original" 2>/dev/null | awk 'NR==1 {print $1}')
  case "$original_context" in
    u:object_r:*:s0*)
      chcon "$original_context" "$newfile" 2>/dev/null && return 0 ;;
  esac
  chcon u:object_r:vendor_configs_file:s0 "$newfile" 2>/dev/null
}
