# Test Fix Plan

**162 total tests | 108 pass | 54 fail**

Tests that pass: health (mostly), pb-to-sandbox network isolation, auth/permissions, artifacts, turn-batching, MCP full flow (request/approval/config lifecycle), MCP request API, auth hardening, MCP servers collection.

Tests that were expected to fail (MCP + Agent) still fail, but many previously-passing tests are now broken too. Below are the failures grouped by root cause.

---

## Group 1: `/exec` endpoint returns wrong response format (8 tests)

**Root cause:** The sandbox `/exec` endpoint no longer returns `stdout`/`exit_code` fields in the expected JSON shape. Commands return `exit_code: 1` for everything (even `true`), and `stdout` is empty/missing.

**Affected tests:**
- `#31` OpenCode→Sandbox: /exec returns valid response format
- `#32` OpenCode→Sandbox: Command executes in tmux pane
- `#33` OpenCode→Sandbox: Non-zero exit code is captured (expects 42, gets 1)
- `#35` OpenCode→Sandbox: Command output contains expected content
- `#36` OpenCode→Sandbox: Working directory is respected
- `#54` Sandbox→OpenCode: Success response format
- `#56` Sandbox→OpenCode: Round-trip completes within 30 seconds
- `#57` Sandbox→OpenCode: Non-zero exit code captured (expects 42, gets 1)
- `#58` Sandbox→OpenCode: Multi-line output captured
- `#59` Sandbox→OpenCode: Empty output handled
- `#60` Sandbox→OpenCode: Command timeout respects limit

**File:** `tests/connection/opencode-to-sandbox.bats`, `tests/connection/sandbox-to-opencode.bats`

