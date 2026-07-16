# REFERENCES

Here's the full reference list, grouped by where each thing sits.

**c1 — PocketBase / Go**
- **PocketBase** — [`pocketbase/pocketbase`](https://github.com/pocketbase/pocketbase). Used as a Go library, not just the binary.
- **ACP Go client** — [`coder/acp-go-sdk`](https://github.com/coder/acp-go-sdk). Coder-backed, typed requests/responses, has working examples bridging Claude Code and Gemini CLI over ACP.
- **AG-UI Go SDK** — [`ag-ui-protocol/ag-ui`](https://github.com/ag-ui-protocol/ag-ui), specifically `sdks/community/go`. Not first-party but has real cross-org usage (Microsoft's Agent Framework, Tencent's trpc-agent-go both build on it).

**c2 — goose and what it spawns**
- **goose** — [`aaif-goose/goose`](https://github.com/aaif-goose/goose). Note the org: it moved from `block/goose` to the Agentic AI Foundation. Old links/docs may still say `block/goose`.
- **claude-agent-acp** — [`zed-industries/claude-agent-acp`](https://github.com/zed-industries/claude-agent-acp) (also appears mirrored under `agentclientprotocol/claude-agent-acp` — same project, ACP itself is consolidating toward a neutral org the way goose did). This is the binary `GOOSE_PROVIDER=claude-acp` spawns.
- **codex-acp** — [`zed-industries/codex-acp`](https://github.com/zed-industries/codex-acp). Same role, for `GOOSE_PROVIDER=codex-acp`.
- **ACP spec itself** — [`zed-industries/agent-client-protocol`](https://github.com/zed-industries/agent-client-protocol) (Rust crate: `agent-client-protocol` on crates.io) and the docs site [agentclientprotocol.com](https://agentclientprotocol.com) — this is where the JSON Schema for generating your Dart types would ultimately trace back to, if you ever go that route for ACP-shaped data instead of just AG-UI-shaped data.

**c3 — MCP gateway catalog**
- **Cognee** — [`topoteretes/cognee`](https://github.com/topoteretes/cognee), MCP server specifically at `cognee-mcp/` in that repo. This is the catalog entry, not a library you import.
- GitHub, Notion, internal servers — whatever you already have registered, unchanged.

**Reference only — not a dependency, but worth keeping bookmarked**
- [`namanrajpal/acp-to-agui`](https://github.com/namanrajpal/acp-to-agui) — the small Python/TS reference bridge with the ACP→AG-UI event mapping table. Don't depend on it (early, 6 stars, built for a talk), but it's the best existing worked example of the exact translation you're writing in Go.

**Flutter side — deferred until the c1↔c2 Go spike succeeds**
- [`ag_ui`](https://pub.dev/packages/ag_ui) on pub.dev — the Dart AG-UI client to use for the eventual Flutter data-layer swap. It supplies typed AG-UI event models, decoding, and SSE support; PocketCoder should wrap it in its existing repository/cubit layer rather than rebuild the client protocol. Pin a released version and validate authenticated reconnect/background behavior against c1 before cutover.
- `acp_dart` and `dart_acp` — unnecessary in this architecture: Flutter speaks AG-UI only, while c1 (Go) is the ACP client.

One more useful one for tracking maturity/timing risk on the c2 side: the [`goosed`→ACP-over-HTTP tracking issue](https://github.com/aaif-goose/goose/issues/6642) — worth watching since that's the transport your whole c1↔c2 hop depends on, and it's still consolidating. The 2026-07-16 spike found that the currently pinned Goose image exposes an older per-POST SSE dialect rather than the current ACP Streamable-HTTP RFD, and remote `session/load` has not yet succeeded. Treat a successful remote reload on the selected Goose version as a hard prerequisite for c1.


# PocketCoder Revamp v2 — Architecture Plan

**Status:** design settled, pending implementation. Supersedes the container topology in the original `revamp` doc (which dropped `interface` but kept a 3-container ACP-only picture). This version adds AG-UI as the frontend-facing protocol and settles where memory (Cognee) lives.

## Motivation, unchanged from v1

Lean on FOSS protocols/tools instead of hand-rolled glue: MCP for tools, ACP for agent↔execution-harness communication, and (new in this version) AG-UI for harness↔frontend communication. Each protocol does the one job it's designed for; PocketCoder's own code is limited to the translation seams between them, not a bespoke protocol of its own.

## Container topology

| Container | Runs | Role |
|---|---|---|
| **c1** | PocketBase (as Go library) + Go AG-UI server + Go ACP client | Auth, state ledger, approval log, ACP↔AG-UI translation. The "front door" to the mobile app. |
| **c2** | goose, in ACP agent-server mode (`goose serve`) | The agent core. Spawns `claude-agent-acp` / `codex-acp` as a child process depending on `GOOSE_PROVIDER`. Least-trusted container — this is where arbitrary tool execution happens. |
| **c3** | Docker MCP Gateway | Hosts/proxies every external tool as an MCP server: GitHub, Notion, internal servers, and **Cognee** (memory/knowledge graph). |

Down from the original 4 (pocketbase, sandbox, interface, mcp-gateway) → this is 3, same as v1, but c2's contents and c3's catalog have changed.

`docker-socket-proxy-write` stays as-is, unaffected by any of this (PocketBase's container-restart capability).

## Data flow

```
Mobile (Flutter)
   │  AG-UI events over SSE (JSON, not binary protobuf)
   ▼
c1: PocketBase (auth, approval ledger)
   │  ACP-over-HTTP (JSON-RPC), via Go ACP client (coder/acp-go-sdk or similar)
   ▼
c2: goose (ACP agent-server mode)
   │  Provider trait → spawns claude-agent-acp / codex-acp as child process
   │  goose's own extensions + gateway-proxied MCP tools passed through to that process
   ▼
c3: Docker MCP Gateway
   ├── GitHub, Notion, internal servers (existing)
   └── Cognee (memory: remember / recall / forget)
```

Every tool call — shell exec via the `developer` extension, or an MCP call like Cognee's `remember` — is expected to surface back up through goose's ACP `session/update` → c1's `requestPermission` handling → the phone approve/deny UX. (Whether MCP-sourced calls actually hit this path identically to builtins is unconfirmed — see Open Questions. You've said this one doesn't worry you much either way, noted here for completeness.)

## Why goose sits where it does (two ACP roles at once)

goose in c2 is simultaneously:
- **An ACP *agent* (server)**, facing c1 — this is `goose serve` / ACP-over-HTTP, the target of the `goosed`→ACP-over-HTTP consolidation (tracked upstream, still maturing — pin a version).
- **An ACP *client***, facing whichever harness binary it spawned via `GOOSE_PROVIDER=claude-acp` / `codex-acp` — goose's `Provider` trait plugs the harness in, but goose still holds its **own** SQLite-backed session (`sessions.db`) independent of the harness's inner session. The two session IDs don't correlate; goose's own docs say so directly. This is real translation, not a pass-through (confirmed via a real goose bug where token usage was silently dropped crossing this boundary — since fixed, but illustrative of the seam).

This is architecturally different from Zed↔Claude Code (one hop, no goose in the middle) — deliberately accepted, because the SQLite session store, resume, and usage tracking goose already has would otherwise have to be hand-built.

## Why Cognee lives behind c3, not inside c2

Cognee is an MCP server by design (`remember`/`recall`/`forget`, plus code-graph tools) — that's its native shape, and c3 already exists specifically to host things of that shape (GitHub, Notion, internal servers). Putting it there instead of bundling it into c2:

- **Keeps the least-trusted container's blast radius small.** c2 is the one container explicitly modeled as "assume compromise" (restricted egress, no route to sensitive data). Cognee's whole value is a *persistent* knowledge graph — exactly the kind of durable, valuable state that shouldn't sit unguarded inside the untrusted execution loop's own container.
- **Routes every memory call through the same approval gate as everything else** — `remember`/`recall`/`forget` become ordinary MCP tool calls subject to `requestPermission`, not a locally-reachable escape hatch.
- **Avoids mixing runtimes.** Cognee is Python + its own local vector/graph store (standalone mode, self-contained — no external Neo4j/Postgres needed); goose is a Rust binary. Different lifecycles, different restart/crash semantics — better as separate processes/containers regardless of trust boundaries.
- **Matches your own stated instinct** — the flow was originally described as "docker mcp gateway - claude code + cognee," grouping it with the gateway, not with goose. The topology now matches that.

## Protocol boundaries (one job each)

| Protocol | Between | Job |
|---|---|---|
| **MCP** | c3 ↔ (c2's spawned harness, or goose directly) | Tool access — GitHub, Notion, internal servers, Cognee |
| **ACP** | c2 ↔ c1, and (inner hop) c2 ↔ spawned harness binary | Agent-execution-environment integration — session, tool calls, permission requests |
| **AG-UI** | c1 ↔ Flutter | Frontend-facing event stream — text streaming, tool call visibility, approval state |

## What's config vs. what's code

**Config:**
- Compose file topology (3 containers, volumes, networks)
- Cognee catalog entry in the MCP gateway (image, env vars for embedding-model key, standalone-mode volume)
- goose provider selection (`GOOSE_PROVIDER=claude-acp`, `--with-extension` / `--with-streamable-http-extension` pointed at the gateway)

**Real code (scoped, but real):**
1. **ACP→AG-UI translation layer**, in c1. The event mapping itself is small (~6 rules: message chunks, tool call start/args/end, one state-update for approval). The actual work is bridging ACP's *blocking* `request_permission()` to the *async* phone-approve flow.
2. **Session-ID correlation.** goose session ID ≠ inner ACP session ID ≠ PocketBase approval-log row ≠ push notification target. This bookkeeping is yours to own; nothing upstream hands it to you.
3. **PocketBase auth + reverse-proxy**: JWT verify → look up `user_id → goose_session_id` → inject `GOOSE_SERVER__SECRET_KEY` → forward into `goose serve`.
4. **Flutter data-layer swap**, deferred until c1↔c2 is proven — use the Dart `ag_ui` client for AG-UI SSE events, wrapped behind the existing repository/cubit layer, and handle reconnect/resume when the OS backgrounds the app.
5. **Dart contract validation** — capture one real c1 payload per AG-UI event type and validate it against the pinned `ag_ui` decoder in Flutter tests. Keep PocketCoder-specific mapping types only where the app's existing UI state needs them; do not generate a parallel general-purpose AG-UI client.

## Open questions / risks carried forward

- **ACP-over-HTTP maturity**: `goosed`→ACP-over-HTTP consolidation (upstream issue #6642) is active, not finalized. Pin a goose version.
- **MCP-sourced tool calls through `requestPermission`**: unconfirmed whether they surface identically to builtins. Low concern per your read, but relevant the moment Cognee's calls need to show up in the approval UI the same way shell commands do.
- **SDK maturity, Go side**: solid — `coder/acp-go-sdk` (Coder-backed) and the community AG-UI Go SDK (used by Microsoft's Agent Framework and Tencent's trpc-agent-go independently) are reasonable bets.
- **SDK maturity, Dart side**: `ag_ui` is the selected Flutter-side AG-UI client, but Flutter work is intentionally deferred. Pin and exercise it against PocketCoder's authenticated c1 SSE endpoint—especially reconnect and background/resume—before committing to the cutover.
- **Governance signal, positive**: goose has moved from Block to the Agentic AI Foundation (Linux Foundation), the same body governing MCP — reduces single-vendor churn risk relative to when this bet was first considered.
