# PocketCoder — Current State (March 2026)

What's actually built and tested today, organized by layer.

---

## Infrastructure (Docker Compose Stack)

All containers run, pass health checks, and communicate correctly.

| Container | Purpose | Status | Health Check |
|-----------|---------|--------|-------------|
| `pocketcoder-pocketbase` | State hub, auth, API, Go hooks | Healthy | `curl /api/health` |
| `pocketcoder-opencode` | Reasoning engine (OpenCode) | Healthy | `curl /health` |
| `pocketcoder-sandbox` | Isolated execution (tmux + poco-agents) | Healthy | `curl /health` (shell proxy + poco-agents) |
| `pocketcoder-mcp-gateway` | MCP server gateway | Healthy | `curl /health` |
| `pocketcoder-interface` | PB <-> OpenCode bridge | Healthy | `wget /healthz` |
| `pocketcoder-docker-proxy-write` | Docker socket proxy (restart ops) | Running | - |
| `pocketcoder-sqlpage` | SQLite observability dashboard | Running | - |
| `pocketcoder-ntfy` | Push notifications (optional profile) | Available | `--profile foss` |

**Networks**: 6 isolated Docker networks enforce trust boundaries. OpenCode has no Docker socket. Sandbox has no PocketBase access. MCP gateway has read-only Docker.

**Volumes**: `pb_data`, `opencode_workspace`, `opencode_data`, `llm_keys` (shared), `shell_bridge`

---

## PocketBase Collections

| Collection | Purpose | Tested |
|------------|---------|--------|
| `users` | Auth (admin, agent, guest roles) | Yes |
| `chats` | Chat sessions (1:1 with OpenCode sessions) | Yes |
| `messages` | Chat messages with streaming parts | Yes |
| `permissions` | Tool execution approval/denial | Yes |
| `mcp_servers` | MCP server registry | Yes |
| `llm_keys` | API keys per provider per user | Yes (19 BATS tests) |
| `llm_config` | Active model selection (global + per-chat) | Yes (19 BATS tests) |
| `llm_providers` | Provider catalog (synced from OpenCode) | Yes (19 BATS tests) |
| `subagents` | poco-agents subagent registry | Yes |
| `whitelist_targets` | Allowed file/directory patterns | Yes |
| `whitelist_actions` | Allowed action patterns | Yes |
| `healthchecks` | System component health records | Yes |
| `ai_agents` | Agent profile registry | Yes |
| `ai_models` | Model registry | Yes |
| `ai_prompts` | System prompt registry | Yes |
| `ssh_keys` | SSH public keys for terminal access | Yes |
| `devices` | Push notification device registration | Yes |
| `proposals` | SOP proposals | Schema only |
| `sops` | Standard operating procedures | Schema only |
| `questions` | Agent questions for user | Yes |

---

## Go Hooks (PocketBase)

| Hook | Trigger | Action | Tested |
|------|---------|--------|--------|
| `llm.go` | `llm_keys` create/update/delete | Writes `llm.env` to OpenCode + shared volume, restarts OpenCode | Yes (BATS) |
| `mcp.go` | `mcp_servers` create/update/delete | Writes `docker-mcp.yaml` + `mcp.env`, restarts MCP gateway | Yes (BATS) |
| `agents.go` | Agent config changes | Bundles agent config | Yes |
| `permissions.go` | Permission events | Permission lifecycle hooks | Yes |
| `notifications.go` | Various events | ntfy push notifications | Yes |
| `sops.go` | SOP events | SOP lifecycle | Schema only |
| `timestamps.go` | Record events | Auto-timestamp management | Yes |

---

## Interface Service (TypeScript/Bun)

