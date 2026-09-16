#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/dist"
STAGE="$ROOT/.build-stage.$$"
VERSION="$(awk -F= '$1=="version" {print $2}' "$ROOT/module/module.prop")"
ZIP="$OUT/HyperOS-Thermal-Refresh-Guard-v${VERSION}.zip"

trap 'rm -rf "$STAGE"' EXIT INT TERM
rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUT"
rm -f "$ZIP"
cp -a "$ROOT/module/." "$STAGE/"

# Android /system/bin/sh requires LF scripts. Normalize the staged files so a
# Windows checkout cannot produce a broken release ZIP.
find "$STAGE" -type f -exec sed -i 's/\r$//' {} +
(
  cd "$STAGE"
  zip -qr "$ZIP" . -x '*.DS_Store'
)

echo "$ZIP"

