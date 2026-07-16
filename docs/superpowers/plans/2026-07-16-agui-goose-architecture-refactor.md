# AG-UI / Goose Architecture Refactor — Implementation Plan

**Goal:** Replace the current `interface` + OpenCode + sandbox execution path with the three-container design in `docs/architecture-refactor.md`.

| Container | Responsibility |
|---|---|
| **c1 — PocketBase + Go** | Authenticate the mobile user, authorize access to a PocketCoder chat, map that chat to its goose ACP session, and translate the live ACP connection to AG-UI SSE. |
| **c2 — goose** | Authoritative agent runtime: conversation/session history, active turn state, permission requests and decisions, provider session state, tool execution, and recovery. It launches `claude-agent-acp` or `codex-acp`. |
| **c3 — Docker MCP Gateway** | Every external MCP tool, including Cognee persistent memory. |

Flutter talks only to c1. PocketBase is the identity and routing control plane, **not** a duplicate conversation, event, approval, or memory ledger. Goose is the system of record for a chat's agent state.

## Decisions fixed by this plan

1. **One PocketCoder chat maps 1:1 to one goose ACP session; a user owns N chats.** Store only `chat_id → goose_acp_session_id` in PocketBase. A user never maps directly to one shared agent session.
2. **Goose owns state.** Do not persist assistant messages, AG-UI events, tool calls, approvals, provider-session IDs, or a second session log in PocketBase. The existing PocketBase message/permission records become transitional UI data and are removed from the live agent path.
3. **c1 is a stateless authenticated bridge.** It may keep in-memory subscribers and pending permission futures while running, but must reconstruct a view after restart using `session/load` from goose.
4. **Reconnect means reload from goose.** Flutter reconnects to c1; c1 resumes/loads the mapped goose session and translates its replay notifications to an AG-UI snapshot/history stream. There is no PocketBase event replay log or `Last-Event-ID` persistence requirement.
5. **Permissions are passed through, not copied.** `request_permission` blocks in c1 until the authenticated Flutter client posts a selected option. c1 returns that option directly to goose. Goose retains the approval in its own session history.
6. **Cognee remains an MCP server in c3.** Its own persisted memory is authoritative for long-term memory; c1 neither calls Cognee directly nor stores memory copies.

## Why this is viable

ACP provides `session/new`, `session/load`, `session/prompt`, `session/cancel`, streamed session updates, and a server-to-client `request_permission` request. Goose's ACP-over-HTTP project identifies session persistence/resumption and history replay as required server behavior. The bridge therefore only needs to maintain the live ACP connection and normalize events for Flutter; it does not need to invent durable run or approval state. [goose ACP-over-HTTP issue](https://github.com/aaif-goose/goose/issues/6642), [ACP protocol](https://github.com/agentclientprotocol/agent-client-protocol)

