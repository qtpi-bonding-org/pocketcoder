#!/bin/sh
set -eu

# Publish Caddy's local certificate state into the existing public snapshot.
# This intentionally never exposes Caddy's private-key path or key material.
status_file=${POCKETCODER_STATUS_FILE:-/var/lib/pocketcoder/public/status.json}
domain=${1:-}
status_dir=$(dirname -- "$status_file")
install -d -m 0755 "$status_dir"

state=pending
issuer=
expires=
reason='certificate has not been issued yet'
cert=
for root in /var/lib/caddy/.local/share/caddy/certificates /var/lib/caddy/.config/caddy/certificates /var/lib/caddy/.local/share/caddy /var/lib/caddy/.config/caddy; do
  [ -n "$domain" ] || continue
  candidate=$(find "$root" -type f -path "*/$domain/$domain.crt" -print -quit 2>/dev/null || true)
  if [ -n "$candidate" ]; then cert=$candidate; break; fi
done

if [ -n "$cert" ] && command -v openssl >/dev/null 2>&1; then
  if details=$(openssl x509 -in "$cert" -noout -issuer -enddate 2>/dev/null); then
    issuer=$(printf '%s\n' "$details" | sed -n 's/^issuer=//p')
    expires=$(printf '%s\n' "$details" | sed -n 's/^notAfter=//p')
    issuer_lc=$(printf '%s' "$issuer" | tr '[:upper:]' '[:lower:]')
    if printf '%s' "$issuer_lc" | grep -Eq 'staging|fake|internal'; then
      state=failed
      reason='Caddy has a non-production or staging certificate'
    elif printf '%s' "$issuer_lc" | grep -Eq "let.s encrypt|zerossl"; then
      state=ready
      reason='browser-trusted certificate is present in Caddy storage'
    else
      state=unknown
      reason='Caddy certificate issuer is not recognized as a production public CA'
    fi
  else
    state=failed
    reason='Caddy certificate record is unreadable'
  fi
fi

if command -v journalctl >/dev/null 2>&1 && journalctl -u caddy.service --since '8 days ago' --no-pager 2>/dev/null | grep -Eiq '429|too many certificates|rate limit|rate-limited'; then
  state=rate_limited
  reason='certificate authority rejected issuance because the hostname is rate-limited'
fi

exec 9>>"$status_dir/.status.lock"
flock 9
existing='{}'
if [ -s "$status_file" ] && jq -e . "$status_file" >/dev/null 2>&1; then existing=$(cat "$status_file"); fi
tmp=$(mktemp -p "$status_dir" .status.XXXXXX)
jq --argjson schema 3 --arg state "$state" --arg hostname "$domain" \
  --arg issuer "$issuer" --arg expiresAt "$expires" --arg reason "$reason" \
  '(. + {schema:$schema,tls:{state:$state,hostname:(if $hostname == "" then null else $hostname end),
    issuer:(if $issuer == "" then null else $issuer end),
    expiresAt:(if $expiresAt == "" then null else $expiresAt end),reason:$reason}})' \
  <<<"$existing" > "$tmp"
chmod 0644 "$tmp"
mv -f "$tmp" "$status_file"
flock -u 9
exec 9>&-
