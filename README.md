# PocketCoder

**A sovereign, mobile-first coding agent you run on your own infrastructure.** Use local models through Ollama or a hosted provider, receive private notifications through ntfy, and approve consequential actions from your phone before they run — without routing commands through a chat app.

PocketCoder is a solo research project built in the open. It follows an **Alpine Linux** philosophy — a tiny original surface area standing on FOSS "giant's shoulders" rather than hand-rolled glue: **PocketBase** for state and auth, **Goose** as the default harness, and open agent protocols (**ACP**, **AG-UI**, **MCP**) for everything in between.

> ### ⚠️ Status: mid-build, core loop usable
> - ✅ **Backend contract (c1 ↔ c2) is implemented and passes live acceptance** against a real model — authenticated runs, streaming, tool calls, and phone approve/deny all work.
> - ✅ **The Flutter client's core loop is live**: chat list (home screen), conversation, file browser, MCP/scheduler/skills/tool-permissions/agent-config/notification settings, logout — all wired to real PocketBase-backed data, no stubs.
> - ✅ **Pocket Memory replaces Cognee** with an always-on Rust/SQLite MCP service: agent-authored observations and interpretations, local multilingual hybrid recall, and no generative-memory LLM.
> - ✅ **The c3 MCP gateway container runs by default** (no Compose profile gate) — external MCP servers are approved per-deployment via the `mcp_servers` PocketBase collection.
> - 💤 **Dormant:** the Rust sandbox proxy is retained for future work — see [`dormant/`](dormant/).
>
> Treat this as an architecture experiment you can read and run, not a finished product.

### Who this is for

PocketCoder is intended for a **single self-hosted VPS shared by one person or a small group of trusted friends and family**. It is not designed as a hostile multi-tenant SaaS boundary. People who share a deployment should be trusted with one another's workspace, agent activity, logs, and configured integrations.

The default architecture supports a fully self-hosted path: PocketCoder, Goose,
Ollama, and optional ntfy all run in your Compose deployment. If you choose a
hosted model provider or enable external MCP servers, those services may receive
prompts, file contents, or other data when the agent uses them. Review the
privacy policies and permissions of every provider or integration before
connecting sensitive accounts.

## Why it exists

Two patterns have emerged for working with autonomous agents, and PocketCoder aims for the secure middle ground:

- **Mission-control on the go.** Tools like Google Antigravity showed that a lot of agent work is *reviewing plans and approving executions*, not typing syntax. That subset fits a phone perfectly — assign tasks, review plans, approve deployments while away from your keyboard.
- **A safe alternative to chat-bridge agents.** Tools like OpenClaw let you message a personal agent to do real work, but route system commands through unauthenticated chat apps — a documented security nightmare. PocketCoder gives you the same convenience inside a proper authenticated app where **every tool call is gated by an explicit, human-inspectable approval** before it executes.

**Core principles:** scoped for mobile (orchestration, not 500-line diffs on a phone) · human-in-the-loop by default · open protocols instead of bespoke glue · local-first when desired, provider-independent when useful.

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

The deployment also removes a traditionally annoying setup step: the provisioned system can derive a public `sslip.io` hostname from the VPS IP and use Caddy to obtain HTTPS automatically, without asking the user to buy a domain or hand-configure a certificate. This Caddy HTTPS route is the recommended VPS path for the Flutter app. Tailscale is an optional alternative for self-hosted Docker deployments.

This is different from the common mobile-agent pattern where a user must already have a running desktop, CLI session, or VPS and then pair a phone to it. PocketCoder’s open/self-hosted path remains available through [`deploy.sh`](deploy.sh); mobile VPS provisioning is a separate proprietary convenience layer.

## Architecture

The agent core is three containers connected by open protocols:

