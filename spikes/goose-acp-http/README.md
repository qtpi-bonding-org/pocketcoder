# Goose ACP compatibility spike

Disposable harness for the first PocketCoder c1↔c2 gate. It deliberately has no PocketBase, Flutter, Docker MCP Gateway, or provider configuration.

## What it proves

1. The selected Go ACP SDK can initialize a goose ACP session, create a session, forward streamed updates, and prompt it over the supported `goose acp` stdio transport.
2. A returned session ID can be saved and supplied back to `session/load` in a fresh harness process.
3. `goose serve` is reachable at its authenticated `/acp` endpoint before investing in the missing Go streamable-HTTP transport adapter.

The Go SDK currently exposes a line-delimited JSON-RPC connection API. The HTTP preflight is therefore intentionally separate: do not treat its success as proof that c1 can already issue ACP methods over HTTP.

## Result — 2026-07-16

Using Goose image `ghcr.io/block/goose@sha256:d85a724ee487425f38ce015323adf2003591268ee515d9018ac89450ed7d3a5a` and MiniMax M2.5:

- `initialize → session/new → session/prompt` succeeded through the Go SDK and `goose acp`; streamed thought and message updates were received.
- `goose serve` started successfully with `GOOSE_SERVER__SECRET_KEY`; `/status` was healthy and an authenticated `GET /acp` returned `400`, confirming authentication succeeded and a valid Streamable-HTTP ACP request is required.
- A separate-process `session/load` test is **not yet proven**. The stdio harness is the wrong topology for that restart check because it spawns a new goose process; the production test must attach c1 to one long-lived `goose serve` instance and exercise `session/load` through its HTTP transport.

**Decision:** proceed with a small Go Streamable-HTTP transport adapter (or adopt one from the ACP SDK if it lands) before starting PocketBase integration. Do not build c1 routes or Flutter work yet.

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

## Run the HTTP preflight

In a separate terminal, start a pinned goose server. Bind it only to a private network during the spike:

```bash
export GOOSE_SERVER__SECRET_KEY='replace-with-a-long-random-secret'
goose serve --host 127.0.0.1 --port 3000
```

Then:

```bash
GOOSE_SERVER__SECRET_KEY="$GOOSE_SERVER__SECRET_KEY" ./http-preflight.sh
```

Expected: `/status` succeeds and `/acp` returns anything except `401`/`403` when sent `Accept: text/event-stream` and `X-Secret-Key`.

## Exit criteria

- `initialize`, `session/new`, one prompt, and `session/load` work with a pinned goose version.
- The same session can be loaded after the harness restarts.
- The exact HTTP behavior, response headers, and stream framing at `/acp` are captured.
- A follow-up implementation decision is recorded: use an upstream Go streamable-HTTP ACP transport, or add the smallest adapter around the ACP SDK's existing line-delimited connection.

Delete this directory once that decision is implemented and covered by the production c1 integration tests.