| Feature | Direction | Tested |
|---------|-----------|--------|
| Event pump (message streaming) | OpenCode → PocketBase | Yes |
| Event pump (message completion) | OpenCode → PocketBase | Yes |
| Event pump (permission requests) | OpenCode → PocketBase | Yes |
| Command pump (user messages) | PocketBase → OpenCode | Yes |
| Command pump (permission replies) | PocketBase → OpenCode | Yes |
| Command pump (model switch) | PocketBase → OpenCode | Yes (BATS) |
| Provider sync | OpenCode → PocketBase | Yes (BATS) |
| Session cache | Internal | Yes |
| Auth token refresh | Internal | Yes |
| Health endpoint | `/healthz` | Yes |
| Graceful shutdown | Internal | Yes |

---

## Flutter App

### Fully Working

| Screen / Feature | Notes |
|-----------------|-------|
| Boot screen | Animated POCO, health check, connection verification |
| Onboarding/login | PocketBase URL input, email/password, token refresh |
| Home (chat list) | List all chats sorted by recent, create new, tap to resume |
| Chat | Send messages, receive streaming responses, message parts (text, reasoning, tool, file, agent, step) |
| Permission prompts | Real-time watch, approve/deny buttons, decision flows back to agent |
| Question prompts | Agent questions appear, text answer or reject |
| MCP management | Pending vs active servers, approve/deny with config schema |
| Whitelist rules | Two tabs (action rules + targets), full CRUD, active toggle |
| System checks | Health status of all components |
| Agent observability | Container registry with real-time stats |
| SSH terminal | Full xterm emulation, auto SSH key generation, tmux session attachment |
| Artifact viewer | Single file reader from `/workspace` (nav button currently commented out) |
| ntfy push notifications | UnifiedPush integration, device registration with PocketBase |
| Cloud deploy screens | Linode OAuth, config input, deployment progress (execution not wired) |

### Partially Working

| Feature | What's done | What's missing |
|---------|------------|----------------|
| Agent registry | View agents, names, descriptions, prompts | Model picker dialog, prompt selector |
| Settings hub | Menu with 8 sub-systems | Theme toggle UI |
| SOP management | UI structure | Backend integration (hardcoded demo data) |
| Billing/premium | FOSS version always returns premium | Real IAP integration |

### Not Yet Built

| Feature | Backend ready? | Notes |
|---------|---------------|-------|
| LLM key management screen | Yes | Need CRUD screen for `llm_keys` collection |
| Provider/model browser | Yes | Need list screen reading `llm_providers` |
| Model switcher (global + per-chat) | Yes | Need UI writing to `llm_config` |
| Diff summary in chat | API exists in OpenCode | Need interface sync + Flutter widget |
| Notification deep linking | ntfy works | Need tap → navigate to relevant chat/permission |

---

## Integration Tests (BATS)

| Test Suite | Tests | Status |
|------------|-------|--------|
| `llm-management.bats` | 23 | All passing |
| MCP management tests | Existing | Passing |

Tests run via Docker test container: `docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test`

---

## What's Verified End-to-End

These flows have been tested from Flutter through to the backend and back:

1. **Chat flow**: Flutter → create message in PB → interface picks up → sends to OpenCode → streaming response → parts sync back to PB → Flutter renders
2. **Permission flow**: OpenCode needs approval → interface creates PB record → Flutter shows prompt → user taps approve → interface sends to OpenCode → agent continues
3. **MCP approval**: Flutter approves server → PB record update → Go hook writes config → MCP gateway restart
4. **API key save**: PB record create → Go hook writes `llm.env` to both volumes → OpenCode restart → sandbox can read keys
5. **Model switch**: PB record create → interface subscription → `oc.config.update()` or `oc.session.command()`
6. **Provider sync**: Interface calls `oc.provider.list()` → upserts into `llm_providers` → Flutter can read

## What Hasn't Been Tested E2E

- Notification flow: permission request → ntfy push → phone notification → tap → app opens to correct screen
- Multi-user: two PocketBase users chatting simultaneously with separate sessions
- Container crash recovery: OpenCode dies → restarts → interface reconnects → chat resumes
- Long-running agent tasks: agent works for 30+ minutes, user checks in periodically from phone
