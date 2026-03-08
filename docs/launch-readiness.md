# Launch Readiness Checklist

Generated: 2026-03-08

## Blocking — Must Fix Before Launch

### Security

- [x] **SurrealDB hardcoded credentials** — Now uses `${SURREAL_USER}/${SURREAL_PASSWORD}` env vars
- [x] **Sandbox SSH hardcoded password** — Random password generated, immediately discarded
- [x] **Sandbox SSH password auth enabled** — Changed to `PasswordAuthentication no`
- [x] **Sandbox SSH root login enabled** — Changed to `PermitRootLogin no`
- [x] **Secret files written world-readable (0644)** — Changed to `0600`
- [x] **Healthchecks collection publicly writable** — Restricted to agent/admin
- [x] **SOPs collection publicly writable** — Restricted to admin-only
- [x] **Artifact API missing auth middleware** — Added `.Bind(apis.RequireAuth())`
- [x] **Shell command injection in proxy** — Added cwd path validation

### Stability

- [x] **`expect()` panics in poco-agents** — Returns MCP error instead
- [x] **Unbounded session map in proxy** — CleanupStream removes sessions on disconnect
- [x] **No graceful shutdown in proxy** — Added SIGTERM/SIGINT handler

### Configuration

- [x] **Debug logging in production** — Changed to `--log-level INFO`
- [x] **SQLPage development mode** — Changed to `production`
- [x] **MCP gateway debug telemetry** — Set to `0`
- [x] **`:latest` image tags unpinned** — All pinned to specific versions

## Should Fix — High Priority

- [x] **Unbounded tmux window creation** — Max 20 concurrent agents enforced
- [x] **`stdout().flush().unwrap()` panic** — Changed to `.ok()`
- [x] **SSH key sync silent failure** — Warning logged on failure
- [x] **Auth token refresh race condition** — Promise-based lock pattern
- [x] **Dead `whitelist_actions` code** — Removed from permission evaluator
- [x] **Container name leakage in logs API** — Generic error message
- [x] **No Docker resource limits** — Not needed (user decision: unlimited)
- [x] **SurrealDB license notice missing from README** — Added
- [x] **Debug scripts mounted in production** — Mount removed
- [x] **No graceful shutdown in poco-agents** — 10s timeout added
- [x] **SSH keys endpoint missing role check** — Restricted to agent/admin
- [x] **Push notification endpoint missing role check** — Restricted to agent/admin

## Good to Go

- [x] Network isolation — 7 segmented networks
- [x] Docker socket proxy — properly locked down
- [x] PocketBase auth rules — all endpoints audited and secured
- [x] Documentation — README, SECURITY.md, CONTRIBUTING.md, architecture docs
- [x] `.gitignore` — excludes `.env`, secrets, data volumes
- [x] Deploy script — generates secure passwords, handles SSH keys
- [x] CI/CD workflows — functional
- [x] Interface reconnection — exponential backoff
- [x] Health checks — on critical services
- [x] CAO migration — completed
- [x] Hook signatures — standardized to `core.App`
- [x] Interface type safety — constants and interfaces added
- [x] Permission system — tool permissions + runtime firewall working
