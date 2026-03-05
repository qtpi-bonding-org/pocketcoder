# PocketCoder vs OpenClaw: Deep Comparison

Last updated: 2026-03-03

OpenClaw (~191k GitHub stars, MIT license) is the highest-profile open-source AI assistant project. PocketCoder occupies a different niche but competes for the same user intent: "control an AI agent from my phone." This document compares both projects across 12 dimensions using actual source code analysis.

---

## At a Glance

| | PocketCoder | OpenClaw |
|---|---|---|
| **Focus** | Sovereign AI coding assistant | Personal AI assistant |
| **Target user** | Solo devs + non-technical users | Single power user |
| **Mobile story** | Flutter app (dedicated control plane) | iOS/Android/macOS native nodes + chat bridges |
| **Deployment** | Docker Compose (multi-service stack) | npm global install (single Node.js process) |
| **Agent brain** | OpenCode (sidecar HTTP service) | Pi SDK (embedded in-process) |
| **Tool protocol** | MCP (standard, containerized) | Custom TypeScript tools (in-process) |
| **Auth** | PocketBase zero-trust (user/pass, per-user isolation) | Chat app login + DM pairing codes |
| **Multi-user** | Yes (PocketBase users with isolated chats/keys/permissions) | No (single owner; group chats allow shared access) |
| **License** | AGPLv3 | MIT |

---

## 1. Agent Runtime

### OpenClaw: Embedded Pi SDK

Pi is OpenClaw's own agent runtime, embedded directly in the Gateway's Node.js process. It calls LLM APIs (Anthropic, OpenAI, Google, etc.) in-process with no HTTP round-trips.

- Entry: `src/agents/pi-embedded-runner/run.ts`
- Session storage: `~/.openclaw/agents/<agentId>/sessions/*.jsonl`
- Supports model switching, tool injection, session compaction — all in-process

### PocketCoder: OpenCode Sidecar

OpenCode runs as a separate Docker container, accessed via HTTP REST API. The Interface service bridges PocketBase events to OpenCode SDK calls.

- Entry: `services/opencode/` (serves on port 3000)
- Bridge: `services/interface/src/index.ts` (event pump + command pump)
- Config changes trigger container restart via Docker Socket Proxy

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Latency | Lower (in-process) | Higher (HTTP, but local Docker) |
| Isolation | Worse (crash = gateway crash) | Better (OpenCode restarts independently) |
| Upgradeability | Tight coupling to Pi SDK | Can swap OpenCode versions via image tag |

**PocketCoder's sidecar model is the right choice** for a multi-service sovereign stack. Isolation and restartability outweigh the latency cost.

---

## 2. Tool System

### OpenClaw: In-Process TypeScript Tools

Tools are TypeScript functions loaded directly into the Pi runtime. ~30+ built-in tools: browser, cron, image, exec, discord/slack actions, etc.

- Definitions: `src/agents/pi-tools.ts`, `src/agents/tools/`
- Policy: `src/agents/pi-tools.policy.ts` (allowlist/denylist)
- Adding a tool requires code change + recompile + restart

### PocketCoder: MCP Gateway (Standard Protocol)

Tools are MCP servers — separate processes or containers communicating via JSON-RPC over stdio/HTTP. Any language. User approves servers in Flutter UI.

- Gateway: `services/mcp-gateway/` (Docker MCP)
- Config rendered by Go hook: `services/pocketbase/internal/hooks/mcp.go`
- Adding a tool = pull a Docker image or npm install

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Execution speed | Faster (no serialization) | Slower (JSON-RPC + process boundary) |
| Extensibility | Requires TypeScript + rebuild | Any language, hot-addable |
| Ecosystem | ClawHub (~13k skills, proprietary format) | MCP ecosystem (standard protocol, growing) |
| Isolation | Tools run in same process | Tools run in separate containers |

**PocketCoder's MCP approach is more standards-based and extensible.** MCP is becoming the industry standard. OpenClaw rolled their own.

---

## 3. Scheduling / Cron

### OpenClaw: Built-in CronService

Full scheduling system with three schedule types, session isolation, and heartbeat-based execution.

- Service: `src/cron/service.ts`, types: `src/cron/types.ts`
- Schedules: `at` (one-shot timestamp), `every` (interval in ms), `cron` (cron expression + timezone)
- Payloads: system event (inject text) or agent turn (run agent with message, model override, thinking level)
- Session targets: `main` (shared context) or `isolated` (separate session per job)
- Heartbeat: 30-minute default wake cycle fires due jobs
- Persistence: `~/.openclaw/cron/jobs.json`
- State tracking: nextRunAt, lastRunAt, lastStatus, lastError, lastDuration

