# c1 Go Implementation Plan — PocketBase + Goose ACP + AG-UI

> Implementation status (2026-07-16): the first foundation commit pins
> `coder/acp-go-sdk` v0.13.5 and the AG-UI community Go SDK, and adds the
> Streamable-HTTP ACP transport plus a typed ACP→AG-UI bridge. The community
> AG-UI SDK requires Go 1.24.4, so the PocketBase builder image is pinned to
> that patch release as well. The next step is the PocketBase
> `goose_sessions` migration and authenticated coordinator/routes; no browser
> endpoint is exposed by this foundation alone.

> Vertical-slice status (2026-07-16): PocketBase now registers the authenticated
> `POST /api/pocketcoder/chats/{chatId}/runs` SSE endpoint. It authorizes the
> owner, persists only `chat → goose_session_id` in the new `goose_sessions`
> collection, keeps c2 credentials server-side, and streams typed AG-UI events.
> It requires `GOOSE_ACP_URL`, `GOOSE_SERVER__SECRET_KEY`, and a container-visible
> `GOOSE_WORKSPACE`. The authenticated
> `POST /api/pocketcoder/chats/{chatId}/cancel` route forwards cancellation only
> to an in-process active prompt; that prompt's correlated Goose response still
> produces the deterministic AG-UI terminal events. Tool execution and phone
> c1 now exposes the authenticated approval endpoint, advertises no ACP filesystem/
> terminal capabilities, and sends no MCP server configuration. Goose's native shell
> executes in c2 for the selected simplified runtime.

> Acceptance status (2026-07-16): real Docker c1/c2 tests passed for allow, deny, cancel while pending, fresh-c1 session-load reconnect, c1 restart, and c2 restart. Pending approval IDs vanish on c1 restart because they are never persisted, but graceful c1 termination sends Goose a cancelled decision before discarding them; the same chat must subsequently load and run again. Focused Go coverage rejects concurrent runs before SSE begins and sends `session/cancel` when a client context disconnects. Keep the Rust sandbox ACP adapter and legacy agent/MCP services dormant until Goose can be deliberately routed through them; do not present them as part of the active path.

> Testing strategy: retain focused Go c1 tests and PocketBase-only BATS coverage; freeze rather than repair BATS and TypeScript tests that assert the retired Interface/OpenCode topology. See `docs/agent-testing-strategy.md`. Replace frozen agent tests with a c1-route Docker acceptance suite at cutover.
>
> Runtime status (2026-07-16): the additive Compose `agent` profile runs the
> pinned Goose c2 image behind an internal, un-published ACP relay. PocketBase
> uses the relay URL; c2 has no Docker network in common with PocketBase and
> persists its SQLite/session state only in the separate `goose_data` volume.
> `GOOSE_SERVER__SECRET_KEY` and the Anthropic-compatible provider credentials
> must be set by the deployer before starting that profile.
>
> Compose smoke result (2026-07-16): a real authenticated PocketBase request
> completed `RUN_STARTED → TEXT_MESSAGE_CONTENT → RUN_FINISHED` through c1,
> the relay, and pinned c2. A second request to the same chat completed after
> `session/load`, proving the durable mapping works without copied PocketBase
> messages. Inspection confirmed Goose shares no Docker network with
> PocketBase.

> **Backend-closeout plan (2026-07-16):** Flutter is deliberately deferred.
> Before any mobile migration, complete and freeze the c1 contract: make a
> Goose-authoritative chat replay/read boundary explicit; define every public
> run, cancellation, approval, and failure outcome; and prove the contract in
> the isolated c1/c2 acceptance suite. The separate legacy-prune plan remains
> inventory-only until this contract is frozen and Flutter has later cut over.

**Goal:** add the new runtime to the existing PocketBase executable. c1 remains one Go process and one public service; it is **not** a new microservice and does not introduce a second HTTP listener.

## Fixed boundaries

