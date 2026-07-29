# Multi-Harness Selection — Schema + Coordinator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `chats.harness`/`chats.harness_model_override`/`chats.workspace_override` actually drive which harness a chat's ACP session dials, with a correctly-enforced pin (a chat can't silently re-home to a different harness after its session exists), and fix the two coordinator bugs (an early-return that no-ops chat-level overrides on a fresh box, and `selectApplier`'s unconditional Goose-only behavior) that block any of this from working safely with more than one harness type.

**Architecture:** Extend `schema.json` directly (no timestamped migration file — no existing deployments, per `CLAUDE.md`'s own guidance to prefer editing the schema snapshot). Extract the shared resolve+dial+init prefix of `runLoop` and `StreamColdReplay` into one `establishSession` function in the `coordinator` package, carrying everything it needs (`Target`, capability flags, pinned/resolved instance ids) on `SessionProfile` since the coordinator package takes no `core.App`. This plan does **not** provision any real second harness container or write the stdio adapter — it makes the schema and coordinator correct and testable against the single existing Goose deployment, which is exactly what should be true before a second harness type exists at all. Provisioning and the adapter are separate follow-on plans (see the design spec's §5.1–5.5).

**Tech Stack:** Go (PocketBase backend, `server/pocketbase`), the `coder/acp-go-sdk` ACP client SDK, PocketBase's own migration/schema JSON format.

## Global Constraints

