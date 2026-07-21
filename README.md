# PocketCoder

**PocketCoder** is a personal research lab and an experiment in building a "Sovereign AI." It is a minimalist, local-first coding assistant designed with the philosophy of **Alpine Linux**: a tiny surface area that leverages the power of established, battle-tested building blocks.

I am building this as a solo developer because I believe that the most powerful tools shouldn't need a complex "Enterprise" footprint. Instead of hand-rolling glue, PocketCoder stands on open protocols and FOSS "giant's shoulders" — **PocketBase** for state and auth, **Goose** as the agent core, and open agent protocols (**ACP**, **AG-UI**, **MCP**) for everything in between — to keep the custom code to an absolute minimum.

## 🧪 The Experiment: A Secure Bridge for Agentic Workflows

The AI ecosystem is moving fast, and we are seeing two distinct patterns emerge in how people interact with autonomous agents. PocketCoder is an experiment aimed at finding the secure middle ground between them.

**1. The "Antigravity" Workflow on the Go**

Recent tools like Google Antigravity have shown that for *certain parts* of development, a high-level "Mission Control" workflow is highly effective. You aren't typing syntax; you are reviewing agent plans, looking at task lists, and approving executions. While intense, nitty-gritty coding will always belong on a desktop, PocketCoder aims to bring the orchestration subset of your workflow to your phone. It allows you to assign tasks, review plans, and approve deployments securely while away from your keyboard.

**2. A Secure Alternative to OpenClaw**

For non-technical users and developers alike, the appeal of tools like OpenClaw is obvious: the ability to message a personal AI agent from your phone and have it execute real-world tasks. However, routing system-level commands through unauthenticated chat apps (like WhatsApp or Telegram) is a well-documented security nightmare. PocketCoder provides that same mobile convenience, but wraps it in a proper, authenticated application where every tool call is gated by an explicit, human-inspectable approval.

### How PocketCoder Compares (2026)