- Put new code in `services/pocketbase/internal/agent/` and register its routes from `services/pocketbase/main.go`'s existing `OnServe` hook.
- PocketBase authorizes `user → chat` and persists exactly one mapping: `chat → Goose ACP session ID`.
- Goose is authoritative for messages, tool calls, permissions, decisions, active turns, and history. c1 has only process-local subscribers and pending permission waiters.
- c1 connects to the pinned Goose v1.36.0 Streamable-HTTP endpoint. It owns c2 credentials; Flutter never receives the Goose secret.
- Flutter and c3/Cognee stay unchanged/disabled in this plan.

## Local c2 runtime

The additive Compose profile is intentionally off by default, so existing
PocketBase deployments do not start an agent service without provider
credentials. Set the secret once for both c1 and c2, then start the private
runtime before PocketBase:

```bash
export GOOSE_SERVER__SECRET_KEY='use-a-long-random-secret'
export ANTHROPIC_API_KEY="$(jq -r '.minimax.key' /Users/aicoder/.local/share/gait/auth.json)"
export ANTHROPIC_HOST='https://api.minimax.io/anthropic'
export GOOSE_MODEL='MiniMax-M2.5'

docker compose --profile agent up -d --build goose goose-acp-relay
docker compose up -d --build pocketbase
```

`goose-acp-relay` has no published port and is the only service shared between
the c1 and c2 networks. Goose is unprivileged, stores its state in the named
`goose_data` volume, and has no network in common with PocketBase. It currently
permits only the provider configuration proven by the spike (`anthropic` via
the configured Anthropic-compatible endpoint); MCP and gateway tools remain
disabled.

## Package shape

```text
services/pocketbase/internal/agent/
  acp/        Streamable-HTTP connection, typed RPC lifecycle, SSE reader
  sessions/   owner authorization, chat→session persistence, per-chat live state
  agui/       ACP update → minimal AG-UI events and SSE encoder
  api/        authenticated PocketBase route handlers
  testdata/   redacted ACP fixtures and expected AG-UI events
```

Do not reuse the old `internal/agents`, `interface`, or PocketBase realtime command-bus paths. They are legacy runtime code and remain untouched until cutover.

## Delivery steps

1. **Foundation and configuration**
   - Add a version-pinned ACP dependency/transport implementation and c2 settings: private c2 URL, timeouts, and secret loaded only by c1.
   - Implement HTTP/2-capable Streamable-HTTP transport: initialize, connection SSE, per-session SSE, cookies, `session/new`, `session/load`, `session/prompt`, `session/cancel`, and orderly connection close.
   - Treat the correlated `session/prompt` response as the authoritative terminal turn signal—especially after cancellation—not a final text chunk.
   - Unit-test headers, status codes, response routing, connection/session stream routing, reconnect, and malformed SSE.

2. **Session mapping migration**
   - Add a new forward-only `goose_sessions` collection/migration: unique chat relation, owner user relation, unique ACP session ID, pinned Goose version/provider metadata, and timestamps.
   - Do not alter applied migrations or write legacy `chats.acp_session_id`, `messages`, `permissions`, or `acp_terminals` on the new path.
   - Implement an atomic first-session creation path so concurrent bootstrap requests cannot create two Goose sessions for one chat.
   - Test ownership, cross-user denial, uniqueness, race handling, and recovery when Goose creates a session but mapping persistence fails.

3. **Live session coordinator**
   - Create one in-memory coordinator per mapped chat, serializing prompts and multiplexing authenticated SSE subscribers.
   - On first use call `session/new`; on reconnect/c1 restart call `session/load` and rebuild only transient display state from Goose updates.
   - Implement `request_permission` as a pending in-memory future keyed by the ACP request ID. Validate that a caller owns the chat and selects only an option offered by Goose.
   - On c1 restart, discard unresolved futures and reload Goose; never invent a pending approval row from replayed completed tool history.
   - Implement cancellation by forwarding `session/cancel` to the active mapped session and publishing the eventual correlated terminal response.

4. **AG-UI boundary and routes**
   - Map the captured ACP subset to a deliberately small AG-UI contract: user/assistant text chunks, tool-call start/update/end, usage, error, permission-pending state, and run completion.
   - Register routes on PocketBase's existing router:
     - `POST /api/pocketcoder/v2/chats/{chatId}/session`
     - `GET /api/pocketcoder/v2/chats/{chatId}/events`
     - `POST /api/pocketcoder/v2/chats/{chatId}/prompt`
     - `POST /api/pocketcoder/v2/chats/{chatId}/permissions/{requestId}`
     - `POST /api/pocketcoder/v2/chats/{chatId}/cancel`
   - Use the existing PocketBase auth context for every route. Event streams must send a deterministic replay/snapshot before live updates.
   - Start with a hand-written SSE encoder and JSON fixtures; only adopt an AG-UI Go SDK if its toolchain/version constraints are deliberately accepted.

