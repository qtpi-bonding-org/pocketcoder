#!/usr/bin/env bash
# Pulls whatever Caddy certificate material exists on a VPS-script-test box
# down to a local, gitignored directory for manual inspection or trusting
# in a local test client -- never for production use, never committed.
#
# No secrets-vault action needed: SSH access to a disposable VPS-script-test
# box uses only the ephemeral, per-run key Aeroform already generated on
# disk (never a vault secret), so this can run directly.
#
# Usage: fetch-tls-cert.sh [handoff.json]
#        fetch-tls-cert.sh --key <path> --ip <address> [--hostname <name>]
#   With no arguments, defaults to the most recently retained
#   aeroform-nixos-vps-script-handoff-*.json in $TMPDIR. A box whose
#   provisioning test never reached "retained update handoff" (e.g. it
#   timed out waiting on a rate-limited cert, as happened live) has no
#   handoff file -- use --key/--ip directly in that case; the raw SSH key
#   Aeroform generated is still on disk even though the handoff JSON isn't.
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
vps_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
out_dir="$vps_dir/.local/tls"

key_path= ip= hostname=
handoff=
case "${1:-}" in
  --key)
    while [ $# -gt 0 ]; do
      case $1 in
        --key) key_path=${2:?}; shift 2 ;;
        --ip) ip=${2:?}; shift 2 ;;
        --hostname) hostname=${2:?}; shift 2 ;;
        *) echo "usage: $0 [handoff.json] | [--key <path> --ip <address> [--hostname <name>]]" >&2; exit 64 ;;
      esac
    done
    test -n "$key_path" && test -n "$ip" || {
      echo "--key and --ip are both required" >&2
      exit 64
    }
    hostname=${hostname:-$ip}
    ;;
  *)
    handoff=${1:-}
    if [ -z "$handoff" ]; then
      handoff=$(ls -t "${TMPDIR:-/tmp}"/aeroform-nixos-vps-script-handoff-*.json 2>/dev/null | head -1)
    fi
    test -n "$handoff" && test -f "$handoff" || {
      echo "no handoff file found or given; provide one, or use --key/--ip" >&2
      exit 1
    }
    key_path=$(jq -er '.sshPrivateKeyPath' "$handoff")
    ip=$(jq -er '.ipAddress' "$handoff")
    hostname=$(jq -er '.hostname' "$handoff")
    ;;
esac
test -f "$key_path" || { echo "SSH key does not exist: $key_path" >&2; exit 1; }

dest="$out_dir/$hostname-$(date -u '+%Y%m%dT%H%M%SZ')"
mkdir -p "$dest"

ssh_opts=(-i "$key_path" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15)

echo "fetching Caddy certificate material from $ip into $dest" >&2
if ! ssh "${ssh_opts[@]}" "root@$ip" \
    'tar -C /var/lib/caddy/.local/share/caddy -cf - certificates 2>/dev/null' \
    | tar -C "$dest" -xf - 2>/dev/null; then
  echo "no certificate material present yet on the box (issuance may still be in progress)" >&2
  rmdir "$dest" 2>/dev/null || true
  exit 1
fi

found=$(find "$dest" -type f | wc -l | tr -d ' ')
if [ "$found" -eq 0 ]; then
  echo "certificate directory was empty (issuance never completed)" >&2
  rm -rf "$dest"
  exit 1
fi

echo "saved $found file(s) to $dest" >&2
find "$dest" -type f
