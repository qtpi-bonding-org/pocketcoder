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
