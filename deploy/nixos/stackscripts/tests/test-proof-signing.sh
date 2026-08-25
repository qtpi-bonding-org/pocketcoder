#!/bin/sh
# Unit test for pocketcoder-image-installer.sh's proof-signing logic --
# the ONE language implementation of the image-relay auth protocol that
# had zero automated test coverage (Go, TypeScript, and Dart all got
# real tests; this shell logic only ever got human code review). The
# lines below are copy-pasted byte-for-byte from the installer script
# (lines 34-78 as of the commit this test was added in) rather than
# reimplemented, specifically so a bug in the real logic shows up here
# too -- keep them in sync if the installer script's signing logic ever
# changes; a diff between the two is itself a signal something drifted.
#
# Run manually: ./test-proof-signing.sh
set -eu

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}
require_command openssl
require_command xxd
require_command base64
require_command python3

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/proof-signing-test.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Fixture: a fresh P-256 box key, PKCS8 DER, base64 -- matches what
# CredentialService/ProofSigningService actually deliver in production. ---
openssl ecparam -name prime256v1 -genkey -noout -out "$work_dir/box-key.pem"
BOX_PRIVATE_KEY_PKCS8=$(openssl pkcs8 -topk8 -nocrypt -in "$work_dir/box-key.pem" -outform DER | base64 | tr -d '\n')
IMAGE_URL="https://images.relay.pocketcoder.org/v1/artifacts/$(printf '%040d' 1 | sha256sum | cut -c1-64).img.gz"

# ============================================================
# BEGIN: copy-pasted from pocketcoder-image-installer.sh verbatim
# ============================================================
printf '%s' "$BOX_PRIVATE_KEY_PKCS8" | base64 -d > "$work_dir/box_key.der"
openssl pkey -inform DER -in "$work_dir/box_key.der" -pubout -outform DER -out "$work_dir/box_pub.der" 2>/dev/null

tail -c 65 "$work_dir/box_pub.der" > "$work_dir/box_pub_point.bin"
tail -c 64 "$work_dir/box_pub_point.bin" > "$work_dir/box_pub_xy.bin"
head -c 32 "$work_dir/box_pub_xy.bin" > "$work_dir/box_pub_x.bin"
tail -c 32 "$work_dir/box_pub_xy.bin" > "$work_dir/box_pub_y.bin"

