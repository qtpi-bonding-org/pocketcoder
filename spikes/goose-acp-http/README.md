# Goose ACP compatibility spike

Disposable harness for the first PocketCoder c1↔c2 gate. It deliberately has no PocketBase, Flutter, Docker MCP Gateway, or provider configuration.

## What it proves

1. The selected Go ACP SDK can initialize a goose ACP session, create a session, forward streamed updates, and prompt it over the supported `goose acp` stdio transport.
2. The authenticated remote `/acp` endpoint can initialize, create a session, stream updates, and prompt through the actual pinned Goose image.
3. The exact remote transport dialect and reconnect behavior are captured before c1 is designed around it.

The Go SDK currently exposes a line-delimited JSON-RPC connection API. The HTTP path here is a minimal raw adapter for compatibility discovery, not production c1 code.

## Result — 2026-07-16

Using MiniMax M2.5:

- `initialize → session/new → session/prompt` succeeded through the Go SDK and `goose acp`; streamed thought and message updates were received.
- `goose serve` started successfully with `GOOSE_SERVER__SECRET_KEY`; `/status` was healthy.
- `initialize → session/new → session/prompt` also succeeded remotely through one persistent `goose serve`, with thought and message updates streamed to the Go harness.
- Older Goose image `ghcr.io/block/goose@sha256:d85a724ee487425f38ce015323adf2003591268ee515d9018ac89450ed7d3a5a` is **not suitable** for c1: it exposes an older per-POST SSE dialect and a fresh remote `session/load` returned EOF.
- Goose **v1.36.0**, pinned as `ghcr.io/aaif-goose/goose@sha256:8452dbb1aed8b46ec8b25895a1dd60a2e8ad89a10692f782cff32a6cbe35176e`, implements the current Streamable-HTTP handshake: initialize returns JSON with `Acp-Connection-Id`; subsequent ACP POSTs return `202`; connection and session GETs deliver SSE updates.
- On v1.36.0, `initialize → session/new → session/prompt` succeeded, then a new Go client connection ran `session/load`, received replayed history, and completed a second provider-backed prompt. The remote session mapping required no PocketBase conversation copy.

Two additional provider-backed protocol checks succeeded against that same pinned image:

- `session/cancel` was sent after the first agent output of an intentionally long turn. Goose accepted the notification, emitted no more message chunks, and resolved the original `session/prompt` with a deterministic `{"stopReason":"end_turn", ...}` terminal response. c1 must treat the correlated prompt response—not a guessed final text chunk—as the authoritative end-of-turn signal.
- In `approve` mode, Goose emitted `session/request_permission` for both a developer write and read. The harness held each request for three seconds, returned its offered `allow_always` option, executed the resulting ACP filesystem request, and the turn ended successfully. A fresh connection's `session/load` replay included the completed tool calls and final assistant message. The replay does **not** reissue the already-resolved permission callback, so PocketBase must never try to reconstruct a pending approval from history.
- Gateway MCP attachment is **not yet usable** through this hop. An isolated Docker MCP Gateway (SSE, its built-in `mcp-find` catalog tool, and no auto-enabled server) was supplied in `session/new.mcpServers` and Goose accepted the session. In `approve` mode, however, Goose exposed only its built-in extensions; it never exposed or invoked `mcp-find`, so no gateway MCP `request_permission` could occur. The same result occurred with the gateway's required Docker socket attached. Treat this as a c2 compatibility/configuration blocker, not proof that gateway MCP calls bypass approvals.

**Decision:** select Goose v1.36.0 for c2 and use the current Streamable-HTTP ACP profile. Gate A is complete and the developer-tool portion of Gate C is complete. It is safe to build c1's small Go ACP transport package; keep Flutter deferred. Do **not** enable Cognee or gateway MCP tools by default until a pinned Goose configuration/release exposes the attached gateway's tools and the permission check can be repeated.

## Prerequisites