**Fix approach:**
1. Check the sandbox proxy (`proxy/src/main.rs`) for changes to the `/exec` endpoint response format
2. Check if the shell bridge path changed (test #29 says `/shell_bridge/pocketcoder-shell` not found)
3. Likely the Rust proxy response JSON shape changed — update tests to match new format, or fix the proxy

---

## Group 2: Message status is `delivered` instead of `pending` on create (6 tests)

**Root cause:** The Relay hook now processes messages so fast that by the time the test reads back the record, status has already transitioned from `pending` → `delivered`. Tests expect to catch the initial `pending` state.

**Affected tests:**
- `#39` PB→OpenCode: Create user message triggers Relay hook (status = delivered, expected pending)
- `#43` PB→OpenCode: Message status transitions pending → sending → delivered
- `#83` Data Consistency: Message status transitions are correct
- `#88` Full Flow: User sends message (role: user, user_message_status: pending)
- `#89` Full Flow: Relay intercepts via OnRecordAfterCreateSuccess hook

**File:** `tests/connection/pb-to-opencode.bats`, `tests/integration/core/data-consistency.bats`, `tests/integration/core/full-flow.bats`

**Fix approach:**
1. Accept that `delivered` is a valid initial-read state (the relay is just fast)
2. Change assertions to accept `pending` OR `delivered` as valid initial status
3. For transition tests, verify final state is `delivered` rather than trying to catch intermediate states

---

## Group 3: SSE heartbeat / event stream not working (3 tests)

**Root cause:** SSE connection to PocketBase doesn't receive `server.heartbeat` or `message.updated` events within the test timeout window.

**Affected tests:**
- `#22` OpenCode→PB: SSE connection receives server.heartbeat events
- `#27` OpenCode→PB: SSE connection stability for 10 seconds (also has a bash integer comparison bug: `[: 0\n0: integer expected`)
- `#23` OpenCode→PB: SSE connection receives message.updated events

**File:** `tests/connection/opencode-to-pb.bats`

**Fix approach:**
1. Fix the integer parsing bug in test #27 (heartbeat_count has a newline or extra data)
2. Increase SSE listen timeout — heartbeat interval may have changed
3. Verify PocketBase SSE endpoint is actually emitting heartbeats (check PB config/version)

---

## Group 4: Assistant message `parts` / `preview` never populated (9 tests)

**Root cause:** After sending a user message and waiting for OpenCode to process it, the assistant response never gets `parts` populated, and chat `preview`/`last_active` never update. This suggests OpenCode is not generating responses (likely an LLM API key or config issue in the test environment, or the relay→OpenCode→LLM pipeline is broken).

**Affected tests:**
- `#25` OpenCode→PB: Message fields populated from SSE events
- `#26` OpenCode→PB: Chat last_active and preview fields updated
- `#82` Data Consistency: Data relationships are correct
- `#85` Data Consistency: Message parts are preserved through flow
- `#92` Full Flow: OpenCode processes message
- `#96` Full Flow: Synchronous response returned to shell bridge
- `#99` Full Flow: Chat updated with last_active and preview
- `#100` Full Flow: Complete end-to-end test

**File:** `tests/connection/opencode-to-pb.bats`, `tests/integration/core/data-consistency.bats`, `tests/integration/core/full-flow.bats`

**Fix approach:**
1. Check if OpenCode has a valid LLM API key in the test environment (`.env` / docker-compose)
2. Check OpenCode container logs for errors when processing messages
3. If this is an environment issue (no API key), these tests need to be marked as requiring an LLM backend, or use a mock
4. If the relay→OpenCode handoff changed, trace the flow in relay.go

---

## Group 5: OpenCode SSHD not listening (1 test)

**Root cause:** SSH daemon on port 2222 inside the OpenCode container isn't running.

**Affected test:**
- `#3` OpenCode sshd is listening on port 2222

**File:** `tests/health/opencode.bats`

**Fix approach:**
1. Check `docker/opencode_entrypoint.sh` — is sshd being started?
2. Check if the Dockerfile changes broke the SSH setup
3. Verify inside the container: `docker exec pocketcoder-opencode ss -tlnp | grep 2222`

---

## Group 6: Shell bridge path changed (2 tests)

**Root cause:** Tests look for shell bridge at `/shell_bridge/pocketcoder-shell` but it's not found. The Dockerfile copies it to `/app/shell_bridge/` but the test may be running from a different context.

**Affected tests:**
- `#29` OpenCode→Sandbox: Shell bridge binary exists and is executable
- `#93` Full Flow: Command execution via shell bridge → POST /exec

**File:** `tests/connection/opencode-to-sandbox.bats`, `tests/integration/core/full-flow.bats`

**Fix approach:**
1. Verify the actual path inside the sandbox container
2. Update `shell_bridge_path` in tests to match the actual location (`/app/shell_bridge/pocketcoder-shell`)

---

## Group 7: Tmux socket missing in sandbox (1 test)

**Root cause:** Test expects tmux socket at a specific path inside the sandbox but it doesn't exist.

**Affected test:**
- `#95` Full Flow: Tmux execution with sentinel and output capture

**File:** `tests/integration/core/full-flow.bats`

**Fix approach:**
1. Check sandbox entrypoint — is tmux being started with the expected socket path?
2. Verify `tmux -S <socket> list-sessions` inside the sandbox container

---

## Group 8: CAO API response format / curl parsing (1 test)

**Root cause:** `curl -w '%{http_code}'` appends HTTP code to response body. Test expects just `200` on last line but gets `{"status":"ok",...}200`.

**Affected test:**
- `#34` OpenCode→Sandbox: CAO API session resolution

**File:** `tests/connection/opencode-to-sandbox.bats`

**Fix approach:**
1. Use `curl -o /dev/null -w '%{http_code}'` to separate body from status code, or
2. Use `-s -o response.json -w '%{http_code}'` pattern

---

## Group 9: Cleanup / delete not working (5 tests)

**Root cause:** Deleting chat/message/permission records returns HTTP 200 instead of 404 (records still exist after delete), or permission creation fails.

**Affected tests:**
- `#45` PB→OpenCode: Cleanup removes test chats and messages
- `#127` Cleanup: Chat records are cleaned up
- `#128` Cleanup: Message records are cleaned up
- `#129` Cleanup: Permission records are cleaned up
- `#132` Cleanup: Cleanup with dry-run mode
- `#134` Cleanup: Tracked artifacts are cleaned up

**File:** `tests/connection/pb-to-opencode.bats`, `tests/integration/features/cleanup.bats`

**Fix approach:**
1. Check if PocketBase delete API changed (soft delete vs hard delete?)
2. Check if the cleanup helper (`tests/helpers/cleanup.sh`) is using the right API endpoints
3. Permission creation returning `null` ID suggests the permissions collection schema changed

---

## Group 10: CAO Subagent — relay doesn't create subagent records (14 tests)

**Root cause:** The relay is not detecting `_pocketcoder_sys_event` in assistant messages and not creating subagent records. Also, assistant messages have no `parts` (same as Group 4 — OpenCode not generating responses).

**Affected tests:**
- `#111` through `#126` (CAO Subagent suite, minus #112, #120, #125 which pass)

**File:** `tests/integration/features/cao-subagent.bats`

**Fix approach:**
1. This is downstream of Group 4 — if OpenCode doesn't respond, no subagent records get created
2. Fix Group 4 first, then re-run these
3. Also check `backend/pkg/relay/relay.go` for changes to subagent detection logic

---

## Group 11: Agent tests — empty responses from Poco (5 tests)

**Root cause:** Poco (the AI agent) returns empty responses. Same root cause as Group 4 — the LLM backend isn't responding.

**Affected tests:**
- `#61` through `#65` (Agent Full Flow suite)

**File:** `tests/integration/agent/full-flow.bats`

**Fix approach:** Fix Group 4 first. These depend on a working LLM backend.

---

## Group 12: MCP Agent Flow — Poco doesn't engage with MCP workflow (3 tests)

**Root cause:** Poco doesn't respond or doesn't engage with MCP workflow. Empty responses.

**Affected tests:**
- `#66` Agent MCP Flow: Poco requests MCP server
- `#67` Agent MCP Flow: Full lifecycle
- `#68` Agent MCP Flow: Poco checks what's installed before requesting

**File:** `tests/integration/agent/mcp-flow.bats`

**Fix approach:** These were expected to fail (new MCP feature). Fix after Groups 4/11.

---

## Group 13: Dynamic MCP container spin-up (2 tests)

**Root cause:** `docker mcp` gateway adds the tool successfully but doesn't spin up a new container. The gateway logs show `No such image: mcp/<name>:latest` errors.

**Affected tests:**
- `#70` Agent MCP Flow: Approved MCP server spins up a new Docker container
- `#153` MCP Infra: MCP Gateway spins up MCP server container via Dynamic MCP

**File:** `tests/integration/agent/mcp-flow.bats`, `tests/integration/mcp/mcp-full-flow.bats`

**Fix approach:** These were expected to fail (new MCP feature). The gateway needs Docker-in-Docker image pull capability or pre-pulled images.

---

## Group 14: Full Flow auth (1 test)

**Root cause:** `USER_TOKEN` not set after authentication in the full-flow setup.

**Affected test:**
- `#86` Full Flow: User authenticates with PocketBase

**File:** `tests/integration/core/full-flow.bats`

**Fix approach:**
1. Check if the `setup_file` or `setup` function properly authenticates
2. Likely a test ordering issue or the auth helper changed

---

## Recommended Fix Order

| Priority | Group | Tests | Effort | Impact |
|----------|-------|-------|--------|--------|
| 1 | G8: curl parsing | 1 | 5 min | Quick win |
| 2 | G2: pending→delivered race | 6 | 15 min | Fixes 6 tests |
| 3 | G3: SSE heartbeat + integer bug | 3 | 15 min | Fixes 3 tests |
| 4 | G6: Shell bridge path | 2 | 10 min | Fixes 2 tests |
| 5 | G5: SSHD not listening | 1 | 15 min | Fixes 1 test |
| 6 | G1: /exec response format | 11 | 30 min | Fixes 11 tests, unblocks G7 |
| 7 | G7: Tmux socket | 1 | 10 min | Fixes 1 test |
| 8 | G9: Cleanup/delete | 6 | 20 min | Fixes 6 tests |
| 9 | G14: Full flow auth | 1 | 10 min | Fixes 1 test |
| 10 | G4: No assistant response | 9 | 30 min | Investigate env/LLM config |
| 11 | G10: CAO subagent (blocked by G4) | 14 | 15 min | Re-run after G4 |
| 12 | G11: Agent empty responses (blocked by G4) | 5 | 0 min | Re-run after G4 |
| 13 | G12: MCP agent flow (expected fail) | 3 | — | New feature, expected |
| 14 | G13: Dynamic MCP containers (expected fail) | 2 | — | New feature, expected |
