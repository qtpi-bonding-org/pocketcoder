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

# dispatch_ssh_command <name> [shell_env_prefix]
# (stdin is inherited from the caller's stdin)
# Runs a reviewed RootSshCommand through the shared Dart CLI.
dispatch_ssh_command() {
  local name=$1 shell_env_prefix=${2:-} flutter_bin dart_bin repo_root fingerprint_line fingerprint
  flutter_bin=$(resolve_flutter_bin) || return 1
  # `flutter dart run ...` isn't a real subcommand on every Flutter
  # release -- confirmed live: "Could not find a command named 'dart'" on
  # 3.47.0-0.4.pre (beta). The Dart SDK bundled with any Flutter install
  # ships a sibling `dart` executable in the same bin/ directory; invoke
  # that directly instead of going through flutter's own CLI dispatch.
  dart_bin="$(dirname "$flutter_bin")/dart"
  repo_root=$(CDPATH= cd -- "$vps_dir/../../../.." && pwd)
  # dartssh2's onVerifyHostKey expects a SHA256 fingerprint (the literal
  # "SHA256:<base64>" string), not MD5 -- confirmed live: an MD5
  # fingerprint here made every dispatched command fail to connect,
  # closed before ever attempting authentication.
  fingerprint_line=$(ssh-keygen -E sha256 -lf "$VPS_KNOWN_HOSTS" 2>/dev/null | head -1)
  fingerprint=$(printf '%s' "$fingerprint_line" | grep -o 'SHA256:[A-Za-z0-9+/]*')

  if [ -z "$fingerprint" ]; then
    echo "could not derive a host key fingerprint from $VPS_KNOWN_HOSTS" >&2
    return 1
  fi
  (
    cd "$repo_root/client/packages/pocketcoder_flutter" || exit 1
    "$flutter_bin" pub get >/dev/null 2>&1 || exit 1
    if [ -n "$shell_env_prefix" ]; then
      "$dart_bin" run bin/root_ssh_command.dart \
        --command "$name" --host "$VPS_HOST" --key "$VPS_KEY_PATH" \
        --host-key-type "ssh-ed25519" \
        --host-key-fingerprint "$fingerprint" \
        --shell-env-prefix "$shell_env_prefix"
    else
      "$dart_bin" run bin/root_ssh_command.dart \
        --command "$name" --host "$VPS_HOST" --key "$VPS_KEY_PATH" \
        --host-key-type "ssh-ed25519" \
        --host-key-fingerprint "$fingerprint"
    fi
  )
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
#
# Retries only a connection-level failure (rc=255 with a recognized
# "never even reached the remote command" stderr pattern) a few times
# with a short backoff -- confirmed live: a freshly-provisioned box's
# public IP draws internet-wide SSH scanner traffic within minutes, which
# contends with OpenSSH's own per-source connection penalties
# (srclimit_penalise) and legitimate reconnection attempts alike, causing
# transient "Connection refused"/"Connection reset by peer" failures that
# have nothing to do with the box's actual state. Never retries a
# same-rc-255 auth failure or (any other rc) a real remote command
# failure -- only this specific, narrowly-matched connectivity class.
ssh_exec() {
  local timeout_seconds=$1 script=$2
  local stderr_file rc options attempt
  options=$(_ssh_options)
  for attempt in 1 2 3 4; do
    stderr_file=$(mktemp "${TMPDIR:-/tmp}/pocketcoder-ssh-err.XXXXXX")
    # shellcheck disable=SC2086
    with_timeout "$timeout_seconds" ssh $options "root@$VPS_HOST" "$script" \
      2>"$stderr_file"
    rc=$?
    if grep -q 'REMOTE HOST IDENTIFICATION HAS CHANGED' "$stderr_file"; then
      echo "host key changed for $VPS_HOST — refusing to continue" >&2
      rm -f "$stderr_file"
      return 3
    fi
    if [ "$rc" -eq 255 ] && grep -Eq \
        'Connection refused|Connection reset by peer|kex_exchange_identification' \
        "$stderr_file"; then
      if [ "$attempt" -lt 4 ]; then
        echo "ssh_exec: transient connection failure (attempt $attempt), retrying in 5s" >&2
        rm -f "$stderr_file"
        sleep 5
        continue
      fi
    fi
    break
  done
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

VPS_REDACTION_READY=0
VPS_REDACTION_VALUES=

# load_redaction_dictionary — pull every value out of the box's runtime.env
# so it can be scrubbed from captured output. Fetched over the same channel
# being redacted, so failure must fail closed, never open.
load_redaction_dictionary() {
  local env_body
  if ! env_body=$(ssh_exec 30 'cat /var/lib/pocketcoder/config/runtime.env 2>/dev/null'); then
    VPS_REDACTION_READY=0
    return 1
  fi
  VPS_REDACTION_VALUES=$(printf '%s\n' "$env_body" |
    sed -n 's/^[A-Za-z_][A-Za-z0-9_]*=//p' |
    sed 's/^"//; s/"$//' |
    awk 'length($0) >= 8')
  VPS_REDACTION_READY=1
  return 0
}

redact() {
  local text=$1
  if [ "$VPS_REDACTION_READY" != 1 ]; then
    printf '%s' "[output suppressed: redaction dictionary unavailable]"
    return 0
  fi
  # Replace each dictionary value, then structural secrets. The heredoc (not
  # a pipe) keeps the loop in the current shell so $scrubbed survives it.
  local scrubbed=$text
  local value
  while IFS= read -r value; do
    [ -n "$value" ] || continue
    scrubbed=${scrubbed//"$value"/[REDACTED]}
  done <<EOF
$VPS_REDACTION_VALUES
EOF
  scrubbed=$(printf '%s' "$scrubbed" |
    sed -E 's/(Bearer|bearer) [A-Za-z0-9._~+\/=-]+/\1 [REDACTED]/g' |
    sed -E '/-----BEGIN [A-Z ]*PRIVATE KEY-----/,/-----END [A-Z ]*PRIVATE KEY-----/c\
[REDACTED]')
  printf '%s' "${scrubbed:0:${VPS_DETAIL_CAP:-2000}}"
}

boot_id_now() {
  ssh_exec 30 'cat /proc/sys/kernel/random/boot_id'
}

container_started_at() {
  ssh_exec 30 "docker inspect --format '{{.State.StartedAt}}' $1"
}

container_health() {
  ssh_exec 30 "docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $1"
}

# The services a healthy NixOS deployment always runs. Verified against the
# live box; optional profiles (ntfy, tailscale, caddy-in-compose) excluded.
expected_containers() {
  cat <<'EOF'
pocketcoder-pocketbase
pocketcoder-memory
pocketcoder-mcp-gateway
pocketcoder-sqlpage
pocketcoder-docker-proxy-mcp
pocketcoder-docker-proxy-write
EOF
}

# Reachability before DNS settles: pin the hostname to the known IP.
https_probe_pinned() {
  local hostname=$1 ip=$2 path=$3
  curl --fail --silent --show-error --connect-timeout 5 --max-time 15 \
    --resolve "$hostname:443:$ip" "https://$hostname$path"
}

# The real edge: ordinary DNS, real certificate validation, no --insecure.
https_probe_public() {
  local hostname=$1 path=$2
  curl --fail --silent --show-error --connect-timeout 5 --max-time 15 \
    "https://$hostname$path"
}

tls_expiry_days() {
  local hostname=$1 ip=$2 end_date end_epoch
  end_date=$(echo | openssl s_client -connect "$ip:443" -servername "$hostname" 2>/dev/null |
    openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')

  [ -n "$end_date" ] || return 1
  if date -j >/dev/null 2>&1; then
    end_epoch=$(date -j -f '%b %d %T %Y %Z' "$end_date" +%s 2>/dev/null) || return 1
  else
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null) || return 1
  fi
  echo $(( (end_epoch - $(date +%s)) / 86400 ))
}

# start_memory_sampler <run_dir>
start_memory_sampler() {
  local run_dir=$1 repo_root
  repo_root=$(CDPATH= cd -- "$vps_dir/../../../.." && pwd)
  # /usr/local/sbin doesn't exist on this NixOS image (confirmed live:
  # scp fails with "No such file or directory") -- NixOS's filesystem
  # layout has no FHS /usr/local by default. /root always exists;
  # /var/lib/pocketcoder is already relied on by this same function for
  # the phase/stop-file paths below, so it's already guaranteed present.
  local remote_script=/root/pocketcoder-live-memory
  scp -q -i "$VPS_KEY_PATH" -o UserKnownHostsFile="$run_dir/known_hosts" \
    "$repo_root/deploy/release-manager/tests/sample-live-memory.sh" \
    "root@$VPS_HOST:$remote_script" || return 1
  ssh_exec 15 "chmod 0555 $remote_script; \
    rm -f /var/lib/pocketcoder/live-memory.stop; \
    nohup $remote_script /var/lib/pocketcoder/live-memory.tsv \
      /var/lib/pocketcoder/live-test-phase \
      /var/lib/pocketcoder/live-memory.stop 5 \
      >/var/lib/pocketcoder/live-memory.log 2>&1 &" || return 1
}

# collect_memory_sampler <run_dir>
collect_memory_sampler() {
  local run_dir=$1
  ssh_exec 15 "touch /var/lib/pocketcoder/live-memory.stop; sleep 3" || return 0
  scp -q -i "$VPS_KEY_PATH" -o UserKnownHostsFile="$run_dir/known_hosts" \
    "root@$VPS_HOST:/var/lib/pocketcoder/live-memory.tsv" \
    "$run_dir/memory.tsv" || return 0
  python3 - "$run_dir/memory.tsv" "$run_dir/memory-summary.json" <<'PYEOF'
import sys, csv, json
maxima = {}
with open(sys.argv[1]) as f:
    reader = csv.reader(f, delimiter='\t')
    next(reader, None)
    for row in reader:
        if len(row) != 5:
            continue
        key = f"{row[1]}/{row[2]}/{row[3]}"
        try:
            b = int(row[4])
        except ValueError:
            continue
        maxima[key] = max(maxima.get(key, 0), b)
with open(sys.argv[2], "w") as f:
    json.dump({"schemaVersion": 1, "maximumBytesByPhaseAndComponent": maxima}, f, indent=2)
PYEOF
}