5. **Verification and additive deployment**
   - Fake-ACP tests: bootstrap, authorization, new/load, replay ordering, permission allow/deny, invalid selection, cancel, concurrent prompt rejection, c1 restart, and c2 disconnect.
   - Real integration test: pinned c2 with a provider-backed turn, c1 restart, `session/load` replay, then a follow-up turn.
   - Keep legacy routes/runtime active. Gate the new path with `AGENT_RUNTIME=v2` and make it available only to newly created Goose-backed chats.
   - Do not begin Flutter migration until this c1 suite is green.

## Remaining backend-closeout slices

These are the implementation order from the current, live
`POST /api/pocketcoder/chats/{chatId}/runs` contract. They supersede the earlier
aspirational v2 route names above; do not rename public routes merely to match
this planning document.

1. **Goose-owned chat replay contract**
   - Capture the exact `session/load` updates that represent durable Goose
     history, then specify a c1 authenticated read/replay response that emits
     the same minimal AG-UI model as a live run. A chat with no
     `goose_sessions` mapping returns an authenticated empty snapshot: a read
     must neither create a Goose session/mapping nor contact c2.
   - Authorize ownership before contacting c2. It must never return a
     PocketBase copy of messages or synthesize an unresolved permission.
   - Serialize reads through the coordinator. While a run is active, replay
     returns the documented active-run conflict rather than opening a second
     ACP client and calling `session/load` concurrently with `session/prompt`.
   - Specify empty/new sessions, malformed/rejected c2 replay, and the
     active-run conflict. Decide the wire shape and event ordering in fixtures
     before exposing the route.

2. **Contract hardening**
   - Document stable HTTP and AG-UI outcomes for unknown/non-owner chats,
     no active run, active-run conflict, stale/invalid approval, cancellation,
     c2 unavailable, c2 protocol failure, and client stream disconnect.
   - Bound process-local pending approval lifetime. Expiry and cancellation
     must send Goose the explicit cancelled/denied decision that unblocks its
     `request_permission` call, then yield the documented terminal run result.
     Do not persist or replay the pending record.
   - Treat c1 restart as a recovery contract, not merely deletion of the
     in-memory approval ID: c2 must observe the broken/cancelled request and
     the same chat must accept a later `session/load` and new run. If a c2
     prompt remains blocked after c1 has restarted, that is a defect to solve,
     not an accepted lost-approval outcome.
   - Orphaned Goose session (minor): if `session/new` succeeds but persisting
     the `goose_sessions` mapping fails, the unique `chat` index still prevents
     a second *mapped* session — the created Goose session is simply
     unreferenced and the next run creates a fresh one. This is a c2 resource
     leak, not a correctness bug, so it is acceptable pre-launch. Cheap
     mitigation if wanted: on persist failure, best-effort `session/cancel` the
     just-created session and log it; do not build durable orphan tracking.
   - Add narrowly scoped operational diagnostics/metrics for mapping creation,
     session load, turn terminal outcome, permission resolution, and c2 errors;
     never log prompt text, provider credentials, or offered permission payloads.

3. **Backend acceptance gate**
   - Extend `tests/agent-c1/` with replay fixtures and live c1/c2 cases for
     owner versus non-owner reads, an unmapped empty read with no c2 side
     effect, history after a tool/approval, replay after c1 restart, c2
     restart, c2 failure, and the replay-versus-active-run conflict.
   - Prove permission expiry sends the expected ACP decision and terminal
     update. In the live suite, restart c1 while an approval is pending, then
     prove that the *same chat* can load and complete a later run.
   - Keep focused Go tests deterministic with fake ACP. The Docker suite is the
     only provider-backed interop gate; legacy Interface/OpenCode tests remain
     frozen rather than being adapted.
   - Publish the final route/event/error contract in the architecture document
     and mark it frozen before beginning Flutter integration.