- Go 1.24+
- Docker Desktop (the bundled wrapper pins Goose by image digest)
- A MiniMax key in the local gait auth file; the wrapper uses MiniMax's Anthropic-compatible endpoint for tool-capable agent turns

## Run the stdio baseline

```bash
cd spikes/goose-acp-http
go mod tidy
chmod +x container-goose.sh
MINIMAX_AUTH_FILE=/Users/aicoder/.local/share/gait/auth.json \
  go run . --goose ./container-goose.sh --cwd "$(pwd)" \
  --prompt "Reply with exactly: goose ACP spike connected"
```

Copy the `session_id=...` line. Then prove session loading from a new process:

```bash
MINIMAX_AUTH_FILE=/Users/aicoder/.local/share/gait/auth.json \
  go run . --goose ./container-goose.sh --cwd "$(pwd)" \
  --session '<session_id>' --prompt 'Reply with exactly: session load succeeded'
```

The program prints raw `session/update` notifications as JSON on stdout and lifecycle evidence on stderr. The disposable streamable adapter also supports `--mode approve`, `--auto-approve --permission-delay 3s`, and `--cancel-after 5s` for the recorded checks. It implements only enough filesystem/terminal callbacks for the controlled spike; production c1 must use the real sandboxed executor and strict workspace path policy.

The wrapper persists Goose's session database in the named Docker volume `pocketcoder-goose-acp-spike-state`. It runs the disposable container as root solely so Docker's new named volume is writable; the production c2 image must create/chown its state directory and run as an unprivileged user. To start the persistence test over, remove only that disposable volume:

```bash
docker volume rm pocketcoder-goose-acp-spike-state
```

## Run the observed remote HTTP adapter

In a separate terminal, start a pinned goose server. Bind it only to a private network during the spike:

```bash
export GOOSE_SERVER__SECRET_KEY='replace-with-a-long-random-secret'
goose serve --host 127.0.0.1 --port 3000
```

Then:

```bash
GOOSE_SERVER__SECRET_KEY="$GOOSE_SERVER__SECRET_KEY" ./http-preflight.sh
```

Then, against that server:

```bash
go run . --transport=http --http-url http://127.0.0.1:3000/acp \
  --secret "$GOOSE_SERVER__SECRET_KEY" --cwd "$(pwd)" \
  --prompt 'Reply with exactly: goose HTTP ACP spike connected'
```

For Goose v1.36.0, use `--http-dialect=streamable` and a container-visible `--cwd` (the spike uses `/workspace`). This is the selected c1→c2 profile.

`--mcp-sse-url` supplies one SSE MCP server in the ACP `mcpServers` request. The checked-in `mcp-gateway-config/` is only the controlled Docker Gateway fixture used for the negative attachment finding above; it is not production gateway configuration.

## Exit criteria

- [x] A current-Goose remote transport is selected and pinned.
- [x] `initialize`, `session/new`, one prompt, and `session/load` work after the harness restarts.
- [x] The selected release conforms to the current ACP transport.
- [x] `session/cancel` works over the selected transport and ends the correlated prompt request.
- [x] Developer-tool `request_permission` pass-through works and completed history replays after `session/load`.
- [x] Gateway MCP attachment was attempted against a real isolated Docker MCP Gateway and did not expose tools through Goose; Cognee/gateway MCP is disabled by default pending a working c2 attachment.

Delete this directory once that decision is implemented and covered by the production c1 integration tests.

## Result — 2026-07-17 (stdio `session/load` across process restarts)

**Question:** does the `goose acp` **stdio** transport support `session/load`
against the durable on-disk store across a process restart, with history replay?
This decides whether c1 could use the robust `acp.NewClientSideConnection`
(byte-stream) instead of the hand-rolled Streamable-HTTP `streamable.go`.

Tested against the **selected c2 image** (Goose v1.36.0,
`ghcr.io/aaif-goose/goose@sha256:8452dbb1...`) via `container-goose-v136.sh`,
persisting the session DB in the named volume `pocketcoder-goose-stdio-load-test`.

