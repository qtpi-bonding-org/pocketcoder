# Goose ↔ Docker MCP Gateway attachment spike

Disposable follow-up to the "Gateway MCP attachment" negative finding in
`spikes/goose-acp-http/README.md`. That finding was against the older pinned
Goose **v1.36.0**. This spike re-tests both attachment mechanisms against the
**currently pinned c2 image, Goose v1.43.0**
(`ghcr.io/aaif-goose/goose@sha256:b5e2d93bba1a6a6b9302ad3fa70e01fe7a0a5e68c127954653d3b95101c31409`),
against a real Docker MCP Gateway container (`docker mcp gateway run`, same
image/entrypoint as `services/mcp-gateway/`), over a temporary Docker network
neither container has in the tracked `docker-compose.yml`.

## What it proves

1. Whether Goose v1.43.0's ACP `session/new.mcpServers` (session-scoped
   attachment) exposes a gateway's tools.
2. Whether the connection-scoped ACP custom method
   `_goose/unstable/config/extensions/add` (global/static attachment,
   persisted to `config.yaml`) exposes a gateway's tools.
3. Whether the *transport dialect* the gateway is launched with
   (`--transport sse` vs `--transport streaming`) is the actual variable that
   determines success, independent of which of the two ACP mechanisms is used.
4. A real end-to-end proof: a model-driven `session/prompt` turn that calls
   one of the gateway's own built-in tools (`gateway__mcp-find`) and gets a
   real result back from the gateway process.

`main.go` is a small, self-contained (stdlib-only) raw ACP Streamable-HTTP
client, structurally the same dialect proven in `spikes/goose-acp-http`
(`initialize` → open connection SSE stream → `POST` request/`202`/reply over
the stream), extended with the extra calls this spike needed
(`_goose/unstable/config/extensions/add`, `_goose/unstable/tools/list`, and an
`mcpServers`/extension entry that can be typed `sse` or `http`). It does not
modify or depend on `spikes/goose-acp-http`.

## Result — 2026-07-22

Both containers were built and run for real via `docker compose --profile
agent --profile c3 up -d --build goose mcp-gateway` (goose's port 3000
temporarily published to `127.0.0.1` via a disposable
`docker-compose.override.yml`, deleted after the spike), then connected to a
throwaway Docker network (`spike-goose-mcp-net`) — the tracked compose file
was not edited, and mcp-gateway was **not** added to `pocketcoder-agent`.
MiniMax was used as the model provider (`ANTHROPIC_API_KEY`/`ANTHROPIC_HOST`
pointed at MiniMax's Anthropic-compatible endpoint, same pattern as
`spikes/goose-acp-http/container-goose.sh`), `GOOSE_MODEL=MiniMax-M2.5`.

### `initialize` capability negotiation — the headline finding

```
initialize.agentCapabilities.mcpCapabilities = {"http":true,"sse":false,"acp":false}
```

Goose v1.43.0 advertises **`sse: false`** in its ACP `initialize` response.
Per the ACP spec's `McpServerSse` note ("Only available when the Agent
capabilities indicate `mcp_capabilities.sse` is `true`"), any attempt to
supply an `sse`-typed MCP server is expected to be rejected — and it was, for
**both** attachment mechanisms, with the identical explicit error:

```json
{"code":-32602,"message":"Invalid params","data":"SSE is unsupported, migrate to streamable_http"}
```

- `session/new` with `mcpServers: [{"type":"sse","name":"gateway","url":"http://<gateway>:8811/sse", ...}]` → JSON-RPC error above.
- `_goose/unstable/config/extensions/add` with `extension: {"type":"mcp","server":{"type":"sse", ...}}` → same JSON-RPC error above.

This is a **direct, named regression path from the v1.36.0 finding**: v1.36.0
silently accepted an SSE gateway and then never surfaced its tools (a
compatibility/configuration blocker with no error message). v1.43.0 gives an
explicit, actionable error instead — and that error tells you exactly what
changed. The Docker MCP Gateway's `--transport sse` mode (what
`services/mcp-gateway`'s tracked `docker-compose.yml` command line currently
launches: `docker mcp gateway run --transport sse ...`) is a dead end for
Goose v1.43.0, full stop, for either mechanism.

### Switching the gateway to `--transport streaming` — both mechanisms work

