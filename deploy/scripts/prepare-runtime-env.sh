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

chmod 0600 "$runtime_env"
append_default POCKETBASE_SUPERUSER_EMAIL superuser@pocketcoder.local
append_default POCKETBASE_SUPERUSER_PASSWORD "$(random_secret)"
append_default AGENT_EMAIL agent@pocketcoder.local
append_default AGENT_PASSWORD "$(random_secret)"
append_default GOOSE_ACP_URL ws://goose:3000/acp
append_default PN_RELAY_SECRET "$(random_secret)"
append_default MCP_GATEWAY_AUTH_TOKEN "$(random_secret)"
append_default POCKETCODER_SELECTED_HARNESSES goose
append_default POCKETCODER_RELEASE_STATE_DIR /var/lib/pocketcoder/release
append_default POCKETCODER_ARTIFACT_DIR /var/lib/pocketcoder/artifacts

# POCO:BEGIN bootstrap-local-secrets
# Release identity is the only generated value that changes during an update.
# Owner credentials and service secrets above are retained exactly as they are.
# POCO:IMPORTANT:BEGIN
runtime_tmp="$runtime_env.tmp.$$"
sed '/^POCKETCODER_RELEASE=/d' "$runtime_env" > "$runtime_tmp"
printf 'POCKETCODER_RELEASE=%s\n' "$release" >> "$runtime_tmp"
chmod 0600 "$runtime_tmp"
mv -f "$runtime_tmp" "$runtime_env"
# POCO:IMPORTANT:END
# POCO:END bootstrap-local-secrets
