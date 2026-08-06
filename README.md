# PocketCoder

**A sovereign, mobile-first coding agent you own end to end.** Message an AI agent from your phone, watch it work, and approve every consequential action before it runs — all on your own VPS, with your own model key, no chat-app bridge in the middle.

PocketCoder is a solo research project built in the open. It follows an **Alpine Linux** philosophy — a tiny original surface area standing on FOSS "giant's shoulders" rather than hand-rolled glue: **PocketBase** for state and auth, **Goose** as the agent core, and open agent protocols (**ACP**, **AG-UI**, **MCP**) for everything in between.

> ### ⚠️ Status: mid-build, core loop usable
> - ✅ **Backend contract (c1 ↔ c2) is implemented and passes live acceptance** against a real model — authenticated runs, streaming, tool calls, and phone approve/deny all work.
> - ✅ **The Flutter client's core loop is live**: chat list (home screen), conversation, file browser, MCP/scheduler/skills/tool-permissions/agent-config/notification settings, logout — all wired to real PocketBase-backed data, no stubs.
> - ✅ **Cognee memory is live**, sharing Goose's own `agent` Compose profile — not gated behind the MCP gateway.
> - ✅ **The c3 MCP gateway container runs by default** (no Compose profile gate) — external MCP servers are approved per-deployment via the `mcp_servers` PocketBase collection.
> - 💤 **Dormant:** the Rust sandbox proxy is retained for future work — see [`dormant/`](dormant/).
>
> Treat this as an architecture experiment you can read and run, not a finished product.

## Why it exists

Two patterns have emerged for working with autonomous agents, and PocketCoder aims for the secure middle ground:

- **Mission-control on the go.** Tools like Google Antigravity showed that a lot of agent work is *reviewing plans and approving executions*, not typing syntax. That subset fits a phone perfectly — assign tasks, review plans, approve deployments while away from your keyboard.
- **A safe alternative to chat-bridge agents.** Tools like OpenClaw let you message a personal agent to do real work, but route system commands through unauthenticated chat apps — a documented security nightmare. PocketCoder gives you the same convenience inside a proper authenticated app where **every tool call is gated by an explicit, human-inspectable approval** before it executes.

**Core principles:** scoped for mobile (orchestration, not 500-line diffs on a phone) · human-in-the-loop by default · open protocols instead of bespoke glue · bring-your-own-model (Goose is decoupled from the LLM).

## Mobile-first provisioning

PocketCoder is designed to be more than a phone remote for a VPS that was already prepared through SSH. The intended Pro convenience flow is:

```text
Phone
  → provision PocketCoder on a Linode or Elestio VPS
  → receive a working HTTPS URL automatically
  → configure the agent and model provider
  → start work
  → receive approval requests
  → approve, deny, deploy, or update from the phone
```

The deployment also removes a traditionally annoying setup step: the provisioned system can derive a public `sslip.io` hostname from the VPS IP and use Caddy to obtain HTTPS automatically, without asking the user to buy a domain or hand-configure a certificate. Tailscale Funnel provides another automatic HTTPS path when that mode is selected.

This is different from the common mobile-agent pattern where a user must already have a running desktop, CLI session, or VPS and then pair a phone to it. PocketCoder’s open/self-hosted path remains available through [`deploy.sh`](deploy.sh); mobile VPS provisioning is a separate proprietary convenience layer.

## Architecture

The agent core is three containers connected by open protocols:

| Container | Runs | Role |
|:---|:---|:---|
| **c1** | PocketBase (as a Go library) + Go AG-UI server + Go ACP client | The "front door." Auth, chat ownership, the single `chat → Goose-session` mapping, and the **ACP ↔ AG-UI translation** seam. |
| **c2** | **Goose** in ACP agent-server mode (`goose serve`) | The default agent harness and sole provider of Goose-only features such as schedules and extensions. |
| **Peer harnesses** | Claude Agent ACP / Codex ACP, provisioned independently on first selection | Optional agent harness containers routed per chat. Each exposes the same authenticated ACP WebSocket boundary through PocketCoder's stdio adapter. |
| **c3** | Docker MCP Gateway | Runs by default. Hosts external tools as MCP servers (GitHub, Notion, etc.), approved per-deployment via the `mcp_servers` PocketBase collection. **Cognee memory is no longer part of this — see below.** |