The Docker MCP Gateway binary (`docker mcp gateway run --help`) documents a
third transport value beyond `stdio`/`sse`: **`streaming`**
(`--transport string   stdio, sse or streaming`). Running the *same* gateway
image/entrypoint with `--transport streaming` starts a standard MCP
Streamable-HTTP server on `/mcp` instead of `/sse`:

```
> Start streaming server on port 8811
> Gateway URL: http://localhost:8811/mcp
```

Pointing Goose at that URL with `type: "http"` (ACP's name for
Streamable-HTTP MCP, matching the `http: true` capability from `initialize`)
worked on **both** mechanisms:

**1. Session-scoped (`session/new.mcpServers`):**

```json
{"cwd":"/workspace","mcpServers":[{"type":"http","name":"gateway","url":"http://spike-mcp-gateway-streaming:8811/mcp","headers":[]}]}
```

`session/new`'s response `_meta.extensionResults` included
`{"name":"gateway","success":true}`, and the subsequent
`_goose/unstable/tools/list` call returned the gateway's built-in tools,
namespaced `gateway__*`:

```
gateway__mcp-find, gateway__mcp-add, gateway__mcp-remove,
gateway__mcp-exec, gateway__mcp-config-set, gateway__code-mode
```

**2. Global/static (`_goose/unstable/config/extensions/add`), called once
after `initialize`, before any session existed:**

```json
{
  "extension": {
    "type": "mcp",
    "server": {"type": "http", "name": "gateway", "url": "http://spike-mcp-gateway-streaming:8811/mcp", "headers": []}
  },
  "enabled": true
}
```

This call returned `{}` (success) with **no session in scope**, confirming
the prior research's claim that it is connection-scoped, not session-scoped.
It **persisted to the mounted `goose_config` volume's `config.yaml`** — the
exact real on-disk shape Goose wrote:

```yaml
extensions:
  gateway:
    enabled: true
    type: streamable_http
    name: gateway
    description: ''
    uri: http://spike-mcp-gateway-streaming:8811/mcp
    envs: {}
    env_keys: []
    headers: {}
    timeout: null
    socket: null
    bundled: null
```

(Note the on-disk `type` is `streamable_http`, not the ACP request's `http` —
Goose renames it when persisting.) A session created afterward also showed
`{"name":"gateway","success":true}` in `extensionResults`, and
`_goose/unstable/tools/list` again returned the same `gateway__*` tools.

### Real model-invoked tool call through the gateway

To rule out "the tool is listed but Goose can't actually call it" (the
ambiguity flagged as a risk in the task), a real `session/prompt` turn was
run against a gateway catalog (`test-catalog.yaml` in this directory, copied
from `services/mcp-gateway/config/docker-mcp.yaml.template`'s `hello-world`
fixture) with the prompt "call `gateway__mcp-find` with query `hello`,
limit 5, then repeat the raw result". The model called the tool; Goose
executed it against the live gateway process; the gateway returned a real
catalog match; the model echoed it back:

```json
{"prompt":"hello","servers":[{"description":"Approved by user for PocketCoder","long_lived":false,"name":"hello-world"}],"total_matches":1}
```

streamed as an ACP `tool_call` → `tool_call_update` (`status: completed`)
pair, with `stopReason: end_turn`. This is full attach-to-invoke proof, not
just a `tools/list` listing. (`mcp/hello-world:latest` itself does not
currently exist as a pullable image — `docker: Error response from daemon: No
such image` — so invoking the *downstream* hello-world server's own tool was
not exercised; that is a fixture-availability gap, unrelated to the Goose
attachment question this spike answers.)

## Conclusion

- **v1.36.0 → v1.43.0 changed the failure mode from silent to explicit, and
  changed the actual outcome from broken to working — but only for the
  Streamable-HTTP MCP transport.** SSE-typed MCP servers are explicitly
  unsupported in v1.43.0 (`sse: false` in `initialize`, and a clear
  `"SSE is unsupported, migrate to streamable_http"` error from both
  attachment mechanisms). Anyone reading only the old v1.36.0 finding would
  wrongly conclude gateway attachment is still broken in general; it is not
  — it is broken **only** for the transport the tracked
  `services/mcp-gateway` container currently launches with.