- **Step 1 (process A):** `initialize → session/new → session/prompt` over stdio
  succeeded. Session `20260717_1` created; prompt "Remember this magic number:
  4271 …" completed with streamed updates.
- **Step 2 (process B, fresh container, same volume):** `initialize →
  session/load(20260717_1) → session/prompt` succeeded. Load **replayed the prior
  turn's history** (the earlier user message and assistant reply). The follow-up
  prompt "What magic number did I ask you to remember earlier?" was answered
  **`4271`** — memory carried across the process restart.

**Conclusion:** Goose's session store is on-disk and **transport-independent**;
stdio `session/load` resume works identically to the proven HTTP path. The
"smash the containers together with stdio" option is therefore viable at the
foundational level: c1 could dial a byte stream (e.g. `socat TCP-LISTEN,fork
EXEC:"goose acp"` in c2) into `acp.NewClientSideConnection` and delete
`streamable.go`. Still unproven over stdio-across-containers: the socat/TCP
bridge itself, permission pass-through, and cancellation — each a smaller,
separate check before committing to the transport switch.

**Harness note:** v1.36.0 rejects `session/load` with `mcpServers: null`
(`invalid type: null, expected a sequence`). `LoadSessionRequest` must send
`McpServers: []acp.McpServer{}`, mirroring `NewSession`. Fixed in `main.go`.
The in-container workspace path (`--cwd /workspace`), not the host path, must be
passed to goose.

## Result — 2026-07-17 (cross-container stdio bridge over TCP)

**Question:** can c1 reach `goose acp` (stdio) across the container boundary
over a socket, feeding a plain byte stream into the SDK's robust
`ClientSideConnection` — i.e. is "smash the containers together with stdio"
real, without collapsing c1 and c2 into one container?

Setup: `Dockerfile.socat` layers `socat` onto the pinned v1.36.0 image. c2 runs
`socat TCP-LISTEN:9000,reuseaddr,fork EXEC:"goose acp"` (a fresh `goose acp`
process per TCP connection). The harness gained a `--transport tcp --tcp-addr`
mode that dials the socket and hands the `net.Conn` to
`acp.NewClientSideConnection(conn, conn)` — no `streamable.go`, no hand-rolled
HTTP.

- **TCP new:** `initialize → session/new → session/prompt` over the socket
  succeeded (session `20260717_2`). socat's EXEC framing carried newline-JSON
  cleanly; c2 logs showed no corruption.
- **TCP load (cross-process over bridge):** a fresh connection (new forked goose
  process) ran `session/load(20260717_2)` and the agent recalled `8888` from the
  earlier bridged turn.
- **Cross-transport:** session `20260717_1`, created earlier over **plain
  stdio**, loaded over the **TCP bridge** and recalled `4271`. A session is
  transport-independent.

**Conclusion:** the bridge mechanics work. c1 could dial a socket into the
maintained SDK connection and delete `streamable.go`. For production, replace
socat with a small Go supervisor shim in c2 (restores channel auth, controls
child lifecycle, reaps zombies on socket drop).

**Still unproven for the stdio/bridge path (next spike slices, per review):**
concurrent-writer safety on the on-disk session store (the gating question);
permission pass-through; `session/cancel`; child/orphan behavior + session-store
sanity when the socket drops mid-turn; and cold-start latency per run.

## Result — 2026-07-17 (stdio gating checks: concurrency, permission, cancel, drop, latency)

Ran the reviewer's gating list for the stdio/bridge path against pinned v1.36.0.

- **Session storage:** `data/sessions/sessions.db` is **SQLite in WAL mode**
  (`-wal`/`-shm` present).
