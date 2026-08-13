#!/bin/sh
set -eu

payload=${1:?payload path is required}
role=${2:?signing role is required}
key_id=${3:?signing key ID is required}
output=${4:?signature envelope output path is required}

case "$role" in
  root | release | channel | metadata | revocation) ;;
  *) echo "unsupported signing role: $role" >&2; exit 1 ;;
esac
case "$key_id" in
  '' | *[!a-z0-9-]*) echo "invalid signing key ID" >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
key_file=${POCKETCODER_SIGNING_KEY_FILE:-}
if test -z "$key_file"; then
  test -n "${POCKETCODER_SIGNING_KEY_B64:-}" || {
    echo "POCKETCODER_SIGNING_KEY_FILE or POCKETCODER_SIGNING_KEY_B64 is required" >&2
    exit 1
  }
  key_file="$tmp_dir/private-key.pem"
  if printf '%s' "$POCKETCODER_SIGNING_KEY_B64" | base64 --decode \
      > "$key_file" 2>/dev/null; then
    :
  else
    printf '%s' "$POCKETCODER_SIGNING_KEY_B64" | base64 -D > "$key_file"
  fi
  chmod 0600 "$key_file"
fi

openssl pkeyutl -sign -rawin -inkey "$key_file" \
  -in "$payload" -out "$tmp_dir/signature.bin"
if command -v sha256sum >/dev/null 2>&1; then
  payload_sha=$(sha256sum "$payload" | cut -d' ' -f1)
else
  payload_sha=$(shasum -a 256 "$payload" | cut -d' ' -f1)
fi
signature=$(base64 < "$tmp_dir/signature.bin" | tr -d '\n')

jq -n --arg role "$role" --arg keyId "$key_id" \
  --arg payloadSha256 "$payload_sha" --arg signature "$signature" '
  {
    schemaVersion: 1,
    algorithm: "ed25519",
    role: $role,
    keyId: $keyId,
    payloadSha256: $payloadSha256,
    signature: $signature
  }
' > "$output"