- **Both attachment mechanisms work identically once the gateway speaks
  Streamable-HTTP (`type: "http"` / gateway `--transport streaming`):**
  session-scoped `session/new.mcpServers` and the global/static
  `_goose/unstable/config/extensions/add` (confirmed session-free, confirmed
  to persist a real `config.yaml` extension entry) both attach the gateway,
  both expose its `gateway__*` tools via `_goose/unstable/tools/list`, and a
  real prompted tool call through the gateway succeeded end-to-end.
- **Recommendation: "Goose attaches to the Docker MCP Gateway as an SSE
  extension" is not viable and should not be pursued** — that specific
  transport is dead on v1.43.0. **"Goose attaches to the Docker MCP Gateway
  as a Streamable-HTTP extension" is viable today** and is the fix: change
  `services/mcp-gateway`'s command from `--transport sse` to `--transport
  streaming` (gateway then serves `/mcp` instead of `/sse` — the URL Goose is
  pointed at must change to match), and use either ACP mechanism to attach
  it. This spike does not implement that change in the tracked
  `docker-compose.yml`/config — only reports it.
- Everything else about production wiring is unchanged from the documented
  state: `mcp-gateway` still shares no Docker network with `goose` in the
  tracked compose file (this spike used a disposable network, deleted after);
  making the fix real still requires deciding what network carries
  goose↔gateway traffic without compromising the `pocketcoder-agent` boundary
  documented in `docker-compose.yml`, and reconciling `mcp-gateway`'s
  dynamic, PocketBase-rendered `docker-mcp.yaml`/`mcp.env` (currently "0
  approved servers" in the live tracked config) with whichever attachment
  mechanism c1/c2 end up using.

## Addendum — 2026-07-23: does `--watch` make the restart-on-approve step unnecessary?

`hooks/mcp.go`'s `RegisterMcpHooks` restarts the `mcp-gateway` container on
every `mcp_servers` approve/deny/revoke (`renderMcpConfig` + `restartContainer`).
Docker's own docs list `--watch` (default `true`, undocumented scope —
"Watch for changes and reconfigure the gateway") on `docker mcp gateway run`,
raising the question of whether that restart is defensive/unnecessary. Tested
directly against a standalone gateway container (`--transport streaming`,
same image/entrypoint as `services/mcp-gateway/`, no Goose involved — this is
a gateway-only question):

- Called the gateway's own `mcp-find` tool directly over raw MCP
  Streamable-HTTP (JSON-RPC `initialize` → `tools/call`) to establish a
  baseline: catalog has 1 server (`hello-world`), `mcp-find` returns it.
- Edited `docker-mcp.yaml` on disk to add a second server, **no container
  restart**, two ways: in-place overwrite, and the exact atomic
  temp-file+`os.Rename` pattern `renderMcpConfig` itself uses in production.
  Re-ran `mcp-find` on both the same MCP session and a brand-new session
  (rules out per-session caching) after each edit. **Neither edit was
  visible** — `mcp-find` kept returning only `hello-world`, and gateway logs
  (`--verbose`) showed zero reconfigure/watch activity for either edit.
- Control test: `docker restart`'d the same container (no catalog change
  since the last edit). `mcp-find` immediately returned all 3 accumulated
  servers.

**Conclusion: `--watch` does not hot-reload `--catalog` contents on this
gateway version, at least not for a host bind-mounted file edited either
in-place or via atomic rename.** The restart-on-approve step in
`hooks/mcp.go` is not defensive leftover cruft — it is empirically required.
Keep it exactly as designed; do not attempt to remove it in favor of
`--watch`. (Scope note: this only tests catalog-file reload. Whether
`--watch` covers `--config`/`--registry`/`--secrets` changes was not tested
and is irrelevant to this plan, which only ever changes the catalog file.)

## Prerequisites

- Docker Desktop running.
- Go 1.23+ (stdlib only; no `go mod tidy` needed).
- A MiniMax key in the local gait auth file (only needed for the
  `--prompt` real-tool-call check; `initialize`/`session/new`/`tools/list`
  do not require a working provider call).
- `services/mcp-gateway/Dockerfile` currently fails to build unless
  `scripts/install-docker-mcp.sh` is executable in the working tree (it is
  committed as `100644`). This spike `chmod +x`'d it locally to build, then
  restored the original mode afterward — that is a pre-existing repo
  packaging gap, not something this spike fixes.

## Reproduce

```bash
# 1. Bring up goose + mcp-gateway (sse transport, as tracked today) with
#    goose's port published locally via a disposable override:
cat > docker-compose.override.yml <<'EOF'
services:
  goose:
    ports:
      - "127.0.0.1:3000:3000"
