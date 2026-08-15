#!/usr/bin/env bash
# Shared primitives for the VPS suite. Sourced, never executed directly.
# Targets stock macOS bash 3.2: no associative arrays, no GNU coreutils.

# with_timeout <seconds> <command...>
# Runs the command with a wall-clock bound. Returns the command's exit code,
# or 124 if it had to be killed. Pure bash: stock macOS has no `timeout`.
with_timeout() {
  local seconds=$1
  shift
  "$@" &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$seconds" ]; then
      # The braces matter: bash announces a killed background job
      # ("Terminated: 15") when it reaps it, and that noise would otherwise
      # land in the captured phase output. Grouping the kill and the wait
      # lets one redirect suppress the notification. Verified on bash 3.2.
      { kill -TERM "$pid" 2>/dev/null
        sleep 1
        kill -KILL "$pid" 2>/dev/null
        wait "$pid"; } 2>/dev/null
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

# retry_until <deadline_seconds> <interval_seconds> <command...>
# Polls until the command succeeds or the wall-clock deadline passes.
retry_until() {
  local deadline=$1 interval=$2
  shift 2
  local started
  started=$(date +%s)
  while :; do
    if "$@"; then
      return 0
    fi
    if [ $(( $(date +%s) - started )) -ge "$deadline" ]; then
      return 1
    fi
    sleep "$interval"
  done
}