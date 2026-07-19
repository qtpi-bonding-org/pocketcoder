# Agent-Definition Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PocketBase the source of truth for the Goose agent's config (model, provider, keys, mode, MCP servers, tool policy), delivered through the mechanisms Goose supports today, shaped so a future Goose per-session/recipe capability is a one-component swap.

**Architecture:** A pure render package (`internal/gooseconfig`) turns config records into Goose's native `config.yaml` + a sourced `keys.env`; a hook writes them (goose-uid-owned) and restarts the goose container. A `SessionProfile` + capability-gated `ProfileApplier` seam in the coordinator delivers the per-session bits ACP allows (cwd, mcpServers at `session/new`; mode via `set_session_mode`). Profile resolution lives at the API layer (the coordinator holds no `core.App`) and is injected like the existing `ResolveSession` closure.

**Tech Stack:** Go, PocketBase `v0.36.1` (`core.App`, migrations, record hooks; verified against `go.mod`), `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK, `gopkg.in/yaml.v3` (already a dependency), Docker Compose + docker-socket-proxy.

**Source spec:** `docs/superpowers/specs/2026-07-19-agent-definition-revamp-design.md`. Read it first; this plan implements it section-by-section.

## Global Constraints

- **Security:** `GOOSE_SERVER__SECRET_KEY` and provider API keys NEVER appear in any HTTP response. Keys live only in the rendered `keys.env` (goose-uid-owned, `0600`) on the shared volume. Nothing writes keys into `config.yaml` or a response. Goose gets no PocketBase token and no network path to the PB DB — this plan adds only a shared **file** volume.
- **Root-writer / non-root-reader:** PocketBase runs as root; Goose runs as `USER goose`. Every rendered file is `chown`ed to the goose uid or it is unreadable (spec §6.4). Confirm the goose uid before relying on a literal.
- **MCP single-path:** per-chat MCP servers are delivered ONLY per-session over ACP (`stdio` type only for now); they are NOT written into `config.yaml`'s `extensions:` block (spec §5.1).
- **Do not invent Goose config keys:** the global system prompt / instructions key is emitted only if the pinned build supports one (spec §13.5); otherwise omit. Same for the `mode` enum values (spec §13.3 — only `approve` is known-good).
- **Coordinator is PocketBase-agnostic:** no `core.App` in `internal/agent/coordinator`. DB reads are injected from `internal/api`.
- **TDD:** every new function gets a failing test first. Renderers are pure and golden-tested.
- **Commands run from** `services/pocketbase/` unless noted. Go module: `github.com/qtpi-automaton/pocketcoder/backend`. Test: `go test ./internal/<pkg>/...`.

---

## ⚠️ HARD PREREQUISITE — sequencing against the c1↔c2 bridge

**Phase B modifies `internal/agent/coordinator/run.go` (`initSession`, `StartPrompt`, `StreamColdReplay`) and `internal/api/agent.go`, which the Robust c1↔c2 Bridge plan (`2026-07-19-robust-c1-c2-bridge.md`) is actively rewriting.** Phase B MUST NOT begin until that bridge implementation is merged through its transport cutover (its Task 14). The function signatures in Phase B's integration steps are grounded against the bridge's *planned* shape (`StartPrompt`, `StreamColdReplay`, `initSession(ctx, conn, sc, bridge, hub, sessionID, created)`); **re-ground them against the merged code before editing.**

**Phase A has NO coordinator dependency** — it is pure PocketBase render/hook/migration/infra work and can start immediately, in parallel with the bridge.

---

## File Structure

**Phase A (PB-only, no coordinator):**
- Create: `internal/gooseconfig/{config.go,keys.go,permissions.go,doc.go}` + `_test.go` peers + `testdata/` golden files
- Create: `internal/hooks/goose_config.go` + `internal/hooks/goose_config_test.go`
- Modify: `internal/hooks/helpers.go` (add `GooseContainer`, remove `PocoContainer`)
- Remove render bodies: `internal/hooks/llm.go`, `internal/hooks/tool_permissions.go`, `internal/hooks/agents.go`; delete `internal/agents/bundler.go`
- Modify: `main.go` (swap hook registrations)
- Create: `pb_migrations/1752000100_poco_config_mode.go` (add `mode`, drop `config`)
- Modify: `../../docker-compose.yml` (shared `goose_config` volume), `../goose/entrypoint.sh` (source keys.env)

**Phase B (after bridge):**
- Create: `internal/agent/coordinator/profile.go` + `profile_test.go`
- Create: `internal/api/profile.go` + `profile_test.go`
- Modify: `internal/agent/coordinator/run.go` (thread `ProfileFunc`, `initSession`)
- Modify: `internal/api/agent.go` (build + inject profile in prompt/stream handlers)

---

# PHASE A — Render pipeline (ships independently)

### Task 1: `gooseconfig.keys` — provider_keys → env file

**Files:**
- Create: `internal/gooseconfig/doc.go`, `internal/gooseconfig/keys.go`
- Test: `internal/gooseconfig/keys_test.go`

**Interfaces:**
- Produces: `func RenderKeysEnv(keySets []map[string]any) []byte` — deterministic `KEY=VALUE\n` output, keys sorted, from N provider_keys `env_vars` maps merged (later sets win on collision). Pure; the hook supplies the maps.

- [ ] **Step 1: Write the failing test**

```go
package gooseconfig

import "testing"