4. **Prepare, but do not execute, legacy removal**
   - Use `2026-07-16-pocketbase-goose-legacy-prune.md` to produce an exact
     table/field/route/test dependency inventory and a retention/rollback
     decision. This slice changes no legacy schema and deletes no code.

## Explicit non-goals

- No Flutter changes.
- No Cognee/gateway MCP enablement: the Goose v1.36 gateway attachment spike did not expose gateway tools. Keep default-deny until a new pinned compatibility proof succeeds.
- No legacy PocketBase schema deletion. That is governed by the separate cleanup plan.

## Done when

A newly created v2 chat has exactly one stored Goose session mapping; an authenticated client can reconnect after a c1 restart and receive its history solely from `session/load`; prompts, developer permissions, and cancellation work without creating PocketBase message/permission/terminal records.

---

## Transport rewrite slice (2026-07-17): WebSocket via the SDK connection

> **For agentic workers:** implement task-by-task with TDD. This slice REPLACES
> the hand-rolled Streamable-HTTP transport; it does not add a parallel one.
> Evidence for every design choice is in `spikes/goose-acp-http/README.md`
> (2026-07-17 results) and the transport-decision section of
> `docs/architecture-refactor.md`.

**Goal:** Replace `internal/agent/acp/streamable.go` with `goose serve`
WebSocket driven through the maintained `coder/acp-go-sdk` `ClientSideConnection`
plus a thin WS↔byte-stream adapter, and rewire the coordinator from its imperative
`acpClient` interface to the SDK's callback + typed-method model. Delete the
hand-rolled transport at the end.

**Unchanged by this slice:** `internal/agent/agui/bridge.go` (it already consumes
`acpsdk.SessionUpdate`, which is exactly what the SDK's `Client.SessionUpdate`
callback delivers); the public routes in `internal/api/agent.go` (route shapes,
auth, `goose_sessions` mapping); the frozen AG-UI event contract. Do not touch
them except where a signature note below says so.

### Design decisions (resolved — do not re-litigate during execution)

1. **Per-run connection, not persistent.** Keep today's lifecycle: each run/replay
   dials a fresh WS, `Initialize`, `session/new` or `session/load`,
   `SetSessionMode`, `Prompt`/replay, then closes. This preserves the existing
   fail-fast semantics for free — a dropped WS surfaces as an SDK error from the
   in-flight `Prompt`/`LoadSession` call, so the run ends deterministically as
   `RUN_ERROR` (no hang; the bug the deleted `streamable.go` had cannot recur).
   Recovery is the next run's `session/load`, exactly as today.

2. **`RequestPermission` is the blocking callback — this is the load-bearing
   change.** The SDK inverts control: instead of an `OnNotification` switch that
   spawns `handlePermissionRequest`, the SDK calls our `Client.RequestPermission`
   method and BLOCKS on its return value. Map it onto the existing async phone
   flow: inside `RequestPermission`, register a pending waiter keyed by a
   generated id, emit the AG-UI `STATE_DELTA` (permission pending), then block on
   a channel. The `/approvals` route signals that channel with the chosen option;
   the callback returns the corresponding `RequestPermissionResponse{Selected}`.
   The blocking `select` MUST include the SDK-provided callback `ctx.Done()`
   (this is `reqCtx`, cancelled when Goose sends `$/cancel_request` or the WS
   drops) alongside the decision channel and the expiry timer — do **not**
   substitute `context.Background()`, or a mid-turn WS drop leaves the waiter
   hung until the 5-min timeout after `Prompt` has already returned `RUN_ERROR`.
   On decision, timer, or ctx cancellation, return the matching
   `RequestPermissionResponse{Selected|Cancelled}`. This is a *better* fit than
   the old `Respond`-by-rpcID design and removes the manual JSON-RPC id plumbing.
   Concurrency is safe (verified against `acpsdk` connection.go): inbound
   *requests* like `RequestPermission` are each dispatched on their own
   goroutine, while `SessionUpdate` notifications drain on a separate single
   goroutine — so blocking in `RequestPermission` cannot stall update delivery
   or the outstanding `Prompt` response.

