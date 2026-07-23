# Tool-Permissions UI — Design

## Problem

`tool_permissions` rows already control what Goose is allowed to do —
delivered live over ACP by `deliverToolPermissions`
(`services/pocketbase/internal/hooks/goose_config.go`), built by the MCP
governance UI plan. But nothing lets a human view or edit those rows short
of SSH-ing into PocketBase's Admin UI directly. The Settings screen already
has a "TOOL PERMISSIONS" button (`settings_screen.dart:24`) that pushes
`AppRoutes.configureToolPermissions` — but no `GoRoute` is registered for
that path, so the button currently does nothing. There's also partial dead
scaffolding from an earlier, abandoned attempt: a `ToolPermission` Freezed
model, a duplicate `ToolPermissionsException` class definition, route
constants — but no DAO, repository, cubit, or screen.

This spec builds the missing UI on top of the schema and delivery mechanism
that already exist, fixes the dead route, and reconciles the duplicate
exception class. No PocketBase schema or backend delivery logic changes.

## Prior research this spec builds on

- `docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md` (Component
  4) — built `_goose/unstable/tools/permissions/set` live delivery,
  `gooseconfig.RenderToolPermissions`, and `deliverToolPermissions`. This
  spec is the "Tool-permissions UI" that spec's Out-of-scope section
  explicitly deferred: *"Any UI or schema change to `tool_permissions`... —
  editing screens, per-tool approval flows — stays separate."*
- `docs/superpowers/specs/2026-05-07-pocketbase-config-layer-schema-design.md`
  — original schema design for `tool_permissions` (`tool`, `pattern`,
  `action`, `active`, `poco_config`/`sandbox_config`).
- `spikes/goose-acp-config-surface/ownership-map.md:89` — the "tool
  permissions are intentionally deployment-wide for now" decision this spec
  follows for scope (see Component 1).
- Direct verification against Goose's real ACP schema
  (`.independent_repos/goose_reference/crates/goose/acp-schema.json`) and
  matching engine (`crates/goose/src/config/permission.rs:147-166`):
  `ToolPermissionEntry` is `{toolName: string, permission: enum}` — no
  pattern/glob field exists, and matching is exact string equality only.
  `spikes/goose-acp-config-surface/README.md:36` independently confirms the
  same: *"exact-name match only (no glob/prefix)"*. `tool_permissions.pattern`
  was designed (2026-05-07, before this was confirmed) for glob/argument
  matching within a tool call — a capability Goose's ACP surface never
  shipped. `RenderToolPermissions` already drops any row where
  `pattern != "*"` (`gooseconfig/permissions.go:64-66`), so `pattern` is
  permanently dead weight for every row this UI will ever create.

## Architecture

```
Flutter (ToolPermissionsScreen)
   │  PocketBase write to tool_permissions (poco_config always empty)
   ▼
tool_permissions collection (existing, unchanged schema)
   │  RegisterGooseConfigHooks's CRUD hooks (existing, unchanged)
   ▼
deliverToolPermissions → AdminConn → _goose/unstable/tools/permissions/set
   ▼
goose (c2) enforces allow/ask/deny per tool call
```

This spec adds only the top box. Everything from `tool_permissions` down is
already built and unchanged.

### Component 1 — Global-only scope (no per-`poco_config` editing)

`poco_config` is documented as *"intentionally deployment-wide for now"*
(`ownership-map.md:89`), and `deliverToolPermissions`'s query already unions
global rows (`poco_config` empty) with the current default `poco_config`'s
rows — there is no existing concept of a user picking *which* `poco_config`
to scope a rule to. Building a per-config picker would be UI ahead of
backend reality: only the default config's scoped rows are ever delivered.