```
Mobile (Flutter)
   │  AG-UI events over SSE
   ▼
c1  PocketBase — auth, chat→Goose-session mapping, ACP↔AG-UI translation
   │  ACP over an authenticated WebSocket (coder/acp-go-sdk)
   ▼
c2  Selected harness — Goose by default, or an independently provisioned Claude Code/Codex container
   │  (MCP tools via c3)
   ▼
c3  Docker MCP Gateway — GitHub, Notion, etc. (approved per-deployment)
```

**Each protocol does one job:**

| Protocol | Between | Job |
|:---|:---|:---|
| **AG-UI** | c1 ↔ Flutter | Frontend event stream — text streaming, tool-call visibility, approval state |
| **ACP** | c1 ↔ c2 (and c2 ↔ its spawned harness) | Session, tool calls, permission requests |
| **MCP** | c3 ↔ c2 | Tool access — GitHub, Notion, etc. |

**Cognee memory runs as a Goose extension, not through the MCP gateway.** It shares Goose's own `agent` Compose profile (`docker compose --profile agent up -d` starts both), configured live via the `cognee_config` PocketBase collection → rendered `cognee.env` → mounted into the container. It is enabled by default whenever the agent runtime is, independent of `c3`.

Goose is the **sole system of record** for conversation history (its own SQLite session store). PocketBase stores only authentication and the `chat_id → goose_session_id` mapping — it is not a conversation or approval ledger. The Flutter client keeps a local Drift cache as an offline mirror that Goose refreshes on load.

The security model and its honest limits (tool execution currently lives inside c2; the hardened sandbox is dormant) are documented in [`SECURITY.md`](SECURITY.md); the full design and open questions in [`docs/architecture-refactor.md`](docs/architecture-refactor.md).

## How it compares

| | **PocketCoder** | **Cloud remote-control** | **Chat-bridge agents** |
|:---|:---|:---|:---|
| **Cost** | ~$10/mo (VPS only) | Subscription + VPS if headless | ~$10/mo (VPS) |
| **Approve tool calls from phone** | Built-in, real-time | Not really — watch the screen | No permission gate |
| **Provision from phone** | Designed for one-tap VPS provisioning | Usually requires an existing machine/session | Usually manual/self-hosted setup |
| **Laptop required** | No — runs on a VPS | DIY / unofficial | No |
| **LLM provider** | Any (bring your own key) | Usually one vendor | Any |
| **Multi-user** | Yes (via PocketBase) | Single session | Single user |
| **Data sovereignty** | Fully self-hosted, no telemetry | Routes through a vendor | Self-hosted, but commands via chat apps |
| **Security posture** | Every action gated by explicit approval | Permission modes, no mobile override | Approval bolted on, if any |

## Quick Start

The only prerequisite is **Docker** — everything else is containerized.

1. **Deploy the infrastructure.** Generates secure passwords into a local `.env` and prompts for the credentials your chosen Goose provider needs:
   ```bash
   ./deploy.sh
   ```
2. **Launch the client** on web, iOS, or Android:
   ```bash
   ./client/scripts/run_chrome_incognito.sh   # clean incognito Chrome
   ./client/scripts/run_ios.sh                # iOS Simulator
   ./client/scripts/run_android.sh            # Android device/emulator
   ```

**OS:** any Linux with Docker (Ubuntu 22.04+ recommended); also runs on macOS via Docker Desktop for local dev. A 2 GB / 1 vCPU VPS covers the core + agent runtime at idle — active agent workloads spike above that.

## Remote Access (Tailscale)

Reach PocketCoder from your phone anywhere — no port forwarding, no public IP.

