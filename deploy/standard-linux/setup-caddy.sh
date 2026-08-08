#!/usr/bin/env bash
# Install and configure native Caddy for the standard Ubuntu/Debian path.
# This mirrors the NixOS deployment: Caddy owns ports 80/443 and proxies the
# loopback-only PocketBase listener using an automatically derived sslip.io name.

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Native Caddy setup supports Linux VPS hosts only." >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root, for example: sudo $0" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the Linux distribution." >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *)
    echo "Unsupported distribution: ${ID:-unknown}. This supports Ubuntu/Debian." >&2
    exit 1
    ;;
esac

if ! command -v caddy >/dev/null 2>&1; then
  apt-get update
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
fi

PUBLIC_IP=""
for attempt in 1 2 3 4 5; do
  for url in https://ifconfig.me/ip https://api.ipify.org https://icanhazip.com; do
    candidate=$(curl -4sf --max-time 10 "$url" | tr -d '[:space:]' || true)
    if [[ "$candidate" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      PUBLIC_IP="$candidate"
      break 2
    fi
  done
  echo "Attempt $attempt: could not determine a public IPv4 address; retrying in 5s..." >&2
  sleep 5
done

if [[ -z "$PUBLIC_IP" ]]; then
  echo "Could not determine a public IPv4 address; refusing to configure HTTPS." >&2
  exit 1
fi

IP_DASHED=${PUBLIC_IP//./-}
DOMAIN="${IP_DASHED}.sslip.io"

install -d -m 0755 /etc/caddy /etc/pocketcoder
install -d -m 0755 /var/lib/pocketcoder/public
cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
  handle /_pocketcoder/status.json* {
    uri strip_prefix /_pocketcoder
    root * /var/lib/pocketcoder/public
    file_server
  }
  reverse_proxy 127.0.0.1:8090
}
EOF
chmod 0644 /etc/caddy/Caddyfile

cat > /etc/pocketcoder/domain.env <<EOF
BASE_DOMAIN=${DOMAIN}
PUBLIC_IP=${PUBLIC_IP}
PB_URL=https://${DOMAIN}
EOF
chmod 0644 /etc/pocketcoder/domain.env

caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable --now caddy
systemctl restart caddy

echo "Native Caddy configured for https://${DOMAIN}"
