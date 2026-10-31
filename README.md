# PocketCoder

**Meet Poco, your own private AI assistant, on a server that is truly yours.** PocketCoder runs an AI assistant (and a real coding agent) on a server you own, not a company's cloud. The mobile app is how you set it up, talk to it, and approve or deny what it wants to do. You own the machine and the data. Small yet sovereign.

## What the app does

The PocketCoder app is a mobile front end for Poco, the assistant running on your own VPS or machine:

- **Set up a private server from your phone.** Answer a few questions and Poco gets you a hosting provider and a running PocketCoder, explaining each step in plain language. This guided setup is part of PocketCoder Pro; self-hosters run [`deploy.sh`](deploy.sh) instead.
- **Use Poco as an everyday assistant.** Talk through a problem, draft or edit something, look into a question, or make a plan.
- **Use Poco as a real coder.** Ask it to build, fix, or ship software, and it writes and tests the code. Follow its replies, plans, and tool calls as they stream in.
- **Approve or deny actions.** When the agent wants to run a command, edit a file, or use a tool, the request shows up in the app as an explicit approve/deny choice. The default is human-in-the-loop, and you can set "always allow" rules for the things you trust.
- **Pick your agent.** Goose is the default. Claude Code, Codex, and OpenCode are also supported, and each runs in its own Docker container.
- **Browse the workspace.** Look at the files the agent is working on.
- **Extend and schedule.** Connect external tools as MCP servers (GitHub, Notion, and others), manage skills, and schedule recurring tasks.
- **Get notified.** Push notifications tell you when Poco needs your input or finishes a task, even when the app is closed (self-hosted ntfy in this repository).
- **Keep memory.** Pocket Memory, a local Rust/SQLite service, lets the agent store and recall observations across sessions without calling a separate memory LLM.

Behind the app is a small server stack: PocketBase for auth and state, the selected agent harness, a Docker MCP gateway, and Pocket Memory, all in Docker Compose. Everything is on your machine, with no telemetry, and the agent works in a Docker container separate from the rest of your server, so an AI mistake stays small. Bring your own model (local Ollama or a hosted provider) or use the recommended one. If you use a hosted model provider or an external MCP server, that provider receives what the agent sends it.

## Who it is for

- **Anyone who wants a private AI assistant** and doesn't want their conversations and data sitting in someone else's cloud. You don't need to know what a server is: the guided setup handles it.
- **Developers and the curious-but-technical** who want a coding agent they control (Goose, Claude Code, Codex, or OpenCode) and want to review its work from their phone.
- **Self-hosters** who are comfortable with Docker and prefer open source and their own data. The free path is this repository.
- **One person, or a small group of trusted friends and family** sharing a single deployment. PocketCoder is not a hostile multi-tenant SaaS boundary: people sharing a deployment can see one another's workspace, agent activity, logs, and configured integrations.

It is not aimed at editing 500-line diffs on a phone. The phone is for orchestration, review, and control: assigning tasks, reading plans, and approving executions.

## Get it

