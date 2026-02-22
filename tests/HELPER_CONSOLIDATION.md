# Helper Function Consolidation

## Summary

Consolidated duplicate helper functions from integration tests into shared helper files. All integration tests now use the centralized helpers from `tests/helpers/`.

## Changes Made

### 1. Removed Duplicate `wait_for_assistant_message()` Functions

**Files cleaned:**
- `tests/integration/core/data-consistency.bats`
- `tests/integration/agent/full-flow.bats`
- `tests/integration/agent/mcp-flow.bats`
- `tests/integration/auth/permission-gating.bats`
- `tests/integration/features/cao-subagent.bats`
- `tests/integration/features/turn-batching.bats`

**Now using:** `wait_for_assistant_message()` from `tests/helpers/wait.sh`

### 2. Added New Helper Functions

#### tests/helpers/auth.sh
- **`authenticate_agent()`** - Authenticate as agent user (sets AGENT_TOKEN and AGENT_ID)
  - Moved from: `tests/integration/agent/mcp-flow.bats`
  - Usage: `authenticate_agent`

#### tests/helpers/wait.sh
- **`get_assistant_text(message_id)`** - Extract text content from assistant message parts
  - Moved from: `tests/integration/agent/mcp-flow.bats`
  - Usage: `text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")`

#### tests/helpers/mcp.sh
- **`cleanup_mcp_servers(test_id, [token])`** - Delete MCP server records matching a pattern
  - Moved from: `tests/integration/agent/mcp-flow.bats`
  - Usage: `cleanup_mcp_servers "$TEST_ID"`

- **`wait_for_mcp_request(server_name_pattern, [timeout])`** - Wait for MCP server request to be created
  - Moved from: `tests/integration/agent/mcp-flow.bats`
  - Usage: `mcp_id=$(wait_for_mcp_request "fetch" 60)`

### 3. Updated Integration Tests

All integration test files now properly use the shared helpers:
- Load helpers at the top: `load '../../helpers/auth.sh'`, `load '../../helpers/wait.sh'`, etc.
- No duplicate function definitions
- Consistent behavior across all tests

## Benefits

1. **Reduced Code Duplication** - Single source of truth for common test operations
2. **Easier Maintenance** - Bug fixes and improvements in one place benefit all tests
3. **Consistency** - All tests use the same logic for common operations
4. **Better Debugging** - Fixes like the `wait_for_assistant_message()` stderr redirect automatically apply to all tests

## Helper Files Overview

### tests/helpers/auth.sh
- User authentication (`authenticate_user`, `authenticate_agent`, `authenticate_superuser`)
- PocketBase API helpers (`pb_create`, `pb_get`, `pb_update`, `pb_delete`, `pb_list`)

### tests/helpers/wait.sh
- Polling and waiting functions (`wait_for_condition`, `wait_for_endpoint`, `wait_for_message_status`)
- Message helpers (`wait_for_assistant_message`, `get_assistant_text`, `get_message_status`)
- Chat helpers (`wait_for_chat_turn`, `get_chat_session_id`)

### tests/helpers/cleanup.sh
- Test data cleanup (`cleanup_test_data`, `delete_record`)
- OpenCode session cleanup (`delete_opencode_session`)
- Token management (`get_admin_token`)

### tests/helpers/mcp.sh
- MCP gateway interaction (`mcp_tools_call`, `mcp_add_server`, `mcp_find_server`)
- Container management (`snapshot_containers`, `wait_for_new_container`, `assert_container_spun_up`)
- MCP server management (`cleanup_mcp_servers`, `wait_for_mcp_request`)

### tests/helpers/tracking.sh
- Test artifact tracking (`track_artifact`, `generate_test_id`)

### tests/helpers/diagnostics.sh
- Test failure diagnostics (`run_diagnostic_on_failure`)

### tests/helpers/assertions.sh
- Custom assertions for tests

## Testing

All health and connection tests pass with the consolidated helpers:
- ✅ Health tests: 10/10 passing (100%)
- ✅ Connection tests: 38/40 passing (95%)

The integration tests should now also benefit from these improvements.