b64u_file() { base64 < "$1" | tr '+/' '-_' | tr -d '=' | tr -d '\n'; }
b64u_str() { printf '%s' "$1" | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n'; }

BOX_PUB_X=$(b64u_file "$work_dir/box_pub_x.bin")
BOX_PUB_Y=$(b64u_file "$work_dir/box_pub_y.bin")

TRUSTED_ORIGIN="https://images.relay.pocketcoder.org"
IMAGE_URL_PATH=$(printf '%s' "$IMAGE_URL" | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://[^/]+##; s#[?#].*$##')
PROOF_HTU="${TRUSTED_ORIGIN}${IMAGE_URL_PATH}"

PROOF_HEADER=$(b64u_str "$(printf '{\"alg\":\"ES256\",\"typ\":\"dpop+jwt\",\"jwk\":{\"kty\":\"EC\",\"crv\":\"P-256\",\"x\":\"%s\",\"y\":\"%s\"}}' "$BOX_PUB_X" "$BOX_PUB_Y")")
PROOF_JTI=$(head -c 16 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=')
PROOF_IAT=$(date +%s)
PROOF_CLAIMS=$(b64u_str "$(printf '{\"htm\":\"GET\",\"htu\":\"%s\",\"iat\":%s,\"jti\":\"%s\"}' "$PROOF_HTU" "$PROOF_IAT" "$PROOF_JTI")")
PROOF_SIGNING_INPUT="${PROOF_HEADER}.${PROOF_CLAIMS}"

printf '%s' "$PROOF_SIGNING_INPUT" | openssl dgst -sha256 -sign "$work_dir/box_key.der" -keyform DER -out "$work_dir/proof_sig.der"
SIG_HEX=$(xxd -p -c 999 "$work_dir/proof_sig.der" | tr -d '\n')
RLEN=$((16#${SIG_HEX:6:2}))
R_HEX=${SIG_HEX:8:$((RLEN * 2))}
S_TAG_OFFSET=$((8 + RLEN * 2))
SLEN=$((16#${SIG_HEX:$((S_TAG_OFFSET + 2)):2}))
S_HEX=${SIG_HEX:$((S_TAG_OFFSET + 4)):$((SLEN * 2))}
[ "$RLEN" -eq 33 ] && R_HEX=${R_HEX:2}
[ "$SLEN" -eq 33 ] && S_HEX=${S_HEX:2}
R_HEX=$(printf '%064s' "$R_HEX" | tr ' ' '0')
S_HEX=$(printf '%064s' "$S_HEX" | tr ' ' '0')
PROOF_SIG=$(printf '%s' "${R_HEX}${S_HEX}" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=')
PROOF="${PROOF_SIGNING_INPUT}.${PROOF_SIG}"
# ============================================================
# END: copy-pasted from pocketcoder-image-installer.sh
# ============================================================

echo "Generated PROOF (length $(printf '%s' "$PROOF" | wc -c | tr -d ' ') bytes):"
printf '%s\n' "$PROOF"
echo

# --- Assertion 1: exactly 3 dot-separated compact-JWS parts, and the
# ENTIRE value is pure base64url+dots -- no embedded newline, no stray
# control character. This is the exact class of bug that would corrupt
# an HTTP header value and produce a transport-level (not application-
# level) failure, indistinguishable from network flakiness without this
# check. ---
part_count=$(printf '%s' "$PROOF" | awk -F'.' '{print NF}')
[ "$part_count" -eq 3 ] || fail "PROOF has $part_count dot-separated parts, expected 3"
printf '%s' "$PROOF" | grep -Eq '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' \
  || fail "PROOF contains characters outside the base64url+dot set (would corrupt an HTTP header) -- raw bytes: $(printf '%s' "$PROOF" | xxd | head -20)"
[ "$(printf '%s' "$PROOF" | wc -l)" -eq 0 ] || fail "PROOF contains an embedded newline"

# --- Assertion 2: header and claims are each valid JSON with the
# expected shape. ---
python3 - "$PROOF_HEADER" "$PROOF_CLAIMS" <<'PYEOF'
import base64, json, sys

def b64u_decode(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))

header = json.loads(b64u_decode(sys.argv[1]))
claims = json.loads(b64u_decode(sys.argv[2]))

assert header["alg"] == "ES256", header
assert header["typ"] == "dpop+jwt", header
assert header["jwk"]["kty"] == "EC", header
assert header["jwk"]["crv"] == "P-256", header
assert claims["htm"] == "GET", claims
assert claims["htu"].startswith("https://images.relay.pocketcoder.org/"), claims
assert isinstance(claims["iat"], int), claims
assert len(claims["jti"]) >= 16, claims
print("header/claims shape OK")
PYEOF

# --- Assertion 3: the signature actually verifies against the box's
# real public key using an INDEPENDENT verifier -- reconstructs a public
# key DER from ONLY BOX_PUB_X/BOX_PUB_Y (the values the shell logic
# above computed), converts the raw r||s signature back to DER, and
# calls a separate `openssl dgst -verify` invocation. Proves the DER R/S
# extraction byte-offset math produced a genuinely valid signature over
# the exact signing input, not just something that looks like one.
verify_sig_hex_to_der() {
  # Reverse of the extraction above: raw r||s (32+32 bytes) -> minimal
  # DER ECDSA-Sig-Value (SEQUENCE of two INTEGERs), re-adding a leading
  # 0x00 pad byte whenever the top bit of a 32-byte limb is set (DER
  # INTEGER must not be interpreted as negative).
  python3 -c "
import sys
r = bytes.fromhex(sys.argv[1])
s = bytes.fromhex(sys.argv[2])
def enc_int(b):
    b = b.lstrip(b'\\x00') or b'\\x00'
    if b[0] & 0x80:
        b = b'\\x00' + b
    return b'\\x02' + bytes([len(b)]) + b
body = enc_int(r) + enc_int(s)
sys.stdout.buffer.write(b'\\x30' + bytes([len(body)]) + body)
" "$1" "$2" > "$work_dir/reconstructed_sig.der"
}

verify_sig_hex_to_der "$R_HEX" "$S_HEX"

# base64url is unpadded by definition; standard base64 decoders
# (including macOS's BSD `base64 -d`, used to develop this test) require
# padding restored before they'll decode it correctly.
b64u_pad() {
  value="$1"
  rem=$(( ${#value} % 4 ))
  case "$rem" in
    2) printf '%s==' "$value" ;;
    3) printf '%s=' "$value" ;;
    *) printf '%s' "$value" ;;
  esac
}

spki_prefix_hex="3059301306072a8648ce3d020106082a8648ce3d03010703420004"
x_hex=$(b64u_pad "$BOX_PUB_X" | tr '_-' '/+' | base64 -d 2>/dev/null | xxd -p -c 999)
y_hex=$(b64u_pad "$BOX_PUB_Y" | tr '_-' '/+' | base64 -d 2>/dev/null | xxd -p -c 999)
printf '%s' "${spki_prefix_hex}${x_hex}${y_hex}" | xxd -r -p > "$work_dir/reconstructed_pub.der"
openssl pkey -pubin -inform DER -in "$work_dir/reconstructed_pub.der" \
  -pubout -outform PEM -out "$work_dir/reconstructed_pub.pem" 2>/dev/null \
  || fail "could not import reconstructed public key from BOX_PUB_X/BOX_PUB_Y"

printf '%s' "$PROOF_SIGNING_INPUT" | openssl dgst -sha256 \
  -verify "$work_dir/reconstructed_pub.pem" \
  -signature "$work_dir/reconstructed_sig.der" \
  || fail "signature does not verify against the box's own public key"
echo "signature verification OK (independent DER reconstruction + openssl verify)"

echo
echo "ALL PROOF-SIGNING TESTS PASSED"