func TestRenderKeysEnv_SortsAndMerges(t *testing.T) {
	got := string(RenderKeysEnv([]map[string]any{
		{"ANTHROPIC_API_KEY": "sk-a", "FOO": "1"},
		{"FOO": "2", "BAR": "x"}, // FOO overridden by later set
	}))
	want := "ANTHROPIC_API_KEY=sk-a\nBAR=x\nFOO=2\n"
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/gooseconfig/ -run TestRenderKeysEnv -v`
Expected: FAIL — `undefined: RenderKeysEnv`.

- [ ] **Step 3: Write minimal implementation**

`doc.go`:
```go
// Package gooseconfig renders PocketBase agent-definition records into Goose's
// native config.yaml + keys env file. Pure (no I/O); the hook layer writes the
// bytes and owns file ownership/permissions.
package gooseconfig
```

`keys.go`:
```go
package gooseconfig

import (
	"fmt"
	"sort"
	"strings"
)

// RenderKeysEnv merges provider_keys env_vars maps (later sets win) into a
// deterministic KEY=VALUE env file, keys sorted. Secrets live only here.
func RenderKeysEnv(keySets []map[string]any) []byte {
	merged := map[string]string{}
	for _, set := range keySets {
		for k, v := range set {
			merged[k] = fmt.Sprintf("%v", v)
		}
	}
	keys := make([]string, 0, len(merged))
	for k := range merged {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var b strings.Builder
	for _, k := range keys {
		b.WriteString(k)
		b.WriteByte('=')
		b.WriteString(merged[k])
		b.WriteByte('\n')
	}
	return []byte(b.String())
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/gooseconfig/ -run TestRenderKeysEnv -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/gooseconfig/doc.go internal/gooseconfig/keys.go internal/gooseconfig/keys_test.go
git commit -m "feat(gooseconfig): render provider_keys into keys.env"
```

---

### Task 2: `gooseconfig.permissions` — tool_permissions → available_tools + mode, with logged degradations

**Files:**
- Create: `internal/gooseconfig/permissions.go`
- Test: `internal/gooseconfig/permissions_test.go`

> **DECISION — single-extension bucket (resolves Sonnet C1).** `tool_permissions` has **no `extension` field** (verified: `1748000100_acp_schema.go` — fields are `poco_config`/`sandbox_config`, `tool`, `pattern`, `action`, `active`). Goose's `available_tools` is keyed per-extension, but the data model provides no extension binding. For v1 we therefore treat **all `tool_permissions` rows as governing the single builtin coding extension `developer`** (`DefaultToolExtension`), which is the only extension a coding agent runs by default. Per-extension policy needs a future `tool_permissions.extension` field + UI — **out of scope, logged as a limitation.** So `PermRow` carries no `Extension`, and `RenderPermissions` returns one flat allowlist that the hook maps under `DefaultToolExtension`.

**Interfaces:**
- Consumes: a plain `PermRow{Tool, Pattern, Action string}` slice (the hook builds these from active `tool_permissions`).
- Produces:
  - `const DefaultToolExtension = "developer"`
  - `func RenderPermissions(rows []PermRow) (allow []string, dropped []string)` — `allow` = sorted (allow-set − deny-set) for the single default extension; empty if no allow rows (→ hook omits `available_tools`, Goose default = all). `dropped` is human-readable strings for every degraded rule (each `ask`, each dropped non-`*` `pattern`, each allow∩deny conflict). The hook logs `dropped` (spec §7).

- [ ] **Step 1: Write the failing test**

```go
package gooseconfig

import "testing"

func TestRenderPermissions_AllowMinusDeny_AndDegradations(t *testing.T) {
	rows := []PermRow{
		{Tool: "read", Action: "allow", Pattern: "*"},
		{Tool: "write", Action: "allow", Pattern: "*"},
		{Tool: "write", Action: "deny", Pattern: "*"},   // conflict: deny wins
		{Tool: "shell", Action: "ask", Pattern: "*"},    // ask: dropped
		{Tool: "read", Action: "allow", Pattern: "src/*"}, // pattern dropped
	}
	allow, dropped := RenderPermissions(rows)
	if len(allow) != 1 || allow[0] != "read" {
		t.Fatalf("allow = %v, want [read]", allow)
	}
	if len(dropped) != 3 {
		t.Fatalf("dropped = %v, want 3 entries (ask, pattern, conflict)", dropped)
	}
}

func TestRenderPermissions_NoRulesOmits(t *testing.T) {
	if allow, _ := RenderPermissions(nil); len(allow) != 0 {
		t.Fatalf("expected empty allowlist, got %v", allow)
	}
}
```

- [ ] **Step 2: Run — expect FAIL** (`undefined: PermRow`).
Run: `go test ./internal/gooseconfig/ -run TestRenderPermissions -v`

- [ ] **Step 3: Implement**

```go
package gooseconfig

import (
	"fmt"
	"sort"
)

// DefaultToolExtension is the single builtin extension all tool_permissions
// rows are assumed to govern (see Task 2 DECISION); per-extension policy is a
// future extension-field enhancement.
const DefaultToolExtension = "developer"

type PermRow struct{ Tool, Pattern, Action string }

// RenderPermissions maps rich allow/ask/deny rows onto Goose's available_tools
// allowlist (non-empty = only those tools) for the default extension. Lossy by
// design (spec §7): non-"*" patterns are discarded, per-tool `ask` has no
// equivalent, and same-tool allow+deny resolves deny-wins. Every degradation is
// returned in `dropped` for the caller to log.
func RenderPermissions(rows []PermRow) ([]string, []string) {
	allow := map[string]struct{}{}
	deny := map[string]struct{}{}
	var dropped []string

	for _, r := range rows {
		if r.Pattern != "" && r.Pattern != "*" {
			dropped = append(dropped, fmt.Sprintf("pattern dropped (Goose allowlist is tool-name-only): %s pattern=%q", r.Tool, r.Pattern))
		}
		switch r.Action {
		case "allow":
			allow[r.Tool] = struct{}{}
		case "deny":
			deny[r.Tool] = struct{}{}
		case "ask":
			dropped = append(dropped, fmt.Sprintf("ask dropped (no per-tool Goose equivalent; governed by mode): %s", r.Tool))
		}
	}

	var tools []string
	for tool := range allow {
		if _, denied := deny[tool]; denied {
			dropped = append(dropped, fmt.Sprintf("allow/deny conflict, deny wins: %s", tool))
			continue
		}
		tools = append(tools, tool)
	}
	// deny-only (no allow rows) intentionally yields no allowlist: we cannot
	// enumerate the full tool set to subtract from.
	sort.Strings(tools)
	return tools, dropped
}
```

- [ ] **Step 4: Run — expect PASS.**
Run: `go test ./internal/gooseconfig/ -run TestRenderPermissions -v`

- [ ] **Step 5: Commit**

```bash
git add internal/gooseconfig/permissions.go internal/gooseconfig/permissions_test.go
git commit -m "feat(gooseconfig): map tool_permissions to available_tools (lossy, logged)"
```

---

### Task 3: `gooseconfig.config` — default poco_config → config.yaml

**Files:**
- Create: `internal/gooseconfig/config.go`
- Test: `internal/gooseconfig/config_test.go`, `internal/gooseconfig/testdata/config_basic.yaml`

**Interfaces:**
- Consumes: `ConfigInput{Provider, Model, Mode string; AvailableTools map[string][]string}` (the hook fills it from the default poco_config + `RenderPermissions`). `Instructions` is deliberately absent until spec §13.5 confirms a key exists.
- Produces: `func RenderConfigYAML(in ConfigInput) ([]byte, error)` — a Goose `config.yaml` with `GOOSE_PROVIDER`, `GOOSE_MODEL`, `GOOSE_MODE`, and an `extensions:` map carrying only `available_tools` allowlists for named extensions (builtins). No secrets. No per-chat MCP.

- [ ] **Step 1: Write the failing test**

```go
package gooseconfig

import (
	"os"
	"testing"
)

func TestRenderConfigYAML_Golden(t *testing.T) {
	got, err := RenderConfigYAML(ConfigInput{
		Provider: "anthropic", Model: "MiniMax-M2.5", Mode: "approve",
		AvailableTools: map[string][]string{"developer": {"read", "write"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile("testdata/config_basic.yaml")
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(want) {
		t.Fatalf("config.yaml mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
```

- [ ] **Step 2: Run — expect FAIL** (`undefined: ConfigInput`).
Run: `go test ./internal/gooseconfig/ -run TestRenderConfigYAML -v`

- [ ] **Step 3: Implement + write the golden**

`config.go`:
```go
package gooseconfig

import "gopkg.in/yaml.v3"

type ConfigInput struct {
	Provider, Model, Mode string
	AvailableTools        map[string][]string // extension -> allowlist
	// Instructions is intentionally omitted: config.yaml has no documented
	// global system-prompt key (spec §13.5). Add only if verification confirms one.
}

func RenderConfigYAML(in ConfigInput) ([]byte, error) {
	doc := map[string]any{
		"GOOSE_PROVIDER": in.Provider,
		"GOOSE_MODEL":    in.Model,
		"GOOSE_MODE":     in.Mode,
	}
	if len(in.AvailableTools) > 0 {
		exts := map[string]any{}
		for ext, tools := range in.AvailableTools {
			exts[ext] = map[string]any{
				"name":            ext,
				"enabled":         true,
				"available_tools": tools,
			}
		}
		doc["extensions"] = exts
	}
	return yaml.Marshal(doc)
}
```

Generate the golden once, then verify by eye before committing:
```bash
# write testdata/config_basic.yaml to match yaml.Marshal output, e.g.:
# GOOSE_MODE: approve
# GOOSE_MODEL: MiniMax-M2.5
# GOOSE_PROVIDER: anthropic
# extensions:
#     developer:
#         available_tools:
#             - read
#             - write
#         enabled: true
#         name: developer
```
(yaml.v3 sorts map keys alphabetically and indents 4 spaces — let the failing test print the actual bytes, paste them into the golden, confirm they are sane, re-run.)

- [ ] **Step 4: Run — expect PASS.**
Run: `go test ./internal/gooseconfig/ -v`

- [ ] **Step 5: Commit**

```bash
git add internal/gooseconfig/config.go internal/gooseconfig/config_test.go internal/gooseconfig/testdata/config_basic.yaml
git commit -m "feat(gooseconfig): render default poco_config into config.yaml"
```

---

### Task 4: `goose_config` hook — render, write (goose-owned), restart

**Files:**
- Create: `internal/hooks/goose_config.go`
- Modify: `internal/hooks/helpers.go` (add `GooseContainer`)
- Test: `internal/hooks/goose_config_test.go`

**Interfaces:**
- Consumes: `RenderKeysEnv`, `RenderConfigYAML`, `RenderPermissions`, `renderAndRestart`.
- Produces: `func RegisterGooseConfigHooks(app core.App)` — CRUD on `poco_configs`, `provider_keys`, `tool_permissions`, `harness_models`, `prompts` → render+restart(`GooseContainer`); `OnServe` initial render (no restart). Internals: `renderGooseConfig(app) error` writes `config.yaml` (`0640`) + `keys.env` (`0600`) to `gooseConfigDir`, then `chownGoose(path)`.

- [ ] **Step 1: Add the container const**

In `helpers.go`, replace the `PocoContainer` line:
```go
const (
	GooseContainer   = "pocketcoder-goose"
	GatewayContainer = "pocketcoder-mcp-gateway"
)
```
(Do not remove `PocoContainer` until Task 6 removes its last references — to keep the module compiling, temporarily keep BOTH consts here, then drop `PocoContainer` in Task 6.)

- [ ] **Step 2: Write the failing test**

```go
package hooks

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRenderGooseConfig_WritesConfigAndKeys(t *testing.T) {
	dir := t.TempDir()
	// gooseConfigDir is a package var so tests can redirect it.
	old := gooseConfigDir
	gooseConfigDir = dir
	defer func() { gooseConfigDir = old }()

	app := newTestApp(t) // existing hooks test helper; seeds a default poco_config + a provider_key
	if err := renderGooseConfig(app); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "config.yaml")); err != nil {
		t.Fatalf("config.yaml not written: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "keys.env")); err != nil {
		t.Fatalf("keys.env not written: %v", err)
	}
}
```

> **Test-harness reality (Sonnet S6):** `internal/hooks` has **no** unit test-app helper (verified — grep for `newTestApp`/`NewTestApp` is empty), and `tests/agent-c1` is an opt-in, live-model BATS suite requiring real API keys — not something an agent can drive in a RED→GREEN loop. **Therefore this hook-layer step is EXEMPT from the plan's `run test → FAIL/PASS` cycle.** The pure renderers (Tasks 1–3) are the deterministic unit gate; `renderGooseConfig` is verified manually/on-box in Task 7 Step 3 (rendered files appear, goose can read them). Write the test above only if you first add a reusable PB-app helper; otherwise skip it and rely on Task 7's on-box check. Do not fabricate a passing unit test against a non-existent helper.

- [ ] **Step 3: Run — expect FAIL** (`undefined: renderGooseConfig` / `gooseConfigDir`).

- [ ] **Step 4: Implement `goose_config.go`**

```go
package hooks

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/gooseconfig"
)

// gooseConfigDir is the shared-volume path Goose reads its config from.
// The exact path is a verify item (spec §13.1) — GOOSE_PATH_ROOT=/goose is set.
var gooseConfigDir = "/goose-config"

// gooseUID/GID own the rendered files so the non-root goose user can read them
// (spec §6.4/§13.4). Confirm against the pinned image; -1 leaves ownership.
var gooseUID, gooseGID = 1000, 1000

func RegisterGooseConfigHooks(app core.App) {
	log.Println("🪿 [GooseConfig] Registering Goose config hooks...")
	handler := func(e *core.RecordEvent) error {
		return renderAndRestart("[GooseConfig]", func() error { return renderGooseConfig(app) }, GooseContainer, e)
	}
	for _, coll := range []string{"poco_configs", "provider_keys", "tool_permissions", "harness_models", "prompts"} {
		registerCrudHooks(app, coll, handler)
	}
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := renderGooseConfig(app); err != nil {
			log.Printf("⚠️ [GooseConfig] initial render failed: %v", err)
		}
		return e.Next()
	})
}

func renderGooseConfig(app core.App) error {
	if err := os.MkdirAll(gooseConfigDir, 0o755); err != nil {
		return fmt.Errorf("mkdir goose config dir: %w", err)
	}

	// keys.env from all provider_keys
	keyRecs, err := app.FindRecordsByFilter("provider_keys", "1=1", "", 0, 0)
	if err != nil {
		return fmt.Errorf("query provider_keys: %w", err)
	}
	sets := make([]map[string]any, 0, len(keyRecs))
	for _, r := range keyRecs {
		m := map[string]any{}
		if err := r.UnmarshalJSONField("env_vars", &m); err != nil {
			log.Printf("⚠️ [GooseConfig] bad env_vars on %s: %v", r.Id, err)
			continue
		}
		sets = append(sets, m)
	}
	if err := writeGoose("keys.env", gooseconfig.RenderKeysEnv(sets), 0o600); err != nil {
		return err
	}

	// config.yaml from the default poco_config + tool permissions
	def, err := defaultPocoConfig(app) // §5.2: exactly-one / oldest-on-multiple / nil-on-none
	if err != nil {
		return err
	}
	if def == nil {
		log.Println("ℹ️ [GooseConfig] no default poco_config; goose runs on compose-env defaults")
		return nil
	}
	in, dropped, err := configInputFor(app, def) // resolves provider/model/mode + RenderPermissions
	if err != nil {
		return err
	}
	for _, d := range dropped {
		log.Printf("⚠️ [GooseConfig] %s", d)
	}
	yamlBytes, err := gooseconfig.RenderConfigYAML(in)
	if err != nil {
		return err
	}
	return writeGoose("config.yaml", yamlBytes, 0o640)
}

func writeGoose(name string, data []byte, mode os.FileMode) error {
	path := filepath.Join(gooseConfigDir, name)
	if err := os.WriteFile(path, data, mode); err != nil {
		return fmt.Errorf("write %s: %w", name, err)
	}
	// Root writer, non-root reader (spec §6.4). Best-effort: on dev hosts the
	// chown may fail (not root) — log, don't fail the render.
	if err := os.Chown(path, gooseUID, gooseGID); err != nil {
		log.Printf("⚠️ [GooseConfig] chown %s failed (dev host?): %v", name, err)
	}
	return nil
}
```

Implement the two helpers in the same file:
- `defaultPocoConfig(app) (*core.Record, error)` — spec §5.2 tie-break: `FindRecordsByFilter("poco_configs", "is_default = true", "created", 0, 0)`; if >1 log warning + take first; if 0 return `nil, nil`.
- `configInputFor(app, def) (gooseconfig.ConfigInput, []string, error)` — resolve `def.harness_model → harness_models.harness_model_id` for `Model`, and `harness_models.model → models.provider` for `Provider` (two hops; field names verified against `1748000100_acp_schema.go`); `def.GetString("mode")` for `Mode`. Then query active `tool_permissions` (global + this poco_config's rows), build `[]gooseconfig.PermRow{Tool,Pattern,Action}`, call `allow, dropped := gooseconfig.RenderPermissions(rows)`, and set:
  ```go
  in := gooseconfig.ConfigInput{Provider: provider, Model: model, Mode: mode}
  if len(allow) > 0 {
      in.AvailableTools = map[string][]string{gooseconfig.DefaultToolExtension: allow}
  }
  return in, dropped, nil
  ```

- [ ] **Step 5: Run — expect PASS** (or integration-suite green per Step 2 note).

- [ ] **Step 6: Commit**

```bash
git add internal/hooks/goose_config.go internal/hooks/helpers.go internal/hooks/goose_config_test.go
git commit -m "feat(hooks): render Goose config.yaml + keys.env and restart goose"
```

---

### Task 5: Migration — add `poco_configs.mode`, drop `poco_configs.config`

**Files:**
- Create: `pb_migrations/1752000100_poco_config_mode.go`

**Interfaces:**
- Produces: a `mode` SelectField on `poco_configs` (values provisional per spec §13.3) and removal of the `config` TextField (its writers are deleted in Task 6).

- [ ] **Step 1: Write the migration**

```go
package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		poco, err := app.FindCollectionByNameOrId("poco_configs")
		if err != nil {
			return err
		}
		if poco.Fields.GetByName("mode") == nil {
			// Values are provisional (spec §13.3): only "approve" is verified
			// against the pinned Goose build. Confirm advertised modes first.
			poco.Fields.Add(&core.SelectField{
				Name:      "mode",
				MaxSelect: 1,
				Values:    []string{"auto", "approve", "smart_approve", "chat"},
			})
		}
		if f := poco.Fields.GetByName("config"); f != nil { // dead OpenCode bundle
			poco.Fields.RemoveById(f.GetId())
		}
		return app.Save(poco)
	}, func(app core.App) error {
		poco, err := app.FindCollectionByNameOrId("poco_configs")
		if err != nil {
			return err
		}
		if f := poco.Fields.GetByName("mode"); f != nil {
			poco.Fields.RemoveById(f.GetId())
		}
		if poco.Fields.GetByName("config") == nil {
			poco.Fields.Add(&core.TextField{Name: "config"})
		}
		return app.Save(poco)
	})
}
```

- [ ] **Step 2: Verify it builds & applies**

Run: `go build ./... && go run . migrate up` (or the project's migrate command) against a scratch DB.
Expected: migration applies; `poco_configs` has `mode`, lacks `config`.

- [ ] **Step 3: Commit**

```bash
git add pb_migrations/1752000100_poco_config_mode.go
git commit -m "feat(migrations): add poco_configs.mode, drop dead config field"
```

---

### Task 6: Cutover — retire OpenCode renders, swap registrations

**Files:**
- Modify: `internal/hooks/llm.go`, `internal/hooks/tool_permissions.go`, `internal/hooks/agents.go`, `main.go`
- Delete: `internal/agents/bundler.go` (+ its test if any)
- Modify: `internal/hooks/helpers.go` (remove `PocoContainer`)

This is one coherent commit: everything that references `PocoContainer` / OpenCode paths / `GetAgentBundle` goes together so the module never builds red.

- [ ] **Step 1: Remove the dead renders**
  - Delete `RegisterLlmHooks` + `renderLlmEnv` from `llm.go` (whole file, or gut to nothing). Its shared `/llm_keys/llm.env` had no post-prune consumer.
  - Delete `RegisterToolPermissionHooks` + `renderOpenCodeConfig` + `buildPermissionBlock` + `permEntry` from `tool_permissions.go`.
  - Delete `internal/hooks/agents.go` **entirely** (its only content is `RegisterAgentHooks` + imports; gutting just the function leaves unused imports → compile error).
  - Delete `internal/agents/bundler.go` (and its test if any).
  - Remove `PocoContainer` from `helpers.go`.

- [ ] **Step 2: Swap registrations in `main.go`**

Replace the three lines (`RegisterAgentHooks`, `RegisterLlmHooks`, `RegisterToolPermissionHooks`) with the single new hook:
```go
	// 3b. Register Goose config hooks (config.yaml + keys.env render + goose restart)
	hooks.RegisterGooseConfigHooks(app)
```
(Delete the now-dangling comments for the removed hooks.)

- [ ] **Step 3: Verify the module builds and tests pass**

Run: `go build ./... && go test ./...`
Expected: PASS. Grep for stragglers: `grep -rn "PocoContainer\|opencode\|GetAgentBundle\|renderLlmEnv" internal main.go` → only comments/none.

- [ ] **Step 4: Commit**

```bash
git add -A internal/hooks internal/agents main.go
git commit -m "refactor(hooks): retire OpenCode renders for Goose config pipeline"
```

---

### Task 7: Infra — shared config volume + entrypoint sourcing

**Files:**
- Modify: `docker-compose.yml` (repo root)
- Modify: `services/goose/entrypoint.sh`

**Interfaces:**
- Produces: a `goose_config` volume mounted writable into `pocketbase` and read into `goose` at the config path (spec §13.1); `entrypoint.sh` sources `keys.env` before provider validation.

- [ ] **Step 1: Add the volume + mounts**

In `docker-compose.yml`:
- Under `volumes:` add `  goose_config:  # Goose config.yaml + keys.env, written by PocketBase, read by goose`.
- `pocketbase.volumes`: add `      - goose_config:/goose-config`.
- `goose.volumes`: add the config mount. **Path per §13.1** — if the pinned build reads `$GOOSE_PATH_ROOT/config.yaml` that is `/goose`, which already mounts `goose_data`; prefer a dedicated path and point Goose at it, e.g. add `      - goose_config:/goose-config` and set env `      - XDG_CONFIG_HOME=/goose-config` (so config resolves to `/goose-config/goose/config.yaml` — adjust the hook's `gooseConfigDir` to match the resolved subdir). **Resolve the exact path against the running image before finalizing.**

- [ ] **Step 2: Source keys.env in the entrypoint (before provider validation)**

Edit `services/goose/entrypoint.sh`, inserting after `set -eu` / secret-key line and BEFORE the provider `case`:
```sh
# App-managed keys (rendered by PocketBase). Sourced before provider validation
# so ANTHROPIC_API_KEY etc. are present. Guarded so set -e cannot abort on a
# missing/unreadable file (cold boot before first render).
if [ -r /goose-config/keys.env ]; then
  set -a
  . /goose-config/keys.env
  set +a
fi
```

- [ ] **Step 3: Verify the stack boots**

Run (per CLAUDE.md pipeline): `docker compose build pocketbase goose && docker compose --profile agent up -d pocketbase goose`
Expected: both healthy; `docker compose exec goose cat /goose-config/config.yaml` shows rendered config after a `poco_configs` edit; `docker compose exec goose sh -c 'test -r /goose-config/keys.env'` succeeds (readable by goose user). If unreadable → revisit `gooseUID/GID` (Task 4, spec §13.4).

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml services/goose/entrypoint.sh
git commit -m "feat(infra): shared goose_config volume; entrypoint sources keys.env"
```

**Phase A checkpoint:** the global agent is now PocketBase-configurable (model/provider/mode/keys/tool-allowlist) with a container restart. Per-chat MCP/cwd/mode is Phase B.

---

# PHASE B — Coordinator profile seam (START ONLY AFTER THE BRIDGE IS MERGED — see prerequisite)

> Re-ground `StartPrompt`, `StreamColdReplay`, and `initSession` signatures against the merged bridge code before editing. The steps below assume the bridge's planned shapes.

### Task 8: `coordinator/profile.go` — SessionProfile, applier seam

**Files:**
- Create: `internal/agent/coordinator/profile.go`
- Test: `internal/agent/coordinator/profile_test.go`

**Interfaces:**
- Produces:
  - `type SessionProfile struct { Model, Provider, Instructions, Cwd string; AdditionalDirectories []string; McpServers []acpsdk.McpServer; Mode acpsdk.SessionModeId }`
  - `type ProfileFunc func(context.Context) (SessionProfile, error)`
  - `type ProfileApplier interface { Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error }`
  - `GlobalConfigApplier`, `PerSessionApplier` (stub), `func selectApplier(init *acpsdk.InitializeResponse) ProfileApplier`

- [ ] **Step 1: Write the failing test**

```go
package coordinator

import (
	"context"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

func TestGlobalConfigApplier_SetsMode(t *testing.T) {
	fc := &fakeConn{} // existing coordinator test fake
	err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("auto")})
	if err != nil {
		t.Fatal(err)
	}
	// fc.lastMode is the EXISTING field (run_test.go), already read by
	// session_test.go:TestSetModeDispatchesToConn — keep it. Add lastModeSession.
	if fc.lastModeSession != "sess-1" || fc.lastMode != "auto" {
		t.Fatalf("set_mode not forwarded: sess=%q mode=%q", fc.lastModeSession, fc.lastMode)
	}
}

func TestSelectApplier_DefaultsToGlobalToday(t *testing.T) {
	if _, ok := selectApplier(&acpsdk.InitializeResponse{}).(GlobalConfigApplier); !ok {
		t.Fatal("expected GlobalConfigApplier under today's capabilities")
	}
}
```

- [ ] **Step 2: Run — expect FAIL.** Run: `go test ./internal/agent/coordinator/ -run 'Applier' -v`

- [ ] **Step 3: Implement**

```go
package coordinator

import (
	"context"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

type SessionProfile struct {
	Model, Provider, Instructions, Cwd string
	AdditionalDirectories              []string
	McpServers                         []acpsdk.McpServer
	Mode                               acpsdk.SessionModeId
}

type ProfileFunc func(context.Context) (SessionProfile, error)

type ProfileApplier interface {
	Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error
}

// GlobalConfigApplier delivers only what ACP allows post-create today: the
// session mode. Model/provider/prompt are delivered out-of-band by the render
// pipeline + restart (spec §4).
type GlobalConfigApplier struct{}

func (GlobalConfigApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	if p.Mode == "" {
		return nil
	}
	_, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{
		SessionId: acpsdk.SessionId(sessionID), ModeId: p.Mode,
	})
	return err
}

// PerSessionApplier is the future path (Goose #7596): it will additionally
// deliver model/instructions/recipe per session. Stub until the capability exists.
type PerSessionApplier struct{}

func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	return GlobalConfigApplier{}.Apply(ctx, conn, sessionID, p) // no extra capability yet
}

// selectApplier gates on advertised capabilities. Today no SDK field describes
// per-session model/prompt config (#7596 unshipped), so this always returns the
// global applier (spec §4/§S8).
func selectApplier(init *acpsdk.InitializeResponse) ProfileApplier {
	return GlobalConfigApplier{}
}
```

**`fakeConn` change (Sonnet S4):** the real `fakeConn` (`run_test.go`) already has `lastMode string`, set in `SetSessionMode` and read by `session_test.go:TestSetModeDispatchesToConn`. **Keep `lastMode` exactly as-is** (do not rename/remove it — that breaks `session_test.go`). **Add one new field** `lastModeSession string` and set it alongside `lastMode` inside the existing `SetSessionMode`. No other test changes.

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** `feat(coordinator): SessionProfile + capability-gated applier seam`

---

### Task 9: `api/profile.go` — buildSessionProfile

**Files:**
- Create: `internal/api/profile.go`
- Test: `internal/api/profile_test.go` (or integration per the harness note)

**Interfaces:**
- Produces: `func buildSessionProfile(app core.App, chatID string) (coordinator.SessionProfile, error)` — resolves the chat's `poco_config` (or default §5.2), two-hop `harness_model → harness_models.harness_model_id` / `→ models.provider`, `system_prompt → prompts.body`, parses `acp_mcp_servers` (stdio-only, §5.1) → `[]acpsdk.McpServer`, `workspace_folders` → `Cwd` + `AdditionalDirectories` (§S4), `mode` → `acpsdk.SessionModeId`.

> **Test-harness reality (Sonnet S6):** `internal/api` has **no** unit PB-app helper either. This step is **EXEMPT from the RED→GREEN cycle** unless you first add a helper; otherwise verify `buildSessionProfile` through the Task 11 integration path (a real prompt whose Goose `session/new` carries the resolved cwd/mcpServers). The code below must still be written and compile (`go build ./...`).

- [ ] **Step 1: Implement `internal/api/profile.go`.** The `McpServer` construction is a discriminated union — `acpsdk.McpServer{Stdio: &acpsdk.McpServerStdio{...}}`, and `Env` is `[]acpsdk.EnvVariable{{Name,Value}}`, **not** a map (Sonnet C2, verified in `types_gen.go`). Full code:

```go
package api

import (
	"encoding/json"
	"log"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// stdioMcp is the stored acp_mcp_servers JSON shape (spec §5.1). Only stdio is
// supported today; http/sse/acp entries are skipped + logged.
type stdioMcp struct {
	Type    string            `json:"type"`
	Name    string            `json:"name"`
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
}

func buildSessionProfile(app core.App, chatID string) (coordinator.SessionProfile, error) {
	var p coordinator.SessionProfile

	chat, err := app.FindRecordById("chats", chatID)
	if err != nil {
		return p, err
	}

	// Resolve the agent definition: chat's poco_config, else the default (§5.2).
	pocoID := chat.GetString("poco_config")
	var poco *core.Record
	if pocoID != "" {
		if poco, err = app.FindRecordById("poco_configs", pocoID); err != nil {
			return p, err
		}
	} else if poco, err = defaultPocoConfigAPI(app); err != nil {
		return p, err
	}
	if poco == nil {
		// No definition at all: minimal floor (spec §5.2). Coordinator falls
		// back to c.config.Workspace when Cwd == "".
		p.Mode = acpsdk.SessionModeId("approve")
		return p, nil
	}

	// Model: chat.harness_model_override wins, else the poco's harness_model.
	// (Per-chat model is INERT today — spec §4.1 — but resolved for forward-compat.)
	hmID := chat.GetString("harness_model_override")
	if hmID == "" {
		hmID = poco.GetString("harness_model")
	}
	if hmID != "" {
		if hm, err := app.FindRecordById("harness_models", hmID); err == nil {
			p.Model = hm.GetString("harness_model_id")
			if m, err := app.FindRecordById("models", hm.GetString("model")); err == nil {
				p.Provider = m.GetString("provider")
			}
		}
	}
	if spID := poco.GetString("system_prompt"); spID != "" {
		if sp, err := app.FindRecordById("prompts", spID); err == nil {
			p.Instructions = sp.GetString("body")
		}
	}
	if mode := poco.GetString("mode"); mode != "" {
		p.Mode = acpsdk.SessionModeId(mode)
	} else {
		p.Mode = acpsdk.SessionModeId("approve")
	}

	// workspace_folders (JSON array) -> Cwd (first) + AdditionalDirectories (§S4).
	var folders []string
	_ = poco.UnmarshalJSONField("workspace_folders", &folders)
	if len(folders) > 0 {
		p.Cwd = folders[0]
		p.AdditionalDirectories = folders[1:]
	}

	// acp_mcp_servers (JSON array) -> []acpsdk.McpServer, stdio only (§5.1).
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
		p.McpServers = append(p.McpServers, acpsdk.McpServer{
			Stdio: &acpsdk.McpServerStdio{Name: m.Name, Command: m.Command, Args: m.Args, Env: env},
		})
	}
	return p, nil
}

// defaultPocoConfigAPI mirrors the hook's §5.2 tie-break (is_default=true,
// oldest on multiple, nil on none). Kept separate from the hooks package to
// avoid a hooks→api import; the logic is small and identical.
func defaultPocoConfigAPI(app core.App) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("poco_configs", "is_default = true", "created", 0, 0)
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	if len(recs) > 1 {
		log.Printf("[Profile] %d poco_configs marked is_default; using oldest %q", len(recs), recs[0].GetString("name"))
	}
	return recs[0], nil
}
```

- [ ] **Step 2: Verify build** — `go build ./...`. Expected: compiles. (Field names `harness_model_id`, `model`, `provider`, `harness_model_override` verified against `1748000100_acp_schema.go`.)
- [ ] **Step 3: Commit** `feat(api): buildSessionProfile resolves a chat's agent definition`

---

### Task 10: Thread the profile through `initSession` (new + load)

**Files:**
- Modify: `internal/agent/coordinator/run.go`
- Modify: `internal/agent/coordinator/run_test.go`

- [ ] **Step 1: Extend the test** — a detached run asserts the resolved `profile.McpServers`/`Cwd`/`AdditionalDirectories` reach the fake conn's `NewSession` request and `profile.Mode` reaches `SetSessionMode`. Extend `fakeConn` to capture the `NewSessionRequest`/`LoadSessionRequest`.

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement.** In `initSession` (re-ground signature against merged bridge):
  - Capture the `Initialize` response: `initResp, err := conn.Initialize(ctx, initializeRequest())` and `applier := selectApplier(initResp)`.
  - Thread a `SessionProfile` into `initSession` (add a param, or store it on the run handle when the run starts). Build both requests from it:
    ```go
    res, err := conn.NewSession(ctx, acpsdk.NewSessionRequest{
        Cwd: profile.Cwd, AdditionalDirectories: profile.AdditionalDirectories, McpServers: profile.McpServers,
    })
    // ... load branch mirrors with LoadSessionRequest{SessionId, Cwd, AdditionalDirectories, McpServers}
    ```
    If `profile.Cwd == ""`, fall back to `c.config.Workspace` (keep the existing default as the floor).
  - Replace the hardcoded `SetSessionMode(... "approve")` with `applier.Apply(ctx, conn, sessionID, profile)`.
  - Leave `SeedSession` + orphan compensation untouched.

- [ ] **Step 4: Run — expect PASS** (`go test ./internal/agent/coordinator/...`).
- [ ] **Step 5: Commit** `feat(coordinator): apply resolved SessionProfile at session/new|load`

---

### Task 11: Inject the profile from the API handlers (prompt + cold-replay)

**Files:**
- Modify: `internal/agent/coordinator/run.go` (`StartPrompt`, `StreamColdReplay` gain a `ProfileFunc`)
- Modify: `internal/api/agent.go` (build + pass the profile)
- Modify: tests as needed

> **Two distinct init paths (Sonnet C3 — important).** `StartPrompt` runs through `initSession` (Task 10 already wires the profile there). But `StreamColdReplay` (`run.go`) has its **own separate inline init** — `Initialize` → `LoadSession{Cwd: c.config.Workspace, McpServers: []acpsdk.McpServer{}}` — and does **not** call `initSession`. So threading the profile "into `initSession`" does nothing for cold replay; its own `LoadSession` must be patched directly.

- [ ] **Step 1a: `StartPrompt`** — add a `ProfileFunc` parameter, mirroring the existing `ResolveSession` closure; resolve it once at run start and pass the `SessionProfile` to `initSession` (Task 10).

- [ ] **Step 1b: `StreamColdReplay`** — add a `ProfileFunc` parameter and **patch its own `LoadSession` call directly**:
```go
profile, err := profileFn(ctx)
if err != nil {
    return err
}
cwd := profile.Cwd
if cwd == "" {
    cwd = c.config.Workspace
}
if _, err = conn.LoadSession(ctx, acpsdk.LoadSessionRequest{
    SessionId:             acpsdk.SessionId(sessionID),
    Cwd:                   cwd,
    AdditionalDirectories: profile.AdditionalDirectories,
    McpServers:            profile.McpServers,
}); err != nil { /* existing error handling */ }
```
(Cold replay does not set mode — it only re-attaches to replay history — so no `applier.Apply` here.)

- [ ] **Step 2: Wire the handlers** — in `agent.go`, the `session/prompt` and `stream`(cold-replay) handlers pass:
```go
func(ctx context.Context) (coordinator.SessionProfile, error) { return buildSessionProfile(app, chatID) }
```
as the new `ProfileFunc` argument (alongside the existing `gooseSessionForChat`/`saveGooseSession` closures). The `stream` handler builds it before `service.StreamColdReplay(...)`.

- [ ] **Step 3: Verify** — `go build ./... && go test ./...`; then the `tests/agent-c1` integration suite exercises a real prompt end-to-end (per-chat MCP/cwd/mode reach Goose). Expected: green.

- [ ] **Step 4: Commit** `feat(api): inject per-chat SessionProfile into agent runs`

**Phase B checkpoint:** per-chat MCP servers, workspace, and mode are live over ACP; model/provider/prompt remain global (config.yaml) until Goose ships per-session config, at which point `selectApplier` + `PerSessionApplier` flip with no schema or resolution-path change.

---

## Self-Review (completed against the spec)

- **Spec coverage:** §4 seam → Tasks 8/10/11; §5 schema → Task 5 + resolution in 9; §5.1 MCP stdio-only → Task 9; §5.2 default tie-break → Task 4 (`defaultPocoConfig`) + 9; §6 renders → Tasks 1–4; §6.3 retire → Task 6; §6.4 ownership → Task 4 `writeGoose`; §6.5 initial render → Task 4 `OnServe`; §7 tool map → Task 2; §9 infra → Task 7; §10 restart-vs-run → documented (no code); §13 verify-items → surfaced inline at Tasks 4/5/7 and in Global Constraints.
- **Placeholders:** `buildSessionProfile` and the `McpServer` union construction now carry full code (Sonnet C2/S5). `defaultPocoConfig`/`configInputFor` are specified by exact behavior + the two verified two-hop field names; `RenderPermissions` returns a single flat allowlist under `DefaultToolExtension` (Sonnet C1 — no phantom `Extension` field).
- **Type consistency:** `SessionProfile`/`ProfileFunc`/`ProfileApplier`/`ConfigInput`/`PermRow`/`RenderKeysEnv`/`RenderConfigYAML`/`RenderPermissions`/`DefaultToolExtension`/`GooseContainer`/`gooseConfigDir` are used identically across tasks. `fakeConn.lastMode` is preserved (Sonnet S4).
- **TDD deviations (declared):** Task 3's golden test goes RED only because the fixture is absent (standard serialization-golden convention, not a logic RED). Task 4 (hook) and Task 9 (api) are EXEMPT from the RED→GREEN loop — no PB-app unit helper exists; the pure renderers (Tasks 1–3) are the unit gate and Task 7 Step 3 / Task 11 Step 3 are the on-box/integration gates.
- **Two init paths:** `StartPrompt`→`initSession` (Task 10) and `StreamColdReplay`'s own inline `LoadSession` (Task 11 Step 1b) are both patched (Sonnet C3).
