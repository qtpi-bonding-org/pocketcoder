# pc_retry <attempts> <sleep_seconds> -- <command...>
# Runs <command...> up to <attempts> times, sleeping <sleep_seconds> between
# failures. Prints the same "Attempt N: ... retrying in Ss" shape on every
# failure. Returns the last exit code.
pc_retry() {
  local attempts=$1 sleep_seconds=$2 attempt rc
  shift 2
  [ "$1" = "--" ] && shift
  for attempt in $(seq 1 "$attempts"); do
    set +e
    "$@"
    rc=$?
    set -e
    [ "$rc" -eq 0 ] && return 0
    echo "Attempt $attempt: $* failed (exit $rc); retrying in ${sleep_seconds}s" >&2
    [ "$attempt" -eq "$attempts" ] || sleep "$sleep_seconds"
  done
  return "$rc"
}
