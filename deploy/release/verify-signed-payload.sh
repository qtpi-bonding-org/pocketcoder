#!/bin/sh
set -eu

payload=${1:?payload path is required}
envelope=${2:?signature envelope path is required}
delegation=${3:?root delegation path is required}
delegation_envelope=${4:?root delegation signature envelope is required}
root_public_key=${5:?root public key path is required}
expected_role=${6:?expected signing role is required}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "signature verification: $1" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

decode_base64() {
  input=$1
  output=$2
  if printf '%s' "$input" | base64 --decode > "$output" 2>/dev/null; then
    return
  fi
  printf '%s' "$input" | base64 -D > "$output"
}

verify_envelope() {
  signed_payload=$1
  signed_envelope=$2
  public_key=$3
  role=$4
  expected_key_id=${5:-}

  jq -e --arg role "$role" --arg keyId "$expected_key_id" '
    .schemaVersion == 1 and .algorithm == "ed25519" and
    .role == $role and
    ($keyId == "" or .keyId == $keyId) and
    (.payloadSha256 | test("^[0-9a-f]{64}$")) and
    (.signature | type == "string" and length > 0)
  ' "$signed_envelope" >/dev/null || fail "invalid $role envelope"

  expected_sha=$(jq -r '.payloadSha256' "$signed_envelope")
  actual_sha=$(sha256_file "$signed_payload")
  test "$expected_sha" = "$actual_sha" || fail "$role payload digest mismatch"
  decode_base64 "$(jq -r '.signature' "$signed_envelope")" \
    "$tmp_dir/$role.signature"
  openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in "$signed_payload" -sigfile "$tmp_dir/$role.signature" >/dev/null 2>&1 ||
    fail "$role signature is invalid"
}

root_key_id=$(jq -er '.rootKeyId' "$delegation") || fail "invalid root delegation"
verify_envelope "$delegation" "$delegation_envelope" "$root_public_key" root \
  "$root_key_id"
if test "$expected_role" = root; then
  exit 0
fi

key_id=$(jq -r '.keyId' "$envelope")
now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
public_key_b64=$(jq -er --arg role "$expected_role" --arg keyId "$key_id" \
  --arg now "$now" '
  select((.revokedKeyIds | index($keyId)) == null) |
  .roles[$role][] |
  select(.keyId == $keyId and .algorithm == "ed25519") |
  select(.validFrom <= $now and (.validUntil == null or .validUntil >= $now)) |
  .publicKey
' "$delegation") || fail "no active delegation for $expected_role/$key_id"

decode_base64 "$public_key_b64" "$tmp_dir/delegated-public.der"
openssl pkey -pubin -inform DER -in "$tmp_dir/delegated-public.der" \
  -out "$tmp_dir/delegated-public.pem" >/dev/null 2>&1 ||
  fail "delegated public key is invalid"
verify_envelope "$payload" "$envelope" "$tmp_dir/delegated-public.pem" \
  "$expected_role" "$key_id"