| Container | Runs | Role |
|:---|:---|:---|
| **c1** | PocketBase (as a Go library) + Go AG-UI server + Go ACP client | The "front door." Auth, chat ownership, the `chat → harness session` mapping, and the **ACP ↔ AG-UI translation** seam. |
| **c2** | **Selected harness** | Goose by default, or Claude Code/Codex/OpenCode. Every harness is provisioned independently on first selection and exposes the same authenticated ACP WebSocket boundary. |
| **c3** | Docker MCP Gateway | Runs by default. Hosts external tools as MCP servers (GitHub, Notion, etc.), approved per-deployment via the `mcp_servers` PocketBase collection. **Core memory is attached directly per ACP session so PocketBase can inject agent identity.** |
| **Memory** | Pocket Memory | Always-on Rust service with SQLite, FTS5, sqlite-vec, and an in-process multilingual E5 embedder. |

```
Mobile (Flutter)
   │  AG-UI events over SSE
   ▼
c1  PocketBase — auth, chat→harness-session mapping, ACP↔AG-UI translation
   │  ACP over an authenticated WebSocket (coder/acp-go-sdk)
   ▼
c2  Selected harness — Goose by default, or Claude Code/Codex/OpenCode
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

**Pocket Memory is attached directly to each harness through ACP, not routed
through the deployment-wide MCP gateway.** PocketBase injects the resolved
account and concrete agent profile in the MCP connection, so memory tools do not
ask an agent to remember its own identity. The service is local and always on;
if its bundled embedding model is unavailable, canonical writes and FTS5 recall
continue in an explicitly degraded mode.

The selected harness is the **system of record** for its conversation history. PocketBase stores authentication and the `chat_id → external harness session` mapping — it is not a conversation or approval ledger. The Flutter client keeps a local Drift cache as an offline mirror refreshed from the selected harness.

The security model and its honest limits (tool execution currently lives inside c2; the hardened sandbox is dormant) are documented in [`SECURITY.md`](SECURITY.md); the full design and open questions in [`docs/architecture-refactor.md`](docs/architecture-refactor.md).

## How it compares

| | **PocketCoder** | **Cloud remote-control** | **Chat-bridge agents** |
|:---|:---|:---|:---|
| **Cost** | ~$10/mo (VPS only) | Subscription + VPS if headless | ~$10/mo (VPS) |
| **Approve tool calls from phone** | Built-in, real-time | Not really — watch the screen | No permission gate |
| **Provision from phone** | Designed for one-tap VPS provisioning | Usually requires an existing machine/session | Usually manual/self-hosted setup |
| **Laptop required** | No — runs on a VPS | DIY / unofficial | No |
| **LLM provider** | Ollama locally or any hosted provider | Usually one vendor | Any |
| **Sharing model** | Trusted users sharing one deployment; not hostile multi-tenant isolation | Single session | Single user |
| **Data sovereignty** | Fully self-hosted, no telemetry | Routes through a vendor | Self-hosted, but commands via chat apps |
| **Security posture** | Every action gated by explicit approval | Permission modes, no mobile override | Approval bolted on, if any |

## Quick Start

For a self-hosted deployment, the prerequisite is **Docker Compose v2**. The
Flutter development client additionally requires the Flutter/Dart SDK. The
Cloudflare Workers are optional infrastructure for hosted OAuth and
image-manifest services.

1. **Deploy the infrastructure.** Generates secure passwords into a local `.env`, applies the host baseline, installs native Caddy, and derives the VPS's `sslip.io` HTTPS hostname. Harness accounts and model-provider credentials are configured in the app:
   ```bash
   ./deploy.sh
   ```
   On an Ubuntu/Debian Linux host, this also applies the host baseline by default: key-only SSH, Fail2ban, the host firewall, Docker forwarding rules, and unattended security updates. Keep a second SSH session open while applying host firewall changes.
2. **Launch the client** on web, iOS, or Android:
   ```bash
   ./client/scripts/run_chrome_incognito.sh   # clean incognito Chrome
   ./client/scripts/run_ios.sh                # iOS Simulator
   ./client/scripts/run_android.sh            # Android device/emulator
   ```

   These scripts run the public `apps/pocketcoder_foss` target.

For a local Docker-only setup, copy `.env.template` to `.env`, replace the
placeholder passwords and `GOOSE_SERVER__SECRET_KEY`, then run
`docker compose up -d`. Configure Ollama in the app for local inference, or add
credentials for a hosted model provider. PocketBase is available at
`http://127.0.0.1:8090`; point the client at that URL through its existing-server
onboarding screen.