3. **Test seam = an injected connection factory + a fake connection that drives
   callbacks.** The SDK `ClientSideConnection` is a concrete struct, so introduce
   a narrow `Conn` interface (only the methods the coordinator calls) and a
   `DialFunc` the coordinator holds. Production `DialFunc` builds the WS adapter +
   `NewClientSideConnection`. Test `DialFunc` returns a scripted fake whose
   `Prompt`/`LoadSession` invoke the passed-in `acpsdk.Client` callbacks
   (`SessionUpdate`, `RequestPermission`) to reproduce update streams, permission
   requests, and terminal responses — mirroring how `run_test.go`'s current fake
   drives `OnNotification`.

4. **c1 advertises no fs/terminal capabilities.** `InitializeRequest`'s
   `ClientCapabilities` stays empty (Goose's in-container shell acts; c1 implies
   no sandbox). The SDK `Client` interface still requires
   `ReadTextFile`/`WriteTextFile`/`CreateTerminal`/`KillTerminal`/`TerminalOutput`/`ReleaseTerminal`/`WaitForTerminalExit`
   — implement them as rejecting stubs returning an error; Goose will not call
   them because the capabilities are not advertised.

5. **WS auth gap accepted for now.** v1.36.0's WS `/acp` did not enforce
   `X-Secret-Key`. Still send the header (for when upstream fixes it); the real
   control is network isolation — c2 has no published port and shares only the
   relay network with c1. Do not block this slice on it; leave a `TODO(ws-auth)`
   and the open item in the architecture doc.

6. **The update-suppression gate is load-bearing — preserve it (Opus review C1).**
   The SDK's `LoadSession` drains and delivers *every* queued `SessionUpdate` to
   our callback **before it returns** (`acpsdk` connection.go `waitNotificationsUpTo`).
   Today `run.go` guards this with `atomic.Bool acceptingUpdates`, set true only
   *after* `LoadSession` + `SetSessionMode`, so Goose's replayed history is not
   copied into the fresh prompt's frontend stream (frozen-contract requirement).
   The `sessionClient` MUST carry the same gate: `SessionUpdate` returns early
   while false; set it true immediately before `Started()`/`Prompt`. Without
   this, every reconnect run leaks full history into the live stream.

