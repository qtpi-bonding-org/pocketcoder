# MCP Governance UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the already-built MCP-server approval workflow actually reach Goose — today it changes files nobody reads — by fixing the gateway's transport, giving it a network path to Goose, registering it as a Goose extension exactly once, and closing the two behavior gaps (tool-permission delivery, manual server creation) that block it.

**Architecture:** Goose attaches to the Docker MCP Gateway as a single persistent Streamable-HTTP extension, registered once via a session-free `AdminConn` call. Individual MCP server approve/deny/revoke never talks to Goose directly — it only ever rewrites the gateway's own catalog file and restarts the gateway container (the existing, now-validated design). Tool-permission delivery moves off the `config.yaml` file-render path (which must stop writing the `extensions` key so Goose's own writes to it aren't clobbered) onto the same live `AdminConn` channel.

**Tech Stack:** Go (PocketBase hooks/API, `internal/agent/coordinator`, `internal/gooseconfig`), Flutter/Dart (`pocketcoder_flutter` package — Bloc/Cubit, Freezed, PocketBase SDK), Docker Compose, bats (integration tests).

## Global Constraints

- Source of truth for every claim below: `docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md` (Opus-reviewed, no open blocking gaps) and its two prior-research docs, `spikes/goose-acp-config-surface/ownership-map.md` and `spikes/goose-mcp-gateway-attach/README.md`.
- Goose version pinned: `v1.43.0` (`services/goose/Dockerfile`). All ACP method names/params verified directly against `.independent_repos/goose_reference/crates/goose/acp-meta.json` and `acp-schema.json` (gitignored local reference clone, not committed) — exact values are reproduced in each task below, no further lookup needed.
- `_goose/unstable/*` custom methods have no typed Go SDK support; every call goes through `acp.Conn.CallExtension(ctx, method string, params any) (json.RawMessage, error)`, already present (`services/pocketbase/internal/agent/acp/websocket.go:61`).
- `Coordinator.AdminConn(ctx) (acp.Conn, error)` already exists (`services/pocketbase/internal/agent/coordinator/admin.go:76`) — dials Goose, completes `initialize`, creates no session. Caller must `Close()` it. One dial per logical operation, not a standing connection.
- `client/CLAUDE.md` rules apply to all Flutter work in this plan: never use `!`; cubits extend `Cubit<T>` (see `mcp_cubit.dart` — this package's existing MCP cubit does not use `AppCubit<T>`, follow the existing file's own pattern, not a different one); state is `@freezed` implementing `IUiFlowState`; repos wrap every public method in `tryMethod` with a typed exception; DI via `@injectable`(cubits)/`@lazySingleton`(repos+DAOs); l10n dot-notation keys, never hardcode user-facing strings.
- Go style in this codebase: `log.Printf` with an emoji+bracket prefix per subsystem (e.g. `"🔌 [MCP] ..."`, `"🪿 [GooseConfig] ..."`) — match the existing prefix for files you edit, pick a new one only for new files.
- Root `CLAUDE.md`'s Model Generation Pipeline does **not** apply to this plan — no PocketBase collection schema changes (confirmed in the spec's Data Model section: `mcp_servers` already has every field needed).

---

## File Structure

**Go — new:**
- `services/pocketbase/internal/hooks/mcp_gateway.go` — one-time gateway extension registration (`RegisterMcpGatewayExtension`).
- `services/pocketbase/internal/hooks/mcp_gateway_test.go`
- `services/pocketbase/internal/hooks/goose_config_permissions_test.go` — live tool-permission delivery tests.

**Go — modified:**
- `docker-compose.yml` — gateway transport flag, new network on `goose` + `mcp-gateway`.
- `services/pocketbase/internal/gooseconfig/permissions.go` — replace `RenderPermissions` with `RenderToolPermissions`.
- `services/pocketbase/internal/gooseconfig/permissions_test.go` — rewritten for the new function.
- `services/pocketbase/internal/gooseconfig/config.go` — drop the `extensions` key / `AvailableTools` field from `RenderConfigYAML`/`ConfigInput`.
- `services/pocketbase/internal/gooseconfig/config_test.go` — golden test updated (no `extensions` key).
- `services/pocketbase/internal/gooseconfig/testdata/config_basic.yaml` — golden file updated.
- `services/pocketbase/internal/hooks/goose_config.go` — stop populating `AvailableTools`; add live `tools/permissions/set` delivery; accept a coordinator getter.
- `services/pocketbase/internal/api/agent.go` — `RegisterAgentApi`/`registerAgentApi` return `(*coordinator.Coordinator, error)`.
- `services/pocketbase/internal/hooks/mcp.go` — bind `OnRecordAfterCreateSuccess` alongside the existing `OnRecordAfterUpdateSuccess`.
- `services/pocketbase/main.go` — wire the coordinator getter through to `RegisterGooseConfigHooks` and call `RegisterMcpGatewayExtension`.

**Flutter — modified:**
- `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart` — add `createServer`.
- `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart` — implement it.
- `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart` — add `createServer` method.
- `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart` — wire `ADD NEW` to a real dialog.
- `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` (+ regenerated `.g.dart`/localizations files via the existing l10n build step) — new strings for the add-server dialog.

**Flutter — new:**
- `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`
- `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart`

**Tests — new:**
- `tests/agent-c1/mcp_gateway.bats` (or extend the existing suite file if one already covers MCP — check `tests/agent-c1/` at Task 8 time).

---

### Task 1: Gateway transport switch + dedicated network

**Files:**
- Modify: `docker-compose.yml`

**Interfaces:**
- Consumes: nothing (infra-only).
- Produces: `mcp-gateway` reachable from `goose` at `http://mcp-gateway:8811/mcp` (Streamable-HTTP). Every later Go task assumes this URL is reachable in a real deployment.

- [ ] **Step 1: Switch the gateway's transport flag**

In `docker-compose.yml`, find the `mcp-gateway` service's `command` (currently at line 108):

```yaml
    command: ["--port", "8811", "--transport", "sse", "--verbose", "--log-calls", "--log", "/var/log/mcp-gateway.log", "--catalog", "/root/.docker/mcp/docker-mcp.yaml", "--secrets", "/root/.docker/mcp/mcp.env", "--enable-all-servers"]
```

Change `"sse"` to `"streaming"`:

```yaml
    command: ["--port", "8811", "--transport", "streaming", "--verbose", "--log-calls", "--log", "/var/log/mcp-gateway.log", "--catalog", "/root/.docker/mcp/docker-mcp.yaml", "--secrets", "/root/.docker/mcp/mcp.env", "--enable-all-servers"]
```

- [ ] **Step 2: Add the dedicated network**

In the `networks:` top-level block (currently starting at line 298), add:

```yaml
  # Carries MCP traffic between Goose and the Docker MCP Gateway only —
  # deliberately separate from pocketcoder-agent (Goose's sole path to/from
  # PocketBase) so this addition doesn't touch that boundary.
  pocketcoder-mcp-gateway:
    driver: bridge
```

- [ ] **Step 3: Join both services to it**

In the `goose` service's `networks:` list (currently lines 81-83):

```yaml
    networks:
      - pocketcoder-agent
      - pocketcoder-goose-egress
      - pocketcoder-mcp-gateway
```

In the `mcp-gateway` service's `networks:` list (currently lines 109-111):

```yaml
    networks:
      - pocketcoder-docker
      - pocketcoder-tools
      - pocketcoder-mcp-gateway
```

- [ ] **Step 4: Validate the compose file**

Run: `docker compose config --quiet`
Expected: exits 0, no output (a syntax/reference error would print to stderr and exit non-zero).

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(mcp): switch gateway to streaming transport, add dedicated goose<->gateway network"
```

---

### Task 2: `RenderToolPermissions` — per-tool live-delivery shape

**Files:**
- Modify: `services/pocketbase/internal/gooseconfig/permissions.go`
- Modify: `services/pocketbase/internal/gooseconfig/permissions_test.go`

**Interfaces:**
- Consumes: `PermRow{Tool, Pattern, Action string}` (existing, unchanged).
- Produces: `type ToolPermissionEntry struct { ToolName, Permission string }`, constants `PermissionAlwaysAllow = "always_allow"`, `PermissionAskBefore = "ask_before"`, `PermissionNeverAllow = "never_allow"` (Goose's exact `ToolPermissionLevel` enum values, verified against `acp-schema.json`'s `ToolPermissionLevel` def), and `func RenderToolPermissions(rows []PermRow) ([]ToolPermissionEntry, []string)`. Task 6 calls this directly.

This replaces `RenderPermissions` (`[]string` allowlist, the old `config.yaml`-render shape) entirely — its only caller (`hooks/goose_config.go:190`) is rewired in Task 3. Unlike the old function, `ask` now maps to a real permission level (`ask_before`) instead of being silently dropped — `tools/permissions/set`'s per-tool model has no equivalent limitation.

- [ ] **Step 1: Write the failing test**

Replace the full contents of `services/pocketbase/internal/gooseconfig/permissions_test.go`:

```go
package gooseconfig

import "testing"

