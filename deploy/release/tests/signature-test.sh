#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
keys="$release_dir/fixtures/keys"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

POCKETCODER_SIGNING_KEY_FILE="$keys/test-root-private.pem" \
  "$release_dir/sign-payload.sh" "$release_dir/root-delegation.example.json" \
  root root-2026-01 "$tmp_dir/delegation.sig"
POCKETCODER_SIGNING_KEY_FILE="$keys/test-operations-private.pem" \
  "$release_dir/sign-payload.sh" "$release_dir/release-manifest.example.json" \
  release operations-2026-01 "$tmp_dir/manifest.sig"

"$release_dir/verify-signed-payload.sh" \
  "$release_dir/release-manifest.example.json" "$tmp_dir/manifest.sig" \
  "$release_dir/root-delegation.example.json" "$tmp_dir/delegation.sig" \
  "$keys/test-root-public.pem" release

jq '.serverVersion = "1.0.1"' "$release_dir/release-manifest.example.json" \
  > "$tmp_dir/changed.json"
if "$release_dir/verify-signed-payload.sh" \
    "$tmp_dir/changed.json" "$tmp_dir/manifest.sig" \
    "$release_dir/root-delegation.example.json" "$tmp_dir/delegation.sig" \
    "$keys/test-root-public.pem" release >/dev/null 2>&1; then
  echo "changed signed bytes unexpectedly verified" >&2
  exit 1
fi

jq '.keyId = "wrong-key"' "$tmp_dir/manifest.sig" > "$tmp_dir/wrong-key.sig"
if "$release_dir/verify-signed-payload.sh" \
    "$release_dir/release-manifest.example.json" "$tmp_dir/wrong-key.sig" \
    "$release_dir/root-delegation.example.json" "$tmp_dir/delegation.sig" \
    "$keys/test-root-public.pem" release >/dev/null 2>&1; then
  echo "wrong signing key unexpectedly verified" >&2
  exit 1
fi

# Exercise complete host discovery with a fake transport. The host verifies
# root delegation, pointer, immutable manifest, revocations, digest, size, and
# all three monotonic sequences independently of the app.
manifest_sha=$(sha256sum "$release_dir/release-manifest.example.json" |
  cut -d' ' -f1)
manifest_bytes=$(wc -c < "$release_dir/release-manifest.example.json" |
  tr -d ' ')
jq -n --arg sha "$manifest_sha" --argjson bytes "$manifest_bytes" '
  {schemaVersion:1,channel:"stable",sequence:1,
   promotedAt:"2026-08-12T20:00:00Z",
   manifest:{url:("https://fixtures.test/v1/releases/"+$sha+".json"),
     sha256:$sha,downloadBytes:$bytes,
     signature:{algorithm:"ed25519",keyId:"operations-2026-01",
       url:("https://fixtures.test/v1/releases/"+$sha+".json.sig")}},
   signature:{algorithm:"ed25519",keyId:"operations-2026-01",
     url:"https://fixtures.test/v1/channels/stable/1.sig"}}
' > "$tmp_dir/channel.json"
jq -n '
  {schemaVersion:1,sequence:1,publishedAt:"2026-08-12T21:00:00Z",
   revokedReleases:{}}
' > "$tmp_dir/revocations.json"
POCKETCODER_SIGNING_KEY_FILE="$keys/test-operations-private.pem" \
  "$release_dir/sign-payload.sh" "$tmp_dir/channel.json" channel \
  operations-2026-01 "$tmp_dir/channel.sig"
POCKETCODER_SIGNING_KEY_FILE="$keys/test-operations-private.pem" \
  "$release_dir/sign-payload.sh" "$tmp_dir/revocations.json" revocation \
  operations-2026-01 "$tmp_dir/revocations.sig"

fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/curl" <<'EOF'
#!/bin/sh
output=
url=
while test "$#" -gt 0; do
  case "$1" in
    -o) output=$2; shift 2 ;;
    --max-filesize|--max-time|--retry|--retry-delay) shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
case "$url" in
  */delegations/root.json) source=$FAKE_DELEGATION ;;
  */delegations/root.json.sig) source=$FAKE_DELEGATION_SIGNATURE ;;
  */channels/*.json) source=$FAKE_CHANNEL ;;
  */channels/*/*.sig) source=$FAKE_CHANNEL_SIGNATURE ;;
  */releases/*.json.sig) source=$FAKE_MANIFEST_SIGNATURE ;;
  */releases/*.json) source=$FAKE_MANIFEST ;;
  */revocations/releases.json) source=$FAKE_REVOCATIONS ;;
  */revocations/releases/1.sig) source=$FAKE_REVOCATION_SIGNATURE ;;
  *) exit 22 ;;
esac
cp "$source" "$output"
EOF
chmod +x "$fake_bin/curl"

