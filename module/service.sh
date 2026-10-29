#!/system/bin/sh
# One-shot late boot. Do not start polling or override app/idle FPS policies.
MODDIR=${0%/*}
STATUS="$MODDIR/boot-status.txt"
RESULT="$MODDIR/framework-status.txt"
PROP="$MODDIR/module.prop"
mode=$(sed -n 's/^mode=//p' "$MODDIR/compatibility.txt" | head -n 1)
refresh_ui() {
  value=$1
  sed -i "s|^description=.*|description=$value|" "$PROP" 2>/dev/null || true
}
boot=$(cat "$STATUS" 2>/dev/null)
case "$boot" in
  MOUNTED:*) level='已生效';;
  FRAMEWORK_ONLY:*) level='部分支持';;
  *) printf '%s\n' "${boot:-UNSUPPORTED: no interface}" > "$RESULT"
     refresh_ui "状态: 未找到可验证接口或未生效 | ${boot:-请点击操作查看诊断}"
     exit 0;;
esac
case "$boot" in
  *'PowerKeeper property gated'*) ;;
  *) echo 'PARTIAL: XML supported, framework thermal property unavailable' > "$RESULT"
     refresh_ui "状态: $level (仅 XML) | $boot"; exit 0 ;;
esac
attempt=0
while [ "$attempt" -lt 20 ]; do
  attempt=$((attempt+1))
  if [ "$(getprop sys.boot_completed)" = 1 ]; then
    cur=$(settings get system thermal_limit_refresh_rate 2>&1)
    case "$cur" in
      0|null)
        echo 'READY: framework thermal FPS cap cleared/unset' > "$RESULT"
        refresh_ui "状态: $level | 显示热限帧与 PowerKeeper 控制已处理"
        exit 0;;
      ''|*'Failure'*|*'Exception'*|*'transaction'*) ;;
      *)
        case "$cur" in *[!0-9]*) ;; *)
          if settings put system thermal_limit_refresh_rate 0 >/dev/null 2>&1 &&
             [ "$(settings get system thermal_limit_refresh_rate 2>/dev/null)" = 0 ]; then
            echo 'CLEARED: framework thermal FPS cap reset to zero' > "$RESULT"
            refresh_ui "状态: $level | 显示热限帧与 PowerKeeper 控制已处理"
            exit 0
          fi;; esac;;
    esac
  fi
  sleep 2
done
echo 'PARTIAL: SettingsProvider not ready or FPS cap not cleared' > "$RESULT"
refresh_ui "状态: 部分支持 | 显示接口处理成功，但 Framework 设置未确认"
exit 0