**OS:** any Linux with Docker (Ubuntu 22.04+ recommended); also runs on macOS via Docker Desktop for local dev. A 2 GB / 1 vCPU VPS covers the core + agent runtime at idle — active agent workloads spike above that.

## VPS Access (Caddy HTTPS)

The NixOS VPS image and the standard Ubuntu/Debian deployment both manage Caddy natively on the host and expose PocketBase through an automatically generated HTTPS hostname such as `194-163-45-3.sslip.io`. Caddy terminates TLS and proxies to PocketBase; PocketBase itself is not exposed directly on the public interface. The Flutter app connects to the HTTPS hostname, not to a raw VPS IP address.

The VPS firewall exposes only ports 80 and 443 for web traffic, plus port 22 for key-only SSH administration. The automatic hostname depends on the VPS having a stable public IP and on the external `sslip.io` and certificate services being available.

PocketBase's built-in rate limiter is enabled by default for public deployments: authentication attempts are limited to 10 per minute per client, with additional API and batch-request limits. This is abuse protection, not account isolation; use strong unique passwords for every member.

The included PocketBase backup volume is an on-host recovery copy, not an off-host disaster backup. VPS loss, disk failure, or provider/account loss can still destroy it; export the volumes to storage you control if you need disaster recovery. Dynamically provisioned harnesses also create durable named volumes: each PocketBase user gets a separate workspace volume, while each named harness account gets a separate authentication/state volume. A harness account can be personal to its owner or visible to every trusted profile in that deployment, and each profile selects its preferred account per harness. This lets CLI logins survive container recreation without coupling login ownership to workspace ownership. A complete off-host backup must include these dynamic volumes as well as the Compose-declared volumes. Treat the backup destination as trusted because harness volumes can contain account credentials. Approved MCP OAuth credentials are likewise deployment-global, so trusted household members share the deployment's MCP configuration and credentials.

## Optional Remote Access (Tailscale)

Tailscale is useful when running the Docker deployment yourself or when you want a private Tailnet-only route instead of a public HTTPS hostname.

For a trusted-group deployment, **Private mode is the recommended Tailscale setting**: only devices on your Tailnet can reach the server. Funnel mode creates a public HTTPS URL on the internet; use it only when that tradeoff is intentional and keep strong, unique PocketCoder passwords in place. The public Caddy/sslip.io route remains supported when phone access without Tailscale is more important.