func TestRenderToolPermissions_AllowDenyAsk(t *testing.T) {
	rows := []PermRow{
		{Tool: "read", Action: "allow", Pattern: "*"},
		{Tool: "shell", Action: "ask", Pattern: "*"},
		{Tool: "danger", Action: "deny", Pattern: "*"},
	}
	entries, dropped := RenderToolPermissions(rows)
	want := map[string]string{
		"read":   PermissionAlwaysAllow,
		"shell":  PermissionAskBefore,
		"danger": PermissionNeverAllow,
	}
	if len(entries) != len(want) {
		t.Fatalf("entries = %v, want %d entries", entries, len(want))
	}
	for _, e := range entries {
		if want[e.ToolName] != e.Permission {
			t.Errorf("tool %s: got %s, want %s", e.ToolName, e.Permission, want[e.ToolName])
		}
	}
	if len(dropped) != 0 {
		t.Fatalf("dropped = %v, want none (ask is no longer lossy)", dropped)
	}
}

func TestRenderToolPermissions_ConflictDenyWins(t *testing.T) {
	rows := []PermRow{
		{Tool: "write", Action: "allow", Pattern: "*"},
		{Tool: "write", Action: "deny", Pattern: "*"},
	}
	entries, dropped := RenderToolPermissions(rows)
	if len(entries) != 1 || entries[0].Permission != PermissionNeverAllow {
		t.Fatalf("entries = %v, want single never_allow entry", entries)
	}
	if len(dropped) != 1 {
		t.Fatalf("dropped = %v, want 1 (allow/deny conflict note)", dropped)
	}
}

func TestRenderToolPermissions_PatternDropped(t *testing.T) {
	rows := []PermRow{{Tool: "read", Action: "allow", Pattern: "src/*"}}
	entries, dropped := RenderToolPermissions(rows)
	if len(entries) != 1 || entries[0].Permission != PermissionAlwaysAllow {
		t.Fatalf("entries = %v, want single always_allow entry (pattern dropped, action kept)", entries)
	}
	if len(dropped) != 1 {
		t.Fatalf("dropped = %v, want 1 (pattern note)", dropped)
	}
}