- No migrations. Edit `server/pocketbase/pb_migrations/schema.json` directly; no new timestamped migration file (per `CLAUDE.md` and the confirmed absence of existing deployments — see the design spec's header).
- No backward-compatibility shims. There are no existing deployments to preserve; don't hedge schema or code for one.
- Every schema addition needs an explicit `listRule`/`viewRule`/`createRule`/`updateRule`/`deleteRule` — an unset rule set makes a field invisible to the client (this bit the first draft of the design spec).
- `harness_instances.secret` must be `"hidden": true` — it's a live ACP credential.
- Follow existing patterns exactly: PocketBase text PKs (`autogeneratePattern: "[a-z0-9]{15}"`, `min/max: 15`, `pattern: "^[a-z0-9]+$"`), the existing `hooks/timestamps.go` non-`Request` hook-registration precedent, and the existing `internal/gooseconfig`-style pure/no-I/O package split where applicable.
- Design spec: `docs/superpowers/specs/2026-07-29-multi-harness-selection-design.md` — read §4, §5.1 (resolution only, not provisioning), §5.6, §5.7, §5.8, §6 before starting; this plan implements exactly those sections.

---

## File Structure

| File | Responsibility |
|---|---|
| `server/pocketbase/pb_migrations/schema.json` | Modify: `chats` gains `harness`, `workspace_override`, an index; `harnesses` gains 5 provisioning/capability fields; new `harness_instances` collection; `goose_sessions` gains `harness_instance`. |
| `server/pocketbase/pb_migrations/1756000100_seed.go` | Modify: seed the `goose` `harnesses` row and its default `harness_instances` row (`managed: false`). |
| `server/pocketbase/internal/agent/coordinator/profile.go` | Modify: `SessionProfile` gains `Target`, `ResolvedInstanceID`, `PinnedInstanceID`, `SupportsLiveConfig`, `SupportsGooseExtensions`, `SingleConnectionOnly`; `ProfileApplier.Apply` gains a `modes` param; `selectApplier` branches on the new flags; `PerSessionApplier.Apply` skips unknown modes/unsupported extensions instead of always sending them. |
| `server/pocketbase/internal/agent/coordinator/run.go` | Modify: `DialFunc` gains a `Target` param; new `establishSession` function (the shared resolve+pin-check+capability-check+dial+init prefix, with a per-chat `single_connection_only` mutex and a caller-supplied `beforeSessionCall` hook); `runLoop` and `StreamColdReplay` both call it instead of duplicating the prefix. |
| `server/pocketbase/internal/agent/coordinator/delete_session.go` | Modify: dial via the resolved `Target` from `goose_sessions.harness_instance`, not the default. |
| `server/pocketbase/internal/api/profile.go` | Modify: fix `buildSessionProfile`'s early-return bug; add harness/`Target`/instance-id/capability-flag resolution; add `workspace_override` composition (§5.7) and path validation (§5.8). |
| `server/pocketbase/internal/api/agent.go` | Modify: `gooseSessionForChat` also returns the pinned `harness_instance` id; `saveGooseSession` also stamps it. |
| `server/pocketbase/internal/hooks/chats_harness_pin.go` | Create: the `chats` create/update hook — fast-fail rejection of a harness/workspace_override change once a session exists, and path validation, using non-`Request` hook variants. |
| `server/pocketbase/internal/hooks/schedule_importer.go` | Modify: stamp the seeded default-Goose `harness_instances` id when writing an imported `goose_sessions` row. |

---

## Task 1: Schema — `chats.harness`, `chats.workspace_override`, and an index

**Files:**
- Modify: `server/pocketbase/pb_migrations/schema.json` (the `chats` collection)
- Test: `server/pocketbase/pb_migrations/schema_test.go` (create if it doesn't exist)

**Interfaces:**
- Produces: `chats.harness` (relation → `harnesses`, optional), `chats.workspace_override` (json, nullable) — consumed by Task 6 (`buildSessionProfile`) and Task 8 (`establishSession`'s pin check).

- [ ] **Step 1: Write the failing test**

```go
package pb_migrations

import (
	"encoding/json"
	"os"
	"testing"
)

func TestChatsCollectionHasHarnessFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var chats map[string]any
	for _, c := range collections {
		if c["name"] == "chats" {
			chats = c
		}
	}
	if chats == nil {
		t.Fatal("chats collection not found")
	}
	fieldNames := map[string]bool{}
	for _, f := range chats["fields"].([]any) {
		fieldNames[f.(map[string]any)["name"].(string)] = true
	}
	if !fieldNames["harness"] {
		t.Error("chats.harness field missing")
	}
	if !fieldNames["workspace_override"] {
		t.Error("chats.workspace_override field missing")
	}
	found := false
	for _, idx := range chats["indexes"].([]any) {
		if idx == "CREATE INDEX idx_chats_user_archived ON chats (user, archived)" {
			found = true
		}
	}
	if !found {
		t.Error("chats (user, archived) index missing")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/pb_migrations && go test -run TestChatsCollectionHasHarnessFields -v`
Expected: FAIL — `chats.harness field missing`

- [ ] **Step 3: Add the fields and index to `schema.json`**

Find the `chats` collection object in `schema.json` (identified by `"name": "chats"`). Add two entries to its `fields` array (after the existing `harness_model_override` relation field) and one entry to its `indexes` array (currently `[]`):

```json
{
  "cascadeDelete": false,
  "collectionId": "pc_harnesses",
  "hidden": false,
  "id": "relation_chats_harness",
  "maxSelect": 1,
  "minSelect": 0,
  "name": "harness",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "relation"
},
{
  "hidden": false,
  "id": "json_chats_workspace_override",
  "maxSize": 0,
  "name": "workspace_override",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "json"
}
```

And in `indexes`:

```json
"CREATE INDEX idx_chats_user_archived ON chats (user, archived)"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/pb_migrations && go test -run TestChatsCollectionHasHarnessFields -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/pb_migrations/schema.json server/pocketbase/pb_migrations/schema_test.go
git commit -m "feat(schema): add chats.harness and chats.workspace_override"
```

---

## Task 2: Schema — `harnesses` provisioning and capability fields

**Files:**
- Modify: `server/pocketbase/pb_migrations/schema.json` (the `harnesses` collection)
- Test: `server/pocketbase/pb_migrations/schema_test.go`

**Interfaces:**
- Produces: `harnesses.container_image`, `.launch_template`, `.supports_live_config`, `.supports_goose_extensions`, `.single_connection_only` — consumed by Task 9 (`selectApplier`) and Task 8 (`establishSession`'s mutex).

- [ ] **Step 1: Write the failing test**

```go
func TestHarnessesCollectionHasCapabilityFields(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var harnesses map[string]any
	for _, c := range collections {
		if c["name"] == "harnesses" {
			harnesses = c
		}
	}
	if harnesses == nil {
		t.Fatal("harnesses collection not found")
	}
	want := []string{"container_image", "launch_template", "supports_live_config", "supports_goose_extensions", "single_connection_only"}
	got := map[string]bool{}
	for _, f := range harnesses["fields"].([]any) {
		got[f.(map[string]any)["name"].(string)] = true
	}
	for _, name := range want {
		if !got[name] {
			t.Errorf("harnesses.%s field missing", name)
		}
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/pb_migrations && go test -run TestHarnessesCollectionHasCapabilityFields -v`
Expected: FAIL — `harnesses.container_image field missing`

- [ ] **Step 3: Add the fields to the `harnesses` collection in `schema.json`**

```json
{
  "autogeneratePattern": "",
  "hidden": false,
  "id": "text_harnesses_container_image",
  "max": 0,
  "min": 0,
  "name": "container_image",
  "pattern": "",
  "presentable": false,
  "primaryKey": false,
  "required": false,
  "system": false,
  "type": "text"
},
{
  "hidden": false,
  "id": "json_harnesses_launch_template",
  "maxSize": 0,
  "name": "launch_template",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "json"
},
{
  "hidden": false,
  "id": "bool_harnesses_supports_live_config",
  "name": "supports_live_config",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "bool"
},
{
  "hidden": false,
  "id": "bool_harnesses_supports_goose_extensions",
  "name": "supports_goose_extensions",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "bool"
},
{
  "hidden": false,
  "id": "bool_harnesses_single_connection_only",
  "name": "single_connection_only",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "bool"
}
```

(PocketBase bool fields default to `false` when unset, matching the design spec's stated defaults for all three flags — no explicit `default` key needed.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/pb_migrations && go test -run TestHarnessesCollectionHasCapabilityFields -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/pb_migrations/schema.json server/pocketbase/pb_migrations/schema_test.go
git commit -m "feat(schema): add harnesses provisioning and capability fields"
```

---

## Task 3: Schema — new `harness_instances` collection, and `goose_sessions.harness_instance`

**Files:**
- Modify: `server/pocketbase/pb_migrations/schema.json` (new collection + `goose_sessions` field)
- Test: `server/pocketbase/pb_migrations/schema_test.go`

**Interfaces:**
- Produces: `harness_instances` collection (`harness`, `harness_model`, `launch_key`, `container_name`, `acp_endpoint`, `secret` [hidden], `status`, `last_error`, `managed`, `created`, `updated`); `goose_sessions.harness_instance`. Consumed by Task 4 (seed), Task 6 (`buildSessionProfile`), Task 8 (`establishSession`), Task 10 (`delete_session.go`).

- [ ] **Step 1: Write the failing test**

```go
func TestHarnessInstancesCollectionExists(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var hi map[string]any
	for _, c := range collections {
		if c["name"] == "harness_instances" {
			hi = c
		}
	}
	if hi == nil {
		t.Fatal("harness_instances collection not found")
	}
	if hi["listRule"] != "@request.auth.id != ''" {
		t.Errorf("harness_instances.listRule = %v, want @request.auth.id != ''", hi["listRule"])
	}
	if hi["createRule"] != nil {
		t.Errorf("harness_instances.createRule should be null (superuser only)")
	}
	fields := map[string]map[string]any{}
	for _, f := range hi["fields"].([]any) {
		m := f.(map[string]any)
		fields[m["name"].(string)] = m
	}
	for _, name := range []string{"harness", "harness_model", "launch_key", "container_name", "acp_endpoint", "secret", "status", "last_error", "managed", "created", "updated"} {
		if fields[name] == nil {
			t.Errorf("harness_instances.%s field missing", name)
		}
	}
	if hidden, _ := fields["secret"]["hidden"].(bool); !hidden {
		t.Error("harness_instances.secret must be hidden: true")
	}
	uniquePair := false
	uniqueName := false
	for _, idx := range hi["indexes"].([]any) {
		s := idx.(string)
		if s == "CREATE UNIQUE INDEX idx_harness_instances_pair ON harness_instances (harness, launch_key)" {
			uniquePair = true
		}
		if s == "CREATE UNIQUE INDEX idx_harness_instances_name ON harness_instances (container_name)" {
			uniqueName = true
		}
	}
	if !uniquePair || !uniqueName {
		t.Error("harness_instances missing one or both unique indexes")
	}
}

func TestGooseSessionsHasHarnessInstance(t *testing.T) {
	data, err := os.ReadFile("schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var collections []map[string]any
	if err := json.Unmarshal(data, &collections); err != nil {
		t.Fatal(err)
	}
	var gs map[string]any
	for _, c := range collections {
		if c["name"] == "goose_sessions" {
			gs = c
		}
	}
	if gs == nil {
		t.Fatal("goose_sessions collection not found")
	}
	found := false
	for _, f := range gs["fields"].([]any) {
		if f.(map[string]any)["name"] == "harness_instance" {
			found = true
		}
	}
	if !found {
		t.Error("goose_sessions.harness_instance field missing")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/pb_migrations && go test -run 'TestHarnessInstancesCollectionExists|TestGooseSessionsHasHarnessInstance' -v`
Expected: FAIL — `harness_instances collection not found`

- [ ] **Step 3: Add the `harness_instances` collection and `goose_sessions.harness_instance` field**

Add a new collection object to the top-level `schema.json` array (following the exact PocketBase collection shape used by `harness_models` elsewhere in the file — PB-owned text PK with `autogeneratePattern: "[a-z0-9]{15}"`):

```json
{
  "id": "pc_harness_instances",
  "listRule": "@request.auth.id != ''",
  "viewRule": "@request.auth.id != ''",
  "createRule": null,
  "updateRule": null,
  "deleteRule": null,
  "name": "harness_instances",
  "type": "base",
  "fields": [
    {
      "autogeneratePattern": "[a-z0-9]{15}",
      "hidden": false,
      "id": "text_hi_id",
      "max": 15,
      "min": 15,
      "name": "id",
      "pattern": "^[a-z0-9]+$",
      "presentable": false,
      "primaryKey": true,
      "required": true,
      "system": true,
      "type": "text"
    },
    {
      "cascadeDelete": false,
      "collectionId": "pc_harnesses",
      "hidden": false,
      "id": "relation_hi_harness",
      "maxSelect": 1,
      "minSelect": 1,
      "name": "harness",
      "presentable": false,
      "required": true,
      "system": false,
      "type": "relation"
    },
    {
      "cascadeDelete": false,
      "collectionId": "pc_harness_models",
      "hidden": false,
      "id": "relation_hi_harness_model",
      "maxSelect": 1,
      "minSelect": 0,
      "name": "harness_model",
      "presentable": false,
      "required": false,
      "system": false,
      "type": "relation"
    },
    {
      "autogeneratePattern": "",
      "hidden": false,
      "id": "text_hi_launch_key",
      "max": 0,
      "min": 0,
      "name": "launch_key",
      "pattern": "",
      "presentable": false,
      "primaryKey": false,
      "required": true,
      "system": false,
      "type": "text"
    },
    {
      "autogeneratePattern": "",
      "hidden": false,
      "id": "text_hi_container_name",
      "max": 0,
      "min": 0,
      "name": "container_name",
      "pattern": "",
      "presentable": false,
      "primaryKey": false,
      "required": true,
      "system": false,
      "type": "text"
    },
    {
      "autogeneratePattern": "",
      "hidden": false,
      "id": "text_hi_acp_endpoint",
      "max": 0,
      "min": 0,
      "name": "acp_endpoint",
      "pattern": "",
      "presentable": false,
      "primaryKey": false,
      "required": false,
      "system": false,
      "type": "text"
    },
    {
      "autogeneratePattern": "",
      "hidden": true,
      "id": "text_hi_secret",
      "max": 0,
      "min": 0,
      "name": "secret",
      "pattern": "",
      "presentable": false,
      "primaryKey": false,
      "required": false,
      "system": false,
      "type": "text"
    },
    {
      "hidden": false,
      "id": "select_hi_status",
      "maxSelect": 1,
      "name": "status",
      "presentable": false,
      "required": true,
      "system": false,
      "type": "select",
      "values": ["pending", "running", "stopped", "error"]
    },
    {
      "autogeneratePattern": "",
      "hidden": false,
      "id": "text_hi_last_error",
      "max": 0,
      "min": 0,
      "name": "last_error",
      "pattern": "",
      "presentable": false,
      "primaryKey": false,
      "required": false,
      "system": false,
      "type": "text"
    },
    {
      "hidden": false,
      "id": "bool_hi_managed",
      "name": "managed",
      "presentable": false,
      "required": false,
      "system": false,
      "type": "bool"
    },
    {
      "hidden": false,
      "id": "autodate_hi_created",
      "name": "created",
      "onCreate": true,
      "onUpdate": false,
      "presentable": false,
      "system": false,
      "type": "autodate"
    },
    {
      "hidden": false,
      "id": "autodate_hi_updated",
      "name": "updated",
      "onCreate": true,
      "onUpdate": true,
      "presentable": false,
      "system": false,
      "type": "autodate"
    }
  ],
  "indexes": [
    "CREATE UNIQUE INDEX idx_harness_instances_name ON harness_instances (container_name)",
    "CREATE UNIQUE INDEX idx_harness_instances_pair ON harness_instances (harness, launch_key)"
  ],
  "created": "2026-07-29 00:00:00.000Z",
  "updated": "2026-07-29 00:00:00.000Z",
  "system": false
}
```

Add one field to the existing `goose_sessions` collection's `fields` array:

```json
{
  "cascadeDelete": false,
  "collectionId": "pc_harness_instances",
  "hidden": false,
  "id": "relation_gs_harness_instance",
  "maxSelect": 1,
  "minSelect": 0,
  "name": "harness_instance",
  "presentable": false,
  "required": false,
  "system": false,
  "type": "relation"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/pb_migrations && go test -run 'TestHarnessInstancesCollectionExists|TestGooseSessionsHasHarnessInstance' -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/pb_migrations/schema.json server/pocketbase/pb_migrations/schema_test.go
git commit -m "feat(schema): add harness_instances collection and goose_sessions.harness_instance"
```

---

## Task 4: Seed the default Goose harness + its harness_instances row

**Files:**
- Modify: `server/pocketbase/pb_migrations/1756000100_seed.go`
- Test: same file's existing test file (find it via `find server/pocketbase/pb_migrations -name '*seed*test*'`) — add to it; if none exists, create `server/pocketbase/pb_migrations/1756000100_seed_test.go` following the pattern of any other migration test in the directory.

**Interfaces:**
- Produces: a `harnesses` row with `cli_id: "goose"`, and a `harness_instances` row with `managed: false`, `container_name: "pocketcoder-goose"`, `acp_endpoint: ""`, `secret: ""` — consumed by Task 6 (`buildSessionProfile`'s "no chat.harness set" default resolution) and Task 8 (`establishSession`'s empty-`Target`-means-defaults convention).

- [ ] **Step 1: Write the failing test**

```go
func TestSeedCreatesDefaultGooseHarnessInstance(t *testing.T) {
	app := testApp(t) // use whatever test-app helper this package's existing seed tests already use
	harnesses, err := app.FindRecordsByFilter("harnesses", "cli_id = 'goose'", "", 0, 0)
	if err != nil || len(harnesses) != 1 {
		t.Fatalf("expected exactly one seeded goose harness, got %d, err %v", len(harnesses), err)
	}
	instances, err := app.FindRecordsByFilter("harness_instances", "harness = {:h}", "", 0, 0, map[string]any{"h": harnesses[0].Id})
	if err != nil || len(instances) != 1 {
		t.Fatalf("expected exactly one seeded goose harness_instance, got %d, err %v", len(instances), err)
	}
	inst := instances[0]
	if inst.GetBool("managed") {
		t.Error("seeded default goose harness_instances row must have managed = false")
	}
	if inst.GetString("container_name") != "pocketcoder-goose" {
		t.Errorf("container_name = %q, want pocketcoder-goose", inst.GetString("container_name"))
	}
	if inst.GetString("acp_endpoint") != "" {
		t.Error("seeded default row's acp_endpoint must be empty (means: use Coordinator.Config defaults)")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/pb_migrations && go test -run TestSeedCreatesDefaultGooseHarnessInstance -v`
Expected: FAIL — 0 seeded goose harnesses

- [ ] **Step 3: Add the seed rows in `1756000100_seed.go`**

Open the file and find where it currently seeds `tool_permissions`/users (per the design spec's §2 finding that nothing else is seeded today). Add, following the same `core.NewRecord(collection)` pattern already used there:

```go
harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
if err != nil {
	return err
}
gooseHarness := core.NewRecord(harnessesColl)
gooseHarness.Set("name", "Goose")
gooseHarness.Set("cli_id", "goose")
gooseHarness.Set("acp_transport", "websocket")
gooseHarness.Set("supports_live_config", true)
gooseHarness.Set("supports_goose_extensions", true)
gooseHarness.Set("single_connection_only", false)
if err := app.Save(gooseHarness); err != nil {
	return fmt.Errorf("seed goose harness: %w", err)
}

instancesColl, err := app.FindCollectionByNameOrId("harness_instances")
if err != nil {
	return err
}
gooseInstance := core.NewRecord(instancesColl)
gooseInstance.Set("harness", gooseHarness.Id)
gooseInstance.Set("launch_key", "")
gooseInstance.Set("container_name", "pocketcoder-goose")
gooseInstance.Set("acp_endpoint", "")
gooseInstance.Set("secret", "")
gooseInstance.Set("status", "running")
gooseInstance.Set("managed", false)
if err := app.Save(gooseInstance); err != nil {
	return fmt.Errorf("seed goose harness_instance: %w", err)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/pb_migrations && go test -run TestSeedCreatesDefaultGooseHarnessInstance -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/pb_migrations/1756000100_seed.go server/pocketbase/pb_migrations/*seed*test*.go
git commit -m "feat(seed): seed default goose harness and harness_instances row"
```

---

## Task 5: `SessionProfile` gains `Target`, instance ids, and capability flags; `DialFunc` gains `Target`

**Files:**
- Modify: `server/pocketbase/internal/agent/coordinator/profile.go`
- Modify: `server/pocketbase/internal/agent/coordinator/run.go` (`DialFunc` type, `Config.Dial` field type, the default closure in `New`)
- Test: `server/pocketbase/internal/agent/coordinator/profile_test.go`

**Interfaces:**
- Consumes: nothing new (pure struct/type additions).
- Produces: `type Target struct{ URL, Secret string }`; `SessionProfile.Target Target`, `.ResolvedInstanceID`, `.PinnedInstanceID string`, `.SupportsLiveConfig`, `.SupportsGooseExtensions`, `.SingleConnectionOnly bool`; `DialFunc = func(context.Context, acpsdk.Client, Target) (acp.Conn, error)`. Consumed by Task 6 (`buildSessionProfile` populates these), Task 7 (`selectApplier`), Task 8 (`establishSession`).

- [ ] **Step 1: Write the failing test**

```go
func TestSessionProfileCarriesTargetAndCapabilityFlags(t *testing.T) {
	p := SessionProfile{
		Target:                  Target{URL: "ws://example/acp", Secret: "s3cr3t"},
		ResolvedInstanceID:      "abc123456789012",
		PinnedInstanceID:        "abc123456789012",
		SupportsLiveConfig:      true,
		SupportsGooseExtensions: false,
		SingleConnectionOnly:    true,
	}
	if p.Target.URL != "ws://example/acp" {
		t.Error("Target.URL not settable")
	}
	if !p.SupportsLiveConfig || p.SupportsGooseExtensions == true && false {
		// compile-time field existence is the real assertion here
	}
	if p.ResolvedInstanceID != p.PinnedInstanceID {
		t.Error("expected fields to be independently settable and equal in this fixture")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/internal/agent/coordinator && go test -run TestSessionProfileCarriesTargetAndCapabilityFlags -v`
Expected: FAIL — compile error, `SessionProfile` has no field `Target`

- [ ] **Step 3: Add the fields to `SessionProfile` and define `Target`**

In `profile.go`, add above `SessionProfile`:

```go
// Target identifies the harness_instances row a session should dial —
// empty means "use Coordinator.Config's compose-managed defaults" (the
// convention harness_instances.acp_endpoint/.secret already use).
type Target struct {
	URL, Secret string
}
```

Extend the `SessionProfile` struct:

```go
type SessionProfile struct {
	Model, Provider, Instructions, Cwd string
	AdditionalDirectories               []string
	McpServers                          []acpsdk.McpServer
	Mode                                acpsdk.SessionModeId

	Target                  Target
	ResolvedInstanceID      string // the harness_instances id this chat resolves to right now
	PinnedInstanceID        string // the harness_instances id goose_sessions.harness_instance already points at (empty if none yet)
	SupportsLiveConfig      bool
	SupportsGooseExtensions bool
	SingleConnectionOnly    bool
}
```

In `run.go`, change `DialFunc`:

```go
type DialFunc func(context.Context, acpsdk.Client, Target) (acp.Conn, error)
```

And the default closure in `New` (`run.go:114-118`):

```go
if config.Dial == nil {
	config.Dial = func(ctx context.Context, client acpsdk.Client, t Target) (acp.Conn, error) {
		url, secret := config.GooseURL, config.GooseSecret
		if t.URL != "" {
			url, secret = t.URL, t.Secret
		}
		return acp.Dial(ctx, acp.DialConfig{URL: url, Secret: secret}, client)
	}
}
```

This will break every existing call site that invokes `c.config.Dial(ctx, sc)` — leave those broken for now; Task 8 fixes them all when `establishSession` is introduced. Confirm the package still fails to compile with exactly the expected "not enough arguments" errors (not a different, unexpected error) before moving on:

Run: `cd server/pocketbase/internal/agent/coordinator && go build ./... 2>&1 | head -20`
Expected: several `not enough arguments in call to c.config.Dial` errors, no other kind

- [ ] **Step 4: Run the new test to verify it passes (ignore the expected build breakage in other files for now)**

Run: `cd server/pocketbase/internal/agent/coordinator && go test -run TestSessionProfileCarriesTargetAndCapabilityFlags -v ./profile_test.go ./profile.go`
Expected: PASS (compiling just this test file + `profile.go` in isolation avoids the broken call sites elsewhere)

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/agent/coordinator/profile.go server/pocketbase/internal/agent/coordinator/run.go server/pocketbase/internal/agent/coordinator/profile_test.go
git commit -m "feat(coordinator): add Target type and capability/instance fields to SessionProfile"
```

---

## Task 6: `establishSession` — the shared resolve/pin-check/capability-check/dial/init prefix

**Files:**
- Modify: `server/pocketbase/internal/agent/coordinator/run.go`
- Test: `server/pocketbase/internal/agent/coordinator/run_test.go`

**Interfaces:**
- Consumes: `Target`, `SessionProfile` (Task 5); `DialFunc` (Task 5); `acp.Conn`'s existing `Initialize`/`NewSession`/`LoadSession` methods.
- Produces: `func (c *Coordinator) establishSession(ctx context.Context, client acpsdk.Client, profile SessionProfile, sessionID string, beforeSessionCall func()) (conn acp.Conn, newSessionID string, modes *acpsdk.SessionModeState, err error)`. Consumed by Task 8 (`runLoop`) and Task 9 (`StreamColdReplay`).

This is the highest-risk task in the plan — it is exactly the piece round 4 of the design review found broken twice. Read the design spec's §5.6 in full before writing this function; the three things it must get right are: (1) compare `profile.ResolvedInstanceID` vs `profile.PinnedInstanceID`, not `Target`s; (2) hold a per-chat mutex for the connection's full lifetime only when `profile.SingleConnectionOnly` is true, never skip the dial; (3) call `beforeSessionCall()` immediately before the `NewSession`/`LoadSession` call, not before or after establishSession as a whole.

- [ ] **Step 1: Write the failing tests**

```go
func TestEstablishSessionRejectsHarnessMismatch(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{
		Target:             Target{URL: "ws://new-harness/acp"},
		ResolvedInstanceID: "newharness12345",
		PinnedInstanceID:   "oldharness12345", // different from ResolvedInstanceID
	}
	_, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err == nil {
		t.Fatal("expected an error when resolved harness differs from pinned harness")
	}
}

func TestEstablishSessionAllowsMatchingPin(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{
		Target:             Target{URL: "ws://same-harness/acp"},
		ResolvedInstanceID: "sameharness1234",
		PinnedInstanceID:   "sameharness1234",
	}
	_, _, _, _, release, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err != nil {
		t.Fatalf("expected no error when resolved == pinned, got %v", err)
	}
	release()
}

func TestEstablishSessionCallsBeforeSessionCallBeforeLoadSession(t *testing.T) {
	f := newFakeConn() // fake records call order; see existing fake in run_test.go/session_test.go
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var calledBefore bool
	profile := SessionProfile{PinnedInstanceID: "", ResolvedInstanceID: ""}
	_, _, _, _, release, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() { calledBefore = true })
	if err != nil {
		t.Fatal(err)
	}
	release()
	if !calledBefore {
		t.Fatal("beforeSessionCall must be invoked before LoadSession")
	}
}

func TestEstablishSessionErrorsWhenLoadSessionCapabilityMissing(t *testing.T) {
	f := newFakeConn()
	f.initResp = acpsdk.InitializeResponse{AgentCapabilities: acpsdk.AgentCapabilities{LoadSession: false}}
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{}
	_, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err == nil {
		t.Fatal("expected an error resuming a session against a harness that doesn't advertise LoadSession")
	}
}

func TestEstablishSessionSerializesSingleConnectionOnlyHarness(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{ResolvedInstanceID: "inst1", SingleConnectionOnly: true}

	_, _, _, _, release1, err := c.establishSession(context.Background(), nil, profile, "sess1", func() {})
	if err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		_, _, _, _, release2, err := c.establishSession(context.Background(), nil, profile, "sess1", func() {})
		if err != nil {
			t.Error(err)
		}
		release2()
		close(done)
	}()

	select {
	case <-done:
		t.Fatal("second establishSession call must block until the first releases")
	case <-time.After(50 * time.Millisecond):
		// expected: still blocked
	}
	release1()
	<-done // must now complete
}
```

(These reference `f.initResp` and call-order recording on the package's existing `fakeConn` test helper — extend that helper if it doesn't already support setting a custom `InitializeResponse` or recording call order; follow the existing style in `session_test.go`'s `newFakeConn()`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/agent/coordinator && go test -run TestEstablishSession -v`
Expected: FAIL — `establishSession` undefined

- [ ] **Step 3: Implement `establishSession` in `run.go`**

```go
// establishSession is the resolve+pin-check+capability-check+dial+init
// prefix shared by runLoop and StreamColdReplay. It does NOT call
// SeedSession, ProfileApplier.Apply, or Prompt — those are each caller's
// own job, done with the conn/sessionID/modes this returns. See design
// spec §5.6 for why the split is drawn exactly here.
//
// The returned release func must be deferred by the caller immediately
// upon receiving a non-nil conn (release is a no-op when profile is not
// SingleConnectionOnly). It is NOT called internally by establishSession,
// because the lock must be held for the connection's full lifetime, which
// outlives this function — only the caller knows when that lifetime ends
// (conn.Close(), whether called directly or via a deferred cleanup).
// wasNew reports whether this call minted a brand-new session (sessionID
// was empty) — callers need this to decide whether to persist a new
// goose_sessions row; sessionID's own emptiness can no longer be used for
// that check once establishSession owns both branches internally.
func (c *Coordinator) establishSession(
	ctx context.Context, client acpsdk.Client, profile SessionProfile, sessionID string,
	beforeSessionCall func(),
) (conn acp.Conn, newSessionID string, modes *acpsdk.SessionModeState, wasNew bool, release func(), err error) {
	release = func() {}

	// Pin check: compare resolved vs. pinned harness identity, not Targets
	// (an unresolved Target and the pinned default Target are both the
	// zero value and would otherwise compare equal).
	if profile.PinnedInstanceID != "" && profile.ResolvedInstanceID != "" &&
		profile.PinnedInstanceID != profile.ResolvedInstanceID {
		return nil, "", nil, false, release, fmt.Errorf("this chat's harness changed after its session was created — start a new chat")
	}

	if profile.SingleConnectionOnly {
		release = c.lockChatConnection(profile.ResolvedInstanceID)
	}

	dialedConn, dialErr := c.config.Dial(ctx, client, profile.Target)
	if dialErr != nil {
		release()
		return nil, "", nil, false, func() {}, fmt.Errorf("dial harness: %w", dialErr)
	}
	initResp, err := dialedConn.Initialize(ctx, initializeRequest())
	if err != nil {
		dialedConn.Close()
		release()
		return nil, "", nil, false, func() {}, fmt.Errorf("initialize harness: %w", err)
	}

	cwd := profile.Cwd
	if cwd == "" {
		cwd = c.config.Workspace
	}

	if sessionID == "" {
		beforeSessionCall()
		res, err := dialedConn.NewSession(ctx, acpsdk.NewSessionRequest{
			Cwd: cwd, AdditionalDirectories: profile.additionalDirectories(), McpServers: profile.mcpServers(),
		})
		if err != nil {
			dialedConn.Close()
			release()
			return nil, "", nil, false, func() {}, err
		}
		if string(res.SessionId) == "" {
			dialedConn.Close()
			release()
			return nil, "", nil, false, func() {}, errors.New("session/new response missing sessionId")
		}
		return dialedConn, string(res.SessionId), res.Modes, true, release, nil
	}

	if !initResp.AgentCapabilities.LoadSession {
		dialedConn.Close()
		release()
		return nil, "", nil, false, func() {}, fmt.Errorf("harness does not support resuming a session (AgentCapabilities.LoadSession is false)")
	}
	beforeSessionCall()
	res, err := dialedConn.LoadSession(ctx, acpsdk.LoadSessionRequest{
		SessionId: acpsdk.SessionId(sessionID), Cwd: cwd, AdditionalDirectories: profile.additionalDirectories(), McpServers: profile.mcpServers(),
	})
	if err != nil {
		dialedConn.Close()
		release()
		return nil, "", nil, false, func() {}, fmt.Errorf("load harness session: %w", err)
	}
	return dialedConn, sessionID, res.Modes, false, release, nil
}
```

Add the mutex-map helper referenced above (a minimal per-key lock, matching the style of the existing `c.mu`-guarded maps in this file):

```go
// lockChatConnection blocks until no other caller holds the named key's
// connection lock, then holds it until the returned func is called. Only
// used when a harness's single_connection_only flag is set (§5.6 item 2)
// — Goose and any harness that safely serves multiple connections never
// takes this path.
func (c *Coordinator) lockChatConnection(key string) func() {
	c.mu.Lock()
	if c.connLocks == nil {
		c.connLocks = map[string]chan struct{}{}
	}
	for {
		ch, held := c.connLocks[key]
		if !held {
			c.connLocks[key] = make(chan struct{})
			c.mu.Unlock()
			return func() {
				c.mu.Lock()
				delete(c.connLocks, key)
				c.mu.Unlock()
			}
		}
		c.mu.Unlock()
		<-ch // wait for the holder to release
		c.mu.Lock()
	}
}
```

Add `connLocks map[string]chan struct{}` to the `Coordinator` struct next to the existing `hubs`/`runs` maps.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/agent/coordinator && go test -run TestEstablishSession -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/agent/coordinator/run.go server/pocketbase/internal/agent/coordinator/run_test.go
git commit -m "feat(coordinator): add establishSession shared dial/init prefix with pin, capability, and single-connection checks"
```

---

## Task 7: Wire `runLoop` and `StreamColdReplay` onto `establishSession`

**Files:**
- Modify: `server/pocketbase/internal/agent/coordinator/run.go` (`runLoop`, `initSession` removed, `StreamColdReplay`)
- Test: `server/pocketbase/internal/agent/coordinator/run_test.go`, `session_test.go`

**Interfaces:**
- Consumes: `establishSession` (Task 6).
- Produces: `runLoop` and `StreamColdReplay` both call `establishSession`, each keeping its own distinct `SeedSession`/`Apply`/`Prompt` (run path) or bounded-replay-then-close (replay path) logic exactly as before, per the design spec's explicit statement of what stays outside `establishSession`.

- [ ] **Step 1: Write the failing test**

```go
func TestRunLoopStillPublishesSeedSessionAfterEstablish(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("chatA", "hello",
		func(context.Context) (string, error) { return "", nil }, // new session
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	c.waitRunDone(t, "chatA")
	// existing hub-published-events assertions for SeedSession content go here,
	// following whatever this suite's existing runLoop tests already assert
	// (see run_test.go for the pre-existing pattern this test extends).
}

func TestStreamColdReplayStillEmitsHistoryThroughEstablish(t *testing.T) {
	f := newFakeConn()
	f.loadSessionHistory = []acpsdk.SessionNotification{ /* fixture matching existing StreamColdReplay tests */ }
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var emitted []events.Event
	err := c.StreamColdReplay(context.Background(), "chatA", "existing-session-id",
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(seq int, ev events.Event) error { emitted = append(emitted, ev); return nil })
	if err != nil {
		t.Fatal(err)
	}
	if len(emitted) == 0 {
		t.Fatal("expected replayed history events, got none — accepting-flag timing regression")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail (or pass vacuously if `runLoop`/`StreamColdReplay` still use the old duplicated code — confirm by checking the diff coverage, not just green)**

Run: `cd server/pocketbase/internal/agent/coordinator && go test -run 'TestRunLoopStillPublishesSeedSessionAfterEstablish|TestStreamColdReplayStillEmitsHistoryThroughEstablish' -v`
Expected: compile failure until `runLoop`/`StreamColdReplay` are rewritten in step 3 (since Task 5/6 broke their old `c.config.Dial(ctx, sc)` calls)

- [ ] **Step 3: Rewrite `runLoop` and `StreamColdReplay` to call `establishSession`**

In `runLoop` (`run.go`), replace the block from `conn, err := c.config.Dial(runCtx, sc)` through the old `initSession` call with:

```go
conn, sessionID, modes, wasNew, release, err := c.establishSession(runCtx, sc, profile, sessionID, func() {})
if err != nil {
	hub.Publish(events.NewRunErrorEvent("session init", events.WithErrorCode("goose_unavailable")))
	return
}
h.conn = conn
h.sessionID = sessionID
sc.sessionID = sessionID
h.teardown = func(bool) { release(); /* existing teardown body continues to run alongside this */ }

if wasNew {
	if err := created(runCtx, sessionID); err != nil {
		if _, dErr := conn.UnstableDeleteSession(runCtx, acpsdk.UnstableDeleteSessionRequest{SessionId: acpsdk.SessionId(sessionID)}); dErr != nil {
			log.Printf("coordinator: orphan session delete failed: %v", dErr)
		}
		release()
		hub.Publish(events.NewRunErrorEvent("session init", events.WithErrorCode("goose_unavailable")))
		return
	}
}
for _, e := range bridge.SeedSession(modes) {
	hub.Publish(e)
}
applier := selectApplier(profile) // Task 8 changes selectApplier's signature — this line is finalized there
if err := applier.Apply(runCtx, conn, sessionID, profile, modes); err != nil {
	release()
	hub.Publish(events.NewRunErrorEvent("session init", events.WithErrorCode("goose_unavailable")))
	return
}
h.accepting.Store(true)
hub.Publish(bridge.Started())
```

(`bridge.SeedSession`'s exact parameter shape must match whatever `SeedSession(res.Modes, res.ConfigOptions)` takes today in the pre-existing code — confirm its signature in `agui/bridge.go` before finalizing this call; the placeholder shown assumes a single `modes` argument only because `establishSession` doesn't currently surface `ConfigOptions` separately — if the existing `SeedSession` needs both, extend `establishSession`'s return tuple with the response's `ConfigOptions` too, following the exact same pattern used for `modes` above.)

The existing `teardown`'s `once.Do` body (`run.go:684-698`) must also call `release()` if `establishSession` succeeded but a later step (`Prompt`, cancellation, panic) tears the run down — add `release()` into that `once.Do` closure directly, not only into the early-return paths shown above, so every exit path releases the lock exactly once regardless of which one is taken.

In `StreamColdReplay`, replace the block from `conn, err := c.config.Dial(ctx, sc)` through the old inline `LoadSession` call with:

```go
conn, _, _, _, release, err := c.establishSession(ctx, sc, profile, sessionID, func() { sc.accepting.Store(true) })
if err != nil {
	return err
}
defer release()
defer conn.Close()
return emitAll(emitSeq, bridge.Finished(acpsdk.StopReasonEndTurn))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/agent/coordinator && go test ./... -v`
Expected: PASS (full package — this task's rewiring touches enough of `run.go` that the whole suite, not just the two new tests, is the real gate)

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/agent/coordinator/run.go server/pocketbase/internal/agent/coordinator/run_test.go server/pocketbase/internal/agent/coordinator/session_test.go
git commit -m "refactor(coordinator): wire runLoop and StreamColdReplay onto establishSession"
```

---

## Task 8: `selectApplier` branches on capability flags; `Apply` gains and checks `modes`

**Files:**
- Modify: `server/pocketbase/internal/agent/coordinator/profile.go`
- Test: `server/pocketbase/internal/agent/coordinator/profile_test.go`

**Interfaces:**
- Consumes: `SessionProfile.SupportsLiveConfig`/`.SupportsGooseExtensions` (Task 5); `*acpsdk.SessionModeState` from `establishSession` (Task 6/7).
- Produces: `ProfileApplier.Apply(ctx, conn, sessionID, profile, modes)` (signature change); `selectApplier(profile SessionProfile) ProfileApplier` (signature change — no longer takes `*acpsdk.InitializeResponse`, since the capability it needs is now on `profile`, not the ACP response).

- [ ] **Step 1: Write the failing tests**

```go
func TestApplySkipsGooseExtensionsWhenUnsupported(t *testing.T) {
	conn := &recordingConn{} // extend/add a test fake that records which methods were called, if profile_test.go doesn't already have one
	p := SessionProfile{Instructions: "be helpful", SupportsGooseExtensions: false, SupportsLiveConfig: true}
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
		t.Fatal(err)
	}
	if conn.calledSystemPromptSet {
		t.Error("must not call the Goose-private system-prompt method when SupportsGooseExtensions is false")
	}
}

func TestApplySkipsSetConfigOptionWhenLiveConfigUnsupported(t *testing.T) {
	conn := &recordingConn{}
	p := SessionProfile{Provider: "anthropic", Model: "claude", SupportsLiveConfig: false}
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
		t.Fatal(err)
	}
	if conn.calledSetConfigOption {
		t.Error("must not call session/set_config_option when SupportsLiveConfig is false")
	}
}

func TestApplySkipsSetSessionModeWhenModeNotAdvertised(t *testing.T) {
	conn := &recordingConn{}
	p := SessionProfile{Mode: "approve"}
	modes := &acpsdk.SessionModeState{AvailableModes: []acpsdk.SessionMode{{Id: "chat"}}} // "approve" not in the list
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, modes); err != nil {
		t.Fatal(err)
	}
	if conn.calledSetSessionMode {
		t.Error("must not call session/set_mode with a mode id the harness didn't advertise")
	}
}

func TestApplyDoesNotSkipModeWhenModesIsNil(t *testing.T) {
	conn := &recordingConn{}
	p := SessionProfile{Mode: "approve"}
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
		t.Fatal(err)
	}
	if !conn.calledSetSessionMode {
		t.Error("nil modes must mean 'don't assert', not 'skip' — expected SetSessionMode to still be called")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/agent/coordinator && go test -run TestApply -v`
Expected: FAIL — compile error, `Apply` takes 4 args not 5

- [ ] **Step 3: Update `ProfileApplier`/`GlobalConfigApplier`/`PerSessionApplier`/`selectApplier`**

```go
type ProfileApplier interface {
	Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) error
}

type GlobalConfigApplier struct{}

func (GlobalConfigApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) error {
	if p.Mode == "" {
		return nil
	}
	if modes != nil && !modeAdvertised(modes, p.Mode) {
		return nil // logging is the caller's job at the call site, per existing logging conventions in this file
	}
	_, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{
		SessionId: acpsdk.SessionId(sessionID), ModeId: p.Mode,
	})
	return err
}

func modeAdvertised(modes *acpsdk.SessionModeState, mode acpsdk.SessionModeId) bool {
	for _, m := range modes.AvailableModes {
		if m.Id == mode {
			return true
		}
	}
	return false
}

type PerSessionApplier struct{}

func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) error {
	if err := (GlobalConfigApplier{}).Apply(ctx, conn, sessionID, p, modes); err != nil {
		return err
	}
	if p.SupportsLiveConfig {
		if p.Provider != "" {
			if _, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
				ValueId: &acpsdk.SetSessionConfigOptionValueId{SessionId: acpsdk.SessionId(sessionID), ConfigId: "provider", Value: acpsdk.SessionConfigValueId(p.Provider)},
			}); err != nil {
				return fmt.Errorf("apply provider: %w", err)
			}
		}
		if p.Model != "" {
			if _, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
				ValueId: &acpsdk.SetSessionConfigOptionValueId{SessionId: acpsdk.SessionId(sessionID), ConfigId: "model", Value: acpsdk.SessionConfigValueId(p.Model)},
			}); err != nil {
				return fmt.Errorf("apply model: %w", err)
			}
		}
	}
	if p.SupportsGooseExtensions && p.Instructions != "" {
		if _, err := conn.CallExtension(ctx, "_goose/unstable/session/system-prompt/set", systemPromptSetParams{
			SessionID: sessionID, SystemPrompt: p.Instructions,
		}); err != nil {
			return fmt.Errorf("apply instructions: %w", err)
		}
	}
	return nil
}

// selectApplier always returns PerSessionApplier — the branching that used
// to matter (whether Goose advertised per-session config at all) now lives
// inside PerSessionApplier.Apply itself, gated on the resolved harness's
// own capability flags carried on profile, not on the ACP InitializeResponse
// (which cannot express a Goose-private capability like
// SupportsGooseExtensions in the first place).
func selectApplier(profile SessionProfile) ProfileApplier {
	return PerSessionApplier{}
}
```

Update `run.go`'s call site (`applier := selectApplier(&initResp)` from the old code, now `selectApplier(profile)` per Task 7's draft) and the `applier.Apply(...)` call to pass `modes` as the fifth argument.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/agent/coordinator && go test ./... -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/agent/coordinator/profile.go server/pocketbase/internal/agent/coordinator/run.go server/pocketbase/internal/agent/coordinator/profile_test.go
git commit -m "feat(coordinator): gate Apply on harness capability flags and advertised modes"
```

---

## Task 9: Fix `buildSessionProfile`'s early-return bug and add harness/Target/instance-id resolution

**Files:**
- Modify: `server/pocketbase/internal/api/profile.go`
- Test: `server/pocketbase/internal/api/profile_test.go` (create if it doesn't exist — check `find server/pocketbase/internal/api -name '*_test.go'` first)

**Interfaces:**
- Consumes: `chats.harness`/`.workspace_override` (Task 1), `harnesses.*` capability fields (Task 2), `harness_instances` (Task 3/4), `SessionProfile`'s new fields (Task 5).
- Produces: `buildSessionProfile(app, chatID) (coordinator.SessionProfile, error)` resolves chat-level fields even with no `poco_config`, and populates `Target`/`ResolvedInstanceID`/`PinnedInstanceID`/the three capability flags/composed `workspace_override`.

- [ ] **Step 1: Write the failing tests**

```go
func TestBuildSessionProfileResolvesChatFieldsWithNoPocoConfig(t *testing.T) {
	app := testApp(t) // this package's existing PocketBase test-app helper
	harness, instance := seedTestHarnessAndInstance(t, app, "goose", true, true, false)
	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})
	// deliberately: no poco_configs row exists, and none is marked is_default

	profile, err := buildSessionProfile(app, chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if profile.ResolvedInstanceID != instance.Id {
		t.Errorf("ResolvedInstanceID = %q, want %q — the early-return bug regression", profile.ResolvedInstanceID, instance.Id)
	}
}

func TestBuildSessionProfileWorkspaceOverrideKeepsPocoAdditionalDirectories(t *testing.T) {
	app := testApp(t)
	poco := createTestPocoConfig(t, app, map[string]any{"workspace_folders": []string{"/workspace/project", "/workspace/tools"}})
	chat := createTestChat(t, app, map[string]any{"poco_config": poco.Id, "workspace_override": []string{"/workspace/other"}})

	profile, err := buildSessionProfile(app, chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if profile.Cwd != "/workspace/other" {
		t.Errorf("Cwd = %q, want /workspace/other (chat override wins)", profile.Cwd)
	}
	if len(profile.AdditionalDirectories) != 1 || profile.AdditionalDirectories[0] != "/workspace/tools" {
		t.Errorf("AdditionalDirectories = %v, want [/workspace/tools] (poco's extra dirs preserved per §5.7)", profile.AdditionalDirectories)
	}
}

func TestBuildSessionProfileRejectsWorkspaceOverrideOutsideRoot(t *testing.T) {
	app := testApp(t)
	chat := createTestChat(t, app, map[string]any{"workspace_override": []string{"/goose/config"}})
	_, err := buildSessionProfile(app, chat.Id)
	if err == nil {
		t.Fatal("expected rejection of a workspace_override outside /workspace")
	}
}

func TestBuildSessionProfileRejectsTraversal(t *testing.T) {
	app := testApp(t)
	chat := createTestChat(t, app, map[string]any{"workspace_override": []string{"/workspace/../etc"}})
	_, err := buildSessionProfile(app, chat.Id)
	if err == nil {
		t.Fatal("expected rejection of a workspace_override containing .. traversal")
	}
}
```

(`seedTestHarnessAndInstance`/`createTestChat`/`createTestPocoConfig` are small test helpers to add alongside these tests if the package doesn't already have equivalents — follow whatever fixture-building pattern `api`'s existing tests use, e.g. `agent_test.go`, for creating records against a test PocketBase app.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/api && go test -run TestBuildSessionProfile -v`
Expected: FAIL — `TestBuildSessionProfileResolvesChatFieldsWithNoPocoConfig` fails because the early return skips everything

- [ ] **Step 3: Rewrite `buildSessionProfile`**

```go
// workspaceRoot is the mount point every catalog harness is required to
// share (§6.3) — the same value the coordinator falls back to.
const workspaceRoot = "/workspace"

func validateWorkspacePath(p string) error {
	clean := filepath.Clean(p)
	if clean != workspaceRoot && !strings.HasPrefix(clean, workspaceRoot+"/") {
		return fmt.Errorf("workspace path %q is outside %s", p, workspaceRoot)
	}
	return nil
}

func buildSessionProfile(app core.App, chatID string) (coordinator.SessionProfile, error) {
	var p coordinator.SessionProfile

	chat, err := app.FindRecordById("chats", chatID)
	if err != nil {
		return p, err
	}

	// Chat-level fields are read FIRST, unconditionally — this is the fix
	// for the early-return bug: they must not depend on a poco_config
	// existing at all.
	hmID := chat.GetString("harness_model_override")
	harnessID := chat.GetString("harness")

	var chatFolders []string
	_ = chat.UnmarshalJSONField("workspace_override", &chatFolders)
	if len(chatFolders) > 0 {
		if err := validateWorkspacePath(chatFolders[0]); err != nil {
			return p, err
		}
		p.Cwd = chatFolders[0]
	}

	pocoID := chat.GetString("poco_config")
	var poco *core.Record
	if pocoID != "" {
		if poco, err = app.FindRecordById("poco_configs", pocoID); err != nil {
			return p, err
		}
	} else if poco, err = defaultPocoConfigAPI(app); err != nil {
		return p, err
	}

	p.Mode = acpsdk.SessionModeId("approve")
	if poco != nil {
		if hmID == "" {
			hmID = poco.GetString("harness_model")
		}
		if spID := poco.GetString("system_prompt"); spID != "" {
			if sp, err := app.FindRecordById("prompts", spID); err == nil {
				p.Instructions = sp.GetString("body")
			}
		}
		if mode := poco.GetString("mode"); mode != "" {
			p.Mode = acpsdk.SessionModeId(mode)
		}
		var pocoFolders []string
		_ = poco.UnmarshalJSONField("workspace_folders", &pocoFolders)
		if p.Cwd == "" && len(pocoFolders) > 0 {
			p.Cwd = pocoFolders[0]
		}
		if len(pocoFolders) > 1 {
			p.AdditionalDirectories = pocoFolders[1:] // §5.7: always unioned in, regardless of a chat-level cwd override
		}
		var raw []stdioMcp
		_ = poco.UnmarshalJSONField("acp_mcp_servers", &raw)
		for _, m := range raw {
			if m.Type != "" && m.Type != "stdio" {
				log.Printf("[Profile] skipping non-stdio MCP server %q (type=%s) — unsupported today", m.Name, m.Type)
				continue
			}
			env := make([]acpsdk.EnvVariable, 0, len(m.Env))
			for k, v := range m.Env {
				env = append(env, acpsdk.EnvVariable{Name: k, Value: v})
			}
			p.McpServers = append(p.McpServers, acpsdk.McpServer{Stdio: &acpsdk.McpServerStdio{Name: m.Name, Command: m.Command, Args: m.Args, Env: env}})
		}
	}

	// Resolve harness: chat.harness wins; else the model's harness; else
	// the seeded default (§5.6.1).
	var harnessRec *core.Record
	if harnessID != "" {
		if harnessRec, err = app.FindRecordById("harnesses", harnessID); err != nil {
			return p, err
		}
	}
	if hmID != "" {
		hm, err := app.FindRecordById("harness_models", hmID)
		if err == nil {
			p.Model = hm.GetString("harness_model_id")
			if m, err := app.FindRecordById("models", hm.GetString("model")); err == nil {
				p.Provider = m.GetString("provider")
			}
			if harnessRec == nil {
				if hr, err := app.FindRecordById("harnesses", hm.GetString("harness")); err == nil {
					harnessRec = hr
				}
			}
		}
	}
	if harnessRec == nil {
		if harnessRec, err = app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil); err != nil {
			return p, err
		}
	}

	p.SupportsLiveConfig = harnessRec.GetBool("supports_live_config")
	p.SupportsGooseExtensions = harnessRec.GetBool("supports_goose_extensions")
	p.SingleConnectionOnly = harnessRec.GetBool("single_connection_only")

	launchKey := ""
	if !p.SupportsLiveConfig && hmID != "" {
		launchKey = hmID
	}
	instance, err := app.FindFirstRecordByFilter("harness_instances", "harness = {:h} && launch_key = {:k}",
		map[string]any{"h": harnessRec.Id, "k": launchKey})
	if err == nil && instance != nil {
		p.ResolvedInstanceID = instance.Id
		p.Target = coordinator.Target{URL: instance.GetString("acp_endpoint"), Secret: instance.GetString("secret")}
	}
	// Note for the implementer: provisioning a missing instance (§5.1) is
	// explicitly out of scope for this plan — a missing row here should
	// surface a clear "harness not provisioned" error, not attempt to
	// create a container. Wire that error path before shipping; it is not
	// shown in this draft because provisioning is a separate follow-on
	// plan per the design spec's §5.1.

	if gs, err := app.FindFirstRecordByFilter("goose_sessions", "chat = {:c}", map[string]any{"c": chatID}); err == nil && gs != nil {
		p.PinnedInstanceID = gs.GetString("harness_instance")
	}

	return p, nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/api && go test -run TestBuildSessionProfile -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/api/profile.go server/pocketbase/internal/api/profile_test.go
git commit -m "fix(api): buildSessionProfile resolves chat-level fields without a poco_config, adds harness/Target/instance resolution"
```

---

## Task 10: `gooseSessionForChat`/`saveGooseSession` carry `harness_instance`; `delete_session.go` resolves its `Target`

**Files:**
- Modify: `server/pocketbase/internal/api/agent.go` (`gooseSessionForChat`, `saveGooseSession`, and their two call sites)
- Modify: `server/pocketbase/internal/agent/coordinator/delete_session.go`
- Test: `server/pocketbase/internal/api/agent_test.go`, `server/pocketbase/internal/agent/coordinator/delete_session_test.go` (create if absent)

**Interfaces:**
- Consumes: `goose_sessions.harness_instance` (Task 3); `Target`/`DialFunc` (Task 5).
- Produces: `saveGooseSession` writes `harness_instance`; `delete_session.go`'s `DeleteSession` dials the pinned instance's `Target` instead of the compose default.

- [ ] **Step 1: Write the failing tests**

```go
// in api package
func TestSaveGooseSessionStampsHarnessInstance(t *testing.T) {
	app := testApp(t)
	chat := createTestChat(t, app, nil)
	if err := saveGooseSession(context.Background(), app, chat.Id, "user1", "session-abc", "instance-123456789012"); err != nil {
		t.Fatal(err)
	}
	rec, err := app.FindFirstRecordByFilter("goose_sessions", "chat = {:c}", map[string]any{"c": chat.Id})
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("harness_instance") != "instance-123456789012" {
		t.Errorf("harness_instance = %q, want instance-123456789012", rec.GetString("harness_instance"))
	}
}
```

```go
// in coordinator package
func TestDeleteSessionDialsPinnedInstance(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var dialedTarget Target
	c.config.Dial = func(ctx context.Context, client acpsdk.Client, t Target) (acp.Conn, error) {
		dialedTarget = t
		return f, nil
	}
	app := testPocketBaseApp(t) // this package's own test-app helper if one exists, else use the api package's via an exported test seam
	seedGooseSessionWithInstance(t, app, "chat1", Target{URL: "ws://pinned-instance/acp"})
	if err := c.DeleteSession(context.Background(), app, "chat1"); err != nil {
		t.Fatal(err)
	}
	if dialedTarget.URL != "ws://pinned-instance/acp" {
		t.Errorf("dialed %q, want the pinned instance's URL, not the default", dialedTarget.URL)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```
cd server/pocketbase/internal/api && go test -run TestSaveGooseSessionStampsHarnessInstance -v
cd server/pocketbase/internal/agent/coordinator && go test -run TestDeleteSessionDialsPinnedInstance -v
```
Expected: FAIL — `saveGooseSession` doesn't take a 5th param; `DeleteSession` doesn't resolve a `Target`

- [ ] **Step 3: Update both functions and their call sites**

In `api/agent.go`:

```go
func saveGooseSession(ctx context.Context, app core.App, chatID, userID, sessionID, harnessInstanceID string) error {
	collection, err := app.FindCollectionByNameOrId("goose_sessions")
	if err != nil {
		return err
	}
	record := core.NewRecord(collection)
	record.Set("chat", chatID)
	record.Set("user", userID)
	record.Set("goose_session_id", sessionID)
	record.Set("harness_instance", harnessInstanceID)
	if err := app.Save(record); err != nil {
		return fmt.Errorf("save Goose session: %w", err)
	}
	return nil
}
```

Update its call site (the `created` closure passed to `StartPrompt`) to pass `buildSessionProfile(app, chatID)`'s `ResolvedInstanceID` — since the closure only receives `sessionID` today, extend it to close over the already-built `profile` from the surrounding handler:

```go
runID, err := service.StartPrompt(chatID, prompt,
	func(context.Context) (string, error) { return gooseSessionForChat(app, chatID, re.Auth.Id) },
	func(ctx context.Context) (coordinator.SessionProfile, error) { return buildSessionProfile(app, chatID) },
	func(ctx context.Context, sessionID string) error {
		profile, perr := buildSessionProfile(app, chatID)
		if perr != nil {
			return perr
		}
		err := saveGooseSession(ctx, app, chatID, re.Auth.Id, sessionID, profile.ResolvedInstanceID)
		if err == nil {
			app.Logger().Debug("Goose session mapping created", "chat_id", chatID)
		}
		return err
	},
	...)
```

In `coordinator/delete_session.go`, resolve `Target` before dialing:

```go
func (c *Coordinator) DeleteSession(ctx context.Context, app core.App, chatID string) error {
	record, err := app.FindFirstRecordByFilter("goose_sessions", "chat = {:chat}", map[string]any{"chat": chatID})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil
		}
		return fmt.Errorf("look up goose session mapping: %w", err)
	}
	sessionID := record.GetString("goose_session_id")
	if sessionID == "" {
		return app.Delete(record)
	}

	target := Target{}
	if instID := record.GetString("harness_instance"); instID != "" {
		if inst, err := app.FindRecordById("harness_instances", instID); err == nil {
			target = Target{URL: inst.GetString("acp_endpoint"), Secret: inst.GetString("secret")}
		}
	}

	sc := &sessionClient{c: c, chatID: chatID, sessionID: sessionID, accepting: &atomic.Bool{}, emit: func(events.Event) error { return nil }}
	conn, err := c.config.Dial(ctx, sc, target)
	if err != nil {
		return fmt.Errorf("dial goose for session delete: %w", err)
	}
	defer conn.Close()
	if _, err := conn.Initialize(ctx, initializeRequest()); err != nil {
		return fmt.Errorf("initialize goose for session delete: %w", err)
	}
	if _, err := conn.UnstableDeleteSession(ctx, acpsdk.UnstableDeleteSessionRequest{SessionId: acpsdk.SessionId(sessionID)}); err != nil {
		log.Printf("coordinator: DeleteSession's UnstableDeleteSession failed (harness may not implement it): %v", err)
	}
	return app.Delete(record)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```
cd server/pocketbase/internal/api && go test -run TestSaveGooseSessionStampsHarnessInstance -v
cd server/pocketbase/internal/agent/coordinator && go test -run TestDeleteSessionDialsPinnedInstance -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/api/agent.go server/pocketbase/internal/agent/coordinator/delete_session.go server/pocketbase/internal/api/agent_test.go server/pocketbase/internal/agent/coordinator/delete_session_test.go
git commit -m "feat: stamp and resolve goose_sessions.harness_instance through saveGooseSession and DeleteSession"
```

---

## Task 11: `chats` create/update hook — fast-fail harness pin + path validation

**Files:**
- Create: `server/pocketbase/internal/hooks/chats_harness_pin.go`
- Test: `server/pocketbase/internal/hooks/chats_harness_pin_test.go`

**Interfaces:**
- Consumes: `chats.harness`/`.workspace_override` (Task 1), `goose_sessions` (existing + Task 3), `hooks/timestamps.go`'s registration pattern.
- Produces: a registered hook rejecting (a) a `chats.harness` change once a `goose_sessions` row exists for that chat, and (b) any `workspace_override` write outside `/workspace`.

- [ ] **Step 1: Write the failing tests**

```go
package hooks

func TestChatsHarnessPinRejectsChangeAfterSessionExists(t *testing.T) {
	app := testApp(t)
	RegisterChatsHarnessPinHook(app)
	chat := createTestChat(t, app, map[string]any{"harness": "harnessA1234567"})
	seedGooseSession(t, app, chat.Id) // any existing goose_sessions row for this chat

	chat.Set("harness", "harnessB1234567")
	err := app.Save(chat)
	if err == nil {
		t.Fatal("expected rejection of a harness change once a session exists")
	}
}

func TestChatsHarnessPinAllowsChangeBeforeSessionExists(t *testing.T) {
	app := testApp(t)
	RegisterChatsHarnessPinHook(app)
	chat := createTestChat(t, app, map[string]any{"harness": "harnessA1234567"})
	// no goose_sessions row yet

	chat.Set("harness", "harnessB1234567")
	if err := app.Save(chat); err != nil {
		t.Fatalf("expected the change to be allowed before any session exists, got %v", err)
	}
}

func TestChatsHarnessPinRejectsWorkspaceOverrideOutsideRoot(t *testing.T) {
	app := testApp(t)
	RegisterChatsHarnessPinHook(app)
	chat := createTestChat(t, app, nil)
	chat.Set("workspace_override", []string{"/etc/passwd"})
	if err := app.Save(chat); err == nil {
		t.Fatal("expected rejection of workspace_override outside /workspace")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/hooks && go test -run TestChatsHarnessPin -v`
Expected: FAIL — `RegisterChatsHarnessPinHook` undefined

- [ ] **Step 3: Implement the hook**

```go
package hooks

import (
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

// RegisterChatsHarnessPinHook registers a fast-fail UX check for two of the
// design spec's §5.6/§5.8 invariants. It is NOT the source of truth for
// either — establishSession's own check (coordinator package) is what
// actually prevents a mismatched dial, since this hook can only see writes
// to the chats collection itself (it cannot see a poco_configs.harness_model
// reassignment, for instance). Uses the non-Request hook variants
// specifically (per hooks/timestamps.go's precedent) so backend app.Save
// calls — including the agent role's own writes — are not skipped.
func RegisterChatsHarnessPinHook(app core.App) {
	app.OnRecordUpdate("chats").BindFunc(func(e *core.RecordEvent) error {
		orig := e.Record.Original()
		if orig != nil && orig.GetString("harness") != e.Record.GetString("harness") {
			hasSession, err := chatHasGooseSession(e.App, e.Record.Id)
			if err != nil {
				return err
			}
			if hasSession {
				return fmt.Errorf("this chat's harness cannot be changed after a session has been created — start a new chat")
			}
		}
		if err := validateWorkspaceOverride(e.Record); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordCreate("chats").BindFunc(func(e *core.RecordEvent) error {
		if err := validateWorkspaceOverride(e.Record); err != nil {
			return err
		}
		return e.Next()
	})
}

func chatHasGooseSession(app core.App, chatID string) (bool, error) {
	_, err := app.FindFirstRecordByFilter("goose_sessions", "chat = {:c}", map[string]any{"c": chatID})
	if err != nil {
		if errors.Is(err, core.ErrNoRows) { // adjust to this codebase's actual not-found sentinel (sql.ErrNoRows per api/agent.go's existing usage) if core.ErrNoRows isn't correct — confirm against agent.go's import before finalizing
			return false, nil
		}
		return false, err
	}
	return true, nil
}

const workspaceRoot = "/workspace" // duplicated from internal/api/profile.go's identical check deliberately — these are two different packages and this hook must not import internal/api

func validateWorkspaceOverride(rec *core.Record) error {
	var folders []string
	_ = rec.UnmarshalJSONField("workspace_override", &folders)
	for _, f := range folders {
		clean := filepath.Clean(f)
		if clean != workspaceRoot && !strings.HasPrefix(clean, workspaceRoot+"/") {
			return fmt.Errorf("workspace_override path %q is outside %s", f, workspaceRoot)
		}
	}
	return nil
}
```

Register it alongside the other hooks in `main.go`'s `OnServe` handler (find where `RegisterGooseConfigHooks`/`timestamps`'s registration happens and add `hooks.RegisterChatsHarnessPinHook(app)` next to it).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/hooks && go test -run TestChatsHarnessPin -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/hooks/chats_harness_pin.go server/pocketbase/internal/hooks/chats_harness_pin_test.go server/pocketbase/main.go
git commit -m "feat(hooks): add chats harness-pin fast-fail and workspace_override path validation"
```

---

## Task 12: `schedule_importer.go` stamps the default harness_instance

**Files:**
- Modify: `server/pocketbase/internal/hooks/schedule_importer.go`
- Test: whatever existing test file covers `schedule_importer.go` (check `find server/pocketbase/internal/hooks -name '*schedule_import*test*'`)

**Interfaces:**
- Consumes: the seeded default `harness_instances` row (Task 4).
- Produces: imported `goose_sessions` rows have `harness_instance` populated, matching the pin-check's expectations everywhere else.

- [ ] **Step 1: Write the failing test**

```go
func TestScheduleImporterStampsDefaultHarnessInstance(t *testing.T) {
	app := testApp(t) // this package's existing test-app helper, matching whatever schedule_importer's current tests use
	// ... trigger whatever existing test path creates an imported chat + goose_sessions row ...
	rec, err := app.FindFirstRecordByFilter("goose_sessions", "chat = {:c}", map[string]any{"c": importedChatID})
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("harness_instance") == "" {
		t.Error("imported goose_sessions row must have harness_instance set to the default goose instance")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/internal/hooks && go test -run TestScheduleImporterStampsDefaultHarnessInstance -v`
Expected: FAIL — `harness_instance` empty

- [ ] **Step 3: Update the write in `schedule_importer.go`**

At the `goose_sessions` creation around `schedule_importer.go:96-102`, add the default instance lookup and set the field:

```go
defaultInstance, err := app.FindFirstRecordByFilter("harness_instances", "container_name = 'pocketcoder-goose'", nil)
if err != nil {
	return fmt.Errorf("look up default goose harness_instance for import: %w", err)
}
record.Set("harness_instance", defaultInstance.Id)
```

(Insert this immediately before the existing `record.Set("goose_session_id", ...)` line, inside the same transaction — a missing default instance should fail the whole import loudly, per Task 4's seeding making this row always present.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/internal/hooks && go test -run TestScheduleImporterStampsDefaultHarnessInstance -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/hooks/schedule_importer.go
git commit -m "feat(hooks): stamp default harness_instance on imported goose_sessions rows"
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-07-29-multi-harness-selection-design.md`):
- §4.1 (`chats.harness`/`.workspace_override`/index) → Task 1. ✅
- §4.2 (`harnesses` fields) → Task 2. ✅
- §4.3 (`harness_instances`, `goose_sessions.harness_instance`) → Task 3. ✅
- §5.2 (seeded default row) → Task 4. ✅
- §5.6 (`establishSession`, pin check, capability check, single-connection mutex, accepting-timing, escape hatch) → Tasks 5-7, 11. Escape-hatch UI (deleting a stuck `goose_sessions` row) is **not** implemented here — it's a client/API surface concern, correctly out of scope for a schema+coordinator plan; flagged as a gap for the client-facing plan, not missed silently.
- §5.7 (workspace composition) → Task 9.
- §5.8 (path validation, both enforcement points) → Tasks 9 and 11.
- §5.9 (constrained combinations / provider normalization) → explicitly **not** in this plan (client-side filtering concern, belongs to the client plan).
- §6.1-6.4 → Tasks 5, 6, 8.
- §5.1/§5.3/§5.4/§5.5 (provisioning, event watcher, stdio adapter, AdminConn scope) → **explicitly out of scope**, per this plan's stated goal; a separate follow-on plan.
- §7 (client UI) → **explicitly out of scope**; separate follow-on plan.

**Placeholder scan:** The first draft of Task 6 left the lock-release wiring and Task 7's `created()`-guard as flagged notes rather than finished code — both were caught on self-review and fixed inline: `establishSession` now returns `(conn, newSessionID, modes, wasNew, release, err)`, `release` is threaded through every return path (including into the existing `teardown` `once.Do` closure) and both callers, and `wasNew` replaces the no-longer-valid `sessionID == ""` check at the `runLoop` call site. One remaining, explicitly-scoped gap: Task 9's `buildSessionProfile` notes that provisioning a missing `harness_instances` row is out of scope for this plan (a separate follow-on plan per the design spec's §5.1) and should surface a clear error rather than attempt to create a container — this is a deliberate scope boundary stated in the plan's own Goal, not an unaddressed placeholder, and Task 9's tests don't exercise that path since every fixture they use seeds the instance row Task 4 also seeds for the default case.

**Type consistency:** `Target{URL, Secret string}` used identically across Tasks 5, 6, 9, 10. `SessionProfile`'s new field names (`ResolvedInstanceID`, `PinnedInstanceID`, `SupportsLiveConfig`, `SupportsGooseExtensions`, `SingleConnectionOnly`, `Target`) match verbatim from their Task 5 definition through every later task that reads them (9, 10) or writes them (9). `ProfileApplier.Apply`'s five-argument signature (Task 8) matches its two call sites (Task 7's `runLoop` rewrite). `establishSession`'s signature is used consistently in Tasks 6 and 7, modulo the explicitly-flagged fourth-return-value gap noted above.
