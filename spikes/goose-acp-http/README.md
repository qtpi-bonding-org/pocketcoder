# Goose ACP compatibility spike

Disposable harness for the first PocketCoder c1↔c2 gate. It deliberately has no PocketBase, Flutter, Docker MCP Gateway, or provider configuration.

## What it proves

1. The selected Go ACP SDK can initialize a goose ACP session, create a session, forward streamed updates, and prompt it over the supported `goose acp` stdio transport.
2. The authenticated remote `/acp` endpoint can initialize, create a session, stream updates, and prompt through the actual pinned Goose image.
3. The exact remote transport dialect and reconnect behavior are captured before c1 is designed around it.

The Go SDK currently exposes a line-delimited JSON-RPC connection API. The HTTP path here is a minimal raw adapter for compatibility discovery, not production c1 code.

## Result — 2026-07-16

Using Goose image `ghcr.io/block/goose@sha256:d85a724ee487425f38ce015323adf2003591268ee515d9018ac89450ed7d3a5a` and MiniMax M2.5:

- `initialize → session/new → session/prompt` succeeded through the Go SDK and `goose acp`; streamed thought and message updates were received.
- `goose serve` started successfully with `GOOSE_SERVER__SECRET_KEY`; `/status` was healthy.
- `initialize → session/new → session/prompt` also succeeded remotely through one persistent `goose serve`, with thought and message updates streamed to the Go harness.
- The pinned image does **not** implement the current ACP Streamable-HTTP RFD described in the architecture references. Its observed contract is: `POST /acp` returns `200 text/event-stream` (not `202` plus a long-lived GET stream); initialization returns `Acp-Session-Id` (not `Acp-Connection-Id`); later requests carry that header and return their own SSE response stream. It currently responds over HTTP/1.1.
- A fresh remote connection followed by `session/load` returned EOF without a JSON-RPC response and Goose produced no diagnostic log. Therefore persisted-session reconnect remains **unproven** and is a blocking c1 spike result.

**Decision:** do not build c1 routes or Flutter work yet. First either (a) pin and implement the observed Goose legacy HTTP dialect, including a working remote `session/load` test, or (b) upgrade Goose to a release that actually implements the current ACP Streamable-HTTP RFD and rerun this spike. The latter is preferable, because c1 should not own a bespoke obsolete transport.

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

The program prints raw `session/update` notifications as JSON on stdout and lifecycle evidence on stderr. Use `--auto-approve` only for a controlled, disposable workspace when testing permission callbacks.

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

This command targets the **observed legacy Goose dialect** and is intentionally not a general ACP Streamable-HTTP client.

## Exit criteria

- A current-Goose remote transport is selected and pinned.
- `initialize`, `session/new`, one prompt, and `session/load` work after the harness restarts.
- The selected release conforms to the current ACP transport, or PocketCoder explicitly owns and tests a legacy adapter.

Delete this directory once that decision is implemented and covered by the production c1 integration tests.
