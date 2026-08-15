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

VPS_HOST=
VPS_KEY_PATH=
VPS_KNOWN_HOSTS=

vps_connect() {
  VPS_HOST=$1
  VPS_KEY_PATH=$2
  VPS_KNOWN_HOSTS=$3
}

# pin_host_key — trust on first use. The Aeroform handoff carries no host
# key, so capture it once and pin it for the rest of the run. Host keys live
# on the persistent root disk and survive reboot, so this holds across the
# reboot phase.
pin_host_key() {
  local deadline=${1:-180}
  retry_until "$deadline" 5 sh -c \
    "ssh-keyscan -T 10 -t ed25519 '$VPS_HOST' 2>/dev/null | grep -q ." || return 1
  ssh-keyscan -T 10 -t ed25519 "$VPS_HOST" 2>/dev/null > "$VPS_KNOWN_HOSTS"
  [ -s "$VPS_KNOWN_HOSTS" ]
}

_ssh_options() {
  # Local liveness detection must never outlive the caller's timeout.
  printf '%s\n' \
    -i "$VPS_KEY_PATH" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$VPS_KNOWN_HOSTS" \
    -o ConnectTimeout=15 \
    -o ServerAliveInterval=5 \
    -o ServerAliveCountMax=3
}

# ssh_exec <timeout_seconds> <remote_script>
# The remote script is passed as one argument with no added wrapper, so
# nested single-quoted snippets port over unchanged.
ssh_exec() {
  local timeout_seconds=$1 script=$2
  local stderr_file rc options
  stderr_file=$(mktemp "${TMPDIR:-/tmp}/pocketcoder-ssh-err.XXXXXX")
  options=$(_ssh_options)
  # shellcheck disable=SC2086
  with_timeout "$timeout_seconds" ssh $options "root@$VPS_HOST" "$script" \
    2>"$stderr_file"
  rc=$?
  if grep -q 'REMOTE HOST IDENTIFICATION HAS CHANGED' "$stderr_file"; then
    echo "host key changed for $VPS_HOST — refusing to continue" >&2
    rm -f "$stderr_file"
    return 3
  fi
  cat "$stderr_file" >&2
  rm -f "$stderr_file"
  return "$rc"
}

# ssh_exec_detached — for commands whose SSH channel is expected to die
# mid-flight, i.e. `systemctl reboot`. Never fails the caller; all recovery
# assertions belong in the polling that follows.
ssh_exec_detached() {
  ssh_exec "$1" "$2" >/dev/null 2>&1 || true
  return 0
}