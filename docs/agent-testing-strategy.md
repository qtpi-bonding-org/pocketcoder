# Agent runtime testing strategy

The active runtime is c1 PocketBase + c2 Goose. Goose owns conversation and
execution state; c1 owns authenticated API access, the durable chat-to-session
mapping, AG-UI translation, and process-local pending approvals.

## Test layers

1. **Fast Go tests (`services/pocketbase`)** run on every change to c1. They
   cover ACP transport envelopes, AG-UI translation, ownership-facing
   coordinator rules, offered-option validation, cancellation, concurrent-run
   rejection, disconnect cancellation, and restart semantics.
2. **Docker acceptance** runs the `agent` Compose profile with real Goose. It
   creates a temporary authenticated user and chat, then verifies AG-UI
   terminal events for prompt, allow, deny, cancel while pending, reconnect
   through `session/load`, c1 restart, and c2 restart.
3. **Flutter contract tests** begin only when Flutter work resumes. They use
   recorded AG-UI SSE fixtures from the Docker acceptance run; Flutter does
   not need a real model provider for its normal test suite.

## Existing BATS suite

Do not delete it wholesale. It contains useful PocketBase/auth/feature
coverage, but much of its agent topology asserts the retired
`interface -> OpenCode -> sandbox` path.

Keep and re-evaluate independently:

- `tests/integration/auth/**`
- PocketBase-only feature tests once their assumptions are checked
- sandbox and MCP tests while those services remain supported separately

Freeze as **legacy topology tests**; do not repair them for c1/c2:

- `tests/connection/interface-health.bats`
- `tests/connection/*opencode*` and `tests/connection/*sandbox-to-opencode*`
- `tests/integration/agent/**`
- c3 gateway end-to-end tests while gateway attachment remains disabled
- `services/interface/src/*.test.ts` that assert Interface/OpenCode pumps

The replacement suite now lives in `tests/agent-c1/`. Its Compose override and
runner start only c1/c2 plus a disposable BATS container; see
`tests/agent-c1/README.md`. Remove legacy tests only with the corresponding
Interface/OpenCode deletion migration, not before.
