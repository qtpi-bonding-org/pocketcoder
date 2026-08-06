# Spike: upgrading docker-mcp from v0.39.3 to v0.43.3

## Why

`tooling/scripts/install-docker-mcp.sh` pins `docker/mcp-gateway` to `v0.39.3`
(2026-02-14), five months and nine releases behind latest (`v0.43.3`,
2026-07-16). Investigating a security question (whether `gateway__mcp-add`
lets a model bypass PocketCoder's `mcp_servers` approval pipeline and spin up
a server with a raw `docker.sock` mount) turned up that the "safe" behavior
on v0.39.3 is an upstream bug, not a boundary anyone designed: `mcp-find`
searches Docker's default/legacy public catalog while `mcp-add` resolves
against a different, empty registry — confirmed against real GitHub issues
([docker/mcp-gateway#138](https://github.com/docker/mcp-gateway/issues/138),
[#420](https://github.com/docker/mcp-gateway/issues/420)) rather than
PocketCoder-specific config. Relying on that mismatch is fragile: a routine
version bump could silently fix it and reopen the gap. This spike checks
what upgrading actually requires.

## Method

Built `server/mcp-gateway/Dockerfile` locally with
`tooling/scripts/install-docker-mcp.sh`'s `VERSION` bumped to `v0.43.3`,
ran it standalone (`docker run`, not through `docker-compose.yml`) against
this repo's real `server/mcp-gateway/config/` directory, and drove it with
`docker exec ... docker mcp tools call ...` — the same harness
`tests/helpers/mcp.sh` uses. No changes were made to the tracked compose
file or to `hooks/mcp.go`; this is read-only investigation of the CLI's new
behavior.

## Findings

### 1. `docker mcp catalog init` no longer exists

The current entrypoint (`server/mcp-gateway/mcp-gateway-entrypoint.sh`)
runs `docker mcp catalog init` before starting the gateway. On v0.43.3 this
prints the `catalog` subcommand's help text and does nothing — `init` isn't
in the command list anymore (`create`, `list`, `pull`, `push`, `remove`,
`server`, `show`, `tag`). The replacement for "import the standard public
catalog" is `docker mcp catalog create <name> --from-legacy-catalog <url>`,
now an explicit, named action instead of an implicit boot-time step.

**This turns out to be the fix for the security question that motivated
this spike**, not a follow-on task: since nothing auto-imports a public
catalog anymore, `mcp-find` has nothing to search unless something
explicitly creates and loads one. Confirmed empirically — with our real
(empty, 0-approved) `docker-mcp.yaml` loaded and the old `catalog init` step
simply left out, `docker mcp tools call mcp-find query=docker` returns
`{"servers":[],"total_matches":0}`, where the same call against v0.39.3
reliably returned `docker`/`docker-docs`/`simplechecklist` from Docker's
default catalog every time. The fix isn't "block `mcp-add`" — it's "stop
calling the step that populates a catalog PocketCoder never wanted exposed
in the first place."

### 2. `--catalog` / `--enable-all-servers` now require the file to live under `~/.docker/mcp/catalogs/`

v0.39.3 accepted `--catalog /root/.docker/mcp/docker-mcp.yaml` with that
path bind-mounted from anywhere. v0.43.3 rejects it outright:

```
failed to read catalogs for --enable-all-servers: local file path must
resolve within Docker MCP catalogs directory
```

Fix (confirmed working): mount the config directory at
`/root/.docker/mcp/catalogs/` instead of `/root/.docker/mcp/`, and pass
`--catalog docker-mcp.yaml` (resolved relative to that directory) instead
of an absolute bind-mount path. `hooks/mcp.go`'s `mcpConfigPath` constant
(currently `/mcp_config/docker-mcp.yaml`, volume-mapped into the gateway at
`/root/.docker/mcp/docker-mcp.yaml`) and `docker-compose.yml`'s mcp-gateway
volume/command both need this path change together.

### 3. HTTP/streaming transports now require Bearer-token auth by default

Booting without `MCP_GATEWAY_AUTH_TOKEN` or `--allow-unauthenticated`, the
gateway auto-generates a token and prints it once at startup rather than
serving unauthenticated (v0.39.3's behavior — confirmed via its own log
line, `Authentication disabled (running in container)`). Fix: set
`MCP_GATEWAY_AUTH_TOKEN` explicitly (compose can inject a generated secret
the same way `PN_RELAY_SECRET`/`GOOSE_SERVER__SECRET_KEY` already are in
`bootstrap.nix`) and confirm Goose's HTTP extension config
(`_goose/unstable/config/extensions/add`, `type: "http"`) supports a custom
`Authorization` header — **not verified in this spike**, needs checking
against Goose's ACP schema before this is a real integration, not just a
gateway-side change.

### 4. `--verify-signatures` now defaults to `true`, and rejects mutable tags

```
verifying docker image mcp/time:latest: image must be referenced by digest;
pin the MCP image to a sha256 digest or disable signature verification
with --verify-signatures=false
```

`hooks/mcp.go`'s `renderMcpConfig` currently writes `image: mcp/<name>` and
defaults to `:latest` if no tag/digest is given (`mcp.go:135-137`) — this
would be rejected outright by the new default. Confirmed the full path
(catalog load → image pull → server enabled → 2 tools listed) works
end-to-end once `--verify-signatures=false` is passed explicitly.

This is a real decision, not just a flag flip: turning verification off
matches today's behavior (no signature checking existed before) but gives
up a real supply-chain protection Docker just shipped, for a system whose
whole threat model is "the agent proposes an arbitrary image name." The
better fix is probably resolving and pinning a digest at approval-render
time (same "pinned artifact, not a mutable tag" pattern this codebase
already uses everywhere else — NixOS release images, the Docker image
cache manifest, `POCKETCODER_REF`) rather than disabling verification
wholesale. Not attempted in this spike; flagging as the real follow-up
decision.

## Summary: what an actual upgrade needs

1. Drop `docker mcp catalog init` from
   `server/mcp-gateway/mcp-gateway-entrypoint.sh` — it's a no-op now, and
   its absence is what closes the `mcp-find` leak.
2. Move the catalog mount/path: `hooks/mcp.go`'s `mcpConfigPath`,
   `docker-compose.yml`'s `mcp-gateway` volume, and its `--catalog` flag
   value all need to agree on `.../catalogs/docker-mcp.yaml`.
3. Add `MCP_GATEWAY_AUTH_TOKEN` generation (compose/bootstrap secret,
   mirroring existing secrets) and verify Goose's HTTP MCP extension config
   can carry a Bearer token — unverified, needs a Goose-side check.
4. Decide the signature-verification story: pin approved images by digest
   at render time (preferred, more work) vs. `--verify-signatures=false`
   (matches current behavior, gives up a new protection).
5. Bump `tooling/scripts/install-docker-mcp.sh`'s `VERSION` — note this
   script is shared by `opencode` and `sandbox` Dockerfiles too
   (per its own header comment), not just mcp-gateway; their behavior on
   v0.43.3 is unverified by this spike and should be checked before the
   version bump lands, since it changes all three at once.

None of this was applied to the real `docker-compose.yml`/`hooks/mcp.go` —
this spike only ran a standalone container against the real config
directory to observe behavior. `tooling/scripts/install-docker-mcp.sh` in
this worktree has the version bump for reference; nothing else changed.
