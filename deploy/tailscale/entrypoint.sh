#!/bin/sh
set -e

# Start the Tailscale daemon
tailscaled --state=/var/lib/tailscale/tailscaled.state &
TAILSCALED_PID=$!

# Wait for tailscaled socket to be ready
for i in $(seq 1 30); do
  if tailscale status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Authenticate — auth key for headless, interactive login URL if not set
if [ -n "$TS_AUTHKEY" ]; then
  tailscale up --authkey="$TS_AUTHKEY" --hostname="${TS_HOSTNAME:-pocketcoder}"
else
  echo "=============================================="
  echo "  No TS_AUTHKEY set. Starting interactive login."
  echo "  Watch logs for the login URL:"
  echo "    docker logs pocketcoder-tailscale"
  echo "=============================================="
  tailscale up --hostname="${TS_HOSTNAME:-pocketcoder}"
fi

# Reverse-proxy HTTPS to PocketBase
tailscale serve --bg --https=443 http://pocketbase:8090

# Enable Funnel if in funnel mode (default)
if [ "${TAILSCALE_MODE:-funnel}" = "funnel" ]; then
  tailscale funnel --bg 443
  echo ""
  echo "=============================================="
  echo "  Tailscale Funnel ENABLED (public URL)"
  echo "=============================================="
else
  echo ""
  echo "=============================================="
  echo "  Tailscale Private Mode (Tailnet only)"
  echo "=============================================="
fi

echo ""
tailscale status
echo ""
echo "Your PocketCoder URL:"
tailscale funnel status 2>/dev/null || tailscale serve status 2>/dev/null || true

# Keep container alive
wait $TAILSCALED_PID
