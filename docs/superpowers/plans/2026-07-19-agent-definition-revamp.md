# Agent-Definition Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PocketBase the source of truth for the Goose agent's config (model, provider, keys, mode, MCP servers, tool policy), delivered through the mechanisms Goose supports today, shaped so a future Goose per-session/recipe capability is a one-component swap.

**Architecture:** A pure render package (`internal/gooseconfig`) turns config records into Goose's native `config.yaml` + a sourced `keys.env`; a hook writes them (goose-uid-owned) and restarts the goose container. A `SessionProfile` + capability-gated `ProfileApplier` seam in the coordinator delivers the per-session bits ACP allows (cwd, mcpServers at `session/new`; mode via `set_session_mode`). Profile resolution lives at the API layer (the coordinator holds no `core.App`) and is injected like the existing `ResolveSession` closure.

**Tech Stack:** Go, PocketBase v0.29-era (`core.App`, migrations, record hooks), `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK, `gopkg.in/yaml.v3`, Docker Compose + docker-socket-proxy.

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

**Interfaces:**
- Consumes: a plain `PermRow{Tool, Pattern, Action, Extension string}` slice (the hook builds these from `tool_permissions`; `Extension` is the extension the tool belongs to — default `""` = the global/builtin bucket).
- Produces:
  - `func RenderPermissions(rows []PermRow) (allow map[string][]string, dropped []string)` — `allow[extension] = sorted allowlist` = (allow-set − deny-set) per extension; extensions with no allow/deny rows are absent (→ omit `available_tools`, Goose default = all). `dropped` is human-readable strings for every degraded rule (each `ask`, each dropped non-`*` `pattern`, each allow∩deny conflict). The hook logs `dropped` (spec §7).

- [ ] **Step 1: Write the failing test**

```go
package gooseconfig

import "testing"

func TestRenderPermissions_AllowMinusDeny_AndDegradations(t *testing.T) {
	rows := []PermRow{
		{Tool: "read", Action: "allow", Pattern: "*", Extension: "developer"},
		{Tool: "write", Action: "allow", Pattern: "*", Extension: "developer"},
		{Tool: "write", Action: "deny", Pattern: "*", Extension: "developer"}, // conflict: deny wins
		{Tool: "shell", Action: "ask", Pattern: "*", Extension: "developer"},  // ask: dropped
		{Tool: "read", Action: "allow", Pattern: "src/*", Extension: "developer"}, // pattern dropped
	}
	allow, dropped := RenderPermissions(rows)
	if got := allow["developer"]; len(got) != 1 || got[0] != "read" {
		t.Fatalf("allow[developer] = %v, want [read]", got)
	}
	if len(dropped) != 3 {
		t.Fatalf("dropped = %v, want 3 entries (ask, pattern, conflict)", dropped)
	}
}

