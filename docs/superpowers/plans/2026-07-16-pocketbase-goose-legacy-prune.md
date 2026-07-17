# PocketBase Legacy Runtime Prune Plan

> Status (2026-07-16): deferred. Flutter integration is intentionally not yet
> an acceptance gate, and no table, field, route, or legacy test is to be
> removed while the c1 backend contract is still being closed out. The only
> authorized near-term work in this plan is a read-only dependency inventory.
> The current inventory is published in
> `2026-07-17-legacy-runtime-dependency-inventory.md`.
>
> **Pre-launch simplification (2026-07-17): there are no production users and no
> live user data.** The retention/rollback ceremony below is scaffolding for a
> running product; most of it can collapse. Concretely, while pre-launch:
> - **Hard-cut, not coexist.** No `AGENT_RUNTIME=v1/v2` dual runtime and no
>   read-only legacy history adapter are required. Once v2 passes its acceptance
>   suite and Flutter has cut over, delete the legacy runtime outright.
> - **No retention window / rollback window.** "Observe production traffic
>   through the retention period" and "wait for the rollback window to elapse"
>   are moot with zero users; delete legacy state as soon as v2 is proven.
> - **Chat-type immutability is unnecessary.** Precondition #3 exists to protect
>   legacy chats during coexistence. With nothing to protect, you may drop the
>   legacy `messages`/`permissions`/`acp_terminals` data instead of preserving
>   it. If any legacy chats exist at cut time, deleting them is acceptable.
> - **Still keep forward-only migrations** (don't edit applied ones) purely for
>   clean local/dev history — that discipline is cheap and unrelated to users.
>
> Re-introduce the full ceremony below only once real users exist. The pieces
> that survive pre-launch regardless are: `goose_sessions` as the sole c1
> runtime state, `tool_permissions`/`mcp_servers` as configuration (not runtime
> duplicates), and tested backup/restore of the `goose_data` volume.

**Goal:** after the c1 Go runtime and Flutter cutover are proven, remove PocketBase state and code that duplicate Goose-owned conversation/runtime state. This is a separate, delayed, forward-only migration—not part of c1 implementation.

## Retain

- Users, PocketBase auth, chat ownership/title metadata, and the new `goose_sessions` mapping.
- Product configuration that remains independently authoritative: account settings, MCP server catalog approval/configuration, provider configuration, SSH keys, scheduled jobs, and any explicitly retained audit decision.
- Legacy chat data only for a documented read-only retention window.

## Candidate removal scope

Audit each dependency before removal; likely targets are:

| Legacy state/code | New runtime decision |
|---|---|
| `messages` writes and live message command path | Goose owns message history and replay. Retire for Goose-backed chats. |
| `permissions` per-turn records, approval hooks, notifications, and realtime polling | Goose owns the decision/history; c1 keeps only an in-memory pending callback. |
| `acp_terminals` and terminal persistence | The active c1/c2 path advertises no terminal callbacks; Goose's built-in shell runs in c2. Treat c1 executor/proxy code as dormant legacy code, and retire it only after the inventory confirms no remaining legacy caller. |
| `chats.acp_session_id` / `ai_engine_session_id` and related indices | Replace with the unique `goose_sessions` relation. |
| interface/OpenCode/sandbox-specific hooks and API routes | Remove only after v2 is the sole runtime. |

`tool_permissions` and `mcp_servers` are not automatically removable: they configure product policy/catalog behavior and need a separate decision after c3 is re-enabled.

## Preconditions

1. c1 implementation plan is complete and v2 has passed its restart/replay, permission, cancellation, and rollback acceptance suite.
2. Flutter has shipped the c1 AG-UI path and legacy chats remain readable through the documented retention window.
3. Every active/new chat is classified immutable as legacy or Goose-backed; no runtime switches an existing chat between types.
4. Backup/restore is tested for PocketBase and Goose volumes, and the rollback window has elapsed.
5. The gateway/Cognee attachment blocker is resolved separately or remains explicitly disabled; cleanup must not assume it works.

## Delivery steps

1. **Inventory and classify**
   - Trace every query, hook, route, Flutter repository, test, and notification path that reads/writes `messages`, `permissions`, `acp_terminals`, old session-ID fields, or interface/OpenCode state.
   - Label each as legacy display, active command path, configuration, or removable dead code. Publish the list before schema changes.

2. **Stop new writes first**
   - Add assertions/metrics that v2 requests never create legacy message, permission, or terminal records.
   - Remove v2 callers, then observe production/test traffic through the retention period. Do not delete fields or tables yet.

3. **Remove legacy runtime paths**
   - Delete the old interface/OpenCode/sandbox command flow and its PocketBase hooks, API routes, realtime subscriptions, push-notification producers, and integration tests.
   - Keep a read-only legacy history adapter only until the retention date; make it impossible to append to an old chat.

4. **Forward-only schema cleanup**
   - Add a new migration—never edit old applied migrations—to remove unused fields/indexes and then collections only after dependency checks pass.
   - Migrate any deliberately retained audit/reporting requirement into an explicit, minimal product model before deleting `permissions`; do not retain a hidden duplicate ledger by default.
   - Update access rules, timestamp hooks, seeds, backups, and admin UI references in the same release.

5. **Acceptance and deletion**
   - Verify a Goose-backed chat has no PocketBase runtime duplicates; a legacy chat is either read-only or expired by policy.
   - Test backup restore, downgrade/rollback behavior for the supported window, and account/chat deletion cascades.
   - Delete obsolete collections only after the verification release, not alongside initial c1 rollout.

## Done when

PocketBase contains identity, chat metadata, and one Goose-session mapping for v2 chats—no durable duplicated conversation, tool, approval, or terminal state—and no active code path can recreate it.