1. Create a free [Tailscale account](https://tailscale.com) and generate an auth key at [Admin → Keys](https://login.tailscale.com/admin/settings/keys).
2. Add to your `.env`:
   ```env
   TS_AUTHKEY=tskey-auth-xxxxx
   TAILSCALE_MODE=private
   ```
3. Start with the profile and read your URL from the logs:
   ```bash
   docker compose --profile tailscale up -d
   docker logs pocketcoder-tailscale
   ```
4. Enter the printed `https://pocketcoder.xxx.ts.net` URL in the app.

| Mode | Env value | Access | Phone setup |
|------|-----------|--------|-------------|
| **Funnel** | `TAILSCALE_MODE=funnel` | Public HTTPS URL | Just open the URL; advanced/public exposure |
| **Private** | `TAILSCALE_MODE=private` | Tailnet only | Install Tailscale, same account |

Leave `TS_AUTHKEY` blank to authenticate interactively — the login URL prints to the same logs.

## Services & Profiles

`docker-compose.yml` is the complete local stack. Core services run by default;
the rest are opt-in via profiles.

| Service | Profile | Role |
|:---|:---|:---|
| `pocketbase` | *(always)* | c1 — backend, auth, ACP↔AG-UI bridge |
| `ollama` | *(always)* | Local-model runtime; no model is downloaded automatically |
| `mcp-gateway` | *(always)* | c3 — Docker MCP Gateway |
| `docker-socket-proxy-mcp` | *(always)* | Scoped Docker API for MCP server containers |
| `docker-socket-proxy-write` | *(always)* | Scoped Docker API for PocketBase operations |
| `sqlpage` | *(always)* | Observability dashboard |
| `pocket-memory` | *(always)* | Agent-authored SQLite memory with local hybrid recall |
| `ntfy` | `foss` | Self-hosted push notifications |
| `tailscale` | `tailscale` | Remote access (funnel/private) |
| `caddy` | `caddy` | Containerized TLS termination for local Docker deployments |
| `*-harness-image` | `harness-images` | Build-only Goose, Claude Code, Codex, and OpenCode ACP images |

```bash
docker compose up -d
docker compose --profile foss up -d            # add self-hosted ntfy
docker compose --profile tailscale up -d       # add Tailscale access
docker compose --profile caddy up -d           # local Docker TLS route
docker compose --profile harness-images build  # prebuild all selectable harness images
```

On Linux, `deploy.sh` configures native host Caddy instead of the `caddy`
Compose profile. Do not enable both on the same host because they compete for
ports 80 and 443.

### Memory sizing measurements

The signed deployment-sizing policy stores exact bytes in
[`deploy/release/deployment-sizing.json`](deploy/release/deployment-sizing.json).
These measurements were taken on 2026-08-13 with the pinned `linux/amd64`
images under Docker Desktop LinuxKit. Container and Caddy values are the
maximum Docker working set across 12 one-second idle samples, except Pocket
Memory: Docker Desktop under-reported its image-backed model pages, so its row
uses the Linux process RSS after one real embedding and return to idle. See the
[Pocket Memory measurements](server/memory/README.md#measured-memory-footprint)
for the cold/warm breakdown and sizing guidance.

| Component | Exact bytes | MiB | Measurement role |
|:---|---:|---:|:---|
| PocketBase | 44,889,539 | 42.810 | Core container, idle maximum |
| MCP Gateway | 108,947,046 | 103.900 | Core container, idle maximum |
| Docker socket proxy (MCP) | 10,506,732 | 10.020 | Core container, idle maximum |
| Docker socket proxy (write) | 7,286,555 | 6.949 | Core container, idle maximum |
| SQLPage | 24,819,794 | 23.670 | Core container, idle maximum |
| Pocket Memory | 206,376,960 | 196.816 | Core container, warm idle process RSS |
| Goose | 42,540,728 | 40.570 | Harness container, idle maximum |
| Claude Code | 10,064,232 | 9.598 | Harness container, idle maximum |
| Codex | 8,158,970 | 7.781 | Harness container, idle maximum |
| OpenCode | 8,081,375 | 7.707 | Harness container, idle maximum |
| Ollama, no model loaded | 167,038,157 | 159.300 | Optional container, idle maximum |
| ntfy | 33,218,888 | 31.680 | Optional container, idle maximum |
| Caddy | 65,245,184 | 62.223 | Pinned Caddy container used as an estimate for native Caddy |
| `pocketcoder-release check-metadata` | 6,692,864 | 6.383 | One-shot Linux peak RSS; exits after the check |

The six permanent core containers total 402,826,626 bytes (384.165 MiB).
The release manager is a systemd one-shot task, not a daemon, so its
steady-state contribution is zero. Approximately 130 MiB of Pocket Memory's
warm RSS is file-backed model data that Linux can reclaim under pressure.

Docker does not publish one fixed Docker Engine memory requirement. Its
[resource guidance](https://docs.docker.com/engine/containers/resource_constraints/)
instead recommends measuring the real application and provisioning adequate
host memory. For local context, one snapshot of the benchmark LinuxKit VM with
five workload containers measured:

| Docker runtime process | Exact bytes | MiB |
|:---|---:|---:|
| `dockerd` | 169,189,376 | 161.352 |
| `containerd` | 60,919,808 | 58.098 |
| Combined engine processes | 230,109,184 | 219.449 |
| Largest `containerd-shim` per container | 18,354,176 | 17.504 |

Those runtime values are environment-specific measurements, not portable
constants. They also exclude Linux itself, filesystem cache, active agent
subprocesses, compilers, package installation, release downloads and database
snapshots. The signed policy therefore declares 2 GiB as the minimum for a
remote-model deployment and recommends 4 GiB for operational headroom. Pocket
Memory's embedding model is already included above; optional generative local
models add their model and context requirements separately.

## Flutter client

The [`client/`](client/) workspace contains the reusable PocketCoder client and
the public FOSS app target:

| Target | Purpose | Melos command |
|:---|:---|:---|
| `apps/pocketcoder_foss` | FOSS/F-Droid-compatible app without proprietary integrations | `melos run run_foss` |

From `client/`:

```bash
dart pub global activate melos
flutter pub get
melos bootstrap
melos run build_gen
melos run build_foss          # FOSS/F-Droid-compatible Android debug APK
melos run check:purity
melos run test
```

When no server URL is saved, the app defaults to `http://127.0.0.1:8090`.
For a VPS, enter the HTTPS URL printed by deployment (or the Tailscale URL)
through the existing-server onboarding flow.

The FOSS target can be compiled independently for Android and is intended to
remain suitable for F-Droid distribution. The separate private PocketCoder Pro
repository consumes this workspace as a pinned Git submodule.

Every script and template executed on a user's VPS is kept in this public
repository. Managed clients may orchestrate those files, but the deployed
bootstrap, host configuration, release activation, and update behavior remain
inspectable at the exact source commit reported by the deployment.

## Cloudflare Workers

The [`workers/`](workers/) directory contains two independent Wrangler
projects. They are not part of Docker Compose and are only needed for the
corresponding hosted features:

| Worker | Purpose | Resources |
|:---|:---|:---|
| `oauth-relay` | PKCE OAuth broker for GitHub and Linode; keeps client secrets server-side | KV namespace and provider OAuth secrets |
| `image-relay` | Public image and release manifests | R2 bucket `pocketcoder-images` |

Each worker has its own `package.json` and `wrangler.toml`. Deploy one with
`cd workers/<name> && npm install && npm run deploy`, or deploy both after
configuring their bindings and secrets with:

```bash
./tooling/scripts/deploy-workers.sh
```

## Testing

The acceptance suite drives a real c1 (PocketBase) → c2 (Goose) turn against a live model and asserts the AG-UI contract end to end:

```bash
tests/compose/agent/run.sh
```

It overlays `docker-compose.agent-test.yml`, starts the active c1/c2/c3
services, and runs the `agent-c1-test` Bats runner in an isolated container.
See [`docs/agent-testing-strategy.md`](docs/agent-testing-strategy.md).

## Codebase

*(Original PocketCoder code — regenerated by `tooling/scripts/generate_audit.sh`; tests and generated code excluded. Dormant Rust — the sandbox proxy and `poco-agents` — lives in [`dormant/`](dormant/) and is excluded.)*

| Language | LoC | Component |
| :--- | ---: | :--- |
| Go | 10056 | c1: PocketBase + ACP client + AG-UI server |
| Dart | 54822 | Flutter client (non-generated) |
| **Core code** | **~64878** | Go + Dart — product code |
| Tests | 23684 | not code — Go 7036 · Dart 8600 · Bash 8048 |
| Tooling | 6534 | not code — Bash scripts / infra |

The backend is deliberately tiny: PocketBase supplies auth, the database, REST, and realtime *as a library*, so c1 is just the ACP client, the AG-UI bridge, and a handful of hooks. Lean glue over battle-tested building blocks is the whole thesis.

## Disclaimer & License

An active research project by a solo developer, built in the open — not a commercial product, no support SLAs. Bug reports are welcome; I move at my own pace.

PocketCoder is licensed as a whole under **AGPL-3.0-or-later**, including the
Flutter client, backend, and self-hosting infrastructure. Third-party runtime
components retain their own licenses. The agent core (Goose) and PocketBase are OSI-approved open
source. Pocket Memory is original AGPL code; its local multilingual E5 model and
other third-party dependencies retain their own FOSS licenses and provenance.

The client and backend here are free software and fully self-hostable. The
separate PocketCoder Pro distribution adds managed one-tap VPS provisioning,
commercial billing, app-store integrations, and hosted push convenience;
self-hosters skip it entirely by running `deploy.sh` directly.