7. **Two SDK-call footguns (Opus review S2/S3).**
   - `InitializeRequest` must set `ProtocolVersion: acpsdk.ProtocolVersionNumber`
     (the spike's `main.go` does; the old transport negotiated it internally).
   - `NewSessionRequest`/`LoadSessionRequest` must set `McpServers:
     []acpsdk.McpServer{}` — a nil slice marshals to `null`, which v1.36.0
     rejects (`invalid type: null, expected a sequence`; README harness note).

### File plan

- **Create** `services/pocketbase/internal/agent/acp/websocket.go`:
  the `wsStream` adapter (ported from `spikes/goose-acp-http/ws_transport.go`,
  proven), the `Conn` interface, a `Dial(ctx, DialConfig, acpsdk.Client) (Conn, error)`
  that builds the WS + `acpsdk.NewClientSideConnection`, and `DialConfig{URL, Secret}`.
- **Create** `services/pocketbase/internal/agent/acp/websocket_test.go`:
  unit tests for `wsStream` framing (see Task 1).
- **Modify** `services/pocketbase/internal/agent/coordinator/run.go`:
  replace the `acpClient` interface (lines ~59-67), `pendingPermission`,
  `activeRun`, the `OnNotification` wiring, and `handlePermissionRequest` with the
  `Conn`/`DialFunc` + `acpsdk.Client` callback model. Preserve the public methods
  and every behavior the current `run_test.go` asserts.
- **Modify** `services/pocketbase/internal/agent/coordinator/run_test.go`:
  the fake becomes a fake `Conn` + `DialFunc` that drives `acpsdk.Client`
  callbacks (contract below). Non-permission test *names* are preserved; the five
  permission tests are **rewritten as concurrent tests** (Task 3b) because they
  no longer assert a `Respond` payload but the blocking callback's return value.
- **Modify** `services/pocketbase/internal/api/agent.go`:
  only if `coordinator.New`/`coordinator.Config` signatures change (e.g. URL is
  now a `ws://` value). Route bodies stay.
- **Modify** `services/pocketbase/go.mod` / `go.sum`: add
  `github.com/coder/websocket` (`coder/acp-go-sdk` already present).
- **Delete** `services/pocketbase/internal/agent/acp/streamable.go` (Task 6, only
  after the new path is green and no references remain).
- **Modify** `docker-compose.yml`: c2 runs `goose serve --host 0.0.0.0` on the
  relay network (was the stdio/HTTP entrypoint); `GOOSE_ACP_URL` becomes the
  `ws://…/acp` relay URL. No published c2 port.

### Interfaces (exact — later tasks rely on these)

```go
// acp/websocket.go
type DialConfig struct{ URL, Secret string }

// Conn is the subset of *acpsdk.ClientSideConnection the coordinator uses,
// plus Close. Signatures match acpsdk exactly (verified against the spike's
// working main.go: Initialize/NewSession/LoadSession/Prompt/SetSessionMode/Cancel).
type Conn interface {
    Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error)
    NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error)
    LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error)
    SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error)
    Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error)
    Cancel(context.Context, acpsdk.CancelNotification) error
    Close() error
}

func Dial(ctx context.Context, cfg DialConfig, client acpsdk.Client) (Conn, error)

// coordinator/run.go — the coordinator holds this and defaults to acp.Dial;
// tests inject a fake.
type DialFunc func(ctx context.Context, client acpsdk.Client) (acp.Conn, error)
```

### Tasks

**Task 1 — Port the WS adapter into the acp package.**
Move `wsStream` + `Dial` from `spikes/goose-acp-http/ws_transport.go` into
`acp/websocket.go`. TDD: `websocket_test.go` starts an in-process
`httptest` WebSocket echo server, writes two newline-delimited JSON messages
through `wsStream.Write`, and asserts each arrives as its own frame and reads
back newline-delimited via `wsStream.Read`. Add `coder/websocket` to go.mod.
Commit.

**Task 2 — `Conn` interface + real `Dial`.**
Define `Conn` and `DialConfig`; `Dial` builds the WS `wsStream` and
`acpsdk.NewClientSideConnection(client, ws, ws)`, returning a wrapper whose
`Close` closes the WS. No new behavior test here (covered live in Task 6);
`go build ./internal/agent/acp/` must pass. Commit.

**Fake `Conn` contract (define before Task 3 — Opus review S5).** The fake's
`Prompt`/`LoadSession` are stateful and concurrent, not one-shot returns. For a
run: `Prompt` must (a) invoke `SessionUpdate` callbacks for scripted updates,
(b) optionally invoke the coordinator's `RequestPermission` callback (which
blocks in the coordinator until `Approve`/`Cancel`/expiry), and (c) return the
terminal `PromptResponse` only *after* that permission resolves — so the fake
needs an internal signal from the permission path, not a fixed return. For a
replay: `LoadSession` invokes `SessionUpdate` callbacks for scripted history,
then returns. Specify this contract as a helper in `run_test.go` so the tests
don't race.