func TestRenderPermissions_NoRulesOmitsExtension(t *testing.T) {
	allow, _ := RenderPermissions(nil)
	if len(allow) != 0 {
		t.Fatalf("expected empty allow map, got %v", allow)
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

type PermRow struct{ Tool, Pattern, Action, Extension string }

// RenderPermissions maps rich allow/ask/deny rows onto Goose's per-extension
// available_tools allowlist (non-empty = only those tools). Lossy by design
// (spec §7): non-"*" patterns are discarded, per-tool `ask` has no equivalent,
// and same-tool allow+deny resolves deny-wins. Every degradation is returned
// in `dropped` for the caller to log.
func RenderPermissions(rows []PermRow) (map[string][]string, []string) {
	type set = map[string]struct{}
	allowByExt := map[string]set{}
	denyByExt := map[string]set{}
	var dropped []string

	ensure := func(m map[string]set, ext string) set {
		if m[ext] == nil {
			m[ext] = set{}
		}
		return m[ext]
	}

	for _, r := range rows {
		if r.Pattern != "" && r.Pattern != "*" {
			dropped = append(dropped, fmt.Sprintf("pattern dropped (Goose allowlist is tool-name-only): %s.%s pattern=%q", r.Extension, r.Tool, r.Pattern))
		}
		switch r.Action {
		case "allow":
			ensure(allowByExt, r.Extension)[r.Tool] = struct{}{}
		case "deny":
			ensure(denyByExt, r.Extension)[r.Tool] = struct{}{}
		case "ask":
			dropped = append(dropped, fmt.Sprintf("ask dropped (no per-tool Goose equivalent; governed by mode): %s.%s", r.Extension, r.Tool))
		}
	}

	out := map[string][]string{}
	for ext, allow := range allowByExt {
		var tools []string
		for tool := range allow {
			if _, denied := denyByExt[ext][tool]; denied {
				dropped = append(dropped, fmt.Sprintf("allow/deny conflict, deny wins: %s.%s", ext, tool))
				continue
			}
			tools = append(tools, tool)
		}
		// deny-only extensions (allow empty) intentionally do not synthesize an
		// allowlist: we cannot enumerate the full tool set to subtract from.
		if len(tools) > 0 {
			sort.Strings(tools)
			out[ext] = tools
		}
	}
	return out, dropped
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

> If `internal/hooks` has no existing test app helper, this task's test is written against the real `tests/agent-c1` integration harness instead (the same decision the bridge plan made for PB HTTP). Check for a helper first: `grep -rl "func newTestApp\|tests.NewTestApp" internal/hooks ../..`. If none exists, implement `renderGooseConfig` and cover it in the integration suite; keep the pure renderer tests (Tasks 1–3) as the unit gate.

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

Implement the two helpers `defaultPocoConfig(app) (*core.Record, error)` (spec §5.2 tie-break: filter `is_default = true` sorted `created`; if >1 log warning + take first; if 0 return nil) and `configInputFor(app, def) (gooseconfig.ConfigInput, []string, error)` (resolve `harness_model → harness_models.harness_model_id` for `Model`, `→ models.provider` for `Provider`, `mode` field for `Mode`; build `[]gooseconfig.PermRow` from active `tool_permissions` and call `gooseconfig.RenderPermissions`) in the same file.

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
  - Delete `RegisterAgentHooks` from `agents.go` (the `config` bundle writer).
  - Delete `internal/agents/bundler.go`.
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
	fc := &fakeConn{} // existing coordinator test fake (extend to capture SetSessionMode args)
	err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("auto")})
	if err != nil {
		t.Fatal(err)
	}
	if fc.lastModeSession != "sess-1" || fc.lastModeID != "auto" {
		t.Fatalf("set_mode not forwarded: sess=%q mode=%q", fc.lastModeSession, fc.lastModeID)
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

(Extend the coordinator test `fakeConn` with `lastModeSession`/`lastModeID` capture in its `SetSessionMode`.)

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** `feat(coordinator): SessionProfile + capability-gated applier seam`

---

### Task 9: `api/profile.go` — buildSessionProfile

**Files:**
- Create: `internal/api/profile.go`
- Test: `internal/api/profile_test.go` (or integration per the harness note)

**Interfaces:**
- Produces: `func buildSessionProfile(app core.App, chatID string) (coordinator.SessionProfile, error)` — resolves the chat's `poco_config` (or default §5.2), two-hop `harness_model → harness_models.harness_model_id` / `→ models.provider`, `system_prompt → prompts.body`, parses `acp_mcp_servers` (stdio-only, §5.1) → `[]acpsdk.McpServer`, `workspace_folders` → `Cwd` + `AdditionalDirectories` (§S4), `mode` → `acpsdk.SessionModeId`.

- [ ] **Step 1: Write the failing test** — seed a chat + default poco_config with a stdio MCP entry and two workspace folders; assert `Cwd`, `AdditionalDirectories`, one `McpServers` (stdio), and `Mode`. (Use the `tests/agent-c1` harness if `internal/api` has no unit app helper — same decision as the bridge plan; check with `grep -rl "newTestApp" internal/api ../..`.)

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** `buildSessionProfile` per the interface, reusing the `defaultPocoConfig` §5.2 semantics (extract that helper to a shared location or reimplement the same tie-break). Skip + log non-`stdio` MCP entries. Apply `chats.harness_model_override` into `Model` (document: inert per-chat today, §4.1).

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** `feat(api): buildSessionProfile resolves a chat's agent definition`

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

- [ ] **Step 1: Extend the coordinator entry points** — add a `ProfileFunc` parameter to `StartPrompt` and `StreamColdReplay`, mirroring the existing `ResolveSession` closure; resolve it once at run start and hand the `SessionProfile` to `initSession` (Task 10).

- [ ] **Step 2: Wire the handlers** — in `agent.go`, the `session/prompt` and `stream` handlers pass:
```go
func(ctx context.Context) (coordinator.SessionProfile, error) { return buildSessionProfile(app, chatID) }
```
as the new `ProfileFunc` argument (alongside the existing `gooseSessionForChat`/`saveGooseSession` closures).

- [ ] **Step 3: Verify** — `go build ./... && go test ./...`; then the `tests/agent-c1` integration suite exercises a real prompt end-to-end (per-chat MCP/cwd/mode reach Goose). Expected: green.

- [ ] **Step 4: Commit** `feat(api): inject per-chat SessionProfile into agent runs`

**Phase B checkpoint:** per-chat MCP servers, workspace, and mode are live over ACP; model/provider/prompt remain global (config.yaml) until Goose ships per-session config, at which point `selectApplier` + `PerSessionApplier` flip with no schema or resolution-path change.

---

## Self-Review (completed against the spec)

- **Spec coverage:** §4 seam → Tasks 8/10/11; §5 schema → Task 5 + resolution in 9; §5.1 MCP stdio-only → Task 9; §5.2 default tie-break → Task 4 (`defaultPocoConfig`) + 9; §6 renders → Tasks 1–4; §6.3 retire → Task 6; §6.4 ownership → Task 4 `writeGoose`; §6.5 initial render → Task 4 `OnServe`; §7 tool map → Task 2; §9 infra → Task 7; §10 restart-vs-run → documented (no code); §13 verify-items → surfaced inline at Tasks 4/5/7 and in Global Constraints.
- **Placeholders:** none — every code step carries real code; helper bodies (`defaultPocoConfig`, `configInputFor`, `buildSessionProfile`) are specified by exact behavior where the two-hop expand is mechanical.
- **Type consistency:** `SessionProfile`/`ProfileFunc`/`ProfileApplier`/`ConfigInput`/`PermRow`/`RenderKeysEnv`/`RenderConfigYAML`/`RenderPermissions`/`GooseContainer`/`gooseConfigDir` are used identically across tasks.
- **Testing-harness honesty:** where `internal/hooks`/`internal/api` lack a unit app helper, tests fall to the real `tests/agent-c1` integration suite (same call the bridge plan made); pure renderers (Tasks 1–3) are the deterministic unit gate.