func TestRenderToolPermissions_NoRulesOmits(t *testing.T) {
	if entries, _ := RenderToolPermissions(nil); len(entries) != 0 {
		t.Fatalf("expected no entries, got %v", entries)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/gooseconfig/... -run TestRenderToolPermissions -v`
Expected: compile error — `undefined: RenderToolPermissions` (and `PermissionAlwaysAllow` etc.).

- [ ] **Step 3: Replace `RenderPermissions` with `RenderToolPermissions`**

Replace the full contents of `services/pocketbase/internal/gooseconfig/permissions.go`:

```go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package gooseconfig

import (
	"fmt"
	"sort"
)

// DefaultToolExtension is the single builtin extension all tool_permissions
// rows are assumed to govern; per-extension policy is a future enhancement.
const DefaultToolExtension = "developer"

type PermRow struct{ Tool, Pattern, Action string }

// Goose's _goose/unstable/tools/permissions/set ToolPermissionLevel enum,
// verified against acp-schema.json's ToolPermissionLevel def.
const (
	PermissionAlwaysAllow = "always_allow"
	PermissionAskBefore   = "ask_before"
	PermissionNeverAllow  = "never_allow"
)

// ToolPermissionEntry mirrors one entry of Goose's
// _goose/unstable/tools/permissions/set request
// (SetToolPermissionsRequest_unstable.toolPermissions[]:
// {toolName, permission}). Plain strings, not acp-go-sdk types — this
// package stays pure (no I/O, no ACP SDK dependency); the hooks layer maps
// this onto the real request struct.
type ToolPermissionEntry struct {
	ToolName   string
	Permission string
}

// RenderToolPermissions maps tool_permissions rows onto Goose's per-tool
// tools/permissions/set entries. Non-"*" patterns are dropped (Goose's
// ToolPermissionEntry is tool-name-only, same limitation the old file-render
// allowlist had). Same-tool conflicts resolve deny > ask > allow — deny
// always wins (noted in dropped); otherwise ask beats allow only because a
// tool can carry both an explicit ask row and a broader allow row and the
// more cautious one should apply. Unlike the old config.yaml allowlist,
// "ask" is never dropped — ask_before is a real permission level here.
func RenderToolPermissions(rows []PermRow) ([]ToolPermissionEntry, []string) {
	actions := map[string]map[string]bool{}
	var dropped []string

	for _, r := range rows {
		if r.Pattern != "" && r.Pattern != "*" {
			dropped = append(dropped, fmt.Sprintf("pattern dropped (Goose tool permissions are tool-name-only): %s pattern=%q", r.Tool, r.Pattern))
		}
		switch r.Action {
		case "allow", "deny", "ask":
		default:
			continue
		}
		if actions[r.Tool] == nil {
			actions[r.Tool] = map[string]bool{}
		}
		actions[r.Tool][r.Action] = true
	}

	tools := make([]string, 0, len(actions))
	for tool := range actions {
		tools = append(tools, tool)
	}
	sort.Strings(tools)

	entries := make([]ToolPermissionEntry, 0, len(tools))
	for _, tool := range tools {
		seen := actions[tool]
		switch {
		case seen["deny"]:
			if seen["allow"] {
				dropped = append(dropped, fmt.Sprintf("allow/deny conflict, deny wins: %s", tool))
			}
			entries = append(entries, ToolPermissionEntry{ToolName: tool, Permission: PermissionNeverAllow})
		case seen["ask"]:
			entries = append(entries, ToolPermissionEntry{ToolName: tool, Permission: PermissionAskBefore})
		case seen["allow"]:
			entries = append(entries, ToolPermissionEntry{ToolName: tool, Permission: PermissionAlwaysAllow})
		}
	}
	return entries, dropped
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/gooseconfig/... -run TestRenderToolPermissions -v`
Expected: all 4 subtests PASS.

- [ ] **Step 5: Full package check**

Run: `cd services/pocketbase && go build ./internal/gooseconfig/... && go vet ./internal/gooseconfig/...`
Expected: builds clean. (`go build ./...` for the whole module will fail until Task 3 removes the caller of the now-deleted `RenderPermissions` — that's expected and fixed next task; don't chase it here.)

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/gooseconfig/permissions.go services/pocketbase/internal/gooseconfig/permissions_test.go
git commit -m "feat(gooseconfig): replace RenderPermissions allowlist with per-tool RenderToolPermissions"
```

---

### Task 3: Drop `extensions` from `config.yaml`, deliver tool permissions live

**Files:**
- Modify: `services/pocketbase/internal/gooseconfig/config.go`
- Modify: `services/pocketbase/internal/gooseconfig/config_test.go`
- Modify: `services/pocketbase/internal/gooseconfig/testdata/config_basic.yaml`
- Modify: `services/pocketbase/internal/hooks/goose_config.go`
- Create: `services/pocketbase/internal/hooks/goose_config_permissions_test.go`
- Modify: `services/pocketbase/internal/api/agent.go`
- Modify: `services/pocketbase/main.go`

**Interfaces:**
- Consumes: `gooseconfig.RenderToolPermissions` (Task 2), `acp.Conn.CallExtension` (existing), `Coordinator.AdminConn` (existing).
- Produces: `hooks.RegisterGooseConfigHooks(app core.App, coord func() *coordinator.Coordinator)` (signature change — was `(app core.App)`), `api.RegisterAgentApi`/`registerAgentApi` now return `(*coordinator.Coordinator, error)`. Task 4 reuses the same `coord` getter.

This is the spec's Component 4, and per the spec it must land as one change: removing `config.yaml`'s `extensions` key without the live-delivery replacement would silently stop enforcing tool permissions.

**Why a getter, not a direct value:** `RegisterGooseConfigHooks` is called from `main.go` before the `*coordinator.Coordinator` exists — the coordinator is only built inside the `app.OnServe()` handler (via `RegisterAgentApi`), but `RegisterGooseConfigHooks`'s hook *bindings* need to be registered earlier, at the same point they are today. A `func() *coordinator.Coordinator` closure lets `main.go` wire the two together: the hook closures capture the getter, and by the time any of them actually fires (always after `OnServe` has run — PocketBase serves no requests and processes no record events until `OnServe` completes), the getter returns a real coordinator. If the coordinator is nil (agent profile disabled, or `configErr != nil`), the live-delivery call skips itself and logs — same pattern the spec's Error Handling section already calls for.

- [ ] **Step 1: Write the failing test for the render-time behavior (no `extensions` key)**

Replace the full contents of `services/pocketbase/internal/gooseconfig/config_test.go`:

```go
package gooseconfig

import "testing"

func TestRenderConfigYAML_NoExtensionsKey(t *testing.T) {
	got, err := RenderConfigYAML(ConfigInput{
		Provider: "anthropic", Model: "MiniMax-M2.5", Mode: "approve",
	})
	if err != nil {
		t.Fatal(err)
	}
	want := "GOOSE_MODE: approve\nGOOSE_MODEL: MiniMax-M2.5\nGOOSE_PROVIDER: anthropic\n"
	if string(got) != want {
		t.Fatalf("config.yaml mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/gooseconfig/... -run TestRenderConfigYAML_NoExtensionsKey -v`
Expected: FAIL — got output still contains an `extensions:` key would fail the string comparison, OR a compile error if `ConfigInput.AvailableTools` no longer exists yet (it still does at this point — the old golden test/data haven't been touched, so this is a genuine behavior-mismatch failure, not a compile error).

- [ ] **Step 3: Drop `extensions`/`AvailableTools` from `config.go`**

In `services/pocketbase/internal/gooseconfig/config.go`, replace the full file:

```go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Goose Config. Renders config.yaml and keys.env consumed by the c2 goose container.
package gooseconfig

import "gopkg.in/yaml.v3"

// ConfigInput captures the resolved default poco_config fields needed to render
// a Goose config.yaml. The hook layer fills this from the default poco_config;
// this package stays pure (no I/O, no PB types).
//
// Deliberately does NOT carry tool permissions or extensions: Goose is the
// sole writer of config.yaml's `extensions` key (via _goose/unstable/
// config/extensions/add, called by hooks.RegisterMcpGatewayExtension and
// tools/permissions/set, called by hooks.deliverToolPermissions) — writing
// either here would clobber whatever Goose itself has written live.
type ConfigInput struct {
	Provider, Model, Mode string
	// Instructions is intentionally omitted: config.yaml has no documented
	// global system-prompt key. Add only if verification confirms one.
}

// RenderConfigYAML renders a Goose config.yaml: GOOSE_PROVIDER/MODEL/MODE
// only. No secrets (they live in keys.env). No extensions (Goose owns that
// key exclusively — see ConfigInput's doc comment).
func RenderConfigYAML(in ConfigInput) ([]byte, error) {
	doc := map[string]any{
		"GOOSE_PROVIDER": in.Provider,
		"GOOSE_MODEL":    in.Model,
		"GOOSE_MODE":     in.Mode,
	}
	return yaml.Marshal(doc)
}
```

- [ ] **Step 4: Delete the now-stale golden fixture content**

Replace `services/pocketbase/internal/gooseconfig/testdata/config_basic.yaml` with:

```yaml
GOOSE_MODE: approve
GOOSE_MODEL: MiniMax-M2.5
GOOSE_PROVIDER: anthropic
```

(This file is no longer read by any test after Step 1's rewrite inlined the expected string — delete it instead if you prefer, but leaving it consistent avoids confusion for anyone grepping `testdata/`.)

- [ ] **Step 5: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/gooseconfig/... -v`
Expected: all tests in the package PASS, including `TestRenderConfigYAML_NoExtensionsKey` and Task 2's `TestRenderToolPermissions_*`.

- [ ] **Step 6: Update `hooks/goose_config.go` — stop populating `AvailableTools`, add live delivery**

Read the current file first (`services/pocketbase/internal/hooks/goose_config.go`) — it's ~212 lines. Replace it in full:

```go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Goose Config Hooks. Renders config.yaml + keys.env from
// PocketBase agent-definition records, writes them goose-uid-owned, then
// restarts the goose container so the new config takes effect. Also
// delivers the tool-permission allowlist live over ACP (config.yaml no
// longer carries it — Goose is the sole writer of its `extensions` key).
package hooks

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/gooseconfig"
)

// gooseConfigDir is the PocketBase-side mount of the shared goose_config volume.
// Goose 1.43.0 derives its config dir from GOOSE_PATH_ROOT=/goose, reading
// /goose/config/config.yaml (confirmed via `goose info`), NOT ~/.config/goose.
var gooseConfigDir = "/goose-config"

// gooseUID/GID own the rendered files so the non-root goose user can read them.
var gooseUID, gooseGID = 1000, 1000

// RegisterGooseConfigHooks wires CRUD events on the agent-definition
// collections to a render+restart handler and a live tool-permission
// delivery call, and runs an initial render on serve startup (no restart —
// goose may not exist yet). coord returns the coordinator built inside
// main.go's OnServe handler; it is nil until that handler runs, and stays
// nil if the agent profile isn't configured — callers must handle nil.
func RegisterGooseConfigHooks(app core.App, coord func() *coordinator.Coordinator) {
	log.Println("🪿 [GooseConfig] Registering Goose config hooks...")

	handler := func(e *core.RecordEvent) error {
		err := renderAndRestart("[GooseConfig]", func() error { return renderGooseConfig(app) }, GooseContainer, e)
		deliverToolPermissions(app, coord)
		return err
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

// renderGooseConfig walks the agent-definition collections and writes the two
// files Goose consumes: config.yaml (model/provider/mode) and keys.env
// (merged provider_keys env_vars). Returns nil if there is no default
// poco_config — Goose then runs on compose-env defaults.
func renderGooseConfig(app core.App) error {
	if err := os.MkdirAll(gooseConfigDir, 0o755); err != nil {
		return fmt.Errorf("mkdir goose config dir: %w", err)
	}

	keyRecs, err := app.FindRecordsByFilter("provider_keys", "1=1", "", 0, 0)
	if err != nil {
		return fmt.Errorf("query provider_keys: %w", err)
	}
	sets := make([]map[string]any, 0, len(keyRecs))
	for _, r := range keyRecs {
		m := map[string]any{}
		if err := r.UnmarshalJSONField("env_vars", &m); err != nil {
			log.Printf("⚠️ [GooseConfig] bad env_vars on provider_keys/%s: %v", r.Id, err)
			continue
		}
		sets = append(sets, m)
	}
	if err := writeGoose("keys.env", gooseconfig.RenderKeysEnv(sets), 0o600); err != nil {
		return err
	}

	def, err := defaultPocoConfig(app)
	if err != nil {
		return err
	}
	if def == nil {
		log.Println("ℹ️  [GooseConfig] no default poco_config; goose runs on compose-env defaults")
		return nil
	}

	in, err := configInputFor(app, def)
	if err != nil {
		return err
	}

	yamlBytes, err := gooseconfig.RenderConfigYAML(in)
	if err != nil {
		return fmt.Errorf("render config.yaml: %w", err)
	}
	return writeGoose("config.yaml", yamlBytes, 0o640)
}

// defaultPocoConfig returns the single agent definition that drives the global
// goose config, applying the spec §5.2 tie-break: is_default=true, deterministic
// first-on-multiple, nil-on-none.
func defaultPocoConfig(app core.App) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("poco_configs", "is_default = true", "name", 0, 0)
	if err != nil {
		return nil, fmt.Errorf("query default poco_configs: %w", err)
	}
	if len(recs) == 0 {
		return nil, nil
	}
	if len(recs) > 1 {
		log.Printf("⚠️ [GooseConfig] %d poco_configs marked is_default; using first by name %q", len(recs), recs[0].GetString("name"))
	}
	return recs[0], nil
}

// configInputFor resolves the provider/model/mode for the given default
// poco_config. Tool permissions are no longer part of this — see
// deliverToolPermissions.
func configInputFor(app core.App, def *core.Record) (gooseconfig.ConfigInput, error) {
	in := gooseconfig.ConfigInput{
		Mode: def.GetString("mode"),
	}

	if hmID := def.GetString("harness_model"); hmID != "" {
		hm, err := app.FindRecordById("harness_models", hmID)
		if err != nil {
			return in, fmt.Errorf("resolve poco_configs.harness_model=%s: %w", hmID, err)
		}
		in.Model = hm.GetString("harness_model_id")
		if mID := hm.GetString("model"); mID != "" {
			m, err := app.FindRecordById("models", mID)
			if err != nil {
				return in, fmt.Errorf("resolve harness_models.model=%s: %w", mID, err)
			}
			in.Provider = m.GetString("provider")
		}
	}
	return in, nil
}

// activeToolPermissionRows queries the same tool_permissions rows the old
// config.yaml render used: active rows, global (poco_config empty) or scoped
// to the current default poco_config.
func activeToolPermissionRows(app core.App) ([]gooseconfig.PermRow, error) {
	def, err := defaultPocoConfig(app)
	if err != nil {
		return nil, err
	}
	if def == nil {
		return nil, nil
	}
	perms, err := app.FindRecordsByFilter("tool_permissions", "active = true", "", 0, 0)
	if err != nil {
		return nil, fmt.Errorf("query tool_permissions: %w", err)
	}
	defID := def.Id
	rows := make([]gooseconfig.PermRow, 0, len(perms))
	for _, p := range perms {
		scope := p.GetString("poco_config")
		if scope != "" && scope != defID {
			continue
		}
		rows = append(rows, gooseconfig.PermRow{
			Tool:    p.GetString("tool"),
			Pattern: p.GetString("pattern"),
			Action:  p.GetString("action"),
		})
	}
	return rows, nil
}

// setToolPermissionsParams mirrors Goose's
// _goose/unstable/tools/permissions/set request
// (SetToolPermissionsRequest_unstable), verified against acp-schema.json.
type setToolPermissionsParams struct {
	ToolPermissions []toolPermissionEntryParam `json:"toolPermissions"`
}

type toolPermissionEntryParam struct {
	ToolName   string `json:"toolName"`
	Permission string `json:"permission"`
}

// deliverToolPermissions resolves the active tool_permissions rows and pushes
// them to Goose live via tools/permissions/set. Best-effort: logs and
// returns on any failure (missing coordinator, unreachable Goose, etc.) —
// never blocks the calling hook's render+restart.
func deliverToolPermissions(app core.App, coord func() *coordinator.Coordinator) {
	c := coord()
	if c == nil {
		log.Println("ℹ️  [GooseConfig] no coordinator (agent profile disabled); skipping live tool-permission delivery")
		return
	}
	rows, err := activeToolPermissionRows(app)
	if err != nil {
		log.Printf("⚠️ [GooseConfig] failed to resolve tool_permissions rows: %v", err)
		return
	}
	entries, dropped := gooseconfig.RenderToolPermissions(rows)
	for _, d := range dropped {
		log.Printf("⚠️ [GooseConfig] %s", d)
	}
	params := setToolPermissionsParams{ToolPermissions: make([]toolPermissionEntryParam, 0, len(entries))}
	for _, e := range entries {
		params.ToolPermissions = append(params.ToolPermissions, toolPermissionEntryParam{ToolName: e.ToolName, Permission: e.Permission})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [GooseConfig] AdminConn failed, tool permissions not delivered live: %v", err)
		return
	}
	defer conn.Close()
	if _, err := conn.CallExtension(ctx, "_goose/unstable/tools/permissions/set", params); err != nil {
		log.Printf("⚠️ [GooseConfig] tools/permissions/set failed: %v", err)
		return
	}
	log.Printf("✅ [GooseConfig] delivered %d tool permission(s) live", len(params.ToolPermissions))
}

// writeGoose writes data to gooseConfigDir/name with the given mode and best-
// effort chown to the goose uid. On dev hosts the chown may fail (not root)
// — log, don't fail the render.
func writeGoose(name string, data []byte, mode os.FileMode) error {
	path := filepath.Join(gooseConfigDir, name)
	if err := os.WriteFile(path, data, mode); err != nil {
		return fmt.Errorf("write %s: %w", name, err)
	}
	if gooseUID >= 0 && gooseGID >= 0 {
		if err := os.Chown(path, gooseUID, gooseGID); err != nil {
			log.Printf("⚠️ [GooseConfig] chown %s failed (dev host?): %v", name, err)
		}
	}
	return nil
}
```

- [ ] **Step 7: Write the failing test for `deliverToolPermissions`**

Create `services/pocketbase/internal/hooks/goose_config_permissions_test.go`. **No test in this codebase currently uses `github.com/pocketbase/pocketbase/tests.NewTestApp()`** (confirmed — zero hits for `pocketbase/tests"` anywhere in `services/pocketbase`), so this is new ground, not an established local pattern. It is, however, PocketBase's own documented way to get a real, disposable `core.App` with your project's actual collections: `tests.NewTestApp()` clones a data dir and calls `app.RunAllMigrations()`, which applies every migration registered via `pb_migrations`' blank import — so this test file must blank-import `pb_migrations` itself (it currently isn't imported anywhere under `internal/hooks`) or `FindCollectionByNameOrId("poco_configs")` will fail with "not found". Verify this works by running Step 8 before writing more tests that depend on it — if `tests.NewTestApp()` errors or migrations don't apply, stop and re-read `pb_migrations`' package for anything that assumes it only ever runs once per real app lifetime before adapting further.

```go
package hooks

import (
	"context"
	"encoding/json"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

// fakeAdminConn is a minimal acp.Conn double for deliverToolPermissions'
// tests — only CallExtension is exercised; every other method is
// unreachable (AdminConn never creates a session or runs a prompt).
type fakeAdminConn struct {
	lastMethod string
	lastParams any
	calls      int
}

func (f *fakeAdminConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeAdminConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *fakeAdminConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeAdminConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeAdminConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeAdminConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	f.lastMethod = method
	f.lastParams = params
	f.calls++
	return json.RawMessage(`{}`), nil
}
func (f *fakeAdminConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeAdminConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *fakeAdminConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeAdminConn) Close() error { return nil }

var _ acp.Conn = (*fakeAdminConn)(nil)

func TestDeliverToolPermissions_SkipsWhenNoCoordinator(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	// Must not panic when coord() returns nil (agent profile disabled).
	deliverToolPermissions(app, func() *coordinator.Coordinator { return nil })
}

func TestDeliverToolPermissions_CallsToolsPermissionsSetWithResolvedRows(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	fc := &fakeAdminConn{}
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		t.Fatalf("coordinator.New: %v", err)
	}

	poco, err := app.FindCollectionByNameOrId("poco_configs")
	if err != nil {
		t.Fatalf("find poco_configs collection: %v", err)
	}
	rec := core.NewRecord(poco)
	rec.Set("name", "default")
	rec.Set("is_default", true)
	if err := app.Save(rec); err != nil {
		t.Fatalf("save poco_config: %v", err)
	}

	perms, err := app.FindCollectionByNameOrId("tool_permissions")
	if err != nil {
		t.Fatalf("find tool_permissions collection: %v", err)
	}
	permRec := core.NewRecord(perms)
	permRec.Set("tool", "read")
	permRec.Set("action", "allow")
	permRec.Set("pattern", "*")
	permRec.Set("active", true)
	if err := app.Save(permRec); err != nil {
		t.Fatalf("save tool_permissions row: %v", err)
	}

	deliverToolPermissions(app, func() *coordinator.Coordinator { return coord })

	if fc.calls != 1 {
		t.Fatalf("CallExtension calls = %d, want 1", fc.calls)
	}
	if fc.lastMethod != "_goose/unstable/tools/permissions/set" {
		t.Fatalf("method = %q, want tools/permissions/set", fc.lastMethod)
	}
	// lastParams is stored as `any` (CallExtension's own signature) but the
	// caller (deliverToolPermissions) always passes a concrete
	// setToolPermissionsParams value, never a pointer — assert against that
	// exact type, matching how it's constructed in goose_config.go.
	params, ok := fc.lastParams.(setToolPermissionsParams)
	if !ok {
		t.Fatalf("params type = %T, want setToolPermissionsParams", fc.lastParams)
	}
	if len(params.ToolPermissions) != 1 || params.ToolPermissions[0].ToolName != "read" || params.ToolPermissions[0].Permission != "always_allow" {
		t.Fatalf("params = %+v, want one read/always_allow entry", params)
	}
}
```

- [ ] **Step 8: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/hooks/... -run TestDeliverToolPermissions -v`
Expected: compile error (`deliverToolPermissions`/`setToolPermissionsParams` already exist from Step 6, so this should actually run — if Step 6 was done first, skip ahead and confirm PASS instead; if you're following strict TDD order, do Step 7 test-writing before Step 6's implementation and expect `undefined: deliverToolPermissions` here). If `tests.NewTestApp()` itself errors (e.g. "collection not found" for `poco_configs`), the blank `pb_migrations` import isn't taking effect — confirm `pb_migrations`' `init()`/`Register` calls actually populate `core.AppMigrations` (or whatever registry `RunAllMigrations` reads) on blank import alone, by checking one file in `services/pocketbase/pb_migrations/`.

- [ ] **Step 9: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/hooks/... -run TestDeliverToolPermissions -v`
Expected: both tests PASS.

- [ ] **Step 10: Wire the coordinator through `main.go` and `api/agent.go`**

In `services/pocketbase/internal/api/agent.go`:
1. Change the signature at line 43-45:

```go
// RegisterAgentApi registers PocketBase-owned routes. AG-UI is the response
// format, not a second public service and never exposes Goose credentials.
// Returns the constructed Coordinator (nil if configErr != nil) so callers
// outside this package (main.go) can reuse it for admin-connection work
// that isn't tied to any HTTP route.
func RegisterAgentApi(app *pocketbase.PocketBase, e *core.ServeEvent) (*coordinator.Coordinator, error) {
	return registerAgentApi(app, e, nil) // nil => coordinator.New uses the real acp.Dial
}
```

2. Change line 50 to return:

```go
func registerAgentApi(app *pocketbase.PocketBase, e *core.ServeEvent, dial coordinator.DialFunc) (*coordinator.Coordinator, error) {
```

3. At the end of the function (currently the closing `}` at line 327), add the return before it:

```go
	return service, configErr
}
```

In `services/pocketbase/main.go`, replace the full file:

```go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Main Orchestrator. Registers hooks, starts the relay, and boots PocketBase.
// @pocketcoder-core: Sovereign Relay. The orchestration layer that syncs the agent runtime with the Sandbox.
package main

import (
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/api"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/provisioning"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func main() {
	app := pocketbase.New()

	// coord is nil until RegisterAgentApi runs inside OnServe below, and
	// stays nil if the agent profile isn't configured. Hooks registered
	// before OnServe (goose config, MCP) capture this getter and only
	// dereference it when an actual event fires — always after OnServe has
	// completed, since PocketBase serves no requests and processes no
	// record CRUD hooks tied to app routes until then.
	var coord *coordinator.Coordinator
	coordGetter := func() *coordinator.Coordinator { return coord }

	// 1. Register Migrations
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: true,
	})

	// 2. Register Global Sovereign Hooks
	hooks.RegisterGlobalTimestamps(app)
	hooks.RegisterSopHooks(app)
	hooks.RegisterNotificationHooks(app)

	// 3. Register MCP Hooks (config rendering + gateway restart)
	// The interface receives MCP status updates via PocketBase realtime subscriptions.
	hooks.RegisterMcpHooks(app)

	// 3b. Register Goose Config Hooks (config.yaml + keys.env render + goose
	// restart + live tool-permission delivery)
	hooks.RegisterGooseConfigHooks(app, coordGetter)

	// 3c. Register Cron Hooks (scheduled agent tasks)
	hooks.RegisterCronHooks(app)

	// 4. Main Application Boot & API Registration
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		app.Logger().Info("🚀 Starting PocketCoder Sovereign Backend...")

		// A. Provision SOPs from filesystem
		provisioning.ProvisionSops(app)

		// B. Register Custom API Endpoints
		api.RegisterSSHApi(app, e)
		api.RegisterMcpApi(app, e)
		api.RegisterProxyApi(app, e)
		api.RegisterLogsApi(app, e)
		api.RegisterCronApi(app, e)
		var err error
		coord, err = api.RegisterAgentApi(app, e)
		if err != nil {
			app.Logger().Warn("agent API not configured; agent profile disabled", "error", err)
		}
		filesystem.RegisterFilesApi(app, e)
		hooks.RegisterPushApi(app, e)

		// C. One-time MCP gateway extension registration (idempotent,
		// retried with backoff — see RegisterMcpGatewayExtension).
		go hooks.RegisterMcpGatewayExtension(coordGetter)

		return e.Next()
	})

	// 5. Launch PocketBase
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
```

(`hooks.RegisterMcpGatewayExtension` is created in Task 4 — this file will not compile until that task lands. That's expected; Task 4 is the very next task and this plan is executed in order.)

- [ ] **Step 11: Run the full package build (will still fail — expected until Task 4)**

Run: `cd services/pocketbase && go build ./...`
Expected: fails with `undefined: hooks.RegisterMcpGatewayExtension` only — no other errors. If any other error appears, fix it before moving to Task 4 (it means Steps 6/10 introduced an unrelated break).

- [ ] **Step 12: Commit**

```bash
git add services/pocketbase/internal/gooseconfig/config.go services/pocketbase/internal/gooseconfig/config_test.go services/pocketbase/internal/gooseconfig/testdata/config_basic.yaml services/pocketbase/internal/hooks/goose_config.go services/pocketbase/internal/hooks/goose_config_permissions_test.go services/pocketbase/internal/api/agent.go services/pocketbase/main.go
git commit -m "feat(goose-config): stop writing extensions key, deliver tool permissions live via AdminConn"
```

---

### Task 4: One-time MCP gateway extension registration

**Files:**
- Create: `services/pocketbase/internal/hooks/mcp_gateway.go`
- Create: `services/pocketbase/internal/hooks/mcp_gateway_test.go`

**Interfaces:**
- Consumes: `func() *coordinator.Coordinator` (Task 3's `coordGetter`, already wired into `main.go`'s call site from Task 3 Step 10), `Coordinator.AdminConn`, `acp.Conn.CallExtension`.
- Produces: `func RegisterMcpGatewayExtension(coord func() *coordinator.Coordinator)` — makes `services/pocketbase/main.go` (Task 3 Step 10) compile.

This is the spec's Component 3. Exact ACP method names/params verified against `acp-meta.json`/`acp-schema.json`:
- `_goose/unstable/config/extensions/list` — empty request (`GetConfigExtensionsRequest_unstable`), response `{extensions: [{extension: {name, type, ...}, enabled, configKey}], warnings: []}`.
- `_goose/unstable/config/extensions/add` — request `{extension: {...}, enabled: bool}` (`AddConfigExtensionRequest_unstable`), empty response.
- The `mcp` variant of `GooseExtension` (verified in `acp-schema.json`'s `GooseExtension` def and confirmed live in the spike): `{"server": {"type": "http", "name": ..., "url": ..., "headers": [...]}, ...}`, `type: "http"` inside `server` (the top-level `extension.type` discriminator for the mcp variant is implicit via the `server` field being present — the spike's real request used `{"extension": {"type": "mcp", "server": {"type": "http", ...}}, "enabled": true}`, matching `services/goose/Dockerfile`'s pinned image; use that exact shape).

- [ ] **Step 1: Write the failing test**

Create `services/pocketbase/internal/hooks/mcp_gateway_test.go`:

```go
package hooks

import (
	"context"
	"encoding/json"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// fakeGatewayConn is a scriptable acp.Conn double: CallExtension responds
// differently per method so tests can simulate "gateway already registered"
// vs. "not yet registered".
type fakeGatewayConn struct {
	extensionsListResponse string // raw JSON returned for config/extensions/list
	calls                   []string
}

func (f *fakeGatewayConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeGatewayConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *fakeGatewayConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeGatewayConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeGatewayConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeGatewayConn) CallExtension(_ context.Context, method string, _ any) (json.RawMessage, error) {
	f.calls = append(f.calls, method)
	if method == "_goose/unstable/config/extensions/list" {
		return json.RawMessage(f.extensionsListResponse), nil
	}
	return json.RawMessage(`{}`), nil
}
func (f *fakeGatewayConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeGatewayConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *fakeGatewayConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeGatewayConn) Close() error { return nil }

var _ acp.Conn = (*fakeGatewayConn)(nil)

func newTestCoordinator(t *testing.T, fc *fakeGatewayConn) *coordinator.Coordinator {
	t.Helper()
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		t.Fatalf("coordinator.New: %v", err)
	}
	return coord
}

func TestRegisterMcpGatewayExtension_SkipsWhenNoCoordinator(t *testing.T) {
	// Must not panic/block when the agent profile is disabled.
	registerMcpGatewayExtensionOnce(context.Background(), func() *coordinator.Coordinator { return nil })
}

func TestRegisterMcpGatewayExtension_AddsWhenAbsent(t *testing.T) {
	fc := &fakeGatewayConn{extensionsListResponse: `{"extensions":[],"warnings":[]}`}
	coord := newTestCoordinator(t, fc)

	registerMcpGatewayExtensionOnce(context.Background(), func() *coordinator.Coordinator { return coord })

	if len(fc.calls) != 2 || fc.calls[0] != "_goose/unstable/config/extensions/list" || fc.calls[1] != "_goose/unstable/config/extensions/add" {
		t.Fatalf("calls = %v, want [list, add]", fc.calls)
	}
}

func TestRegisterMcpGatewayExtension_SkipsWhenAlreadyPresent(t *testing.T) {
	fc := &fakeGatewayConn{extensionsListResponse: `{"extensions":[{"extension":{"name":"gateway"},"enabled":true}],"warnings":[]}`}
	coord := newTestCoordinator(t, fc)

	registerMcpGatewayExtensionOnce(context.Background(), func() *coordinator.Coordinator { return coord })

	if len(fc.calls) != 1 || fc.calls[0] != "_goose/unstable/config/extensions/list" {
		t.Fatalf("calls = %v, want [list] only (already registered, no add call)", fc.calls)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/hooks/... -run TestRegisterMcpGatewayExtension -v`
Expected: compile error — `undefined: registerMcpGatewayExtensionOnce`.

- [ ] **Step 3: Implement `mcp_gateway.go`**

Create `services/pocketbase/internal/hooks/mcp_gateway.go`:

```go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: MCP Gateway Registration. One-time, idempotent
// registration of the Docker MCP Gateway as a Goose extension. See
// docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md Component 3
// and spikes/goose-mcp-gateway-attach/README.md for the verified request
// shapes and the SSE-vs-streaming transport finding this depends on
// (docker-compose.yml's mcp-gateway must run --transport streaming).
package hooks

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// mcpGatewayExtensionName must match the "name" field in the request built
// by registerMcpGatewayExtensionOnce below.
const mcpGatewayExtensionName = "gateway"

// mcpGatewayURL is the gateway's Streamable-HTTP endpoint on the dedicated
// goose<->mcp-gateway Docker network (docker-compose.yml).
const mcpGatewayURL = "http://mcp-gateway:8811/mcp"

// RegisterMcpGatewayExtension attempts gateway registration in a bounded
// retry loop and returns once it either succeeds, confirms the extension is
// already present, or exhausts its retries. Intended to be called with `go`
// from main.go's OnServe handler — never blocks PocketBase startup.
func RegisterMcpGatewayExtension(coord func() *coordinator.Coordinator) {
	const maxAttempts = 6
	const retryDelay = 10 * time.Second

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		ok := registerMcpGatewayExtensionOnce(ctx, coord)
		cancel()
		if ok {
			return
		}
		if attempt < maxAttempts {
			log.Printf("🐳 [MCPGateway] registration attempt %d/%d failed, retrying in %s", attempt, maxAttempts, retryDelay)
			time.Sleep(retryDelay)
		}
	}
	log.Printf("❌ [MCPGateway] gave up registering gateway extension after %d attempts", maxAttempts)
}

// registerMcpGatewayExtensionOnce does one gate-check-add pass. Returns true
// if the caller should stop retrying (success, already-registered, or the
// agent profile isn't configured at all — retrying that case is pointless).
func registerMcpGatewayExtensionOnce(ctx context.Context, coord func() *coordinator.Coordinator) bool {
	if os.Getenv("GOOSE_ACP_URL") == "" || os.Getenv("GOOSE_SERVER__SECRET_KEY") == "" || os.Getenv("GOOSE_WORKSPACE") == "" {
		log.Println("ℹ️  [MCPGateway] agent profile not configured (GOOSE_ACP_URL/GOOSE_SERVER__SECRET_KEY/GOOSE_WORKSPACE unset); skipping gateway registration")
		return true
	}
	c := coord()
	if c == nil {
		log.Println("⚠️ [MCPGateway] agent profile configured but coordinator not yet available")
		return false
	}

	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [MCPGateway] AdminConn failed: %v", err)
		return false
	}
	defer conn.Close()

	listRaw, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/list", struct{}{})
	if err != nil {
		log.Printf("⚠️ [MCPGateway] config/extensions/list failed: %v", err)
		return false
	}
	var listResp struct {
		Extensions []struct {
			Extension struct {
				Name string `json:"name"`
			} `json:"extension"`
		} `json:"extensions"`
	}
	if err := json.Unmarshal(listRaw, &listResp); err != nil {
		log.Printf("⚠️ [MCPGateway] failed to parse config/extensions/list response: %v", err)
		return false
	}
	for _, e := range listResp.Extensions {
		if e.Extension.Name == mcpGatewayExtensionName {
			log.Println("✅ [MCPGateway] gateway extension already registered")
			return true
		}
	}

	addReq := addConfigExtensionParams{
		Extension: gooseExtensionParam{
			Type: "mcp",
			Server: mcpServerHttpParam{
				Type:    "http",
				Name:    mcpGatewayExtensionName,
				URL:     mcpGatewayURL,
				Headers: []string{},
			},
		},
		Enabled: true,
	}
	if _, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/add", addReq); err != nil {
		log.Printf("⚠️ [MCPGateway] config/extensions/add failed: %v", err)
		return false
	}
	log.Println("✅ [MCPGateway] registered gateway extension")
	return true
}

// addConfigExtensionParams mirrors AddConfigExtensionRequest_unstable
// (acp-schema.json). gooseExtensionParam/mcpServerHttpParam mirror the "mcp"
// variant of GooseExtension and the "http" variant of McpServer respectively
// — verified live in spikes/goose-mcp-gateway-attach/README.md's captured
// request/response.
type addConfigExtensionParams struct {
	Extension gooseExtensionParam `json:"extension"`
	Enabled   bool                `json:"enabled"`
}

type gooseExtensionParam struct {
	Type   string              `json:"type"`
	Server mcpServerHttpParam  `json:"server"`
}

type mcpServerHttpParam struct {
	Type    string   `json:"type"`
	Name    string   `json:"name"`
	URL     string   `json:"url"`
	Headers []string `json:"headers"`
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/hooks/... -run TestRegisterMcpGatewayExtension -v`
Expected: all 3 subtests PASS.

- [ ] **Step 5: Full build check**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: builds clean, all tests pass (this is the first point since Task 2 where `go build ./...` for the whole module is expected to succeed — Task 3 Step 11 deliberately left it broken pending this task).

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/hooks/mcp_gateway.go services/pocketbase/internal/hooks/mcp_gateway_test.go
git commit -m "feat(mcp): one-time idempotent gateway extension registration via AdminConn"
```

---

### Task 5: `mcp_servers` create hook — manual-add reaches the gateway

**Files:**
- Modify: `services/pocketbase/internal/hooks/mcp.go`

**Interfaces:**
- Consumes: nothing new.
- Produces: a manually created `mcp_servers` row with `status: 'approved'` now triggers the same render+restart the existing update path already does. Task 7 (Flutter `createServer`) relies on this.

- [ ] **Step 1: Write the failing test**

First check whether `services/pocketbase/internal/hooks/mcp_test.go` already exists (`ls services/pocketbase/internal/hooks/mcp_test.go`). If it doesn't, create it:

Uses the same `tests.NewTestApp()` + blank `pb_migrations` import pattern as Task 3 Step 7 (see that step's note — this is new ground for this codebase, no prior local precedent):

```go
package hooks

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestRegisterMcpHooks_CreateWithApprovedStatusTriggersRender(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	RegisterMcpHooks(app)

	coll, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatalf("find mcp_servers collection: %v", err)
	}
	rec := core.NewRecord(coll)
	rec.Set("name", "manually-added-server")
	rec.Set("status", "approved")

	// This must not error — the create hook firing is enough evidence for
	// this unit test; renderMcpConfig's file-write behavior is already
	// covered by the render logic itself (unchanged by this task) and by
	// Task 8's integration test.
	if err := app.Save(rec); err != nil {
		t.Fatalf("save mcp_servers record: %v", err)
	}
}
```

Add `"github.com/pocketbase/pocketbase/core"` to the import block (needed for `core.NewRecord`).

If `mcp_test.go` already exists, add this test function to it instead of creating a new file, matching whatever import/setup style is already there.

- [ ] **Step 2: Run test to verify it fails**

This test won't actually *fail* to compile or run before the fix — the create currently just succeeds without triggering a render, which this unit test as written can't directly observe (it only asserts `Save` doesn't error). Skip the strict red-green cycle for this specific assertion; instead verify the gap manually first:

Run: `cd services/pocketbase && go test ./internal/hooks/... -run TestRegisterMcpHooks_CreateWithApprovedStatusTriggersRender -v`
Expected: PASS even before the fix (the test as written can't distinguish "no hook fired" from "hook fired but did nothing observable" without a render-side effect to inspect, which needs the full `/mcp_config` filesystem present — out of scope for a unit test). This is why Task 8's integration test is the real regression guard for this behavior; this unit test only documents intent and guards against a panic/error on create. Proceed to Step 3 regardless.

- [ ] **Step 3: Add the create-hook binding**

In `services/pocketbase/internal/hooks/mcp.go`, find `RegisterMcpHooks` (currently lines 39-79). Change:

```go
	app.OnRecordAfterUpdateSuccess("mcp_servers").BindFunc(func(e *core.RecordEvent) error {
		record := e.Record
		newStatus := record.GetString("status")
		serverName := record.GetString("name")

		log.Printf("🔌 [MCP] Server '%s' status changed to '%s'", serverName, newStatus)

		switch newStatus {
		case "approved", "revoked":
			log.Printf("🔌 [MCP] Processing %s for server '%s'", newStatus, serverName)
			if err := renderMcpConfig(app); err != nil {
				log.Printf("❌ [MCP] Failed to render config: %v", err)
				return e.Next()
			}
			if err := restartContainer(GatewayContainer, 30*time.Second); err != nil {
				log.Printf("❌ [MCP] Failed to restart gateway: %v", err)
			}
		case "denied":
			log.Printf("🔌 [MCP] Server '%s' was denied", serverName)
		}

		return e.Next()
	})
```

to:

```go
	mcpStatusHandler := func(e *core.RecordEvent) error {
		record := e.Record
		newStatus := record.GetString("status")
		serverName := record.GetString("name")

		log.Printf("🔌 [MCP] Server '%s' status is '%s'", serverName, newStatus)

		switch newStatus {
		case "approved", "revoked":
			log.Printf("🔌 [MCP] Processing %s for server '%s'", newStatus, serverName)
			if err := renderMcpConfig(app); err != nil {
				log.Printf("❌ [MCP] Failed to render config: %v", err)
				return e.Next()
			}
			if err := restartContainer(GatewayContainer, 30*time.Second); err != nil {
				log.Printf("❌ [MCP] Failed to restart gateway: %v", err)
			}
		case "denied":
			log.Printf("🔌 [MCP] Server '%s' was denied", serverName)
		}

		return e.Next()
	}
	// Update covers the agent-request -> human-approve flow (pending ->
	// approved/denied). Create covers manual add-by-human, which creates the
	// row already 'approved' — without this binding that row would never
	// reach the gateway's catalog until an unrelated update or restart.
	app.OnRecordAfterCreateSuccess("mcp_servers").BindFunc(mcpStatusHandler)
	app.OnRecordAfterUpdateSuccess("mcp_servers").BindFunc(mcpStatusHandler)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/hooks/... -run TestRegisterMcpHooks_CreateWithApprovedStatusTriggersRender -v`
Expected: PASS.

- [ ] **Step 5: Full package check**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/hooks/mcp.go services/pocketbase/internal/hooks/mcp_test.go
git commit -m "fix(mcp): trigger render+restart on mcp_servers create, not just update"
```

---

### Task 6: Flutter — `createServer()` repository + cubit method

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart`
- Test: `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`

**Interfaces:**
- Consumes: `McpServerDao` (existing, `mcp_daos.dart`), `BaseDao.save(String? id, Map<String, dynamic> data)` (existing — `save(null, data)` creates).
- Produces: `IMcpRepository.createServer({required String name, String? image, Map<String, dynamic>? config})`, `McpCubit.createServer(...)` (same params). Task 7's dialog calls `context.read<McpCubit>().createServer(...)`.

- [ ] **Step 1: Write the failing repository test**

Create `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart`, mirroring `test/infrastructure/agent_config/agent_config_repository_test.dart`'s exact pattern (`MockXxxDao extends Mock implements XxxDao`, mock `dao.save(any(), any())`, verify exact call args). `BaseDao<T>.save` returns `Future<McpServer>`, so the mock's `thenAnswer` must return a real `McpServer` — use a `Fake`, matching `_FakePocoConfig`'s pattern in the agent_config test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_repository.dart';

class MockMcpServerDao extends Mock implements McpServerDao {}

class _FakeMcpServer extends Fake implements McpServer {}

void main() {
  late McpRepository repo;
  late MockMcpServerDao dao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dao = MockMcpServerDao();
    repo = McpRepository(dao);
  });

  group('McpRepository.createServer', () {
    test('creates an mcp_servers row with status approved via dao.save(null, ...)',
        () async {
      when(() => dao.save(any(), any())).thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(name: 'hello-world', image: 'mcp/hello-world:latest');

      verify(() => dao.save(null, {
            'name': 'hello-world',
            'status': 'approved',
            'image': 'mcp/hello-world:latest',
          })).called(1);
    });

    test('omits image/config keys entirely when not provided', () async {
      when(() => dao.save(any(), any())).thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(name: 'hello-world');

      verify(() => dao.save(null, {
            'name': 'hello-world',
            'status': 'approved',
          })).called(1);
    });

    test('wraps failures in McpException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.createServer(name: 'hello-world'),
        throwsA(isA<McpException>()),
      );
    });
  });
}
```

Delete the first (deliberately buggy) draft above before committing — it exists in this plan only to show the mistake explicitly (a mock `thenAnswer` returning the wrong type) so the plan's executor doesn't repeat it while adapting from the `agent_config` test's shape, where every daoed method happens to return `void`/`Future<void>`, unlike `McpServerDao.save`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/mcp/mcp_repository_test.dart`
Expected: compile error — `createServer` undefined on `IMcpRepository`/`McpRepository`.

- [ ] **Step 3: Add `createServer` to the interface and repository**

In `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart`, replace the full file:

```dart
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

abstract class IMcpRepository {
  Stream<List<McpServer>> watchServers();
  Future<void> authorizeServer(String id, {Map<String, dynamic>? config});
  Future<void> denyServer(String id);
  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
  });
}
```

In `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart`, add a new method to the class (after `denyServer`):

```dart
  @override
  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
  }) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(null, {
          'name': name,
          'status': 'approved',
          if (image != null && image.isNotEmpty) 'image': image,
          if (config != null) 'config': config,
        });
      },
      McpException.new,
      'createServer',
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/mcp/mcp_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing cubit test**

Create `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`, mirroring `test/application/agent_config/agent_config_cubit_test.dart`'s mocktail pattern exactly:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';

class MockMcpRepository extends Mock implements IMcpRepository {}

void main() {
  late MockMcpRepository repo;
  McpCubit? lastCubit;

  McpCubit buildCubit() {
    final cubit = McpCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockMcpRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('McpCubit.createServer', () {
    test('calls repository.createServer with the given fields', () async {
      when(() => repo.createServer(
            name: any(named: 'name'),
            image: any(named: 'image'),
            config: any(named: 'config'),
          )).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.createServer(name: 'hello-world', image: 'mcp/hello-world:latest');

      verify(() => repo.createServer(
            name: 'hello-world',
            image: 'mcp/hello-world:latest',
            config: null,
          )).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.createServer(
            name: any(named: 'name'),
            image: any(named: 'image'),
            config: any(named: 'config'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createServer(name: 'hello-world');

      expect(cubit.state.hasError, isTrue);
    });
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/mcp/mcp_cubit_test.dart`
Expected: compile error — `createServer` undefined on `McpCubit`.

- [ ] **Step 7: Add `createServer` to `McpCubit`**

In `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart`, add a new method (after `deny`):

```dart
  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
  }) async {
    try {
      await _repository.createServer(name: name, image: image, config: config);
    } catch (e) {
      logError('MCP: Failed to create server', e);
      emit(McpState.error(e.toString()));
    }
  }
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/mcp/mcp_cubit_test.dart`
Expected: both PASS.

- [ ] **Step 9: Full package check**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze && flutter test`
Expected: no new analyzer issues beyond the pre-existing baseline, all tests pass.

- [ ] **Step 10: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart
git commit -m "feat(mcp): add createServer to McpRepository/McpCubit for manual add"
```

---

### Task 7: Flutter — wire "ADD NEW" to a real dialog

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `McpCubit.createServer` (Task 6).
- Produces: nothing further downstream — this is the UI leaf.

- [ ] **Step 1: Add l10n keys**

In `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, add (alongside the existing `mcp*` keys — check the file for where those are grouped and insert nearby):

```json
  "mcpAddDialogTitle": "ADD MCP SERVER",
  "mcpServerNameLabel": "SERVER NAME",
  "mcpImageOptionalLabel": "IMAGE (OPTIONAL)",
  "mcpAddConfigOptional": "Optional config (leave blank if none needed)",
  "actionAdd": "ADD",
```

(`actionAdd` may already exist — check `app_en.arb` for an existing generic "ADD" action key first and reuse it instead of adding a duplicate if so.)

Run the project's existing l10n generation step (check `client/packages/pocketcoder_flutter/README.md` or `melos.yaml` for the exact command — likely `flutter gen-l10n` or a `melos run` target) to regenerate `app_localizations*.dart`/`l10n_key_resolver.g.dart`.

- [ ] **Step 2: Replace the `ADD NEW` button's `onTap`**

In `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart`, find:

```dart
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                        label: 'ADD NEW',
                        onTap: () {}, // TODO: Implement add new MCP
                      ),
                    ),
```

Replace with:

```dart
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                        label: 'ADD NEW',
                        onTap: () => _showAddServerDialog(context),
                      ),
                    ),
```

- [ ] **Step 3: Add the `_showAddServerDialog` method**

Add this method to `_McpManagementView` (alongside the existing `_showAuthorizeDialog`), reusing the same `TerminalDialog`/`TerminalTextField` pattern:

```dart
  void _showAddServerDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<McpCubit>();
    final nameController = TextEditingController();
    final imageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.mcpAddDialogTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: nameController,
              label: context.l10n.mcpServerNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: imageController,
              label: context.l10n.mcpImageOptionalLabel,
              obscureText: false,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionCancel),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              cubit.createServer(
                name: name,
                image: imageController.text.trim().isEmpty
                    ? null
                    : imageController.text.trim(),
              );
              Navigator.of(dialogContext).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionAdd),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Manual verification**

