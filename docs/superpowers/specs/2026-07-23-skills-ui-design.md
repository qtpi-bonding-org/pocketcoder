# Skills UI — Design

## Problem

Goose supports "skills" — markdown files (`SKILL.md` + YAML frontmatter, the
agentskills.io format) the model can load on demand via an always-on
`load_skill(name, args)` tool. Managing them today requires SSH-ing into the
`goose` container and hand-editing files under `~/.agents/skills` (global)
or `<project>/.agents/skills` (project-scoped). This spec builds a Flutter
screen for creating, editing, and deleting skills without shell access,
completing the "foundational trio" of deferred UIs alongside the MCP
governance UI and Tool-Permissions UI (both already shipped).

Unlike those two, skills need **no PocketBase storage at all** — Goose owns
skill files directly, PocketBase is a pure pass-through. This spec also
removes a dead `skills` PocketBase collection and an orphaned Flutter
`Skill` model, both leftover scaffolding from before that "zero schema"
conclusion was reached.

## Prior research this spec builds on

- `spikes/goose-acp-config-surface/ownership-map.md:164-193` ("Skills,
  elaborated") — the ownership decision this spec implements: *"Skills need
  no PocketBase storage under either global or per-project scoping. The
  only PocketBase-side work is a Flutter screen that calls
  `sources/list|create|update|delete` (`type: skill`) directly through the
  admin connection... writing either to the global skills dir or a specific
  chat's workspace-folder-scoped one depending on where the user chooses to
  save it."* Confirmed by direct source read
  (`crates/goose/src/skills/mod.rs`): skills are scoped two ways by Goose
  itself — `global_skills_dir() = ~/.agents/skills` (deployment-wide) vs.
  `project_skills_dir(project_dir) = <project_dir>/.agents/skills`
  (scoped to one working directory) — and are always-on (the "skills"
  platform extension is `default_enabled: true`, `agents/platform_extensions/
  mod.rs:198`), so there's no per-agent "attach this skill" join-table
  concept the way there is for MCP servers.
- `docs/superpowers/plans/2026-07-22-agent-config-foundations.md` — built
  `AdminConn`/`CallExtension`, already landed and already anticipates this
  spec: `admin.go`'s doc comment lists *"tool permissions, MCP extensions,
  skills, schedules"* as `AdminConn`'s intended consumers.
- `docs/superpowers/specs/2026-07-23-tool-permissions-ui-design.md` — the
  precedent for cleaning up dead scaffolding left over from an earlier
  abandoned attempt (there: a duplicate exception class; here: a whole
  unused PocketBase collection and Flutter model).
- Direct verification against Goose's real ACP schema
  (`.independent_repos/goose_reference/crates/goose/acp-meta.json:424-461`,
  `acp-schema.json:4849-5361`) for the exact `sources/*` request/response
  shapes — see Component 2 below.
- `services/pocketbase/internal/api/profile.go:93-98` — confirms how
  PocketCoder resolves a working directory from a `poco_config`:
  `workspace_folders[0]` becomes the session's `Cwd`, which is exactly
  Goose's `project_dir` for skill scoping purposes.

## Architecture

```
Flutter (SkillsScreen)
   │  POST /api/pocketcoder/skills/{list,create,update,delete}
   ▼
skills.go (new PocketBase route, admin-only)
   │  AdminConn → _goose/unstable/sources/{list,create,update,delete}
   │  (type: "skill")
   ▼
goose (c2)
   writes/reads SKILL.md files under:
     ~/.agents/skills                              (global)
     <poco_config.workspace_folders[0]>/.agents/skills   (project)
```

No PocketBase collection is read or written by this feature. Every request
is a synchronous proxy: Flutter → PocketBase route → Goose → response back
up the same chain. This is architecturally different from the MCP
governance UI and Tool-Permissions UI (both of which persist PocketBase
rows and asynchronously deliver them to Goose) — there is nothing for
Flutter to `watch()`, since PocketBase holds no state of its own.

### Component 1 — Global vs. project scope, explicit choice

Every create/edit action requires the user to pick a scope:

- **Global**: writes to `~/.agents/skills`, visible to every session
  regardless of working directory.
- **Project**: the user picks a `poco_config` by name from a dropdown
  (populated via the existing `AgentConfigRepository.watchConfigs()` —
  already built by the agent-config-foundations plan, no new backend
  needed to list configs). The picker excludes any `poco_config` with an
  empty `workspace_folders`, since there's nothing to scope to. Selecting
  one resolves `workspace_folders[0]` client-side and sends it as the
  `projectDir` — this exactly matches how PocketCoder already resolves a
  chat's `Cwd` for session creation (`profile.go:93-98`), so a project-
  scoped skill written this way is guaranteed relevant to any chat that
  runs under that same `poco_config`.

No free-text path entry — a typed path could target a directory no chat is
actually configured to use, silently writing a skill nothing will ever
load.

### Component 2 — Goose's real `sources/*` schema

Verified directly against `.independent_repos/goose_reference` (pinned
v1.43.0, matches `services/goose/Dockerfile`), not inferred:

- **Methods** (`acp-meta.json:424-461`): `_goose/unstable/sources/{list,
  create,update,delete}` (export/import also exist but are out of scope —
  see below).
- **`SourceType` enum** (`acp-schema.json:4884-4895`):
  `["skill","builtinSkill","recipe","subrecipe","agent","project"]`. Every
  request this spec sends uses `type: "skill"`.
- **`SourceScope`** (`acp-schema.json:4896-4944`) — a discriminated union,
  not a boolean: `{"scope":"global"}` or
  `{"scope":"projectDir","projectDir":"<string>"}` (a third variant,
  `projectId`, exists but has no PocketCoder equivalent to supply and is
  unused by this spec).
- **`CreateSourceRequest_unstable`** (`4849-4883`), required
  `["type","name","description","content","target"]` — `target` is a
  `SourceScope`. `content` is the skill body (the markdown that goes inside
  `SKILL.md`, below the frontmatter Goose generates from `name`/
  `description`).
- **`SourceEntry`** (`4958-5007`), required `["type","name","description",
  "content","path","global"]` — `path`: *"Stable on-disk path... Skills use
  the directory containing `SKILL.md`."* `global: boolean` — *"True when the
  source lives in the user's global sources directory; false when inside a
  specific project."* This is how list responses expose which scope each
  skill is already in — the UI groups by this field, it never has to guess.
- **`ListSourcesRequest_unstable`** (`5009-5037`): `type` (send `"skill"`),
  `projectDir?: string`. **`includeProjectSources` does not do what its name
  suggests for this design and must not be used as the way to surface
  project-scoped skills.** Traced directly in
  `crates/goose/src/sources.rs::list_sources_with_roots` (`~857-920`):
  passing `project_dir: Some(X)` is what makes `discover_skills` scan `X`'s
  `.agents/skills` directory (alongside the always-scanned global
  directories, `skills/mod.rs::all_skill_dirs`) — that's the only way a
  project-scoped skill written under a given directory becomes visible
  again. `include_project_sources` is a *separate* mechanism: it additionally
  scans directories registered in Goose's own independent "Project" source
  registry (`SourceType::Project`, `read_project_dir()`,
  `~/.local/share/goose/projects/*.md` or equivalent), populated only by
  `sources/create{type:"project"}` — nothing in this design ever creates one,
  so that flag would always be a no-op here, not a way to reach `poco_config`
  workspace folders. See Component 3's list route for how project scope is
  actually surfaced (one call per known project directory, not one flag).
- **`UpdateSourceRequest_unstable`** (`5224-5260`), required `["type","path",
  "name","description","content"]` — **path-identified, not id-based**.
  `properties` is optional and, per the schema doc, *"When `None`/omitted,
  existing properties preserved"* — this spec never sends it (skills created
  by this UI have no custom frontmatter properties to begin with).
