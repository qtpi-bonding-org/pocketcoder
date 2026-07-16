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