**Task 3a — Rewire `Run`/`RunReserved` and `ReplayReserved` to typed methods +
the gate.** Behavior-preserving for the non-permission tests.
- Introduce the coordinator-scoped `acpsdk.Client` impl (`sessionClient`):
  `SessionUpdate` → gate check (Design #6) → `bridge.Update` → emit; rejecting
  fs/terminal stubs (Design #4). Leave `RequestPermission` for Task 3b.
- Replace `acpClient`/`OnNotification`/`Call`/`Notify`/`Respond` in
  `RunReserved` with `Conn` typed calls (`Initialize` with `ProtocolVersion`,
  `NewSession`/`LoadSession` with non-nil `McpServers`, `SetSessionMode`,
  `Prompt`, `Cancel`) via the injected `DialFunc`. Set the gate true immediately
  before `Started()`/`Prompt`.
- **Port `ReplayReserved` too** (Opus S4): its own `sessionClient` wiring
  `SessionUpdate → bridge → emit`, `Initialize` → `LoadSession` → `Close`, no
  `Prompt`, no permission path. The fake `Conn.LoadSession` drives the replay
  `SessionUpdate` callbacks.
- Keep green: concurrent-run reject, unmapped-replay-no-c2,
  client-disconnect-cancels, restart-clears-pending, shutdown-cancels-active-run.
  Commit.

**Task 3b — Permission callback + concurrent test rewrite (Opus review C2 — NOT
a name-preserving swap).** The five permission tests currently assert the ACP
outcome by reading the old `Respond` payload; there is no `Respond` now — the
outcome is the *return value* of the blocking `RequestPermission`.
- Implement `sessionClient.RequestPermission` per Design #2 (register pending
  waiter, emit `STATE_DELTA`, block on `select { decision / timer / ctx.Done() }`,
  return `Selected|Cancelled`). `Approve` signals the channel (keep
  `ErrNoPendingPermission`, `ErrPermissionOptionNotOffered`); `Cancel`/expiry/
  `Shutdown` resolve it as cancelled.
- **Rewrite these five as concurrent tests** (launch `RequestPermission` in a
  goroutine, await the pending registration/`STATE_DELTA`, act, then synchronize
  on and assert the goroutine's returned `RequestPermissionResponse`):
  `TestApproveForwardsOnlyOfferedOptionAndIsMemoryOnly`,
  `TestDenyForwardsAnOfferedRejectOption`,
  `TestCancelResolvesPendingPermissionAsCancelled`,
  `TestPermissionExpiryResolvesPendingPermissionAsCancelled`,
  `TestShutdownCancelsActiveRunAndResolvesPendingPermission`. Full `coordinator`
  package green. Commit.

**Task 4 — Config + route wiring.**
Update `coordinator.Config`/`New` and `api/agent.go` so the coordinator dials the
`ws://…/acp` relay URL and injects `acp.Dial` by default. Keep env var names
where possible; if `GOOSE_ACP_URL` now carries a `ws://` value, note it. `go build
./...` and `go vet ./internal/agent/...` clean. Commit.

**Task 5 — Compose: `goose serve`.**
Point c2 at `goose serve --host 0.0.0.0` on the relay network, no published port;
set the c1 `GOOSE_ACP_URL` to the relay `ws://` URL. Do not enable MCP/gateway.
Commit.

**Task 6 — Delete `streamable.go` + live integration test.**
Remove `streamable.go` once nothing references it (`grep` for `acp.NewClient`,
`OpenStream`, `NotificationHandler`). Extend `tests/agent-c1/` with a live
`goose serve` WS case mirroring the spike: new chat → run → tool/permission →
`session/load` replay → cancel, over the real relay. Full `go test
./internal/agent/...` green; c1 acceptance suite green. Commit.

### Minor notes (Opus review, N-items)

- `Conn.Close()` must close the `wsStream`; confirm this makes an in-flight
  `Prompt` return a peer-disconnect error (WS read error → SDK `Done()`) — the
  per-run fail-fast in Design #1 depends on it.
- The SDK `Prompt` auto-sends `Cancel` on ctx error, so `cancelOnClientDisconnect`
  partly overlaps it; keep it (it also resolves the pending waiter) but don't
  mistake it for the only cancellation path.
- Stale spike wording: `main.go` flag help says `--mode`/`--cancel-after` are
  "streamable HTTP only", but they apply to every transport and WS mode+cancel
  are proven; ignore the stale help text.

> **Review:** this slice was reviewed by Opus (2026-07-17), verified against
> `acpsdk` v0.13.5 source. Verdict: executable-with-fixes; the C1 update-gate,
> C2 permission-test-restructure, and S1–S5 fixes above are folded in.

### Open items to settle during execution (not blockers)

- **WS auth** (Design #5): leave `TODO(ws-auth)`; rely on network isolation.
- **Mid-turn WS drop reconnect/replay**: the fail-fast + next-run `session/load`
  model is the baseline; do not build reconnection in this slice.

### Done when

`go test ./internal/agent/...` is green with the SDK-connection coordinator and
the WS adapter; `streamable.go` is deleted with no references; the live
`tests/agent-c1/` WS case passes end-to-end against `goose serve`; and the AG-UI
bridge + public routes + frozen contract are unchanged.
