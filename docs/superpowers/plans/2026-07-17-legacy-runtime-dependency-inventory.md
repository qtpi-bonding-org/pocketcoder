# Legacy Runtime Dependency Inventory

Status: read-only inventory for the deferred
`2026-07-16-pocketbase-goose-legacy-prune.md` plan. It makes no schema or
runtime change. The inventory was captured on 2026-07-17 while the Goose c1
contract is still being closed out.

## Retain at hard cut

| Item | Current owner | Decision |
|---|---|---|
| `chats` identity, owner, title | PocketBase | Retain as product metadata. |
| `goose_sessions` | c1 | Retain: the only durable c1 runtime mapping. |
| `tool_permissions`, `mcp_servers` | Product configuration | Retain pending a separate c3 policy decision; they are not Goose turn state. |
| `goose_data` Docker volume | c2 | Retain and cover with backup/restore testing. |

## Delete after the c1 contract and Flutter cutover

| Legacy item | Current dependencies | Cut decision |
|---|---|---|
| `messages` collection and `chats.ai_engine_session_id` | schema `1740000100`; Flutter `communication_daos.dart`, chat cubit/state; cron creates assistant messages | Remove in a forward-only migration. Replace Flutter history with c1 replay first; separately decide whether cron remains a product feature rather than a chat writer. |
| `permissions` collection | schema `1740000100`, ACP additions `1748000100`; Go permission hooks/API/notifications; Flutter `hitl_daos.dart` | Remove its hooks, `/permission` API, notification producer, Flutter DAO and legacy tests. c1 approval is memory-only. |
| `acp_terminals` collection and `chats.acp_session_id` | schema `1748000100`; Flutter collection constants; dormant ACP executor/proxy code | Remove only after proving no legacy Interface caller remains. Active Goose c1/c2 advertises no terminal callbacks. |
| Interface/OpenCode command bus | `services/interface/`, `services/opencode/`, legacy PocketBase hooks and connection tests | Hard-delete at cut; no v1/v2 coexistence or history adapter is needed pre-launch. |

## Active code/test dependency map

- Schema sources: `services/pocketbase/pb_migrations/1740000100_consolidated_schema.go`
  defines `messages`, `permissions`, and `ai_engine_session_id`;
  `1748000100_acp_schema.go` adds `acp_session_id`, ACP fields, and
  `acp_terminals`. These applied migrations must remain untouched; cleanup is
  a new migration.
- Backend legacy paths: `internal/api/permission.go`, `internal/hooks/permissions.go`,
  `internal/hooks/notifications.go`, and `internal/hooks/timestamps.go`.
  `internal/hooks/cron.go` writes `messages`; it requires a product-level
  decision before the collection is removed.
- Configuration paths to retain: `internal/api/mcp.go`, `internal/hooks/mcp.go`,
  and `internal/hooks/tool_permissions.go` configure MCP/OpenCode-era policy.
  They are not turn-state cleanup targets, but OpenCode rendering becomes dead
  once the legacy runtime is removed and should be reviewed separately.
- Flutter legacy readers: `infrastructure/communication/communication_daos.dart`,
  `infrastructure/hitl/hitl_daos.dart`, `application/chat/chat_cubit.dart`,
  and `domain/models/collections.dart`.
- Frozen legacy tests: `tests/connection/*opencode*`, `tests/health/opencode.bats`,
  `tests/integration/agent/*`, `tests/integration/auth/permission-gating.bats`,
  `tests/integration/mcp/mcp-full-flow.bats`, and Interface unit tests under
  `services/interface/src/`. Do not repair these for Goose; replace coverage
  lives in `tests/agent-c1/`.

## Cut checklist

1. Freeze the c1 route/event/error contract and complete its Docker acceptance
   suite, including replay and restart recovery.
2. Cut Flutter to c1 AG-UI replay/run/approval routes.
3. Remove the listed legacy code and tests, then add one forward-only migration
   dropping obsolete fields, indices, and collections. Pre-launch, deleting any
   old records is acceptable.
4. Verify PocketBase and `goose_data` backup/restore, account/chat cascades,
   and that a Goose-backed chat writes no duplicate PocketBase turn state.