### PocketCoder: None

No scheduling capability. Research doc exists (`docs/research/POCO_MEMORY_HYBRID_PLUMBING.md`) but is about memory, not cron.

### Verdict

**Gap.** OpenClaw's cron enables autonomous agent behavior ("check my server every hour," "run tests at 2am"). PocketCoder agents are purely reactive — they only work when a human sends a message.

**Implementation path:** `pc_cron_jobs` PocketBase collection + Go hook with a timer loop that fires OpenCode SDK calls via the Interface service. Pattern 1 (SDK via Interface).

---

## 4. Memory / Knowledge Persistence

### OpenClaw: Hybrid Vector + FTS

Sophisticated memory system with embeddings, full-text search, and hybrid ranking.

- Core: `src/memory/manager.ts`, schema: `src/memory/memory-schema.ts`
- Vector search: sqlite-vec + embeddings via OpenAI or Gemini
- Full-text search: SQLite FTS5
- Hybrid merge: weighted combination of vector + keyword results (RRF-style)
- Auto-indexing: chokidar watches `~/clawd/` markdown files + session transcripts
- Chunk-based: splits markdown into chunks, embeds individually
- Extensions: `extensions/memory-core`, `extensions/memory-lancedb`

### PocketCoder: Research Doc Only

Ambitious design in `docs/research/POCO_MEMORY_HYBRID_PLUMBING.md` with Ebbinghaus forgetting curves, ghost tiers, and decay algorithms. Nothing implemented.

Proposed `pc_memories` collection with weight-based decay, TTL for KV, and deep recall trigger.

### Verdict

**Gap.** OpenClaw's memory lets the agent remember user preferences, project context, and past decisions across sessions. PocketCoder's agent starts fresh each session.

**Implementation path:** Start simple — PocketBase FTS on chat history gets 80% of the value. Add vector search later via an MCP server or OpenCode's own memory features if they evolve.

---

## 5. Security Model

### OpenClaw: Tool Policy + Opt-in Docker Sandbox

- Tool allowlist/denylist via static config: `src/agents/pi-tools.policy.ts`
- Docker sandbox settings: `src/config/types.sandbox.ts` (read-only root, tmpfs, caps, seccomp, AppArmor)
- **Sandboxing is opt-in** — by default, OpenClaw can execute any shell command with no restrictions
- Security researchers have documented sandbox bypass vulnerabilities (Snyk labs)
- No per-action user approval flow

### PocketCoder: Permission Engine + Network Isolation

- Every tool call gated by explicit PocketBase permission record: `services/pocketbase/internal/hooks/permissions.go`
- Authority challenge (UUID) for cryptographic verification
- Audit trail: all permission decisions persisted in PocketBase
- Per-user tool approval: `services/pocketbase/internal/hooks/tool_permissions.go`
- Network isolation: 6 Docker networks with least-privilege connectivity
- Docker Socket Proxy: limits container operations to restart-only
- Shell proxy: command validation layer

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Default posture | Open (no restrictions) | Closed (everything gated) |
| User approval | None (config-based policy) | Every tool call requires approval |
| Audit trail | None | Full (PocketBase records) |
| Container hardening | More mature (seccomp, caps) | Less hardened (no seccomp yet) |
| Network isolation | Single process (N/A) | 6 isolated Docker networks |
| Known bypasses | Yes (Snyk documented) | None documented |

**PocketCoder's permission model is a core differentiator.** OpenClaw's goals.md explicitly calls this out as PocketCoder's advantage over OpenClaw's "unauthenticated chat bridges for system-level commands."

**Enhancement opportunity:** Add read-only root, capability drops, and seccomp profiles to sandbox Dockerfile.

---

## 6. Session Management

### OpenClaw

- JSONL transcripts: `~/.openclaw/agents/<agentId>/sessions/*.jsonl`
- Session branching and compaction
- Single-user; sessions belong to one agent identity

### PocketCoder

- PocketBase collections: `chats`, `messages`, `session_keys`
- Interface bridges PocketBase events to OpenCode sessions
- Multi-user: each PocketBase user has isolated chats
- Realtime subscriptions: Flutter gets live updates via PocketBase WebSocket

