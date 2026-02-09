---
title: Proxy Reference
---

ExecRequest represents a shell command execution request.
It includes the command string, working directory, and metadata for audit trails.
PocketCoderDriver is the core execution engine for the Proxy.
It interacts with TMUX via a UNIX socket to run commands in isolated sessions.
Each session represents a sandboxed environment for a user or agent.
SSE (Server-Sent Events) Handler
Establishes a persistent connection for real-time updates.

# Query Parameters
* `sessionId` - Optional session ID. If not provided, a new UUID is generated.
Health Check Handler
Returns a simple JSON status to indicate the service is running.
Execution Handler
Accepts a command execution request and forwards it to the TMUX driver.
This endpoint assumes that authorization has already been handled by the caller (e.g., Relay).

# Payload
* `cmd` - The command string to execute.
* `cwd` - Optional working directory. Defaults to `/workspace`.
* `session_id` - Optional session ID for isolating the execution context.


**Lines of Code:** 411