- **`DeleteSourceRequest_unstable`** (`5275-5292`), required
  `["type","path"]` — also path-identified.

Every create/update/delete round-trips a `path`: create's response
(`CreateSourceResponse_unstable` → `{"source": SourceEntry}`) returns the
new skill's `path`, which the Flutter list re-fetch then carries forward
for any subsequent edit/delete on that row. There's no separate ID scheme
to invent.

### Component 3 — Backend: `services/pocketbase/internal/api/skills.go` (new)

Four routes. Route registration (`e.Router.POST(...)`, JSON body bind, JSON
response) follows the same shape as every existing custom route
(`api/mcp.go`'s `RegisterMcpApi`), but the role check does not have a
direct precedent to copy: every existing role-gated custom route
(`mcp.go`, `ssh.go`, `cron.go`) checks agent-or-admin, since Goose itself
calls those. This is the first **admin-only** custom route — correct,
since nothing here is ever invoked by Goose, only by a human through
Flutter — but it's new gating logic (`if role != "admin"`), not a copy of
an existing check.

- `POST /api/pocketcoder/skills/list` — `{}` in. Fans out to multiple
  `sources/list` calls and merges the results, since `projectDir` (not
  `includeProjectSources`, see Component 2) is what actually surfaces
  project-scoped skills:
  1. One call with `{type:"skill"}` (no `projectDir`) — returns global
     skills only.
  2. Query PocketBase's own `poco_configs` collection directly (Go, no ACP
     call) for every row with a non-empty `workspace_folders`; for each
     distinct `workspace_folders[0]`, one call with
     `{type:"skill", projectDir: <that path>}` — each such call returns
     that directory's project skills *plus* the same global skills again
     (Goose always scans global dirs regardless of `projectDir`).
  3. Merge all results, deduplicating by `path` (stable and unique per
     skill regardless of how many calls returned it) — this collapses the
     repeated global entries from step 2 back down to one copy each.

  With one `poco_config`, that's 2 Goose calls; with N, it's N+1 — cheap
  and sequential is fine at this deployment's scale (single/family-scale,
  matching every other "process-wide, not per-session" scoping decision
  already accepted elsewhere in this codebase's ACP design). Returns the
  merged `sources` array back to Flutter unmodified (each entry already
  carries `name/description/content/path/global`, exactly what the screen
  needs).