### Verdict

**PocketCoder wins.** Multi-user session isolation with realtime sync and audit trail is the right model for a shared server.

---

## 7. Observability / Telemetry

### OpenClaw: OpenTelemetry (OTLP/HTTP)

Full observability stack via the `diagnostics-otel` extension plugin.

- Extension: `extensions/diagnostics-otel/src/service.ts` (636 LOC)
- Event layer: `src/infra/diagnostic-events.ts` (12 event types)
- 11 OpenTelemetry packages (@opentelemetry/sdk-node, exporters for traces/metrics/logs)

**Three signal types:**

| Signal | Examples |
|--------|---------|
| Metrics | `openclaw.tokens` (counter), `openclaw.cost.usd` (counter), `openclaw.run.duration_ms` (histogram), `openclaw.queue.depth`, `openclaw.session.stuck` |
| Traces | `openclaw.model.usage` spans, `openclaw.webhook.processed` spans, `openclaw.message.processed` spans |
| Logs | Structured OTLP log records from main logger |

- Config: `diagnostics.otel.endpoint`, `sampleRate`, `flushIntervalMs`
- Env vars: `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`
- Compatible with: Jaeger, Datadog, Honeycomb, New Relic, Grafana Tempo

Also has built-in CLI observability:
- `openclaw status --all` — read-only system overview
- `openclaw doctor` — migrations, config diagnostics
- Provider usage tracking: fetches cost data from Anthropic/OpenAI/Gemini APIs directly

### PocketCoder: SQLPage Dashboards

- SQLPage queries OpenCode's SQLite DB directly for cost/token tracking
- SQLPage queries CAO's SQLite DB for subagent task dashboard
- Container health via `/healthz` endpoints
- Dashboard accessible from mobile browser at `/api/pocketcoder/proxy/observability/`
- No structured telemetry export (no OTel, no metrics endpoint)

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Structured telemetry | OpenTelemetry (industry standard) | None |
| Dashboards | CLI-based (`status --all`) | SQLPage (visual, queryable from mobile) |
| Cost tracking | Per-provider API fetching + OTel counters | SQLPage queries on OpenCode SQLite |
| Export to backends | Yes (Jaeger, Datadog, Honeycomb, etc.) | No |
| Mobile-friendly | No (CLI only) | Yes (SQLPage served via PocketBase proxy) |

**OpenClaw has more sophisticated backend telemetry. PocketCoder has more accessible dashboards.** Different strengths. Consider adding OTel export as a future enhancement.

---

## 8. Deployment

### OpenClaw

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

- Single Node.js process with launchd/systemd daemon
- Docker is optional (community-maintained images)
- Config at `~/.openclaw/openclaw.json`
- Workspace at `~/.openclaw/workspace/`

### PocketCoder

```bash
docker compose up
```

- 7+ services: PocketBase, OpenCode, Interface, Sandbox, MCP Gateway, SQLPage, Docker Socket Proxy
- Optional: ntfy (notifications)
- Config via `.env` file
- Volumes for persistence

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Setup complexity | Lower (one command) | Higher (Docker + .env) |
| Isolation | Worse (single process) | Better (containerized services) |
| Upgradeability | `npm update -g` | `docker compose pull && up` |
| Enterprise-friendly | Less (global npm) | More (Docker Compose) |
| Resource usage | Lower (~1 process) | Higher (~7 containers) |

Different trade-offs for different users. PocketCoder's deploy button vision will close the setup gap.

---

## 9. Mobile / Client

### OpenClaw

Three native apps:
- **macOS**: Swift + SwiftUI menu bar app (`apps/macos/`) — includes embedded gateway server
- **iOS**: Swift + SwiftUI (`apps/ios/`) — Canvas, Voice Wake, Talk Mode, camera, screen recording
- **Android**: Kotlin (`apps/android/`) — Canvas, Talk Mode, camera, screen recording, SMS, contacts
- Communication: ACP (Agent Client Protocol) over WebSocket
- Also: 20+ chat channel bridges (WhatsApp, Telegram, Discord, etc.)

### PocketCoder