- **Self-host (free, this repository).** Run [`./deploy.sh`](deploy.sh) on a Linux VPS, or `docker compose up -d` locally, and connect the app to your server. See [Quick Start](#quick-start).
- **PocketCoder Pro (optional).** A paid, separate distribution on the app stores (as "Poco the PocketCoder") that sets up and manages the server for you from your phone: one-tap VPS provisioning, HTTPS configured for you, and hosted push notifications. Your server stays on your own VPS account, so it keeps running if you stop paying. See [What is public and what is Pro](#what-is-public-and-what-is-pro). Details and pricing: [pocketcoder.org](https://pocketcoder.org/).
- **This repository** is the complete public AGPL Core: server, deployment scripts, Workers, and the FOSS Flutter client (`apps/pocketcoder_foss`).

PocketCoder is a solo project built in the open. It follows an **Alpine Linux** philosophy: a tiny original surface area standing on FOSS shoulders, with **PocketBase** for state and auth, **Goose** as the default harness, and open agent protocols (**ACP**, **AG-UI**, **MCP**) in between.

> ### Status: MVP complete
> - ✅ **Backend contract (c1 ↔ c2) passes live acceptance** against a real model: authenticated runs, streaming, tool calls, and phone approve/deny.
> - ✅ **The Flutter client's core loop is live**: chat list, conversation, file browser, MCP/scheduler/skills/tool-permissions/agent-config/notification settings, logout, all wired to real PocketBase-backed data.
> - ✅ **Pocket Memory** is an always-on Rust/SQLite MCP service with local multilingual hybrid recall.
> - ✅ **The c3 MCP gateway runs by default**; external MCP servers are approved per deployment via the `mcp_servers` collection.
> - 💤 **Dormant:** the Rust sandbox proxy is retained for future work, see [`dormant/`](dormant/).
>
> AI can make mistakes. Keep your own backups and review generated code before running it. The current limits of the security model are in [`SECURITY.md`](SECURITY.md).

The default architecture supports a fully self-hosted path: PocketCoder, Goose,
Ollama, and optional ntfy all run in your Compose deployment. Review the privacy
policies and permissions of every hosted provider or integration before
connecting sensitive accounts.

## Why it exists

Two patterns have emerged for working with autonomous agents, and PocketCoder aims for the secure middle ground:

- **Mission-control on the go.** Tools like Google Antigravity showed that a lot of agent work is *reviewing plans and approving executions*, not typing syntax. That subset fits a phone perfectly — assign tasks, review plans, approve deployments while away from your keyboard.
- **A safer alternative to chat-bridge agents.** Chat is convenient, but it is a poor permission and interruption interface for an agent with terminal, filesystem, and network access. PocketCoder puts the interaction inside an authenticated app and exposes the harness's permission requests as explicit, human-inspectable approve/deny choices. The default is human-in-the-loop; configured “always allow” rules and the security limitations of the current c2 runtime are documented in [`SECURITY.md`](SECURITY.md).

**Core principles:** scoped for mobile (orchestration, review, and control rather than 500-line diffs on a phone) · least privilege and human-in-the-loop by default · Docker as the primary runtime boundary · open protocols instead of bespoke glue · local-first when desired, provider-independent when useful.

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

### What is public and what is Pro

This repository is the complete public Core/FOSS product. It includes the
PocketCoder backend, Compose services, Pocket Memory, MCP gateway integration,
release manager, NixOS and standard-Linux deployment scripts, Cloudflare Worker
source, schemas, tests, and the FOSS Flutter client. A self-hoster can inspect,
build, deploy, update, and operate that path from this repository.

PocketCoder Pro is maintained in a separate private repository. Pro adds the
commercial mobile shell and convenience services: hosted provider
provisioning, billing, app-store distribution, and hosted push integrations.
The Pro shell consumes this repository's public Flutter package and public
deployment/release contracts; it does not replace or conceal the server code
that runs on a user's machine. The proprietary onboarding screens and Pro
service adapters are therefore not auditable from this repository by design.
That boundary is intentional and should not be read as claiming that the
one-tap commercial client is fully open-source.

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

The selected harness is the **system of record** for its conversation and session history. PocketBase stores authentication, configuration, permission rules, and the `chat_id → external harness session` mapping — it is not a second conversation database or durable approval ledger. The Flutter client keeps a local Drift cache as an offline mirror refreshed from the selected harness.

### What is current, and what is experimental

PocketCoder has gone through two related designs. An earlier prototype explored a
separate Rust execution gateway, an orchestrator, and multiple subagent
containers. That work tested the security model—especially the combination of
sensitive-data access, untrusted-content ingestion, and external execution—but
the transport wiring (tmux, Unix sockets, WebSockets, and OpenCode SSE) became
too fragile for the MVP. The old sandbox and orchestration code remains under
[`dormant/`](dormant/) as future work.

The current runtime is deliberately smaller: a selected ACP-compatible harness
executes inside c2, c1 translates ACP to AG-UI, and Docker/network isolation
provides the hard boundary. The harness owns the conversation; PocketBase owns
the control-plane configuration around it. This is a strong approval and scope
boundary, not an air-gapped sandbox—see [`SECURITY.md`](SECURITY.md) for the
current limitations.

PocketCoder also includes **Pocket Memory**, a Rust/SQLite service exposed to
the agent through MCP. It stores agent-authored observations and interpretations,
supports FTS5 plus optional local multilingual embeddings, and keeps provenance
so a remembered interpretation can be traced back to an observation. SQLPage is
provided for inspection and observability; it is not an additional agent or a
write-time security filter.

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
| **Security posture** | Harness permission requests surfaced for explicit approval by default; configurable rules; c2 is not yet a hardened sandbox | Permission modes, no mobile override | Approval bolted on, if any |

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
repository consumes this workspace as a pinned Git dependency/submodule. The
public checkout intentionally contains only `apps/pocketcoder_foss`; Pro's
`apps/pocketcoder`, `packages/pocketcoder_pro`, and app-store integrations are
not present here.

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
| Go | 20,090 | VPS — c1: PocketBase + ACP client + AG-UI server |
| Rust | 3,514 | VPS — Pocket Memory |
| **VPS total** | **~23,604** | self-hosted server stack |
| Dart | 100,299 | Mobile — Flutter client (non-generated) |
| TypeScript | 612 | Infra — Cloudflare Workers (FOSS, runs on our account) |
| **Grand total** | **~124,515** | VPS + Mobile + Infra — product code |
| Tests | 53,551 | not code — Go 17,724 · Dart 31,983 · Rust 1,387 · TS 717 · Bash 1,740 |
| Tooling | 7,297 | not code — Bash scripts / infra |

The backend is deliberately tiny: PocketBase supplies auth, the database, REST, and realtime *as a library*, so c1 is just the ACP client, the AG-UI bridge, and a handful of hooks. Lean glue over battle-tested building blocks is the whole thesis.

## Disclaimer & License

An active project by a solo developer, built in the open. The free self-hosted Core has no support SLAs. Bug reports are welcome; I move at my own pace.

PocketCoder is licensed as a whole under **AGPL-3.0-or-later**, including the
Flutter client, backend, and self-hosting infrastructure. Third-party runtime
components retain their own licenses. The agent core (Goose) and PocketBase are OSI-approved open
source. Pocket Memory is original AGPL code; its local multilingual E5 model and
other third-party dependencies retain their own FOSS licenses and provenance.

The client and backend here are free software and fully self-hostable. The
separate PocketCoder Pro distribution adds managed one-tap VPS provisioning,
commercial billing, app-store integrations, and hosted push convenience;
self-hosters skip it entirely by running `deploy.sh` directly. The public
deployment source and the exact release source commit used by a server remain
inspectable even when that server was provisioned by Pro.

For a provider-independent route to the same deployment state, see the
[manual deployment guide](deploy/README.md).