- `POST /api/pocketcoder/skills/create` — body
  `{name, description, content, scope: {global:true} | {projectDir:string}}`,
  maps to `CreateSourceRequest_unstable{type:"skill", name, description,
  content, target: <SourceScope>}`, returns the created `SourceEntry`
  (specifically its `path`).
- `POST /api/pocketcoder/skills/update` — body
  `{path, name, description, content}`, maps to
  `UpdateSourceRequest_unstable{type:"skill", path, name, description,
  content}`.
- `POST /api/pocketcoder/skills/delete` — body `{path}`, maps to
  `DeleteSourceRequest_unstable{type:"skill", path}`.

Each handler opens a fresh `AdminConn` (per-request, matching its documented
"dial, make the call, close" lifetime — `admin.go`'s doc comment), calls
`CallExtension(ctx, "_goose/unstable/sources/<verb>", params)`, unmarshals
the `json.RawMessage` response, and returns it as JSON. No PocketBase
record is read or written by any of the four handlers.

### Component 4 — Flutter: repository/cubit/screen, no DAO

Because there's no PocketBase collection, this doesn't get a
`BaseDao`-backed DAO the way MCP/Tool-Permissions did. Instead:

- **`ISkillsRepository`**/**`SkillsRepository`**: four methods
  (`Future<List<Skill>> listSkills()`, `Future<void> createSkill(...)`,
  `Future<void> updateSkill(...)`, `Future<void> deleteSkill(String path)`),
  each calling the new routes directly via the existing `PocketBase`
  client's raw request method (the same client already injected everywhere
  else — `pb.send('/api/pocketcoder/skills/list', method: 'POST', ...)` —
  no new HTTP client needed). Wrapped in `tryMethod`/`SkillsException`, same
  convention as every other repository.
- A new `Skill` domain model (Freezed, **not** the deleted PocketBase-backed
  one) shaped to match `SourceEntry`: `{name, description, content, path,
  global}`. No `id`, no `fromRecord` — it's never built from a PocketBase
  `RecordModel`, only from JSON the new routes return. Two `SourceEntry`
  fields are deliberately dropped, not carried into the model: `properties`
  (arbitrary frontmatter metadata this UI never writes or reads) and
  `supportingFiles` (extra files alongside `SKILL.md`, populated by Goose
  for skills that have them — this UI's create/edit form only ever writes a
  single-file skill, so it has nothing to show or manage there; a skill
  with supporting files created some other way would still list/edit fine
  here, just without surfacing those extra files). `writable` is also
  dropped: traced directly in `crates/goose/src/skills/mod.rs` and
  `sources.rs`, every code path that builds a `SourceType::Skill` entry
  hardcodes `writable: true` — there is no conditional skill path that
  produces `false` (only other source types like `Agent` vary it). Since
  this spec's `list` request only ever asks for `type:"skill"`, a UI check
  on `writable` would gate a branch Goose can never actually take — dead
  validation for a scenario that can't happen, not defensive design.
- **`SkillsCubit`**/**`SkillsState`**: same 4-variant shape as `McpState`/
  `ToolPermissionsState` (`initial`/`loading`/`loaded(List<Skill>)`/
  `error`), but `loadSkills()` is a one-shot `Future`-based fetch-and-emit,
  not a `Stream` subscription — there's nothing to subscribe to. After any
  create/update/delete, the cubit re-calls `loadSkills()` to refresh (no
  live push from the backend, matching how a plain HTTP CRUD screen works
  anywhere else without a realtime layer).
- **`SkillsScreen`**: mirrors `ToolPermissionsScreen`'s shell
  (`PocketCoderShell`/`BiosFrame`/`BlocProvider`/`UiFlowListener`). Two
  `BiosSection`s — GLOBAL and PROJECT — populated by filtering the loaded
  list on `.global`. "ADD SKILL" opens a dialog: name, description, content
  (multi-line `TerminalTextField`), and a scope picker (Global vs. Project;
  Project reveals the `poco_config` dropdown, sourced from
  `AgentConfigRepository.watchConfigs()`). Each row has EDIT (re-opens the
  same dialog pre-filled, scope no longer editable — Goose's `update`
  request has no scope-change field, only content edits) and DELETE.

### Component 5 — Remove dead scaffolding

- **PocketBase**: new migration deletes the `skills` collection (`pc_skills`,
  created by `1748000100_acp_schema.go:184-202`) — grep confirms zero
  surviving relation fields point at it (unlike `ai_agents`, which needed
  four relation fields dropped first before deletion in
  `1753000000_prune_legacy_ai_config.go`; `skills` needs no such step).
  Modeled directly on that migration's delete pattern
  (`app.FindCollectionByNameOrId` → `app.Delete`).
- **Flutter**: delete `lib/domain/models/skill.dart` (and its generated
  `.freezed.dart`/`.g.dart`) and the `skills` entry from
  `Collections`/`COLLECTION_CONST_OVERRIDES` if present in
  `scripts/generate_models.py`. Per `CLAUDE.md`'s Model Generation
  Pipeline, rerunning `scripts/export_schema.sh` +
  `generate_models.py` after the migration lands will regenerate
  `collections.dart` without the `skills` constant automatically (the
  generator does a full rewrite from the current schema, confirmed by
  reading `generate_collections()` — it doesn't append, so stale entries
  don't survive a rerun) — but the generator has no prune step for
  `lib/domain/models/skill.dart` itself (per-collection files are only ever
  written, never deleted for a collection that's gone), so that file must
  be deleted by hand.

## Data model

No PocketBase schema for skills (Component 1's whole point). The `skills`
collection removal in Component 5 is destructive but safe: the collection
has zero application code reading or writing it today (confirmed:
`Skill`/`skill.dart` has no DAO/repo/cubit/screen referencing it anywhere,
same orphaned-scaffolding shape independently confirmed for
`tool_permissions_exception.dart` in the prior spec) and zero incoming
relations.

## Error handling

- **Goose unreachable** (agent profile not running, or `AdminConn` dial
  fails): each route returns `502` with a generic error; the Flutter cubit
  surfaces it via the existing `SkillsState.error` → `UiFlowListener` toast
  path, same as every other cubit in this app.
- **Duplicate name on create**: Goose's own `sources/create` handler is the
  source of truth for whether a name collision is an error (no PocketCoder-
  side pre-check, since there's no PocketCoder-side data to check against);
  whatever error it returns is passed through as the route's response body
  and surfaced the same way.
- **Empty required fields** (name/description/content): rejected
  client-side before the dialog submits, same guard shape as every other
  "ADD" dialog in this app (`ToolPermissionsScreen`'s empty-tool-name
  check, `McpManagementScreen`'s empty-server-name check).
- **Project scope with no eligible `poco_config`**: if every `poco_config`
  has an empty `workspace_folders`, the Project option in the scope picker
  is disabled with an inline note rather than silently offering a picker
  with nothing in it.

## Testing

- **Go**: `services/pocketbase/internal/api/skills_test.go` — role-gating
  tests (non-admin gets `403`), and request/response marshaling tests
  against a fake `AdminConn`/`CallExtension` (same fake-connection pattern
  the MCP governance UI plan already established for
  `goose_config_permissions_test.go`), asserting each of the four handlers
  builds the exact `sources/*` request shape from Component 2 and returns
  the raw response.
- **Flutter**: `test/infrastructure/skills/skills_repository_test.dart` —
  mocktail-stubbed `PocketBase.send()` calls, asserting each repository
  method posts to the right route with the right body shape and maps the
  response into `Skill`/`List<Skill>`. `test/application/skills/
  skills_cubit_test.dart` — mirrors `McpCubit`/`ToolPermissionsCubit`
  test structure, adapted for `loadSkills()` being `Future`-based instead
  of stream-based (assert it emits `loading` then `loaded`/`error` off a
  single repository call, not a stream subscription).
- No bats/integration test in this spec — unlike the MCP governance UI
  (which needed a real gateway container to prove attachment worked
  end-to-end), skills' `sources/*` methods are already proven live and
  working against real Goose (Component 2's citations are read directly
  from the pinned version's source, not inferred), and the risk surface
  here is entirely in PocketCoder's own request-shape construction, which
  the Go unit tests already cover with a fake connection.

## Out of scope

- Built-in skills (`type: "builtinSkill"`) — read-only shipped skills,
  not shown by this screen at all (considered and explicitly rejected in
  favor of CRUD-only scope, to match the MCP/Tool-Permissions UIs'
  minimal-CRUD precedent).
- `sources/export`/`sources/import` — skill-bundle sharing between
  deployments. Real methods, confirmed to exist, but no product need
  identified yet.
- Recipes, prompt templates, and the scheduler — separate Bucket B plans
  per the ownership-map's "foundational trio" decomposition (this spec
  closes out the third and last item of that trio; recipes/prompt-templates
  were never part of the trio to begin with and remain fully unspecced).
- Any change to `AdminConn`/`CallExtension` themselves — both already exist
  and already anticipate this exact consumer.

## Dependencies

`AdminConn`/`CallExtension`, both already landed
(`docs/superpowers/plans/2026-07-22-agent-config-foundations.md`).
`AgentConfigRepository.watchConfigs()`, already landed (feat(flutter): add
AgentConfigRepository for poco_configs + prompts) — Component 1's project
picker consumes it directly, no new backend needed to list `poco_configs`.
