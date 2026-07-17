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

> Acceptance status (2026-07-16): real Docker c1/c2 tests passed for allow, deny, cancel while pending, fresh-c1 session-load reconnect, and c1 restart. Pending approvals correctly vanish on restart; that is intentional and not a recovery failure. Keep the Rust sandbox ACP adapter and legacy agent/MCP services dormant until Goose can be deliberately routed through them; do not present them as part of the active path.
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

## Explicit non-goals

- No Flutter changes.
- No Cognee/gateway MCP enablement: the Goose v1.36 gateway attachment spike did not expose gateway tools. Keep default-deny until a new pinned compatibility proof succeeds.
- No legacy PocketBase schema deletion. That is governed by the separate cleanup plan.

## Done when

A newly created v2 chat has exactly one stored Goose session mapping; an authenticated client can reconnect after a c1 restart and receive its history solely from `session/load`; prompts, developer permissions, and cancellation work without creating PocketBase message/permission/terminal records.
