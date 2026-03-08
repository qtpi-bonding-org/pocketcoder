# Launch Readiness Checklist

Generated: 2026-03-08

## Blocking — Must Fix Before Launch

### Security

- [ ] **SurrealDB hardcoded credentials** — `docker-compose.yml:231` uses `--user root --pass root`. Use env vars.
- [ ] **Sandbox SSH hardcoded password** — `services/sandbox/Dockerfile:96` sets `worker:password` via `chpasswd`.
- [ ] **Sandbox SSH password auth enabled** — `services/sandbox/Dockerfile:101` enables `PasswordAuthentication yes`. Should be `no`.
- [ ] **Sandbox SSH root login enabled** — `services/sandbox/Dockerfile:103` sets `PermitRootLogin yes`. Should be `no`.
- [ ] **Secret files written world-readable (0644)** — `llm.go:109,114`, `mcp.go:154,158`, `tool_permissions.go:202` write API keys/secrets. Change to `0600`.
- [ ] **Healthchecks collection publicly writable** — `pb_migrations/1740000100_consolidated_schema.go:237-239` has empty rules. Add auth.
- [ ] **SOPs collection publicly writable** — `pb_migrations/1740000100_consolidated_schema.go:312-313` has empty rules. Restrict to admin.
- [ ] **Artifact API missing auth middleware** — `internal/filesystem/filesystem.go` has manual auth check but no `.Bind(apis.RequireAuth())`.
- [ ] **Shell command injection in proxy** — `services/proxy/src/driver.rs:118` interpolates `cwd` without shell escaping.

### Stability

- [ ] **`expect()` panics in poco-agents** — `services/poco-agents/src/tools.rs:223` panics if agent disappears mid-poll. Should return MCP error.
- [ ] **Unbounded session map in proxy** — `services/proxy/src/main.rs:167` never cleans up disconnected SSE sessions. Memory leak.
- [ ] **No graceful shutdown in proxy** — `services/proxy/src/main.rs` has no `with_graceful_shutdown()`. Active connections killed on stop.

### Configuration

- [ ] **Debug logging in production** — `docker-compose.yml:68` OpenCode at `--log-level DEBUG`. Change to `INFO`.
- [ ] **SQLPage development mode** — `docker-compose.yml:207` `SQLPAGE_ENVIRONMENT=development`. Change to `production`.
- [ ] **MCP gateway debug telemetry** — `docker-compose.yml:127` `DOCKER_MCP_TELEMETRY_DEBUG=1`. Set to `0`.
- [ ] **`:latest` image tags unpinned** — `services/pocketbase/Dockerfile:24`, `services/mcp-gateway/Dockerfile:2`, `services/test/Dockerfile:2`, `docker-compose.yml:144,203,317`. Pin to specific versions.

## Should Fix — High Priority

- [ ] **Unbounded tmux window creation** — `services/poco-agents/src/tools.rs` has no limit on spawned agents. DoS vector.
- [ ] **`stdout().flush().unwrap()` panic** — `services/proxy/src/shell.rs:92` panics if stdout closed.
- [ ] **SSH key sync silent failure** — `services/sandbox/entrypoint.sh` background key sync can fail silently.
- [ ] **Auth token refresh race condition** — `services/interface/src/index.ts` `refreshingAuth` flag not atomic.
- [ ] **Missing `whitelist_actions` collection** — Permission evaluator queries collection that doesn't exist in schema.
- [ ] **Container name leakage in logs API** — `services/pocketbase/internal/api/logs.go:63` reveals container names.
- [ ] **No Docker resource limits** — `docker-compose.yml` missing `mem_limit`, `cpus` on sandbox container.
- [ ] **SurrealDB license notice missing from README** — Required by `docs/knowledge-memory-design.md`.
- [ ] **Debug scripts mounted in production** — `docker-compose.yml:93` mounts `./scripts/debug:/workspace/debug`.
- [ ] **No graceful shutdown in poco-agents** — `services/poco-agents/src/main.rs` SIGINT handler has no timeout.

## Good to Go

- [x] Network isolation — 7 segmented networks
- [x] Docker socket proxy — properly locked down
- [x] PocketBase auth rules — correct (with exceptions above)
- [x] Documentation — README, SECURITY.md, CONTRIBUTING.md, architecture docs
- [x] `.gitignore` — excludes `.env`, secrets, data volumes
- [x] Deploy script — generates secure passwords, handles SSH keys
- [x] CI/CD workflows — functional
- [x] Interface reconnection — exponential backoff
- [x] Health checks — on critical services
- [x] CAO migration — completed
- [x] Hook signatures — standardized to `core.App`
- [x] Interface type safety — constants and interfaces added