1. Create a free [Tailscale account](https://tailscale.com) and generate an auth key at [Admin → Keys](https://login.tailscale.com/admin/settings/keys).
2. Add to your `.env`:
   ```env
   TS_AUTHKEY=tskey-auth-xxxxx
   TAILSCALE_MODE=funnel
   ```
3. Start with the profile and read your URL from the logs:
   ```bash
   docker compose --profile tailscale up -d
   docker logs pocketcoder-tailscale
   ```
4. Enter the printed `https://pocketcoder.xxx.ts.net` URL in the app.

| Mode | Env value | Access | Phone setup |
|------|-----------|--------|-------------|
| **Funnel** | `TAILSCALE_MODE=funnel` | Public HTTPS URL | Just open the URL |
| **Private** | `TAILSCALE_MODE=private` | Tailnet only | Install Tailscale, same account |

Leave `TS_AUTHKEY` blank to authenticate interactively — the login URL prints to the same logs.

## Services & Profiles

One `docker-compose.yml`. Core services run by default; the rest are opt-in via profiles.

| Service | Profile | Role |
|:---|:---|:---|
| `pocketbase` | *(always)* | c1 — backend, auth, ACP↔AG-UI bridge |
| `docker-socket-proxy-write` | *(always)* | Scoped Docker API proxy (container restart/logs) |
| `sqlpage` | *(always)* | Observability dashboard |
| `goose` | `agent` | c2 — the Goose agent core |
| `cognee` | `agent` | Agent memory, loaded as a live Goose extension (not via `c3`) |
| `mcp-gateway` | *(always)* | c3 — Docker MCP Gateway |
| `ntfy` | `foss` | Self-hosted push notifications |
| `tailscale` | `tailscale` | Remote access (funnel/private) |
| `caddy` | `caddy` | TLS termination / reverse proxy |

```bash
docker compose --profile harness-images build  # includes lazy Claude/Codex images
docker compose up -d                           # Goose is the default runtime
```

## Testing

The acceptance suite drives a real c1 (PocketBase) → c2 (Goose) turn against a live model and asserts the AG-UI contract end to end:

```bash
tests/agent-c1/run.sh
```

It brings up the `agent` profile via `docker-compose.agent-test.yml` and runs the bats suite in an isolated container. See [`docs/agent-testing-strategy.md`](docs/agent-testing-strategy.md).

## Codebase

*(Original PocketCoder code — regenerated by `tooling/scripts/generate_audit.sh`; tests and generated code excluded. Dormant Rust — the sandbox proxy and `poco-agents` — lives in [`dormant/`](dormant/) and is excluded.)*

| Language | LoC | Component |
| :--- | ---: | :--- |
| Go | 6,697 | c1: PocketBase + ACP client + AG-UI server |
| Dart | 47,306 | Flutter client (non-generated) |
| **Core code** | **~54,003** | Go + Dart — product code |
| Tests | 12,242 | not code — Go 1,999 · Dart 2,505 · Bash 7,738 |
| Tooling | 5,156 | not code — Bash scripts / infra |

The backend is deliberately tiny: PocketBase supplies auth, the database, REST, and realtime *as a library*, so c1 is just the ACP client, the AG-UI bridge, and a handful of hooks. Lean glue over battle-tested building blocks is the whole thesis.

## Disclaimer & License

An active research project by a solo developer, built in the open — not a commercial product, no support SLAs. Bug reports are welcome; I move at my own pace.

All PocketCoder code is **AGPLv3**. The agent core (Goose) and PocketBase are OSI-approved open source. The optional memory component (Cognee) now runs by default alongside the agent runtime (`agent` Compose profile) rather than behind the `c3` gateway; it remains optional via that same profile, and any non-OSI runtime dependency it introduces is tracked here.

**Open core:** the client and backend here are open and fully self-hostable — nothing described above requires anything proprietary. The mobile app's one-tap VPS provisioning (OAuth deploy, billing) is a separate, closed-source convenience layer that funds the project; self-hosters skip it entirely by running `deploy.sh` directly.