EOF
chmod +x scripts/install-docker-mcp.sh   # only if the build fails with "Permission denied"
ANTHROPIC_API_KEY=<minimax-key> ANTHROPIC_HOST=https://api.minimax.io/anthropic \
  GOOSE_MODEL=MiniMax-M2.5 GOOSE_SERVER__SECRET_KEY=spike-secret \
  docker compose --profile agent --profile c3 up -d --build goose mcp-gateway

# 2. Bridge the two containers (they share no network in docker-compose.yml):
docker network create spike-goose-mcp-net
docker network connect spike-goose-mcp-net pocketcoder-goose
docker network connect spike-goose-mcp-net pocketcoder-mcp-gateway

# 3. Run a second gateway instance in --transport streaming mode (the tracked
#    container only runs --transport sse) against the hello-world fixture
#    catalog in this directory:
docker run -d --name spike-mcp-gateway-streaming \
  --network spike-goose-mcp-net \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v "$(pwd)/spikes/goose-mcp-gateway-attach:/root/.docker/mcp" \
  -e DOCKER_MCP_IN_CONTAINER=1 \
  pocketcoder-mcp-gateway \
  --port 8811 --transport streaming --catalog /root/.docker/mcp/test-catalog.yaml \
  --secrets /root/.docker/mcp/does-not-exist --enable-all-servers

# 4. Run the probe
cd spikes/goose-mcp-gateway-attach && go build -o probe .
./probe --secret spike-secret --mcp-http-url http://spike-mcp-gateway-streaming:8811/mcp --list-tools
./probe --secret spike-secret --add-config-extension-http-url http://spike-mcp-gateway-streaming:8811/mcp --list-tools
./probe --secret spike-secret --mcp-sse-url http://spike-mcp-gateway-streaming:8811/sse   # expect the SSE rejection
./probe --secret spike-secret --mcp-http-url http://spike-mcp-gateway-streaming:8811/mcp \
  --prompt "Call the gateway__mcp-find tool with query 'hello' and limit 5, then reply with exactly the raw tool result text and nothing else."

# 5. Clean up
docker rm -f spike-mcp-gateway-streaming
docker network rm spike-goose-mcp-net
docker compose --profile agent --profile c3 down goose mcp-gateway
rm docker-compose.override.yml
```

`probe` flags of note: `--mcp-sse-url` / `--mcp-http-url` (session-scoped
`mcpServers` entry, sse or streamable-http), `--add-config-extension-sse-url`
/ `--add-config-extension-http-url` (`_goose/unstable/config/extensions/add`,
connection-scoped, before `session/new`), `--list-tools`
(`_goose/unstable/tools/list` after `session/new`), `--prompt` (a real
`session/prompt` turn; server→client updates print to stderr).

## Exit criteria

- [x] Re-tested both attachment mechanisms (`session/new.mcpServers` and
      `_goose/unstable/config/extensions/add`) against the currently pinned
      Goose v1.43.0, with a real isolated Docker MCP Gateway container.
- [x] Captured the exact JSON-RPC error for the SSE path on v1.43.0 (`"SSE is
      unsupported, migrate to streamable_http"`) and the `initialize`
      capability (`mcpCapabilities.sse: false`) that predicts it.
- [x] Found and verified a working transport (Streamable-HTTP,
      `--transport streaming` on the gateway, `type: "http"` in the ACP
      request) for both mechanisms, including the real on-disk `config.yaml`
      shape `_goose/unstable/config/extensions/add` persists.
- [x] Verified tool exposure via `_goose/unstable/tools/list`
      (`gateway__mcp-find` etc.) for both mechanisms.
- [x] Went beyond listing: a real `session/prompt` turn had the model call
      `gateway__mcp-find` and return a real result from the live gateway
      process.
- [x] No tracked file left modified; disposable network, override file, and
      second gateway container removed.

Delete this directory once the `--transport streaming` gateway fix and a
goose↔gateway network are implemented in production c2/c3 config and covered
by real integration tests.