This UI manages exactly the deployment-wide rows: every row it creates has
`poco_config` unset (empty string) and `sandbox_config` unset. The DAO reads
apply the same filter, so pre-existing per-`poco_config` rows (e.g. the seed
data's `bash`/`edit`/`skill` overrides scoped to a specific poco_config) are
invisible to this screen — they still exist, still get delivered by
`activeToolPermissionRows`, just aren't editable here. If per-config editing
is wanted later, it's a new, separate increment once the backend actually
supports choosing which `poco_config` a session runs, not a gap this spec
needs to close.

### Component 2 — `pattern` is fixed, not exposed

Every row this UI creates writes `pattern: "*"`. The field is not shown in
any form — there is nothing a user could set it to that would do anything
(see Problem/Prior research: Goose matches tool names exactly, full stop).
The existing `dropped` reason string in `RenderToolPermissions`
(`gooseconfig/permissions.go:65`) already surfaces this at delivery time;
this spec additionally extends that function's doc comment to name the
confirmed source (`acp-schema.json`'s `ToolPermissionEntry`,
`permission.rs`'s exact-match lookup) so a future reader doesn't have to
re-derive the limitation from scratch.

### Component 3 — Flutter DAO / repository / cubit / screen

Mirrors the MCP governance UI's shape exactly
(`lib/infrastructure/mcp/mcp_daos.dart`,
`lib/infrastructure/mcp/mcp_repository.dart`,
`lib/application/mcp/mcp_cubit.dart`,
`lib/presentation/mcp/mcp_management_screen.dart`):

- **`ToolPermissionDao`** (new) — `BaseDao<ToolPermission>` over
  `Collections.toolPermissions`, same one-line shape as `McpServerDao`.
- **`IToolPermissionRepository`** (new interface) /
  **`ToolPermissionRepository`** (new impl):
  - `watchRules()` → `_dao.watch(filter: 'poco_config = ""', sort: 'tool')`
    — global-only (Component 1's scope decision), **not** filtered on
    `active`: a disabled rule must stay visible so it can be re-enabled,
    otherwise `setActive(id, false)` would be indistinguishable from a
    hard delete from the UI's perspective, defeating the reason Component 4
    chose soft-disable over delete in the first place. `deliverToolPermissions`
    (server-side, unchanged) already filters to `active = true` at delivery
    time — this screen showing inactive rows has no effect on enforcement.
  - `createRule({required String tool, required String action})` →
    `_dao.save(null, {'tool': tool, 'pattern': '*', 'action': action, 'active': true})`.
  - `updateAction(String id, String action)` →
    `_dao.save(id, {'action': action})`.
  - `setActive(String id, bool active)` →
    `_dao.save(id, {'active': active})` — this is how a rule is "removed"
    (Component 4).
  - All four wrapped in `tryMethod(..., ToolPermissionsException.new, '<methodName>')`,
    matching `McpRepository`'s pattern exactly.
- **`ToolPermissionsState`** (new, Freezed, `implements IUiFlowState`) —
  same four-variant shape as `McpState`
  (`initial`/`loading`/`loaded(List<ToolPermission> rules)`/`error(String)`),
  same `status`/`error`/`isIdle`/`isLoading`/`isSuccess`/`isFailure`/`hasError`
  getter block.
- **`ToolPermissionsCubit`** (new, `@injectable`) — `watchRules()` (mirrors
  `McpCubit.watchServers()`'s subscribe/emit/onError shape exactly),
  `updateAction(id, action)`, `setActive(id, active)`, `createRule(tool, action)`
  — each a try/catch around the repository call, logging via `logError` and
  emitting `ToolPermissionsState.error` on failure, matching
  `McpCubit.authorize`/`deny`/`createServer`'s exact bodies.
- **`ToolPermissionsScreen`** (new) — `PocketCoderShell` +
  `BiosFrame(title: context.l10n.toolPermissionsTitle)`, `BlocProvider` +
  `UiFlowListener<ToolPermissionsCubit, ToolPermissionsState>`, same
  structural shell as `McpManagementScreen`. Body: an "ADD RULE" button
  above a single `BiosSection` list containing every global rule, active and
  inactive together (sorted by tool name, per the DAO's `sort: 'tool'`) —
  unlike `McpManagementScreen`'s pending/active split, there's no separate
  section, just a dimmed appearance (`TerminalCard`'s existing `isActive`
  flag, inverted: `isActive: rule.active == true`) so disabled rules are
  visually distinct but still present and editable. Each row is a
  `TerminalCard` showing the tool name, a 3-way segmented control
  (ALLOW / ASK / DENY, backed by
  `context.read<ToolPermissionsCubit>().updateAction(rule.id, ...)`), and an
  active/inactive toggle (`setActive`) that a user can flip either
  direction. The "ADD RULE" button opens a
  `TerminalDialog` with one `TerminalTextField` (tool name, free text — no
  catalog, no autocomplete, matches the seed data's own free-text
  convention) and the same 3-way action picker, calling `createRule` on
  submit; empty tool name is rejected client-side before the dialog closes
  (same guard shape as `_showAddServerDialog`'s empty-name check).

### Component 4 — Route registration (fixes the existing dead button)

Register the missing `GoRoute`:

```dart
GoRoute(
  path: AppRoutes.configureToolPermissions,
  name: RouteNames.configureToolPermissions,
  pageBuilder: (context, state) => TerminalTransition.buildPage(
    context: context,
    state: state,
    child: const ToolPermissionsScreen(),
  ),
),
```

placed alongside the other `configure*` routes in `app_router.dart`
(after `configureMcp`, matching the Settings screen's ordering:
`AGENT REGISTRY` → `TOOL PERMISSIONS` → `MCP MANAGEMENT`). `AppRoutes`,
`RouteNames`, and `AppNavigation.toToolPermissions` already exist
(`app_router.dart:217,257,291-292`) and need no changes — the button in
`settings_screen.dart:24,88-89` already calls
`context.push(AppRoutes.configureToolPermissions)` correctly and starts
working the moment the route resolves.

### Component 5 — Reconcile the duplicate exception class

Two `ToolPermissionsException` definitions currently exist:

- `lib/domain/exceptions/tool_permissions_exception.dart` — a standalone
  `implements Exception` class, unreferenced by any other file in the repo
  (confirmed by grep) — dead code from the earlier abandoned attempt.
- `lib/domain/exceptions.dart:57-64` — extends `DomainException`, with
  `.fetchFailed()`/`.updateFailed()` factories, matching the exact pattern
  every other domain exception in that file follows (`McpException`,
  `AuthException`, etc.).

Delete the standalone file. Keep and use the one in `exceptions.dart` — it's
what `Component 3`'s repository wraps calls in via `tryMethod`.

## Data model

No schema changes. `tool_permissions` already has every field this UI
needs (`tool`, `pattern`, `action`, `active`, `poco_config`,
`sandbox_config`) — `pattern`, `poco_config`, and `sandbox_config` are
simply never written to anything but their fixed/empty defaults by this UI
(see Components 1 and 2 for why). The Dart `ToolPermission` model
(`lib/domain/models/tool_permission.dart`) is already generated and correct
as-is — no field changes needed there either.

## Error handling

- **Create/update/toggle failures**: caught in the cubit, logged via
  `logError`, surfaced as `ToolPermissionsState.error` — same shape as
  every other cubit in this codebase, rendered by the existing
  `UiFlowListener` (toast).
- **Empty tool name on create**: rejected client-side before the dialog
  closes (mirrors `_showAddServerDialog`'s `if (name.isEmpty) return;`
  guard) — no round-trip to PocketBase for an invalid row.
- **No server-side validation beyond existing PocketBase field
  requirements** (`tool`, `pattern`, `action` required) — same as the MCP
  governance UI's manual-add path.

## Testing

Flutter only — no backend changes beyond a doc-comment edit (Component 2),
so no Go tests are needed.

- `test/infrastructure/tool_permissions/tool_permission_repository_test.dart`
  (new) — mocktail `MockToolPermissionDao`, mirrors
  `test/infrastructure/mcp/mcp_repository_test.dart`'s exact structure:
  one `group` per method, asserting the exact `dao.save`/`dao.watch` call
  args (e.g. `createRule` verifies `dao.save(null, {'tool': ..., 'pattern':
  '*', 'action': ..., 'active': true})`), plus one test per method
  asserting failures are wrapped in `ToolPermissionsException`.
- `test/application/tool_permissions/tool_permissions_cubit_test.dart`
  (new) — mirrors `test/application/mcp/mcp_cubit_test.dart`'s structure:
  `blocTest`-style assertions that `watchRules()` emits
  `loading` → `loaded([...])` on a repository stream event and `error(...)`
  on a stream error; that `createRule`/`updateAction`/`setActive` call
  through to the repository and emit `error(...)` on a thrown exception.

## Out of scope

- Per-`poco_config` scoped editing (Component 1) — stays global-only until
  the backend's own `poco_config`-selection story exists beyond "the
  current default."
- Any change to `pattern`'s schema presence, `RenderToolPermissions`'s
  conflict-resolution logic, or `deliverToolPermissions`'s delivery
  mechanism — all already correct and unchanged by this spec.
- A tool-name catalog/autocomplete (Component 3) — free text only, matching
  how the backend already treats `tool`.
- Any change to the MCP governance UI, skills, recipes, prompt templates,
  or the scheduler — separate Bucket B plans per the ownership-map's
  "foundational trio" decomposition.

## Dependencies

None beyond what's already on this branch: `tool_permissions` schema,
`gooseconfig.RenderToolPermissions`, and `deliverToolPermissions` all landed
with the MCP governance UI plan
(`docs/superpowers/plans/2026-07-23-mcp-governance-ui.md`, Tasks 2–3).