run_resolver() {
  resolved_channel=${1:-stable}
  resolved_state=${2:-$tmp_dir/state}
  channel_payload=${3:-$tmp_dir/channel.json}
  channel_signature=${4:-$tmp_dir/channel.sig}
  revocation_payload=${5:-$tmp_dir/revocations.json}
  revocation_signature=${6:-$tmp_dir/revocations.sig}
  delegation_payload=${7:-$release_dir/root-delegation.example.json}
  delegation_signature=${8:-$tmp_dir/delegation.sig}
  PATH="$fake_bin:$PATH" \
  RELEASE_BASE=https://fixtures.test \
  POCKETCODER_ROOT_PUBLIC_KEY="$keys/test-root-public.pem" \
  POCKETCODER_VERIFY_SCRIPT="$release_dir/verify-signed-payload.sh" \
  FAKE_DELEGATION="$delegation_payload" \
  FAKE_DELEGATION_SIGNATURE="$delegation_signature" \
  FAKE_CHANNEL="$channel_payload" \
  FAKE_CHANNEL_SIGNATURE="$channel_signature" \
  FAKE_MANIFEST="$release_dir/release-manifest.example.json" \
  FAKE_MANIFEST_SIGNATURE="$tmp_dir/manifest.sig" \
  FAKE_REVOCATIONS="$revocation_payload" \
  FAKE_REVOCATION_SIGNATURE="$revocation_signature" \
    "$release_dir/../scripts/resolve-signed-release.sh" "$resolved_channel" \
      "$resolved_state" "$resolved_state/resolved"
}

run_resolver stable "$tmp_dir/state" > "$tmp_dir/resolution.json"
test "$(jq -r '.manifestSha256' "$tmp_dir/resolution.json")" = \
  "$manifest_sha"
jq '."channel-stable" = 2' "$tmp_dir/state/sequences.json" \
  > "$tmp_dir/state/sequences.next"
mv "$tmp_dir/state/sequences.next" "$tmp_dir/state/sequences.json"
if run_resolver stable "$tmp_dir/state" >/dev/null 2>&1; then
  echo "replayed channel pointer unexpectedly resolved" >&2
  exit 1
fi

# A payload for another channel is validly signed but must not satisfy stable.
jq '.channel = "beta"' "$tmp_dir/channel.json" > "$tmp_dir/wrong-channel.json"
POCKETCODER_SIGNING_KEY_FILE="$keys/test-operations-private.pem" \
  "$release_dir/sign-payload.sh" "$tmp_dir/wrong-channel.json" channel \
  operations-2026-01 "$tmp_dir/wrong-channel.sig"
if run_resolver stable "$tmp_dir/wrong-channel-state" \
    "$tmp_dir/wrong-channel.json" "$tmp_dir/wrong-channel.sig" \
    >/dev/null 2>&1; then
  echo "wrong-channel pointer unexpectedly resolved" >&2
  exit 1
fi

# Persisted root and revocation floors independently reject lower metadata.
mkdir -p "$tmp_dir/root-replay-state"
jq -n '{delegation:2,revocation:1,"channel-stable":1}' \
  > "$tmp_dir/root-replay-state/sequences.json"
if run_resolver stable "$tmp_dir/root-replay-state" >/dev/null 2>&1; then
  echo "lower root delegation unexpectedly resolved" >&2
  exit 1
fi
mkdir -p "$tmp_dir/revocation-replay-state"
jq -n '{delegation:1,revocation:2,"channel-stable":1}' \
  > "$tmp_dir/revocation-replay-state/sequences.json"
if run_resolver stable "$tmp_dir/revocation-replay-state" \
    >/dev/null 2>&1; then
  echo "lower revocation metadata unexpectedly resolved" >&2
  exit 1
fi

# Resolving beta must preserve the already accepted stable sequence.
jq '.channel = "beta" |
  .signature.url = "https://fixtures.test/v1/channels/beta/1.sig"' \
  "$tmp_dir/channel.json" > "$tmp_dir/beta-channel.json"
POCKETCODER_SIGNING_KEY_FILE="$keys/test-operations-private.pem" \
  "$release_dir/sign-payload.sh" "$tmp_dir/beta-channel.json" channel \
  operations-2026-01 "$tmp_dir/beta-channel.sig"
rm -rf "$tmp_dir/channel-state"
run_resolver stable "$tmp_dir/channel-state" >/dev/null
run_resolver beta "$tmp_dir/channel-state" "$tmp_dir/beta-channel.json" \
  "$tmp_dir/beta-channel.sig" >/dev/null
test "$(jq -r '."channel-stable"' \
  "$tmp_dir/channel-state/sequences.json")" -eq 1
test "$(jq -r '."channel-beta"' \
  "$tmp_dir/channel-state/sequences.json")" -eq 1

echo "release signature tests passed"
