# MCP Gateway v0.43 Upgrade + Multi-Harness Attachment — Plan

See `docs/superpowers/specs/2026-08-05-mcp-gateway-v0.43-upgrade-design.md`
for the design and rationale; this is just implementation logistics/order.

## Step 1 — Gateway upgrade (no new features, closes the security gap)

- Bump `tooling/scripts/install-docker-mcp.sh`'s `VERSION` to `v0.43.3`;
  fix its stale "used by opencode, sandbox" header comment (only
  `mcp-gateway` uses it).
- Drop `docker mcp catalog init` from `mcp-gateway-entrypoint.sh`.
- Move the catalog mount: `docker-compose.yml`'s `mcp-gateway` volume to
  `/root/.docker/mcp/catalogs`, command's `--catalog` to the relative
  `docker-mcp.yaml`. Update `hooks/mcp.go`'s `mcpConfigPath`/
  `mcpSecretsPath` (and wherever `/mcp_config` gets mounted from) to match.
- Generate `MCP_GATEWAY_AUTH_TOKEN` in `bootstrap.nix` alongside the other
  generated secrets; add it to `mcp-gateway`'s environment in
  `docker-compose.yml`.
- Verify with `tests/agent-c1/mcp_gateway.bats`'s existing gateway-extension
  test, plus the two new regression cases from the spec's Testing section
  (mcp-find returns empty for unapproved names, mcp-add on a non-approved
  name fails / spins up nothing).

**Checkpoint:** gateway boots, approved servers still auto-enable and are
reachable through Goose exactly as today, `mcp-find`/`mcp-add` no longer
reach anything outside what PocketBase approved. This step alone is
shippable — everything after it is additive.

## Step 2 — Digest pinning for approved images

- `api/mcp.go`'s `mcp_request` handler resolves `input.Image`'s tag to a
  digest before writing the `pending` row (via the scoped
  `docker-socket-proxy-mcp`, which already has `IMAGES=1`).
- `renderMcpConfig` writes the stored digest reference unchanged otherwise.
- If this proves more work than expected, fall back to
  `--verify-signatures=false` explicitly (called out as a conscious
  trade-off in that PR, not silently) and revisit later — doesn't block
  Step 3/4.

## Step 3 — Goose gateway auth (smallest of the multi-harness changes)

- Add `headers: {"Authorization": "Bearer <token>"}` to the existing
  one-time `config/extensions/add` call
  (`docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md`
  Component 3). Token read from PocketBase's own process env.

## Step 4 — Peer-harness attachment (new for all three; can be done in parallel per harness once Step 1 lands)

- `harness_provision.go`'s `renderEnv`: add `MCP_GATEWAY_AUTH_TOKEN` as a
  third reserved key in the `values` map (alongside `__adapter_secret`,
  `__ollama_host`), sourced from PocketBase's process env.
- Add `MCP_GATEWAY_AUTH_TOKEN` to each of the three harnesses'
  `launch_template.env_template` (seed data — find where `harnesses` rows
  live, likely `1756000100_seed.go` or an admin-editable collection).
- Claude Code: bake a static `.mcp.json` into
  `server/harness-adapter/Dockerfile`'s build output (or COPY'd in),
  `${MCP_GATEWAY_AUTH_TOKEN}` in the header.
- Codex: bake a static `config.toml` fragment the same way,
  `bearer_token_env_var = "MCP_GATEWAY_AUTH_TOKEN"`.
- OpenCode: extend `opencode-ollama-config.mjs`'s generated
  `OPENCODE_CONFIG_CONTENT` output to add the `mcp.gateway` block.
- Test each harness end to end: approve a test server via `mcp_request`,
  confirm its tools are reachable through that harness's ACP connection.
  Can land and verify one harness at a time — not all-or-nothing.

## Sequencing notes

- Step 1 is the actual security fix and should land first/alone if there's
  any reason to ship incrementally — it's independently valuable and
  low-risk (no new attach surface, closes an existing leak).
- Steps 3 and 4 don't depend on Step 2 (digest pinning) — order among
  Steps 2-4 is flexible, driven by whichever's easiest to verify next.
- Step 4's three harnesses are independent of each other; do them in any
  order, one at a time, each independently testable.