One cross-platform app:
- **Flutter**: Dart (`client/packages/pocketcoder_flutter/`) — iOS + Android from one codebase
- Communication: PocketBase REST API + WebSocket realtime subscriptions
- Status: Under development
- No chat bridges (dedicated app only — by design)

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Maturity | Production-ready (3 native apps) | Under development (1 Flutter app) |
| Maintenance cost | High (3 codebases, 3 languages) | Low (1 codebase, 1 language) |
| Device features | Deep (camera, location, screen recording, SMS, contacts) | Basic (chat + permissions) |
| Security | Chat app login (no real auth) | PocketBase auth (email/password) |

OpenClaw has more client maturity. PocketCoder's Flutter approach is more sustainable long-term. The dedicated app (vs chat bridges) is a security advantage.

---

## 10. Extensibility

### OpenClaw: Skills + Plugin SDK

- Skills: TypeScript modules in `SKILL.md` format, three tiers (bundled/managed/workspace)
- ClawHub registry: ~13,700 community skills
- Extensions: 32+ in monorepo (`extensions/`) — channels, auth providers, diagnostics, memory backends
- Plugin SDK exported from main package
- Hot-reloadable at runtime

### PocketCoder: MCP Servers

- MCP (Model Context Protocol): Anthropic's standard for tool integration
- Gateway: Docker MCP translates between OpenCode and containerized MCP servers
- Any language (Python, Go, Node, Rust, etc.)
- User approval flow: Flutter UI -> PocketBase -> Go hook -> config render -> Gateway restart
- Growing ecosystem (not yet as large as ClawHub)

### Verdict

| | OpenClaw | PocketCoder |
|---|---|---|
| Ecosystem size | Larger (~13.7k skills) | Smaller (growing MCP ecosystem) |
| Protocol | Proprietary | Standard (MCP) |
| Language support | TypeScript only | Any language |
| Isolation | In-process | Containerized |
| Hot-reload | Yes | Requires gateway restart |

**PocketCoder bet on the standard.** MCP is backed by Anthropic and adopted by Claude Code, Cursor, Windsurf, and others. OpenClaw's proprietary skills format is a walled garden.

---

## 11. Voice / Media

### OpenClaw

- Audio transcription: Google, Deepgram, OpenAI Whisper (`src/media-understanding/`)
- Text-to-speech: ElevenLabs + system TTS fallback (`src/tts/`)
- Voice calls: `extensions/voice-call/`
- Voice Wake + Talk Mode: always-on speech on macOS/iOS/Android
- Media pipeline: images, audio, video with size caps and temp file lifecycle (`src/media/`)

### PocketCoder

- No voice support
- No media pipeline
- No transcription or TTS

### Verdict

**Gap**, but low priority. PocketCoder is a coding assistant — mobile is for orchestration, not conversation. Voice could be added later via MCP servers (Whisper, edge-tts) + Flutter audio plugins.

---

## 12. Webhooks / External Triggers

### OpenClaw

- Gmail Pub/Sub: `src/hooks/gmail-ops.ts` — watch email, ingest as prompts
- Telegram/Line webhooks: channel-specific inbound handlers
- Generic webhook endpoint for external triggers
- Auto-reply triggers with configurable activation

### PocketCoder

PocketBase's REST API **already is** a webhook endpoint. Any authenticated client can `POST /api/collections/messages/records` with `role: 'user'`, and the Interface event pump picks it up and fires OpenCode. CI/CD systems, GitHub Actions, or any external tool can trigger the agent with PB credentials and a chat ID.

If simpler auth is needed later (bearer token, signed URL), a thin Go hook can wrap the PB create. But the core plumbing already exists.

### Verdict

**Not a real gap.** PocketCoder's architecture already supports external triggers via PocketBase's standard API. OpenClaw built dedicated webhook infrastructure because they needed it for chat bridges — PocketCoder doesn't need that.

---

## Recent OpenClaw Development (as of 2026-03-03)

OpenClaw reference repo pulled on 2026-03-03 showed 8,025 new commits (+658k/-185k lines). Notable new capabilities:

### New Extensions

| Extension | What it does | Relevant to PC? |
|-----------|-------------|-----------------|
| `device-pair` | QR code pairing for iOS/Android gateway connections | No — Flutter connects to PocketBase directly |
| `phone-control` | `/phone arm/disarm` for gating camera/screen/writes on iOS | No — different mobile model |
| `talk-voice` | ElevenLabs voice selection for Talk Mode | No — voice not a priority |
| `acpx` | ACP runtime backend via acpx CLI, thread-bound agents | No — PocketCoder uses OpenCode SDK |
| `thread-ownership` | Slack thread ownership for multi-agent routing | No — PocketCoder has PB-based session isolation |
| `diffs` | Read-only diff viewer with PNG/PDF rendering | Maybe — PocketCoder has diff summary planned |
| `feishu` | Full Feishu/Lark channel integration | No — no chat bridges |
| `irc` | IRC channel | No |
| `synology-chat` | Synology NAS chat integration | No |

