#!/bin/sh
set -eu

runtime_env=${1:?runtime environment file is required}
release=${2:?40-character release commit is required}

case "$release" in
  *[!0-9a-f]* | '')
    echo "invalid release commit: $release" >&2
    exit 1
    ;;
esac
if [ "${#release}" -ne 40 ]; then
  echo "invalid release commit: $release" >&2
  exit 1
fi
if [ ! -f "$runtime_env" ]; then
  echo "runtime environment file does not exist: $runtime_env" >&2
  exit 1
fi

append_default() {
  key=$1
  value=$2
  if ! grep -q "^$key=" "$runtime_env"; then
    printf '%s=%s\n' "$key" "$value" >> "$runtime_env"
  fi
}

random_secret() {
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
}

# POCO:BEGIN bootstrap-runtime-settings
chmod 0600 "$runtime_env"
# The boot-env blob the client builds ends its last KEY=value line with no
# trailing newline (a plain '\n'.join, not '\n'.join + trailing) -- append_default's
# `>>` would otherwise glue its first appended line onto the end of that
# last line. That corrupts the glued-onto value's own content AND breaks
# append_default's own "already present" guard for the appended key, since
# grep's `^KEY=` no longer matches a key that isn't at true line-start --
# silently re-appending (and for a random_secret value, silently rotating)
# it on every later activation. Confirmed live: this broke public_ip and
# bootstrap-recovery on a real box.
if [ -s "$runtime_env" ] && [ -n "$(tail -c1 "$runtime_env")" ]; then
  printf '\n' >> "$runtime_env"
fi
append_default POCKETBASE_SUPERUSER_EMAIL superuser@pocketcoder.local
append_default POCKETBASE_SUPERUSER_PASSWORD "$(random_secret)"
append_default AGENT_EMAIL agent@pocketcoder.local
append_default AGENT_PASSWORD "$(random_secret)"
append_default PN_RELAY_SECRET "$(random_secret)"
append_default MCP_GATEWAY_AUTH_TOKEN "$(random_secret)"
append_default POCKETCODER_SELECTED_HARNESSES goose
append_default POCKETCODER_RELEASE_STATE_DIR /var/lib/pocketcoder/release
append_default POCKETCODER_ARTIFACT_DIR /var/lib/pocketcoder/artifacts
# POCO:END bootstrap-runtime-settings

# POCO:BEGIN bootstrap-local-secrets
# Release identity is the only generated value that changes during an update.
# Owner credentials and service secrets above are retained exactly as they are.
runtime_tmp="$runtime_env.tmp.$$"
sed '/^POCKETCODER_RELEASE=/d' "$runtime_env" > "$runtime_tmp"
printf 'POCKETCODER_RELEASE=%s\n' "$release" >> "$runtime_tmp"
chmod 0600 "$runtime_tmp"
mv -f "$runtime_tmp" "$runtime_env"
# POCO:END bootstrap-local-secrets
