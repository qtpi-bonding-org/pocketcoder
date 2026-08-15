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

ssh_stub_dir="$TEST_TMP/sshbin"

# A stub ssh that echoes the remote script back, so tests can assert the
# exact string the harness sends.
stub_bin "$ssh_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case ${SSH_STUB_MODE:-ok} in
  ok)        printf "%s" "$last"; exit 0 ;;
  fail)      echo "remote failed" >&2; exit 9 ;;
  hostkey)   echo "@@@@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @@@@" >&2; exit 255 ;;
  hangup)    echo "Connection to host closed by remote host." >&2; exit 255 ;;
esac'

vps_connect 203.0.113.10 "$TEST_TMP/key" "$TEST_TMP/known_hosts"
: > "$TEST_TMP/key"

out=$(PATH="$ssh_stub_dir:$PATH" ssh_exec 10 'echo hello')
check "ssh_exec: passes the remote script through unmodified" "echo hello" "$out"

PATH="$ssh_stub_dir:$PATH" SSH_STUB_MODE=fail ssh_exec 10 'true' >/dev/null 2>&1
check_rc "ssh_exec: propagates remote failure" 9 "$?"

err=$(PATH="$ssh_stub_dir:$PATH" SSH_STUB_MODE=hostkey ssh_exec 10 'true' 2>&1 >/dev/null)
rc_hostkey=$?
check_rc "ssh_exec: host key change returns 3" 3 "$rc_hostkey"
check_contains "ssh_exec: host key change is explicit" "host key changed" "$err"

PATH="$ssh_stub_dir:$PATH" SSH_STUB_MODE=hangup ssh_exec_detached 10 'systemctl reboot'
check_rc "ssh_exec_detached: tolerates a dropped connection" 0 "$?"

# A nested single-quoted remote snippet must survive untouched, since the
# existing backup() phase relies on this shape.
nested=$(PATH="$ssh_stub_dir:$PATH" ssh_exec 10 'docker exec pb sh -ec '\''test -s /a; echo ok'\''')
check "ssh_exec: nested single quotes survive" "docker exec pb sh -ec 'test -s /a; echo ok'" "$nested"