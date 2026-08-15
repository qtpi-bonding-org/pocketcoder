. "$VPS_DIR/lib/common.sh"

with_timeout 5 true
check_rc "with_timeout: fast success returns 0" 0 "$?"

with_timeout 5 sh -c 'exit 7'
check_rc "with_timeout: propagates exit code" 7 "$?"

with_timeout 1 sleep 10
check_rc "with_timeout: expiry returns 124" 124 "$?"

check "with_timeout: captures stdout" "hi" "$(with_timeout 5 echo hi)"

start=$(date +%s)
retry_until 3 1 false
rc=$?
elapsed=$(( $(date +%s) - start ))
check_rc "retry_until: gives up with 1" 1 "$rc"
check "retry_until: honors deadline" "yes" "$([ "$elapsed" -ge 3 ] && [ "$elapsed" -le 8 ] && echo yes || echo "no:$elapsed")"

retry_until 5 1 true
check_rc "retry_until: immediate success returns 0" 0 "$?"