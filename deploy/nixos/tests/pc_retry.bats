#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../pc_retry.sh"
}

@test "pc_retry returns 0 immediately on first success" {
  attempts_seen=0
  ok() { attempts_seen=$((attempts_seen + 1)); return 0; }
  run pc_retry 3 0 -- ok
  [ "$status" -eq 0 ]
}

@test "pc_retry retries the configured number of times then returns the last exit code" {
  count_file="$BATS_TEST_TMPDIR/count"
  echo 0 > "$count_file"
  always_fail() {
    echo $(($(cat "$count_file") + 1)) > "$count_file"
    return 7
  }
  run pc_retry 3 0 -- always_fail
  [ "$status" -eq 7 ]
  [ "$(cat "$count_file")" = 3 ]
}

@test "pc_retry succeeds on a later attempt without retrying further" {
  count_file="$BATS_TEST_TMPDIR/count"
  echo 0 > "$count_file"
  succeed_on_second() {
    n=$(($(cat "$count_file") + 1))
    echo "$n" > "$count_file"
    [ "$n" -ge 2 ]
  }
  run pc_retry 5 0 -- succeed_on_second
  [ "$status" -eq 0 ]
  [ "$(cat "$count_file")" = 2 ]
}

@test "pc_retry exports PC_RETRY_ATTEMPT/PC_RETRY_ATTEMPTS during the call and unsets them after" {
  seen_file="$BATS_TEST_TMPDIR/seen"
  check_and_fail_once() {
    echo "attempt=${PC_RETRY_ATTEMPT:-unset} attempts=${PC_RETRY_ATTEMPTS:-unset}" >> "$seen_file"
    [ "${PC_RETRY_ATTEMPT:-}" = 2 ]
  }
  pc_retry 2 0 -- check_and_fail_once || true
  [ "$(sed -n 1p "$seen_file")" = "attempt=1 attempts=2" ]
  [ "$(sed -n 2p "$seen_file")" = "attempt=2 attempts=2" ]
  [ -z "${PC_RETRY_ATTEMPT:-}" ]
  [ -z "${PC_RETRY_ATTEMPTS:-}" ]
}

@test "a status write outside any pc_retry block never sees stale attempt values" {
  fails_once() { [ -n "${PC_RETRY_ATTEMPT:-}" ] || return 1; return 1; }
  pc_retry 2 0 -- fails_once || true
  [ -z "${PC_RETRY_ATTEMPT:-}" ]
  [ -z "${PC_RETRY_ATTEMPTS:-}" ]
}
