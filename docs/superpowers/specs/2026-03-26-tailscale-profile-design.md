# Tailscale Profile Design

## Problem

PocketCoder currently supports one networking mode for remote access: Caddy + sslip.io on a VPS with a public IP. This doesn't work for users running PocketCoder on a home desktop/laptop (no public IP, CGNAT) and offers no zero-trust alternative for VPS users who want to avoid exposing ports.

## Solution

Add a `tailscale` Docker Compose profile that provides two networking modes via a single container:

1. **Funnel** (default) — public HTTPS URL, no ports exposed, phone just opens a link
2. **Tailnet** (private) — only devices signed into the user's Tailscale account can connect

## How It Fits With Existing Networking

Three networking modes, user picks one. They are alternatives, not layers:

| Mode | Profile | Where It Works | Public Exposure | Setup Friction |
|------|---------|----------------|-----------------|----------------|
| Caddy + sslip.io | _(default on NixOS)_ | VPS with public IP | Ports 80, 443 | Automatic via NixOS |
| Tailscale Funnel | `--profile tailscale` | Anywhere (home, VPS, laptop) | None (Tailscale edge) | Tailscale account + login |
| Tailscale Private | `--profile tailscale` | Anywhere | None | Tailscale on all devices |

On a VPS, user chooses Caddy OR Tailscale. At home, Tailscale is the only option.

## Docker Compose Changes

Add one service and one network to `docker-compose.yml`:

### Service: `tailscale`

```yaml
tailscale:
  image: tailscale/tailscale:latest
  container_name: pocketcoder-tailscale
  profiles:
    - tailscale
  hostname: pocketcoder
  environment:
    - TS_AUTHKEY=${TS_AUTHKEY:-}
    - TS_STATE_DIR=/var/lib/tailscale
    - TS_SERVE_CONFIG=/config/serve.json
    - TS_EXTRA_ARGS=${TS_EXTRA_ARGS:-}
  volumes:
    - tailscale_state:/var/lib/tailscale
    - ./deploy/tailscale/serve.json:/config/serve.json:ro
  cap_add:
    - NET_ADMIN
    - SYS_MODULE
  devices:
    - /dev/net/tun:/dev/net/tun
  depends_on:
    pocketbase:
      condition: service_healthy
  networks:
    - pocketcoder-tailscale
    - pocketcoder-dashboard
  restart: unless-stopped
```

### Volume

```yaml
tailscale_state:  # Persists Tailscale node identity across restarts
```

### Network

```yaml
pocketcoder-tailscale:
  driver: bridge
```

PocketBase needs `pocketcoder-tailscale` added to its network list so the Tailscale container can reverse-proxy to it. SQLPage gets it too (so the dashboard is accessible via tunnel).

### Serve Config

`deploy/tailscale/serve.json`:

```json
{
  "TCP": {
    "443": {
      "HTTPS": true
    }
  },
  "Web": {
    "${TS_CERT_DOMAIN}": {
      "/": {
        "Proxy": "http://pocketbase:8090"
      }
    }
  }
}
```

This tells Tailscale to reverse-proxy HTTPS traffic to PocketBase. The `TS_CERT_DOMAIN` is auto-populated by Tailscale.

## Two Modes

Controlled by a single env var `TAILSCALE_MODE` in `.env`:

### Funnel Mode (default)

```env
TAILSCALE_MODE=funnel
```

The entrypoint script runs:
```sh
tailscale serve --bg --https=443 http://pocketbase:8090
tailscale funnel --bg 443
```

Result: `https://pocketcoder.tail1234.ts.net` is publicly accessible. Phone opens the URL, hits PocketBase auth, done.

### Private Mode

```env
TAILSCALE_MODE=private
```

The entrypoint script runs:
```sh
tailscale serve --bg --https=443 http://pocketbase:8090
```

No `tailscale funnel`. Result: `https://pocketcoder.tail1234.ts.net` only accessible from devices on the user's Tailnet. Phone must have Tailscale installed and logged into the same account.

## Entrypoint Script

`deploy/tailscale/entrypoint.sh`:

```sh
#!/bin/sh
set -e

# Start tailscaled
tailscaled --state=/var/lib/tailscale/tailscaled.state &

# Wait for tailscaled to be ready
sleep 2

# Authenticate (interactive or via auth key)
if [ -n "$TS_AUTHKEY" ]; then
  tailscale up --authkey="$TS_AUTHKEY" --hostname=pocketcoder
else
  tailscale up --hostname=pocketcoder
  # User must run: docker logs pocketcoder-tailscale
  # to see the login URL
fi

# Serve PocketBase
tailscale serve --bg --https=443 http://pocketbase:8090

# Enable Funnel if requested
if [ "${TAILSCALE_MODE:-funnel}" = "funnel" ]; then
  tailscale funnel --bg 443
  echo "Funnel enabled. Public URL:"
else
  echo "Private mode. Tailnet URL:"
fi

tailscale status

# Keep container running
wait
```

## Setup Flow (User Perspective)

### First Time

1. Create free Tailscale account at tailscale.com
2. Generate auth key in Tailscale admin console (or skip for interactive login)
3. Add to `.env`:
   ```env
   TS_AUTHKEY=tskey-auth-xxxxx    # optional, for headless setup
   TAILSCALE_MODE=funnel          # or "private"
   ```
4. Run: `docker compose --profile tailscale up -d`
5. If no auth key: run `docker logs pocketcoder-tailscale` and open the login URL
6. Note the `https://pocketcoder.tail1234.ts.net` URL
7. Enter that URL in the PocketCoder mobile app onboarding screen

### Subsequent Starts

Just `docker compose --profile tailscale up -d`. Tailscale state is persisted in the volume.

## Security Considerations

- **PocketBase auth is still the primary gate.** Tailscale provides the network transport, not application auth. Even in Funnel mode, users must authenticate with PocketBase credentials.
- **No ports exposed on host.** Unlike Caddy, the Tailscale container doesn't need any published ports. All traffic goes through the Tailscale tunnel.
- **SSH (port 2222) is NOT tunneled.** Only PocketBase (8090) is served through Tailscale. The phone app connects to PocketBase, which relays to OpenCode. Direct SSH from phone to sandbox goes through PocketBase's SSH key sync mechanism, not the tunnel.
- **Funnel mode risk:** Anyone who discovers the `.ts.net` URL can attempt to authenticate. This is the same threat model as Caddy + sslip.io. PocketBase auth + rate limiting are the defense.
- **Private mode:** Zero public exposure. Attacker must compromise the user's Tailscale account first.

## What We're NOT Building

- No desktop GUI wrapper (future consideration)
- No Podman support (Docker only for now)
- No changes to the Caddy + sslip.io NixOS deploy path
- No Cloudflare Tunnel profile (documented as manual alternative only)
- No auto-detection of networking mode

## Files to Create/Modify

| File | Action |
|------|--------|
| `docker-compose.yml` | Add `tailscale` service, volume, network; add network to pocketbase + sqlpage |
| `deploy/tailscale/entrypoint.sh` | Create entrypoint script |
| `deploy/tailscale/serve.json` | Create Tailscale serve config |
| `.env.example` | Add `TS_AUTHKEY`, `TAILSCALE_MODE` vars |
| `README.md` | Add desktop/remote access section |