Run: `cd client/packages/pocketcoder_flutter/../../apps/app && flutter run -d chrome` (or whichever run script `client/scripts/run_chrome_incognito.sh` wraps), navigate to the MCP management screen, tap `ADD NEW`, fill in a name, submit, and confirm a new card appears in the "active" section (status `approved`) without a page reload — the existing `watchServers()` stream should pick it up automatically the same way authorize/deny already do.

- [ ] **Step 5: Full package check**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze && flutter test`
Expected: no new analyzer issues, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart client/packages/pocketcoder_flutter/lib/l10n/app_en.arb client/packages/pocketcoder_flutter/lib/l10n/
git commit -m "feat(mcp): wire ADD NEW to a manual add-server dialog"
```

---

### Task 8: Integration test — full pipeline through a real gateway

**Files:**
- Create: `tests/agent-c1/mcp_gateway.bats`
- Modify: `docker-compose.agent-test.yml` (bring up `mcp-gateway`, not just `goose`+`pocketbase`)
- Modify: `tests/agent-c1/run.sh` (add the `c3` profile)

**Interfaces:**
- Consumes: everything from Tasks 1-5 (this is the end-to-end regression guard for the whole feature). Reuses `tests/agent-c1/acceptance.bats`'s existing `new_chat`/`open_stream`/`start_run`/`wait_for_text`/`wait_for_finish` helpers (confirmed present, read in full) and `tests/agent-c1/config_pipeline.bats`'s `goose_config_dir` helper (confirmed present, read in full).
- Produces: nothing further — this is the plan's final deliverable.