### Security Hardening (Worth Studying)

- **SecretRef system**: Credential management expanded to 64 surfaces — `openclaw secrets` CLI with planning/apply/audit flows. PocketCoder's LLM key management is simpler but functional.
- **Node exec approvals**: Required `systemRunPlan` structure, symlink/hardlink rejection, canonical path enforcement. Good patterns for PocketCoder's shell proxy to adopt.
- **SSRF protections**: IPv6 multicast blocking, CDN hostname allowlisting, workspace hardlink rejection.
- **iOS security stack**: Keychain storage, concurrency locks, TLS fingerprinting, PCM-to-MP3 TTS fallback.

### Cron Improvements

Since our last sync, OpenClaw added:
- **Failure alerts**: Configurable notifications for repeated job errors
- **Per-job model fallback**: `payload.fallbacks` for model override chains
- **Failure destination**: Route failed cron outputs to specific channels
- **Lightweight bootstrap**: Opt-in mode with only `HEARTBEAT.md` for automation runs (less context = cheaper)
- **Account routing**: `--account` flag for multi-account delivery

These are mature production features. When PocketCoder builds cron, study OpenClaw's failure handling patterns.

### Memory Improvements

- **Ollama embedding provider**: Local embeddings without API keys — relevant for PocketCoder's sovereignty thesis
- **LanceDB improvements**: Custom embedding dimensions, hybrid recall with text-weight floor

### New Tools

- **PDF analysis**: Native provider support (Anthropic + Google), fallback extraction for other models, configurable limits. PocketCoder could add this as an MCP server.
- **Diffs viewer**: Canvas-hosted diff visualization with PNG/PDF rendering. Related to PocketCoder's planned diff summary feature.

### Platform Maturity

- **OpenAI WebSocket**: WebSocket-first transport for OpenAI responses (lower latency, server-side context management)
- **Android capabilities**: Now supports notifications, contacts, calendar, motion sensors, photos, SMS, calls — deep device integration
- **ACP dispatch**: Defaults to enabled — agent collaboration protocol is now the standard runtime path

### What This Means for PocketCoder

OpenClaw is moving fast on **breadth** (more channels, more device features, more integrations). PocketCoder should stay focused on **depth** (better security, better multi-user, better sovereignty). The features worth watching:

1. **Cron failure handling** — when we build cron, learn from their patterns
2. **Ollama embeddings** — local memory search without API keys aligns with sovereignty
3. **SecretRef patterns** — credential management is important for multi-user
4. **PDF tool** — easy win as an MCP server

---

## Summary: What to Steal, What to Skip

### Adopt from OpenClaw

| Feature | Priority | Why |
|---------|----------|-----|
| **Cron/scheduling** | High | Enables autonomous agent behavior; core for always-on server |
| **Memory/knowledge** | Medium | Cross-session context; start with PB FTS, add vectors later |
| **Webhooks** | N/A | PocketBase REST API already serves as webhook endpoint |
| **Container hardening** | Medium | Read-only root, seccomp, cap drops for sandbox |
| **OpenTelemetry export** | Low | Structured telemetry for production deployments |
| **Voice/media** | Low | Not core to coding assistant use case |

### Do NOT Copy from OpenClaw

| Feature | Why |
|---------|-----|
| Embedded agent SDK | Sidecar isolation is better for multi-service stacks |
| Three native apps | Flutter write-once is more sustainable |
| Proprietary skills format | MCP is the standard; don't build a walled garden |
| Chat bridge architecture | Dedicated app with real auth is the security advantage |
| Single-user model | Multi-user is PocketCoder's differentiator |

### PocketCoder's Unique Advantages

These are things OpenClaw does NOT have:

1. **Zero-trust permission model** — every tool call gated, audit trail, user approval
2. **Multi-user with isolated auth/keys/sessions** — family/team on one box
3. **MCP-based extensibility** — standards-based, any language, containerized
4. **Network isolation** — 6 Docker networks with least-privilege connectivity
5. **Deploy button vision** — zero-terminal setup from mobile
6. **SQLPage observability** — visual dashboards accessible from mobile browser
