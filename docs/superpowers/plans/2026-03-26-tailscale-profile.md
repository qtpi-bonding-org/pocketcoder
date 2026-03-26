# Tailscale Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `tailscale` Docker Compose profile that enables remote phone access via Tailscale Funnel (public URL) or Tailnet (private mesh), with no host ports exposed.

**Architecture:** A single `tailscale/tailscale` container behind the `tailscale` profile reverse-proxies to PocketBase over a shared Docker network. An entrypoint script handles authentication and mode selection (funnel vs private) via the `TAILSCALE_MODE` env var.

**Tech Stack:** Docker Compose profiles, Tailscale official Docker image, shell scripting

**Spec:** `docs/superpowers/specs/2026-03-26-tailscale-profile-design.md`

---

### Task 1: Create the entrypoint script

**Files:**
- Create: `deploy/tailscale/entrypoint.sh`

- [ ] **Step 1: Create the deploy/tailscale directory and entrypoint script**

```bash
mkdir -p deploy/tailscale
```

Write `deploy/tailscale/entrypoint.sh`:

```sh
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
```

- [ ] **Step 2: Make entrypoint executable**

```bash
chmod +x deploy/tailscale/entrypoint.sh
```

- [ ] **Step 3: Verify the script is valid shell**

Run: `sh -n deploy/tailscale/entrypoint.sh`
Expected: No output (no syntax errors)

- [ ] **Step 4: Commit**

```bash
git add deploy/tailscale/entrypoint.sh
git commit -m "feat(tailscale): add entrypoint script with funnel/private mode support"
```

---

### Task 2: Add Tailscale service, volume, and network to docker-compose.yml

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add the tailscale service**

Add after the `ntfy` service block (before the `volumes:` section), around line 365:

```yaml
  # 🔗 TAILSCALE (Remote Access Tunnel)
  # To enable: docker compose --profile tailscale up
  # Modes: TAILSCALE_MODE=funnel (default, public URL) or TAILSCALE_MODE=private (Tailnet only)
  tailscale:
    image: tailscale/tailscale:latest
    container_name: pocketcoder-tailscale
    profiles:
      - tailscale
    hostname: ${TS_HOSTNAME:-pocketcoder}
    entrypoint: ["/bin/sh", "/entrypoint.sh"]
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY:-}
      - TS_HOSTNAME=${TS_HOSTNAME:-pocketcoder}
      - TAILSCALE_MODE=${TAILSCALE_MODE:-funnel}
    volumes:
      - tailscale_state:/var/lib/tailscale
      - ./deploy/tailscale/entrypoint.sh:/entrypoint.sh:ro
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
    restart: unless-stopped
```

- [ ] **Step 2: Add pocketcoder-tailscale network to PocketBase**

In the `pocketbase` service's `networks:` list, add `- pocketcoder-tailscale` at the end:

```yaml
    networks:
      - pocketcoder-dashboard
      - pocketcoder-docker
      - pocketcoder-pocketbase-sdk
      - pocketcoder-opencode-sdk
      - pocketcoder-tailscale
```

- [ ] **Step 3: Add pocketcoder-tailscale network to SQLPage**

In the `sqlpage` service's `networks:` list, add `- pocketcoder-tailscale`:

```yaml
    networks:
      - pocketcoder-dashboard
      - pocketcoder-tailscale
```

- [ ] **Step 4: Add the tailscale_state volume**

In the `volumes:` section, add:

```yaml
  tailscale_state:  # Persists Tailscale node identity across restarts
```

- [ ] **Step 5: Add the pocketcoder-tailscale network**

In the `networks:` section, add:

```yaml
  pocketcoder-tailscale:
    driver: bridge
```

- [ ] **Step 6: Validate compose file syntax**

Run: `docker compose config --profiles tailscale > /dev/null`
Expected: No errors. Exit code 0.

- [ ] **Step 7: Verify profile isolation — core services unaffected**

Run: `docker compose config --services`
Expected: Output does NOT include `tailscale`. The tailscale service only appears with `--profile tailscale`.

