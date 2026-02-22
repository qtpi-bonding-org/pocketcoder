# Integration Test Findings

## Issue Summary

The integration tests for agent full flow are failing because the agent (Poco/OpenCode) is unable to execute shell commands successfully.

## Test Output Analysis

### Test: "Poco executes a command and returns real output"

**Expected behavior:**
- User sends: "Run this command and show me the output: echo pocketcoder_agent_test_test_1771505192_27545"
- Agent executes the command
- Agent returns the output containing the unique string

**Actual behavior:**
- Agent responds with: "Still failing. The infrastructure is unstable. User, please try again later. I am still secure."
- 3 assistant messages created (agent retried multiple times)
- 2 permissions requested and auto-approved
- No command output in response

## Root Cause

The agent is attempting to execute shell commands but the execution infrastructure is failing. Possible causes:

1. **Shell Bridge Issue**: The shell bridge (`pocketcoder-shell`) may not be functioning correctly
2. **Sandbox Connectivity**: OpenCode may not be able to communicate with the sandbox
3. **Tmux Session Issue**: The tmux session may not be set up correctly
4. **Permission System**: Even though permissions are auto-approved, there may be a timing issue or the approval isn't being communicated back to OpenCode properly

## Evidence

From test output:
```
ALL MESSAGES IN CHAT:
  [user] qttnkwnx0kcnuat - status:  - parts: 1 items
  [assistant] tp18em141q03t5q - status: completed - parts: 3 items
  [assistant] qvwf8zckh5qulqz - status: completed - parts: 4 items
  [assistant] 59fh9yqakxlnwa8 - status: completed - parts: 3 items
```

Multiple assistant messages indicate retries. The agent is aware something is failing and is reporting it to the user.

## Test Infrastructure Improvements Made

1. ✅ Added `wait_for_assistant_message` to wait for message completion (not just creation)
2. ✅ Added auto-approval of pending permissions during test execution
3. ✅ Added comprehensive debugging output showing all messages and their content
4. ✅ Fixed message sorting to get latest message

## Next Steps

Need to investigate the actual execution infrastructure:

1. Check if shell bridge is running and accessible from OpenCode container
2. Verify tmux session exists and is accessible
3. Check OpenCode logs for shell execution errors
4. Verify sandbox container is healthy and responding
5. Test shell bridge directly (bypass OpenCode) to isolate the issue

## Commands to Debug

```bash
# Check if shell bridge is accessible from OpenCode
docker exec pocketcoder-opencode ls -la /shell_bridge/pocketcoder-shell

# Check tmux session in sandbox
docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-sessions

# Check OpenCode logs for errors
docker logs pocketcoder-opencode --tail 50

# Check sandbox logs
docker logs pocketcoder-sandbox --tail 50

# Test shell bridge directly
docker exec pocketcoder-sandbox /shell_bridge/pocketcoder-shell --help
```
