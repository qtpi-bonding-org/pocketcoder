#!/usr/bin/env bash
# The literal remote commands the app ships, mirrored from
# client/packages/pocketcoder_flutter/lib/infrastructure/os_control/
#   ssh_root_command_runner.dart
# tests/test-commands.sh asserts these still appear in that file, so drift
# fails locally instead of silently passing on a VPS.

shipped_command() {
  case $1 in
    restartPocketCoder)
      cat <<'EOF'
if [ -f /opt/pocketcoder/current/docker-compose.prebuilt.yml ]; then if docker compose version >/dev/null 2>&1; then docker compose --project-name pocketcoder --env-file /var/lib/pocketcoder/config/runtime.env -f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart; else docker-compose --project-name pocketcoder --env-file /var/lib/pocketcoder/config/runtime.env -f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart; fi; else echo "PocketCoder Compose release was not found" >&2; exit 1; fi
EOF
      ;;
    updatePocketCoder)
      cat <<'EOF'
if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; then /opt/pocketcoder/current/bin/pocketcoder-release update; else echo "PocketCoder release manager was not found" >&2; exit 1; fi
EOF
      ;;
    restartNixOs) printf '%s\n' 'systemctl reboot' ;;
    updateNixOs) printf '%s\n' 'nixos-rebuild switch --upgrade' ;;
    saveBackup) printf '%s\n' 'docker exec pocketcoder-pocketbase /app/backup_db.sh' ;;
    exportCaddyCertificate)
      cat <<'EOF'
set -eu
domain=$(sed -n 's/^BASE_DOMAIN=//p' /etc/pocketcoder/domain.env)
for root in /var/lib/caddy/.local/share/caddy/certificates /var/lib/caddy/.config/caddy/certificates /var/lib/caddy/.local/share/caddy /var/lib/caddy/.config/caddy; do
  cert=$(find "$root" -type f -path "*/$domain/$domain.crt" -print -quit 2>/dev/null || true)
  key=${cert%.crt}.key
  if [ -n "$cert" ] && [ -r "$key" ] && openssl x509 -in "$cert" -checkend 0 -noout >/dev/null 2>&1; then
    issuer=$(basename "$(dirname "$(dirname "$cert")")")
    jq -n --arg hostname "$domain" --arg issuer "$issuer" --arg cert "$(base64 -w0 "$cert" 2>/dev/null || base64 < "$cert" | tr -d '\n')" --arg key "$(base64 -w0 "$key" 2>/dev/null || base64 < "$key" | tr -d '\n')" '{hostname:$hostname,issuer:$issuer,certificatePemBase64:$cert,privateKeyPemBase64:$key}'
    exit 0
  fi
done
exit 1
EOF
      ;;
    restoreCaddyCertificate)
      cat <<'EOF'
set -eu
tmp=$(mktemp)
key_tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp.crt" "$key_tmp"' EXIT
cat > "$tmp"
domain=$(jq -r '.hostname // empty' "$tmp")
cert=$(jq -r '.certificatePemBase64 // empty' "$tmp" | base64 -d)
key=$(jq -r '.privateKeyPemBase64 // empty' "$tmp" | base64 -d)
test -n "$domain" -a -n "$cert" -a -n "$key"
case "$domain" in *[!A-Za-z0-9.-]*|'') exit 1 ;; esac
printf '%s' "$cert" > "$tmp.crt"
printf '%s' "$key" > "$key_tmp"
openssl x509 -in "$tmp.crt" -checkend 0 -noout
cert_pub=$(openssl x509 -in "$tmp.crt" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum)
key_pub=$(openssl pkey -in "$key_tmp" -pubout -outform DER | sha256sum)
test "$cert_pub" = "$key_pub"
issuer=$(jq -r '.issuer // "acme-v02.api.letsencrypt.org-directory"' "$tmp")
case "$issuer" in *[!A-Za-z0-9._-]*|'') exit 1 ;; esac
cert_dir=/var/lib/caddy/.local/share/caddy/certificates/$issuer/$domain
install -d -m 0700 "$cert_dir"
cp "$tmp.crt" "$cert_dir/$domain.crt"
cp "$key_tmp" "$cert_dir/$domain.key"
chmod 0600 "$cert_dir/$domain.key"
systemctl restart caddy
EOF
      ;;
    *) echo "unknown shipped command: $1" >&2; return 1 ;;
  esac
}