Run: `docker compose --profile tailscale config --services`
Expected: Output includes `tailscale` along with all core services.

- [ ] **Step 8: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(tailscale): add tailscale service, volume, and network to compose"
```

---

### Task 3: Update .env.template with Tailscale variables

**Files:**
- Modify: `.env.template`

- [ ] **Step 1: Add Tailscale section to .env.template**

Append to the end of `.env.template`:

```env

# --- Tailscale Remote Access ---
# Required when using --profile tailscale
# Get an auth key from: https://login.tailscale.com/admin/settings/keys
# Leave blank for interactive login (check docker logs for URL)
TS_AUTHKEY=
# "funnel" = public URL (default), "private" = Tailnet devices only
TAILSCALE_MODE=funnel
# Hostname shown in Tailscale admin console
TS_HOSTNAME=pocketcoder
```

- [ ] **Step 2: Commit**

```bash
git add .env.template
git commit -m "feat(tailscale): add Tailscale env vars to .env.template"
```

---

### Task 4: Smoke test the Tailscale profile

This task validates the full integration locally. It does NOT require a Tailscale account — it verifies that the container starts, connects to PocketBase's network, and the entrypoint runs correctly.

**Files:** None (testing only)

- [ ] **Step 1: Verify compose resolves with tailscale profile**

Run: `docker compose --profile tailscale config | grep -A 20 'tailscale:'`
Expected: The tailscale service definition appears with correct image, volumes, networks, entrypoint, and environment variables.

- [ ] **Step 2: Verify PocketBase has the tailscale network**

Run: `docker compose --profile tailscale config | grep -A 30 'pocketcoder-pocketbase:' | grep tailscale`
Expected: `pocketcoder-tailscale` appears in PocketBase's network list.

- [ ] **Step 3: Verify no port mappings on tailscale container**

Run: `docker compose --profile tailscale config | yq '.services.tailscale.ports // "none"'`
Expected: `none` — the tailscale container should expose zero host ports.

- [ ] **Step 4: Verify core services still work without profile**

Run: `docker compose config --services | sort`
Expected: Normal service list without `tailscale`. No regressions.

- [ ] **Step 5: Commit all remaining changes (if any fixups were needed)**

```bash
git add -A
git commit -m "fix(tailscale): fixups from smoke test"
```

Skip this step if no changes were needed.

---

### Task 5: Update README with Tailscale remote access section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the README to find the right insertion point**

Read `README.md` and identify where networking/deployment is discussed. The Tailscale section should go near existing deployment or configuration documentation.

- [ ] **Step 2: Add Remote Access section**

Add a section titled `## Remote Access (Tailscale)` with the following content:

```markdown
## Remote Access (Tailscale)

Access PocketCoder from your phone anywhere — no port forwarding, no public IP required.

### Quick Start

1. Create a free [Tailscale account](https://tailscale.com)
2. Generate an auth key at [Tailscale Admin > Keys](https://login.tailscale.com/admin/settings/keys)
3. Add to your `.env`:
   ```env
   TS_AUTHKEY=tskey-auth-xxxxx
   TAILSCALE_MODE=funnel
   ```
4. Start with the tailscale profile:
   ```bash
   docker compose --profile tailscale up -d
   ```
5. Check logs for your URL:
   ```bash
   docker logs pocketcoder-tailscale
   ```
6. Enter the `https://pocketcoder.xxx.ts.net` URL in the PocketCoder app

### Modes

| Mode | Env Value | Access | Phone Setup |
|------|-----------|--------|-------------|
| **Funnel** | `TAILSCALE_MODE=funnel` | Public HTTPS URL | Just open the URL |
| **Private** | `TAILSCALE_MODE=private` | Tailnet only | Install Tailscale on phone, same account |

### Interactive Login (no auth key)

Leave `TS_AUTHKEY` blank and check logs for the login URL:
```bash
docker compose --profile tailscale up -d
docker logs pocketcoder-tailscale
# Open the printed URL in your browser to authenticate
```
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Tailscale remote access section to README"
```