| | **PocketCoder** | **Claude Remote Control** | **OpenClaw** |
|:---|:---|:---|:---|
| **Cost** | ~$10/mo (VPS only) | $100–200/mo (Max plan) + VPS if headless | ~$10/mo (VPS) |
| **Permission approval from phone** | Built-in, real-time approve/deny | [Not implemented](https://github.com/anthropics/claude-code/issues/29438) — must watch screen | No permission system |
| **Push notifications on block** | ntfy (free) + FCM, with presence suppression | [Not implemented](https://github.com/anthropics/claude-code/issues/29438) — community workarounds via ntfy | N/A |
| **Laptop required** | No — runs on VPS (laptop mode also works) | [DIY via SSH + tmux](https://github.com/anthropics/claude-code/issues/29479), not officially supported | No — self-hosted |
| **LLM provider** | Any (via Goose provider + your own API key) | Claude only | Any |
| **Multi-user** | Yes (family/team via PocketBase) | Single session | Single user |
| **Auth model** | PocketBase authenticated chat ownership | Anthropic account | Chat app login |
| **Data sovereignty** | Fully self-hosted, no telemetry | Traffic routes through Anthropic | Self-hosted, but commands via chat bridges |
| **Security model** | Every tool call gated by explicit approval | Permission modes, no mobile override | [No approval by default](https://www.crowdstrike.com/en-us/blog/what-security-teams-need-to-know-about-openclaw-ai-super-agent/) — bolted-on after [security incidents](https://www.giskard.ai/knowledge/openclaw-security-vulnerabilities-include-data-leakage-and-prompt-injection-risks) |
| **Mobile app** | Native Flutter (iOS + Android + F-Droid) | Claude iOS/Android app | 20+ chat apps (WhatsApp, Telegram, etc.) |
| **MCP management** | Approve/deny/view from phone | Via terminal only | Via config files |

### 🛡️ Core Principles

- **Scoped for Mobile:** We aren't trying to replace your desktop IDE or force you to read 500-line diffs on a 6-inch screen. PocketCoder is built for high-level agent orchestration, planning, and approval.

- **Human-in-the-Loop by default:** No open chat bridges or unauthenticated webhooks. Every sensitive action the agent wants to take surfaces as an explicit approval on your phone (via the agent's own permission protocol) *before* it runs.

- **Protocols, not bespoke glue:** PocketCoder isn't a massive, bespoke framework. It is intentionally lightweight glue connecting open protocols — **MCP** for tools, **ACP** for agent↔harness communication, **AG-UI** for the stream to your phone — so each protocol does the one job it's designed for. You can audit the seams in an afternoon.

- **LLM Agnostic:** The agent core (Goose) is decoupled from the model. Point `GOOSE_PROVIDER` at Claude (`claude-acp`), Codex (`codex-acp`), or another provider and bring your own API key. PocketCoder remains your sovereign infrastructure.

## 🏛️ Architecture

PocketCoder's agent core is three containers connected by open protocols:

| Container | Runs | Role |
|:---|:---|:---|
| **c1** | PocketBase (as a Go library) + Go AG-UI server + Go ACP client | The "front door." Authentication, chat ownership, the single `chat → Goose-session` mapping, and the **ACP ↔ AG-UI translation** seam. |
| **c2** | **Goose** in ACP agent-server mode (`goose serve`) | The agent core. Spawns `claude-agent-acp` / `codex-acp` per `GOOSE_PROVIDER`. The **least-trusted** container — this is where tool execution happens. |
| **c3** | Docker MCP Gateway *(dormant)* | Will host external tools as MCP servers (GitHub, Notion, **Cognee** memory). Disabled by default until attachment is validated. |

```
Mobile (Flutter)
   │  AG-UI events over SSE
   ▼
c1  PocketBase — auth, chat→Goose-session mapping, ACP↔AG-UI translation
   │  ACP over an authenticated WebSocket (coder/acp-go-sdk)
   ▼
c2  Goose (goose serve) — spawns claude-agent-acp / codex-acp
   │  (MCP tools — dormant)
   ▼
c3  Docker MCP Gateway — GitHub, Notion, Cognee  [not yet enabled]
```

**Protocol boundaries — one job each:**

| Protocol | Between | Job |
|:---|:---|:---|
| **AG-UI** | c1 ↔ Flutter | Frontend event stream — text streaming, tool-call visibility, approval state |
| **ACP** | c1 ↔ c2 (and c2 ↔ its spawned harness) | Session, tool calls, permission requests |
| **MCP** | c3 ↔ c2 | Tool access — GitHub, Notion, Cognee *(dormant)* |

Goose is the **sole system of record** for conversation history (its own SQLite session store). PocketBase stores only authentication and the `chat_id → goose_session_id` mapping; it is not a conversation or approval ledger. The Flutter client keeps a local Drift cache as an offline mirror that Goose refreshes on load.

> **Status:** The c1↔c2 backend contract is implemented and passes live acceptance against a real model. The Flutter client is mid-rebuild on AG-UI. c3 (MCP gateway / Cognee) and the dormant Rust sandbox proxy are future work — see `docs/architecture-refactor.md` for the full design and open questions.

## ⚠️ Disclaimer
PocketCoder is an active research project. As a solo developer, I'm building this in the open to share my progress. It is not a commercial product, and there are no support SLAs. If you find a bug, I'd love to hear about it, but please understand I'm moving at my own pace!

## 🚀 Quick Start

The only system prerequisite is **Docker**. Everything else is completely containerized.

1. **Deploy the Infrastructure**
   Run the deployment script from the root directory. It auto-generates secure passwords in a local `.env` file and prompts you for the credentials your chosen Goose provider needs:
   ```bash
   ./deploy.sh
   ```

2. **Launch the Client**
   You can run the Flutter frontend in an incognito web browser, iOS simulator, or Android device/emulator using the provided helper scripts:
   ```bash
   # Run in a clean incognito Chrome instance
   ./client/scripts/run_chrome_incognito.sh

   # Or run on an iOS Simulator
   ./client/scripts/run_ios.sh

   # Or run on an Android Device/Emulator
   ./client/scripts/run_android.sh
   ```

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

## Services & Profiles

The stack is a single `docker-compose.yml`. Core services run by default; the rest are opt-in via profiles.

| Service | Profile | Role |
|:---|:---|:---|
| `pocketbase` | *(always)* | c1 — backend, auth, ACP↔AG-UI bridge |
| `docker-socket-proxy-write` | *(always)* | Scoped Docker API proxy (container restart/logs) |
| `sqlpage` | *(always)* | Observability dashboard |
| `goose` | `agent` | c2 — the Goose agent core |
| `mcp-gateway` | `c3` | Docker MCP Gateway *(dormant)* |
| `ntfy` | `foss` | Self-hosted push notifications |
| `tailscale` | `tailscale` | Remote access (funnel/private) |
| `caddy` | `caddy` | TLS termination / reverse proxy |

```bash
# Core only
docker compose up -d

# Core + agent runtime
docker compose --profile agent up -d
```

**OS:** Any Linux with Docker (Ubuntu 22.04+ recommended). Also runs on macOS via Docker Desktop for local development. A 2 GB / 1 vCPU VPS is enough for the core + agent runtime at idle; active agent workloads spike CPU and memory above idle.

## Testing

The active acceptance suite drives a real c1 (PocketBase) → c2 (Goose) turn against a live model and asserts the AG-UI contract end to end:

```bash
tests/agent-c1/run.sh
```

It brings up the `agent` profile via `docker-compose.agent-test.yml` and runs the bats suite in an isolated container. See `docs/agent-testing-strategy.md`.

## Third-Party Licenses

All PocketCoder code is licensed under **AGPLv3**. The agent core (Goose) and PocketBase are OSI-approved open source. The optional memory/knowledge component (Cognee, behind the c3 MCP gateway) is not yet enabled; any non-OSI runtime dependency it introduces will be documented here and kept optional via a Docker Compose profile.