- **Concurrent writers:** two `goose acp` processes creating+prompting distinct
  sessions **simultaneously** against the same `sessions.db` both completed with
  **no `database is locked` / `SQLITE_BUSY` / corruption**. WAL handles the
  two-chats-at-once case. (Two writers on the *same* session is prevented by
  c1's per-chat run serialization and was not stress-tested.)
- **Permission pass-through over stdio:** in `approve` mode, `request_permission`
  fired over stdio and the auto-approved option was sent back; Goose's built-in
  **shell** tool then executed in-container and returned its result
  (`permission-shell-ok`), `stopReason=end_turn`. (An ACP *file-write* tool
  failed only because the spike's host-side `WriteTextFile` callback can't write
  the container path — a harness artifact; production c1 advertises no fs
  callbacks and lets Goose's in-container shell act.)
- **Cancel over stdio:** `session/cancel` mid-turn resolved the prompt with a
  deterministic terminal `stopReason`, no hang — same contract as HTTP.
- **Socket drop mid-turn (TCP bridge):** killing the c1 side mid-turn left the
  session store sane — a fresh `session/load` of the dropped session succeeded
  with no lock/corruption. No lingering goose observed (image lacks `ps` for a
  definitive orphan check; the planned production Go supervisor shim owns child
  lifecycle/reaping explicitly).
- **Cold start:** ~1.7s wall for a fresh connection + trivial turn *including one
  provider round-trip*; goose spawn/init is a negligible fraction. No mobile
  time-to-first-token concern.

**Verdict:** every gating check the reviewer named passes over stdio. The
stdio-via-socket-bridge path is a viable, lower-code alternative to the
hand-rolled Streamable-HTTP transport. Recommended production shape: a small Go
supervisor shim in c2 (not raw socat) for channel auth + child lifecycle, and a
tripwire to adopt the official ACP-over-HTTP SDK transport if/when it ships.

## Result — 2026-07-17 (WebSocket dialect: does it plug into the SDK connection?)

**Question:** `goose serve` advertises "ACP server over HTTP and WebSocket." Is
the WS dialect clean enough that a thin adapter lets the robust SDK
`ClientSideConnection` run over it — retiring both the hand-rolled
`streamable.go` and the stdio socat/shim?

Setup: `goose serve --host 0.0.0.0` (v1.36.0, default port 3284). WS endpoint is
**`/acp`** (same path, content-negotiated by the `Upgrade` header; `/ws` and `/`
are 404). Added `ws_transport.go`: a ~40-line `wsStream` adapter presenting the
WS as newline-delimited JSON (one JSON-RPC message per text frame) and feeding it
straight into `acp.NewClientSideConnection` — no `streamable.go`.

- **init → new → prompt:** succeeded over WS; 5 `session/update` frames streamed.
  **No `Acp-Connection-Id` correlation needed** — the single duplex WS channel
  is the connection.
- **Load/resume:** a fresh WS connection ran `session/load` and recalled `5309`
  from the earlier turn.
- **Permission:** in `approve` mode the built-in shell tool executed and returned
  `ws-perm-ok`, `stopReason=end_turn`.
- **Cancel:** `session/cancel` mid-turn resolved the prompt with a terminal
  `stopReason`, no hang.
- **Auth gap:** the WS `/acp` endpoint accepted a full unauthenticated session
  (no `X-Secret-Key`) in v1.36.0, whereas HTTP `/acp` enforces the secret. WS
  auth therefore currently rests on network isolation (same as a raw socket).
  Flag upstream / gate c2 at the network layer regardless.

**Verdict:** WebSocket is the cleanest fit. `goose serve` (persistent WS server,
no socat/shim, no per-connection process spawn) + a ~40-line WS→bytestream
adapter + the maintained SDK `ClientSideConnection` gives every capability the
other transports have, with the least bespoke code and no c2 bridge process.
Recommended c1 transport, pending: (1) confirm/repair WS channel auth or enforce
network isolation, (2) verify reconnect/replay semantics on a mid-turn WS drop
(the same open Gate-B question for all transports).
