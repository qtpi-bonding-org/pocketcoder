# MCP Gateway v0.43 Upgrade + Multi-Harness Attachment — Design

**Status:** Proposed, spike-verified. See `spikes/mcp-gateway-v0.43-upgrade/README.md`
for the raw investigation this spec is built on — every claim about the
gateway's new CLI behavior below was run against a real v0.43.3 container,
not read from docs alone.

## Purpose

`tooling/scripts/install-docker-mcp.sh` pins `docker/mcp-gateway` to
`v0.39.3` (2026-02-14), five months and nine releases behind latest
(`v0.43.3`, 2026-07-16). A security investigation into whether
`gateway__mcp-add` lets a model bypass PocketCoder's `mcp_servers` approval
pipeline found that the pinned version's apparent safety is an upstream bug
(confirmed against [docker/mcp-gateway#138](https://github.com/docker/mcp-gateway/issues/138)
and [#420](https://github.com/docker/mcp-gateway/issues/420)), not a
boundary anyone designed — `mcp-find` searches Docker's auto-imported
public catalog while `mcp-add` resolves against a different, disconnected
registry. A routine version bump could silently fix that upstream bug and
reopen the gap with no PocketCoder-side change to notice it.

This spec upgrades the gateway to close that gap for real (not by
accident), and — since the user-facing feature this unblocks is bigger than
a version bump — also does the first-ever wiring of MCP-gateway attachment
for the three peer harnesses (Claude Code, Codex, OpenCode), which
currently have none at all. Only Goose has gateway attachment today
(`docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md`).

## Why upgrading is the actual fix, not just hygiene

`docker mcp catalog init` — the first command in
`server/mcp-gateway/mcp-gateway-entrypoint.sh` — does not exist in v0.43.3.
On v0.39.3 it silently imports Docker's full public catalog at every boot;
that's what `mcp-find` was leaking to the model regardless of what
PocketBase had approved. On v0.43.3, importing a catalog is an explicit,
named action (`docker mcp catalog create <name> --from-legacy-catalog
<url>`) that this integration simply never needs to call. Verified: with
our real (empty) PocketBase-rendered catalog loaded and no catalog-init
step, `docker mcp tools call mcp-find query=docker` returns
`{"servers":[],"total_matches":0}` — the discovery surface only ever
reflects what PocketBase approved, by construction, not by relying on a bug
that a version bump could fix out from under us.

## Component 1 — Gateway container: catalog path, entrypoint, auth

### Catalog mount path changes

v0.43.3 rejects `--catalog`/`--enable-all-servers` unless the file resolves
under `~/.docker/mcp/catalogs/` (confirmed:
`local file path must resolve within Docker MCP catalogs directory`).
Three things move together:

- `docker-compose.yml`'s `mcp-gateway` volume:
  `./server/mcp-gateway/config:/root/.docker/mcp/catalogs` (was
  `/root/.docker/mcp`).
- `mcp-gateway`'s command: `--catalog docker-mcp.yaml` (relative, resolved
  under that directory — was an absolute in-container path).
- `hooks/mcp.go`'s `mcpConfigPath`/`mcpSecretsPath` constants and whatever
  path Aeroform/bootstrap mounts as `/mcp_config` need to land inside that
  same `catalogs/` subdirectory on the gateway side. `renderMcpConfig`'s
  own logic (image/title/description/secrets, no `volumes:` key) is
  unchanged — only the target path moves.

### Entrypoint

`mcp-gateway-entrypoint.sh` drops the `docker mcp catalog init` line
entirely — it is a no-op on v0.43.3 (prints catalog-subcommand help) and
its absence is what keeps `mcp-find` scoped to approved servers only.

### Mandatory HTTP auth

v0.43.3 requires Bearer-token auth on HTTP/streaming transports by default
(auto-generates and prints a token if none is supplied — confirmed via
gateway startup log). `--allow-unauthenticated` is available but not
recommended: the whole point of this spec is tightening this boundary, not
opting back out of a default Docker just shipped. Instead:

- Generate `MCP_GATEWAY_AUTH_TOKEN` once, in `bootstrap.nix`, the same
  block that already generates `PN_RELAY_SECRET`/`GOOSE_SERVER__SECRET_KEY`
  (`tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32`).
- Pass it to `mcp-gateway` itself as `MCP_GATEWAY_AUTH_TOKEN` (the gateway
  reads this env var natively — no flag needed once it's set).
- Every client that connects to the gateway needs the same token; see
  Component 2.

### Signature verification

v0.43.3 defaults `--verify-signatures=true` and rejects mutable tags
outright (confirmed:
`image must be referenced by digest; pin the MCP image to a sha256 digest`).
`renderMcpConfig` currently writes `image: mcp/<name>` and defaults to
`:latest` (`hooks/mcp.go:135-137`) — this would be rejected wholesale.

**Decision: resolve and pin a digest at `mcp_request` time, not
`--verify-signatures=false`.** This matches every other pinned-artifact
pattern already in this codebase (`POCKETCODER_REF`, the NixOS release
image, the Docker image cache manifest) — approve what was actually
reviewed, not whatever a mutable tag happens to resolve to later.
Concretely:

- `api/mcp.go`'s `mcp_request` handler resolves `input.Image`'s tag to a
  digest (`docker manifest inspect`-equivalent, or a pull via the already-
  scoped `docker-socket-proxy-mcp` — it already grants `IMAGES=1`) and
  stores the resolved `name@sha256:...` reference on the `mcp_servers`
  record, not the original tag. Doing this *before* human approval means
  the human reviewing the request sees and approves the exact digest that
  will run — not a tag that could point somewhere else by the time
  `renderMcpConfig` fires.
- `renderMcpConfig` writes that stored digest reference as-is; no change
  to its no-`volumes:` safety property.
- If resolving a digest turns out to be more work than this spec's budget
  allows for v1, `--verify-signatures=false` is the documented fallback —
  but land as a conscious, called-out trade-off in that PR, not a default.

## Component 2 — Multi-harness attachment (new — Goose is the only harness with this today)

All four harnesses can reference an **environment variable** for the auth
token rather than needing it baked into a per-instance-rendered file —
confirmed for each:

| Harness | Mechanism |
|---|---|
| Goose | `config/extensions/add` payload's `headers` map — built directly in Go, reads the token from PocketBase's own process env |
| Claude Code (CLI) | `.mcp.json` supports `${VAR}`/`${VAR:-default}` expansion in `headers`/`url` (works in CLI, not Desktop — irrelevant here, ours is headless) |
| Codex | `config.toml`'s `[mcp_servers.<name>]` takes `bearer_token_env_var = "MCP_GATEWAY_AUTH_TOKEN"` — no interpolation needed at all |
| OpenCode | `opencode.json`'s `headers` supports `"Bearer {env:MCP_GATEWAY_AUTH_TOKEN}"` |

This means: one secret, delivered as a plain env var, everywhere. The only
new code is a small **static** (non-secret, checked-in) MCP-attach snippet
per harness — the same for every deployment, since only the token value
varies and that's resolved at read time by each CLI's own env-var support.

### Delivery mechanism, confirmed against `adapter.go`

`bridgeConnection` spawns each harness's ACP process **fresh per
connection** (`exec.Command(cfg.Cmd[0], cfg.Cmd[1:]...)`, no `cmd.Env`
override — full container env is inherited). That means a static config
file referencing an env var works for every spawn without any
per-connection registration step, as long as the env var and the config
file both exist in the container before the first connection arrives.

- **Claude Code**: bake a static `.mcp.json` into
  `server/harness-adapter/Dockerfile`'s image (the `claude-code-harness`
  build), with `${MCP_GATEWAY_AUTH_TOKEN}` in the `Authorization` header
  and `http://mcp-gateway:8811/mcp` as the URL. Harmless to include even on
  harness types that don't use it if the file is added generically, but
  simplest to gate it in the `ARG`-driven build the same way
  `ACP_AGENT_PACKAGE` already differs per harness.
- **Codex**: same approach — a static `config.toml` fragment with
  `bearer_token_env_var = "MCP_GATEWAY_AUTH_TOKEN"`, baked into the image
  at build time, no per-value interpolation needed.
- **OpenCode**: extend the *existing* `OPENCODE_CONFIG_CONTENT` generation
  in `opencode-ollama-config.mjs` (currently Ollama-model discovery only)
  to also emit an `mcp.gateway` block reading
  `process.env.MCP_GATEWAY_AUTH_TOKEN`. This reuses an established pattern
  rather than adding a new one — OpenCode already gets its config
  generated once at container start and exported as an env var consumed by
  every per-connection spawn.
- **Goose**: extend the existing one-time `config/extensions/add` call
  (`docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md`
  Component 3) to include `headers: {"Authorization": "Bearer <token>"}` in
  the payload. Smallest change of the four — one field on an existing call.

### Getting the token into each peer-harness container

`harness_provision.go`'s `renderEnv` already builds a `values` map with two
reserved keys (`__adapter_secret`, `__ollama_host`) merged in before
rendering each harness's `launch_template.env_template` against it
(`harness_provision.go:308-311`). Add a third reserved key,
`MCP_GATEWAY_AUTH_TOKEN` (read from PocketBase's own process env, same
source Goose's registration call uses) — then each harness's
`launch_template.env_template` just needs one new entry:
`{"MCP_GATEWAY_AUTH_TOKEN": "{{.MCP_GATEWAY_AUTH_TOKEN}}"}`, same shape as
every existing entry. No new rendering machinery.

**Plan must resolve:** exact `harnesses` seed rows / `launch_template`
JSON for all three peer harnesses need this new `env_template` entry added
— confirm the seed migration (`1756000100_seed.go` or wherever
`harnesses` rows are seeded) at implementation time.

## Component 3 — Shared installer script blast radius

`tooling/scripts/install-docker-mcp.sh`'s header comment claims it's
"used by opencode, sandbox, and mcp-gateway Dockerfiles" — checked, this is
stale. Only `server/mcp-gateway/Dockerfile` references it today; OpenCode's
harness image builds from `server/harness-adapter/Dockerfile` via
`npm install opencode-ai`, unrelated to the `docker-mcp` CLI, and "sandbox"
is the dormant Rust proxy. The version bump (`VERSION="v0.39.3"` →
`"v0.43.3"`) only affects `mcp-gateway`. Worth fixing the stale comment in
the same change.

## Non-negotiable rules

1. `docker mcp catalog init` (or any equivalent that imports a broad
   public catalog) must never run in the gateway's entrypoint — this is
   the actual fix for the `mcp-find` discovery leak, not an incidental
   side effect.
2. `renderMcpConfig` keeps its no-`volumes:` invariant exactly as-is; this
   spec does not touch that safety property, only the path it writes to
   and the image reference format (tag → resolved digest).
3. `MCP_GATEWAY_AUTH_TOKEN` is generated once, centrally, alongside the
   other bootstrap-generated secrets — never hand-entered, never logged.
4. Every client (Goose, all three peer harnesses) authenticates to the
   gateway with that same token; `--allow-unauthenticated` is not used.
5. A peer harness's static MCP-attach config never contains the token
   value itself — only a reference to the env var name. The token is
   injected exactly once, as a container env var, via the existing
   `renderEnv`/`env_template` mechanism.

## Out of scope

- Building a UI/flow for a human to browse Docker's public catalog before
  requesting a server (unrelated to this spec; the governed
  `mcp_request`/approval path is unchanged).
- Any change to the `mcp_servers` approval state machine itself.
- Rearchitecting `renderMcpConfig` beyond the path/digest changes above.
- Deciding whether `gateway__mcp-add`/`mcp-exec`/etc. (the gateway's own
  bundled dynamic-tools) should be explicitly denied in `tool_permissions`
  regardless of this upgrade. Worth doing independently, not blocked on or
  by this spec.

## Testing

Extend `tests/agent-c1/mcp_gateway.bats` (already exercises
`gateway__mcp-find` against a real ACP `tools/list` call) with:

1. Assert `mcp-find` returns zero results for a query with no matching
   approved server, proving the catalog-leak fix holds under the real
   compose stack, not just the standalone spike harness.
2. Assert a real model-invoked call to `gateway__mcp-add` for a
   *non-approved* server name fails, and does not spin up a container —
   regression coverage for the original security question this spec traces
   back to.
3. New scenario file (or extend existing) covering at least one peer
   harness's gateway attachment end to end — approve a test server via
   `mcp_request`, confirm its tools are reachable through that harness's
   ACP connection, matching the existing Goose-only proof shape.

## References

- `spikes/mcp-gateway-v0.43-upgrade/README.md` — raw investigation,
  standalone-container evidence for every claim about v0.43.3's behavior
  above.
- `docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md` —
  Goose-only gateway attachment, the precedent this spec extends to the
  other three harnesses.
- [docker/mcp-gateway#138](https://github.com/docker/mcp-gateway/issues/138),
  [#420](https://github.com/docker/mcp-gateway/issues/420) — upstream
  issues confirming the v0.39.3 catalog/registry mismatch this spec closes
  by upgrading.