`docker-compose.agent-test.yml` currently starts only `goose`+`pocketbase` (its header comment says so explicitly: *"It intentionally does not depend on Interface, OpenCode, sandbox, or c3"*) — this task changes that, since the gateway pipeline can't be tested without `c3` running.

- [ ] **Step 1: Add `mcp-gateway` to the test compose file**

In `docker-compose.agent-test.yml`, update the header comment and `depends_on`, and add a container-name env var matching the pattern `GOOSE_CONTAINER`/`POCKETBASE_CONTAINER` already use:

```yaml
# Opt-in acceptance runner for the active c1 PocketBase + c2 Goose runtime,
# plus c3 (the Docker MCP Gateway) for MCP-governance coverage. It
# intentionally does not depend on Interface, OpenCode, or the sandbox.
services:
  agent-c1-test:
    build:
      context: .
      dockerfile: services/test/Dockerfile
    profiles: ["agent-test"]
    depends_on:
      goose:
        condition: service_healthy
      pocketbase:
        condition: service_healthy
      mcp-gateway:
        condition: service_healthy
    volumes:
      - ./tests:/tests:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      PB_URL: http://pocketbase:8090
      PB_AUTH_COLLECTION: ${PB_AUTH_COLLECTION:-users}
      AGENT_TEST_EMAIL: ${AGENT_TEST_EMAIL:?set an ordinary PocketBase test-user email}
      AGENT_TEST_PASSWORD: ${AGENT_TEST_PASSWORD:?set that test user's password}
      AGENT_TEST_TIMEOUT_SECONDS: ${AGENT_TEST_TIMEOUT_SECONDS:-120}
      GOOSE_CONTAINER: ${GOOSE_CONTAINER:-pocketcoder-goose}
      POCKETBASE_CONTAINER: ${POCKETBASE_CONTAINER:-pocketcoder-pocketbase}
      MCP_GATEWAY_CONTAINER: ${MCP_GATEWAY_CONTAINER:-pocketcoder-mcp-gateway}
    networks:
      # Reaches PocketBase's API only; the private pocketcoder-agent ACP net
      # stays a two-node c1<->c2 channel.
      - pocketcoder-pocketbase-sdk
```

