# Goose ACP compatibility spike

Disposable harness for the first PocketCoder c1↔c2 gate. It deliberately has no PocketBase, Flutter, Docker MCP Gateway, or provider configuration.

## What it proves

1. The selected Go ACP SDK can initialize a goose ACP session, create a session, forward streamed updates, and prompt it over the supported `goose acp` stdio transport.
2. A returned session ID can be saved and supplied back to `session/load` in a fresh harness process.
3. `goose serve` is reachable at its authenticated `/acp` endpoint before investing in the missing Go streamable-HTTP transport adapter.

The Go SDK currently exposes a line-delimited JSON-RPC connection API. The HTTP preflight is therefore intentionally separate: do not treat its success as proof that c1 can already issue ACP methods over HTTP.

## Prerequisites

- Go 1.24+
- A pinned goose binary on `PATH` (record its `goose --version` output with every result)
- A configured Goose provider for a real prompt; no provider is needed to discover an initialize/transport failure

## Run the stdio baseline

```bash
cd spikes/goose-acp-http
go mod tidy
go run . --cwd "$(pwd)" --prompt "Reply with exactly: goose ACP spike connected"
```

Copy the `session_id=...` line. Then prove session loading from a new process:

```bash
go run . --cwd "$(pwd)" --session '<session_id>' --prompt 'Reply with exactly: session load succeeded'
```

The program prints raw `session/update` notifications as JSON on stdout and lifecycle evidence on stderr. Use `--auto-approve` only for a controlled, disposable workspace when testing permission callbacks.

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
