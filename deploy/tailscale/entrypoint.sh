#!/bin/sh
set -e

# Start the Tailscale daemon
tailscaled --state=/var/lib/tailscale/tailscaled.state &
TAILSCALED_PID=$!

# Wait for tailscaled socket to be ready
ready=0
for i in $(seq 1 30); do
  if tailscale status >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -eq 0 ]; then
  echo "WARNING: tailscale did not report ready after 30s" >&2
fi

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

# Enable Funnel only when explicitly requested. Private Tailnet access is the
# safe default for a trusted-group deployment.
if [ "${TAILSCALE_MODE:-private}" = "funnel" ]; then
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
tailscale funnel status || tailscale serve status 2>/dev/null || true

# Keep container alive
wait $TAILSCALED_PID