The previously referenced ACP→AG-UI bridge reaches the same split: explicit message boundaries and a blocking permission callback are the real translation work. Its data-store/session-manager pieces are not part of this design because goose supplies the durable session. [ACP→AG-UI reference bridge](https://github.com/namanrajpal/acp-to-agui)

## Mandatory compatibility gates

Do these as small, pinned-version spikes before changing production compose topology or deleting services. A failed gate blocks cutover rather than being papered over with a PocketBase ledger.

- [ ] **Gate A — goose ACP-over-HTTP:** Partial result (2026-07-16): pinned Goose successfully initialized, created a session, streamed updates, and prompted over remote HTTP; however it exposed an older `200 text/event-stream`/`Acp-Session-Id` per-POST dialect rather than the current Streamable-HTTP RFD, and a fresh remote `session/load` returned EOF. Before c1, select/pin a Goose release and prove initialize, create, prompt, updates, load, and cancel over that exact transport. Record endpoint, authentication, headers, and exact session ID returned.
- [ ] **Gate B — restart/resume:** Start a session and complete a turn; restart c1; reconnect to the same c2; call `session/load` using the PocketBase-mapped session ID; confirm goose replays enough history for Flutter to rebuild chat and accepts a follow-up prompt. Restart c2 too and repeat, proving the mounted goose session store is sufficient.
- [ ] **Gate C — permission pass-through:** For one developer/shell operation and one gateway MCP operation, verify that goose sends an ACP `request_permission`, c1 can hold it while the phone is offline, the eventual selected option completes the original ACP request, and `session/load` shows the decision. If gateway MCP calls do not reach this mechanism, explicitly choose a policy before enabling Cognee: gateway-level enforcement, an allowlist of non-mutating calls, or no Cognee by default.
- [ ] **Gate D — event contract:** Capture redacted updates for text chunks, thinking (if exposed), tool start/arguments/result, completion/error, usage, and a permission request. Map these into the smallest AG-UI event subset that represents the current Flutter UI. Validate JSON fixtures and use them as the c1/Dart contract.
- [ ] **Gate E — mobile lifecycle:** Prove authenticated SSE, Flutter background/foreground reconnect, c1 restart reconnect, and duplicate-history handling against the Gate B goose session. On reconnect c1 must send a deterministic replay/snapshot before live events; Flutter must replace or de-duplicate its displayed transient state.
- [ ] **Gate F — Cognee in the gateway:** Prove the c3 catalog entry using a pinned Cognee image, HTTP/streamable transport, persistent volume, user/chat namespace convention, and backup/restore. Cognee MCP exposes `remember`, `recall`, and `forget`; use the goose session or PocketBase chat ID as its scope only after verifying the tool inputs. [Cognee MCP](https://github.com/topoteretes/cognee/tree/main/cognee-mcp)

## Minimal PocketBase data model

Add one forward-only migration; do not modify old applied migrations.

| Record | Fields/rules |
|---|---|
| `goose_sessions` | `chat` (unique relation), `user` (owner relation), `acp_session_id` (unique text), `provider`, `goose_version`, `created`, `last_connected_at`. Owner may read; only c1's service account writes. |
| `chats` | Retain the existing PocketCoder chat/user/title metadata. Add a relation to `goose_sessions` only if it makes lookup simpler; otherwise the unique relation above is sufficient. |

`messages`, `permissions`, and `acp_terminals` are not written by the new runtime. Keep them only for legacy chat display during the migration window, then remove the old UI path and schema in a later forward-only migration. If a minimal audit trail is wanted later, add it as a separate product decision—not an implicit duplicate of goose state.

## c1 bridge design

Create a focused Go package under `services/pocketbase/internal/agent/`:

| Package | Responsibility |
|---|---|
| `acp` | Pinned Go ACP SDK adapter: HTTP connection lifecycle, initialize, new/load/prompt/cancel, notifications, and `request_permission` callback. |
| `sessions` | Authorizes `user → chat`, reads/writes the single `goose_sessions` mapping, serializes one active prompt per chat, and re-establishes ACP connections after c1 restart. |
| `agui` | Stateless ACP→AG-UI mapper and SSE encoder. Maintains only connection-local open-message/tool-call state needed to emit valid event boundaries. |
| `api` | PocketBase routes: chat bootstrap/history stream, prompt, permission decision, cancel, and health. |

Register routes through the existing PocketBase `OnServe` hook in `services/pocketbase/main.go`; do not introduce another public server.

### Route contract

| Endpoint | Behavior |
|---|---|
| `POST /api/pocketcoder/v2/chats/{chatId}/session` | Authenticated owner returns/creates the mapped goose ACP session. On first use c1 calls `session/new`, stores the returned ID, and returns a bootstrap stream URL. |
| `GET /api/pocketcoder/v2/chats/{chatId}/events` | Authenticated AG-UI SSE. c1 calls `session/load` when opening/reopening the stream, emits a deterministic replay/snapshot from goose notifications, then forwards live updates. Only one active stream is required per device; support replacement cleanly. |
| `POST /api/pocketcoder/v2/chats/{chatId}/prompt` | Authenticated owner submits a message to the mapped goose session. Reject a concurrent prompt for the same chat or queue it explicitly; do not use PocketBase message creation as a command bus. |
| `POST /api/pocketcoder/v2/chats/{chatId}/permissions/{requestId}` | Authenticated owner sends an exact pending ACP option. c1 resolves the in-memory waiting callback; after a c1 crash, reload the session and require goose to reissue/recover the request rather than trusting a copied row. |
| `POST /api/pocketcoder/v2/chats/{chatId}/cancel` | Authenticated owner sends ACP `session/cancel`. |

The Go ACP SDK is a reasonable starting point, but its documented examples are stdio-oriented; Gate A must prove HTTP support or supply the smallest transport adapter necessary. [ACP Go SDK](https://github.com/coder/acp-go-sdk)

## Delivery sequence

### 1. Lock the protocol contract

- [ ] Complete Gates A–F and check redacted ACP/AG-UI fixtures into `services/pocketbase/internal/agent/testdata/`.
- [ ] Pin goose, provider adapter, ACP SDK, AG-UI Go SDK, Cognee, and Docker MCP Gateway versions/digests. Do not use `main`, `latest`, or unversioned npm installs. Note that the current community AG-UI Go module requires Go 1.24.4 while this repository declares Go 1.24.0; either raise the toolchain deliberately or hand-write the small SSE event encoder. [AG-UI Go module](https://github.com/ag-ui-protocol/ag-ui/tree/main/sdks/community/go)
- [ ] Define `schemas/agui-events.schema.json` from captured JSON payloads—not AG-UI protobufs—and generate the Dart models used by Flutter. The official AG-UI project defines an event-based, transport-agnostic protocol; only adopt its events used here. [AG-UI](https://github.com/ag-ui-protocol/ag-ui)

### 2. Build c1 without changing Flutter

- [ ] Add `goose_sessions` migration and tests for ownership, unique chat/session mappings, first-session creation races, and no cross-user access.
- [ ] Implement `acp`, `sessions`, `agui`, and API routes with fake ACP tests. Test stream bootstrap/replay, live mapping, tool boundary ordering, permission wait/allow/deny/timeout, cancellation, c1 restart, and c2 restart.
- [ ] Add an authenticated c1 health endpoint reporting c2 reachability, negotiated ACP version/capabilities, active live connections, and pinned runtime versions—without exposing prompts, secrets, or approval payloads.
- [ ] Keep the existing interface runtime enabled; new routes are additive and unused by Flutter until its migration is complete.

### 3. Introduce c2 and c3 additively

- [ ] Add a pinned goose image/wrapper and entrypoint that permits only supported `GOOSE_PROVIDER` values and verifies the selected provider binary. Use a named `goose_data` volume for goose's SQLite/session data.
- [ ] Add goose with no published port. Allow only c1→c2 control traffic and c2→c3 tool traffic. Deny c2 routes to PocketBase, Docker socket proxies, dashboard, and public networks.
- [ ] Add Cognee to the Docker MCP Gateway catalog with its own pinned image, `cognee_data` volume, scoped secrets, health check, and the namespace proven by Gate F. The current Cognee MCP documentation supports HTTP, SSE, and stdio and provides the three-memory-operation API; select HTTP if it matches the gateway's supported upstream transport. [Cognee MCP README](https://github.com/topoteretes/cognee/tree/main/cognee-mcp)
- [ ] Update MCP configuration rendering only to configure c3. Remove all c1/c2 direct-memory code.
- [ ] Add compose tests for the allowed/denied network matrix, c1→c2 ACP bootstrap, c2→c3 tool call, c2 restart and session load, and persistent Cognee restart.

### 4. Move Flutter to AG-UI

- [ ] Add generated AG-UI models plus a small authenticated SSE client/reconnect manager under `client/packages/pocketcoder_flutter/lib/infrastructure/communication/`.
- [ ] Replace `ChatRepository.watchHotPipe` with the c1 bootstrap/event stream. Keep the current PocketBase cold-pipe history only while legacy chats exist; new chats load and replay history from goose through c1.
- [ ] Map AG-UI messages/tool events to the existing chat UI state so visual components do not need a rewrite. Map AG-UI permission state to the existing approval screen; post its selected option to c1.
- [ ] Handle foregrounding by reopening the stream and replacing transient history with the goose replay, then continuing live. Test duplicate chunks, c1/c2 restart, auth refresh, denied permission, cancelled prompt, and failed stream.
- [ ] Do not take a hard dependency on the community Dart `ag_ui` package until Gate E validates its reconnect/auth behavior against this API. It currently offers typed models and SSE support, so it is useful comparison material; generated local types remain the default plan. [ag_ui Dart package](https://pub.dev/packages/ag_ui)

### 5. Cut over, then delete

- [ ] Add `AGENT_RUNTIME=v2` to select the new route only for new chats. A chat is permanently legacy or goose-backed; never reinterpret an old OpenCode/ACP ID as a goose session ID.
- [ ] Run acceptance cases: new chat, session resume, assistant stream, tool display, shell permission allow/deny, MCP permission policy, cancel, Flutter background/reconnect, c1 restart, c2 restart, Cognee remember/recall/forget, and backup/restore of `goose_data`/`cognee_data`.
- [ ] After the acceptance suite and rollback rehearsal pass, delete `services/interface/`, `services/sandbox/`, `services/opencode/`, then their compose networks, volumes, hooks, tests, scripts, and stale documentation.
- [ ] Delete `services/poco-memory/` and `services/open-notebook-mcp/`. Remove Open Notebook/SurrealDB only after confirming its human-facing UI is not required; this decision is independent of the new runtime.
- [ ] After the legacy retention period, remove the unused PocketBase message/permission/terminal command-path fields in a separate forward-only migration.

## Acceptance and rollback

**Acceptance:** Every new PocketCoder chat has exactly one c1-owned mapping to a goose session; a browser/mobile reconnect and c1 restart can rebuild it solely by `session/load`; permission decisions and history appear from goose; c2 cannot reach PocketBase; no new runtime state is duplicated into PocketBase.

**Rollback:** Set `AGENT_RUNTIME=v1` for new chats. Existing v2 chats remain readable/reconnectable through c1+goose; do not destroy their volumes or roll back database migrations. Rollback preserves the old runtime rather than attempting to convert opaque goose state back into OpenCode state.

## Files expected to change

**Add:** `services/pocketbase/internal/agent/{acp,sessions,agui,api}/`, one PocketBase migration, `services/goose/`, AG-UI schema/Dart generation, and c1/c2/c3/Flutter contract tests.

**Modify:** `services/pocketbase/main.go`, Go dependencies, `docker-compose.yml`, MCP config renderer, Flutter chat/permission repositories and cubits, Caddy/deploy/test helpers, and architecture docs.

**Delete only after cutover:** `services/interface/`, `services/sandbox/`, `services/opencode/`, legacy Poco-memory/Open Notebook MCP code, and the respective obsolete Compose configuration.