- [ ] **Step 2: Bring up `c3` in `run.sh`**

In `tests/agent-c1/run.sh`, change:

```bash
docker compose --profile agent up -d --build goose pocketbase
docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile agent --profile agent-test run --rm agent-c1-test \
  --tap /tests/agent-c1/acceptance.bats
```

to:

```bash
docker compose --profile agent --profile c3 up -d --build goose pocketbase mcp-gateway
docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile agent --profile c3 --profile agent-test run --rm agent-c1-test \
  --tap /tests/agent-c1/acceptance.bats /tests/agent-c1/mcp_gateway.bats
```

- [ ] **Step 3: Write the bats scenario**

Create `tests/agent-c1/mcp_gateway.bats`:

```bash
#!/usr/bin/env bats

# Regression coverage for docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md.
# Proves the full pipeline spikes/goose-mcp-gateway-attach/README.md validated
# manually: gateway registration, catalog approval, and tool exposure through
# a real model-invoked call.

setup() {
  : "${PB_URL:?}"
  : "${PB_AUTH_COLLECTION:?}"
  : "${AGENT_TEST_EMAIL:?}"
  : "${AGENT_TEST_PASSWORD:?}"
  : "${GOOSE_CONTAINER:?}"
  : "${POCKETBASE_CONTAINER:?}"
  : "${MCP_GATEWAY_CONTAINER:?}"

  AUTH=$(curl -fsS -X POST "$PB_URL/api/collections/$PB_AUTH_COLLECTION/auth-with-password" \
    -H 'Content-Type: application/json' \
    -d "{\"identity\":\"$AGENT_TEST_EMAIL\",\"password\":\"$AGENT_TEST_PASSWORD\"}")
  USER_TOKEN=$(jq -r .token <<<"$AUTH")
  USER_ID=$(jq -r .record.id <<<"$AUTH")
  [ -n "$USER_TOKEN" ] && [ "$USER_TOKEN" != null ]
  CHAT_IDS=()
  MCP_SERVER_IDS=()
}

teardown() {
  if [ -n "${STREAM_PID:-}" ]; then
    kill "$STREAM_PID" 2>/dev/null || true
    wait "$STREAM_PID" 2>/dev/null || true
  fi
  for chat_id in "${CHAT_IDS[@]}"; do
    curl -sS -X DELETE "$PB_URL/api/collections/chats/records/$chat_id" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  done
  for server_id in "${MCP_SERVER_IDS[@]}"; do
    curl -sS -X DELETE "$PB_URL/api/collections/mcp_servers/records/$server_id" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  done
}

# goose_config_dir mirrors config_pipeline.bats's helper — the directory
# Goose actually reads config.yaml from, taken from `goose info`.
goose_config_dir() {
  docker exec "$GOOSE_CONTAINER" goose info 2>/dev/null |
    awk '/Config yaml:/{print $3}' | xargs dirname
}

gateway_extension_count() {
  local cfg_dir
  cfg_dir=$(goose_config_dir)
  docker exec "$GOOSE_CONTAINER" sh -c "grep -c '^  gateway:' '$cfg_dir/config.yaml' 2>/dev/null || echo 0"
}

wait_for_gateway_extension() {
  for _ in $(seq 1 60); do
    [ "$(gateway_extension_count)" -ge 1 ] && return 0
    sleep 2
  done
  return 1
}

new_chat() {
  local title="mcp-gateway-${BATS_TEST_NUMBER}-$(date +%s%N)"
  local record
  record=$(curl -fsS -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"title\":\"$title\",\"user\":\"$USER_ID\"}")
  CHAT_ID=$(jq -r .id <<<"$record")
  CHAT_IDS+=("$CHAT_ID")
}

open_stream() {
  local cursor="${1:-0}"
  if [ -n "${STREAM_PID:-}" ]; then
    kill "$STREAM_PID" 2>/dev/null || true
    wait "$STREAM_PID" 2>/dev/null || true
  fi
  STREAM_FILE="$BATS_TEST_TMPDIR/stream-${RANDOM}.sse"
  curl --retry 5 --retry-connrefused --retry-delay 1 \
    --max-time "${AGENT_TEST_TIMEOUT_SECONDS:-120}" -sS -N \
    "$PB_URL/api/pocketcoder/chats/$CHAT_ID/stream?cursor=$cursor" \
    -H "Authorization: $USER_TOKEN" >"$STREAM_FILE" 2>&1 &
  STREAM_PID=$!
  sleep 1
}

start_run() {
  local prompt="$1"
  local resp
  resp=$(curl --max-time 15 -sS \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/session/prompt" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"prompt\":[{\"type\":\"text\",\"text\":$(jq -Rs . <<<"$prompt")}]}")
  RUN_ID=$(jq -r .runId <<<"$resp")
  [ -n "$RUN_ID" ] && [ "$RUN_ID" != null ]
}

wait_for_text() {
  local expected="$1"
  local attempts="${2:-40}"
  local text
  for _ in $(seq 1 "$attempts"); do
    text=$(grep '^data: ' "$STREAM_FILE" 2>/dev/null | sed 's/^data: //' |
      jq -r 'select(.type == "TEXT_MESSAGE_CONTENT") | .delta' 2>/dev/null | tr -d '\n')
    printf '%s' "$text" | grep -Fq "$expected" && return 0
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
  return 1
}

wait_for_finish() {
  for _ in $(seq 1 40); do
    grep -q '"type":"RUN_FINISHED"' "$STREAM_FILE" 2>/dev/null && return 0
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
  return 1
}

@test "mcp gateway extension registers exactly once and survives a pocketbase restart" {
  wait_for_gateway_extension
  [ "$(gateway_extension_count)" -eq 1 ]

  docker restart "$POCKETBASE_CONTAINER"
  # Give PocketBase's OnServe (and RegisterMcpGatewayExtension's first
  # attempt) time to run again after the restart.
  for _ in $(seq 1 30); do
    curl --max-time 5 -fsS "$PB_URL/api/health" >/dev/null 2>&1 && break
    sleep 2
  done

  wait_for_gateway_extension
  [ "$(gateway_extension_count)" -eq 1 ]
}

@test "approving an mcp_servers row reaches the gateway's catalog" {
  local name="agent-c1-test-server-$(date +%s%N)"
  local record
  record=$(curl -fsS -X POST "$PB_URL/api/collections/mcp_servers/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"status\":\"approved\",\"image\":\"mcp/hello-world:latest\"}")
  local server_id
  server_id=$(jq -r .id <<<"$record")
  [ -n "$server_id" ] && [ "$server_id" != null ]
  MCP_SERVER_IDS+=("$server_id")

  local found=0
  for _ in $(seq 1 30); do
    if docker exec "$MCP_GATEWAY_CONTAINER" cat /root/.docker/mcp/docker-mcp.yaml 2>/dev/null | grep -q "$name"; then
      found=1
      break
    fi
    sleep 2
  done
  [ "$found" -eq 1 ]
}

@test "gateway tools are reachable through a real model-invoked call" {
  wait_for_gateway_extension

  new_chat
  open_stream
  start_run "Call the gateway__mcp-find tool with query 'hello' and limit 5, then reply with exactly the raw tool result text and nothing else."
  wait_for_finish
  wait_for_text 'total_matches'
}
```

- [ ] **Step 4: Run the suite**

Run: `tests/agent-c1/run.sh`
Expected: all tests pass, including the three new ones in `mcp_gateway.bats`.

- [ ] **Step 5: Commit**

```bash
git add tests/agent-c1/mcp_gateway.bats docker-compose.agent-test.yml tests/agent-c1/run.sh
git commit -m "test(mcp): integration coverage for gateway registration + approval pipeline"
```

---

## Final verification

- [ ] `cd services/pocketbase && go build ./... && go vet ./... && go test ./...` — all green.
- [ ] `cd client/packages/pocketcoder_flutter && flutter analyze && flutter test` — no new issues, all green.
- [ ] `docker compose config --quiet` — compose file still valid.
- [ ] `tests/agent-c1/run.sh` — full acceptance suite (existing + new) passes.
- [ ] Manual: bring up `agent` + `c3` profiles, approve a real MCP server from the Flutter UI, confirm it's reachable via a real chat turn asking Goose to use it (not just `tools/list` — an actual model-invoked call, the same proof bar the spike used).
