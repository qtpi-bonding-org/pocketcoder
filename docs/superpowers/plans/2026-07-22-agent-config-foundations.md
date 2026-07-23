# Agent Config Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status: implemented.** All deliverables described here landed on `goose-agui-refactor-plan` in commits `07df43005`..`91ccdabc2` (ProviderCubit/ProviderScreen, AgentConfigScreen, dead AI/LLM screen+schema removal). This file was committed after the fact for the historical record; per-step checkboxes below were not individually re-verified against the final diff.

**Goal:** Replace PocketCoder's dead agent/provider config surface (two Flutter screens writing to PocketBase collections nothing in Go reads) with a real one: live, no-restart delivery of provider/model/system-prompt to Goose over ACP, and working Flutter screens against the schema Goose's config render pipeline actually consumes.

**Architecture:** This is the first of several plans implementing the ownership map in `spikes/goose-acp-config-surface/{README.md,ownership-map.md}`. Scope here is exactly Bucket A (provider, model, system prompt, mode — items with no durable Goose-side state, so PocketBase must own them) plus deleting the two legacy Flutter screens/schemas that currently mislead users into thinking they've configured something. Tool permissions, MCP governance, skills, and the scheduler are explicitly out of scope — separate plans, since they depend on the admin-connection infrastructure this plan happens to also build, but have their own schema/UI work this plan does not need.

**Tech Stack:** Go (PocketBase hooks, ACP coordinator, `github.com/coder/acp-go-sdk`), Dart/Flutter (Cubit/freezed/injectable, `pocketbase_drift`).

## Global Constraints

- Goose version pinned: `v1.43.0` (`services/goose/Dockerfile`) — all ACP method names/behavior in this plan are verified against that exact tag, cloned at `.independent_repos/goose_reference` (gitignored, not committed).
- No typed Go SDK support exists for any `_goose/unstable/*` custom method (verified: zero `-i goose` hits in `acp-go-sdk@v0.13.5`). All custom-method calls in this plan go through the SDK's `CallExtension(ctx, method string, params any) (json.RawMessage, error)` escape hatch, which requires the method string to start with `_` (Goose's `_goose/unstable/...` methods qualify).
- `client/CLAUDE.md` rules apply to all Flutter work: never use `!`; cubits extend `AppCubit<T>`; state is `@freezed` + `IUiFlowState` with `status`/`error`, `status: UiFlowStatus.success` must be set explicitly; repos wrap every public method in `tryMethod` with a typed exception; DI via `@injectable`(cubits)/`@lazySingleton`(repos+DAOs); l10n dot-notation keys, never hardcode user-facing strings. Follow `mcp_management_screen.dart`'s pattern (freezed union state, `Cubit` — see note below) over `agent_management_screen.dart`/`llm_management_screen.dart`'s, which are the ones being deleted.
- Root `CLAUDE.md`'s Model Generation Pipeline applies to Task 13 (schema migration): rebuild containers → export schema → regenerate Dart models → `build_runner build`.
- **Do not touch `goose_config.go`'s restart-trigger hook registration in this plan.** The existing file+restart pipeline keeps rendering `poco_configs`/`tool_permissions` as the container's *boot default* unchanged — this plan adds a live per-session override on top, it does not replace or shrink the restart path. Shrinking that pipeline (removing the `extensions` key to avoid the `config/extensions/add` clobber) is Bucket B/MCP-phase work, a separate plan, because that co-ownership conflict only exists for extensions, not for provider/model/prompt.
- **Do not touch `sandbox_agents`, `sandbox_configs`, `skills`, or `harness_auth`** — separate concerns (dormant sandbox cleanup and skills/Bucket-B passthrough respectively), not part of this plan's Bucket A scope.

---

## File Structure

**Go — new:**
- `services/pocketbase/internal/agent/coordinator/admin.go` — `AdminConn`, the no-op admin ACP client.
- `services/pocketbase/internal/agent/coordinator/profile.go` — extend in place: real `PerSessionApplier`.

**Go — modified:**
- `services/pocketbase/internal/agent/acp/websocket.go` — add `CallExtension` to the `Conn` interface.
- `services/pocketbase/internal/agent/coordinator/profile.go` — `selectApplier` always returns `PerSessionApplier` (capability confirmed present in the pinned version, no negotiation needed).
- `services/pocketbase/pb_migrations/` — one new migration dropping the 6 dead collections.

**Flutter — new (mirrors the `mcp` package shape, the cleanest existing example):**
- `lib/domain/agent_config/i_agent_config_repository.dart`
- `lib/infrastructure/agent_config/agent_config_daos.dart` (`PocoConfigDao`, `PromptDao`)
- `lib/infrastructure/agent_config/agent_config_repository.dart`
- `lib/application/agent_config/agent_config_cubit.dart`, `agent_config_state.dart`
- `lib/presentation/agent_config/agent_config_screen.dart`
- `lib/domain/provider/i_provider_repository.dart`
- `lib/infrastructure/provider/provider_daos.dart` (`HarnesseDao`, `ModelDao`, `HarnessModelDao`, `ProviderKeyDao`)
- `lib/infrastructure/provider/provider_repository.dart`
- `lib/application/provider/provider_cubit.dart`, `provider_state.dart`
- `lib/presentation/provider/provider_screen.dart`

**Flutter — deleted:**
- `lib/presentation/settings/agent_management_screen.dart`
- `lib/presentation/llm/llm_management_screen.dart`
- `lib/application/ai/ai_config_cubit.dart`, `ai_config_state.dart` (+ generated `.freezed.dart`/`.g.dart`)
- `lib/domain/ai_config/i_ai_config_repository.dart`
- `lib/infrastructure/ai_config/ai_config_daos.dart`, `ai_config_repository.dart`
- `lib/application/llm/llm_cubit.dart`, `llm_state.dart` (+ generated)
- `lib/domain/llm/i_llm_repository.dart`
- `lib/infrastructure/llm/llm_daos.dart`, `llm_repository.dart`

---

### Task 1: Add `CallExtension` to the coordinator's `acp.Conn` interface

**Files:**
- Modify: `services/pocketbase/internal/agent/acp/websocket.go`
- Test: `services/pocketbase/internal/agent/acp/websocket_test.go` (or wherever the existing `Conn` fake/test lives — grep `type.*fake.*Conn\|type.*stub.*Conn` under `internal/agent/` first; if none exists yet, add one alongside this change)

**Interfaces:**
- Consumes: nothing new — `acpsdk.ClientSideConnection.CallExtension(ctx, method string, params any) (json.RawMessage, error)`, already present in the vendored SDK.
- Produces: `acp.Conn` gains `CallExtension(ctx context.Context, method string, params any) (json.RawMessage, error)`, usable by every later task in this plan and by all future Bucket-B work.

- [ ] **Step 1: Write the failing test**

`services/pocketbase/internal/agent/acp/conn_test.go` already has a compile-time-assertion pattern for exactly this kind of change (interface growth on `Conn`), used previously for `SetSessionConfigOption`/`UnstableDeleteSession`. Copy it rather than building an httptest/JSON-RPC handshake (`websocket_test.go` only has two unrelated tests, `TestWSURLWithTokenAppendsQueryParam` and `TestWSStreamFramesNewlineDelimitedMessages` — nothing to copy there). Add to `conn_test.go`:

```go
// Fails to build until Conn declares CallExtension.
var _ = func(c Conn) {
	var _ func(context.Context, string, any) (json.RawMessage, error) = c.CallExtension
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go build ./internal/agent/acp/...`
Expected: compile error — `c.CallExtension undefined (type Conn has no field or method CallExtension)`.

- [ ] **Step 3: Add `CallExtension` to the interface and both implementations**

In `services/pocketbase/internal/agent/acp/websocket.go`, find the `Conn` interface (confirmed at L54-64) and add one line:

```go
type Conn interface {
	// ... existing methods unchanged ...
	CallExtension(ctx context.Context, method string, params any) (json.RawMessage, error)
}
```

Add `"encoding/json"` to `websocket.go`'s import block — it is not present today (current imports are `bytes`, `context`, `fmt`, `net/url`, `strings`, `sync`, plus two external packages) and is required for `json.RawMessage` in the new signature.

`sdkConn` (L111-114) already embeds `*acpsdk.ClientSideConnection`, which already has `CallExtension` — no method body needed there, it satisfies the interface automatically once declared. `coordinator`'s test fake, `run_test.go`'s `fakeConn`, needs a matching method added too — see Task 2 Step 3, which adds it alongside `AdminConn`'s other test needs.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go build ./...`
Expected: builds clean.

- [ ] **Step 5: Full package verification**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: all green — this is an additive interface change, must not break any existing test.

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/agent/acp/websocket.go services/pocketbase/internal/agent/coordinator/run_test.go
git commit -m "feat(agent): expose CallExtension on the coordinator's ACP Conn interface"
```

---

### Task 2: `Coordinator.AdminConn` — a session-free connection to Goose

**Files:**
- Create: `services/pocketbase/internal/agent/coordinator/admin.go`
- Test: `services/pocketbase/internal/agent/coordinator/admin_test.go`

**Interfaces:**
- Consumes: `c.config.Dial(ctx, client acpsdk.Client) (acp.Conn, error)` (existing `Config.Dial`, `run.go:41,52`), `initializeRequest()` (existing, `run.go:554-561`).
- Produces: `func (c *Coordinator) AdminConn(ctx context.Context) (acp.Conn, error)` — dials Goose, completes the `initialize` handshake, returns a ready `acp.Conn` with **no session created**. Caller is responsible for calling `conn.Close()` (or whatever the existing `acp.Conn` close method is named — check `Conn` interface from Task 1's file) when done with it, mirroring how `runLoop`/`StreamColdReplay` already `defer` closing their dialed connections. Later plans (tool permissions, MCP, skills, scheduler) call this to reach Goose from Settings-style Flutter actions that aren't tied to an open chat.

- [ ] **Step 1: Write the failing test**

`run_test.go`'s real `fakeConn` (L49-73, methods L123-219) is a flat struct with hardcoded-behavior methods and plain capture fields (`lastMode`, `lastModeSession`, `lastNewSessionReq`, etc.) — it does NOT have callback-style `on*` hooks. First extend it with the capture fields this task (and Task 3) need, in the same style as its existing fields:

```go
// Add to fakeConn's struct fields (run_test.go, alongside lastMode/lastModeSession):
initializeCalls      int
newSessionCalls      int
lastSetConfigOption  acpsdk.SetSessionConfigOptionRequest
setConfigOptionCalls []acpsdk.SetSessionConfigOptionRequest
lastExtensionMethod  string
lastExtensionParams  any
callExtensionCalls   int
```

Instrument the existing `Initialize`/`NewSession` methods to increment `initializeCalls`/`newSessionCalls` (they already have bodies — just add the increment, don't change existing behavior). Add a new `CallExtension` method (also needed by Task 1's interface addition and Task 3):

```go
func (f *fakeConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	f.mu.Lock()
	f.lastExtensionMethod = method
	f.lastExtensionParams = params
	f.callExtensionCalls++
	f.mu.Unlock()
	return json.RawMessage(`{}`), nil
}
```

Now the test:

```go
func TestAdminConnDialsAndInitializesWithoutCreatingASession(t *testing.T) {
	fc := &fakeConn{}
	coord, err := New(Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	conn, err := coord.AdminConn(context.Background())
	if err != nil {
		t.Fatalf("AdminConn: %v", err)
	}
	defer conn.Close()

	if fc.initializeCalls != 1 {
		t.Errorf("expected AdminConn to complete the initialize handshake once, got %d calls", fc.initializeCalls)
	}
	if fc.newSessionCalls != 0 {
		t.Error("AdminConn must not create a session — it's for session-free custom methods only")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/... -run TestAdminConn -v`
Expected: FAIL — `coord.AdminConn` undefined (once `fakeConn`'s new fields/methods are added first, so the only remaining failure is the missing `AdminConn` method itself).

- [ ] **Step 3: Implement `AdminConn`**

```go
package coordinator

import (
	"context"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

// adminClient satisfies acpsdk.Client for connections that never create a
// session. Every server-to-client callback here is unreachable in practice
// (Goose only calls these mid-prompt/mid-tool-call, and AdminConn never
// starts a prompt), so each returns "unsupported" rather than panicking,
// matching the existing sessionClient's own unsupported() helper for the
// file/terminal methods it doesn't implement (run.go:383-402).
type adminClient struct{}

func (adminClient) SessionUpdate(context.Context, acpsdk.SessionNotification) error { return nil }
func (adminClient) ReadTextFile(context.Context, acpsdk.ReadTextFileRequest) (acpsdk.ReadTextFileResponse, error) {
	return acpsdk.ReadTextFileResponse{}, unsupported()
}
func (adminClient) WriteTextFile(context.Context, acpsdk.WriteTextFileRequest) (acpsdk.WriteTextFileResponse, error) {
	return acpsdk.WriteTextFileResponse{}, unsupported()
}
func (adminClient) CreateTerminal(context.Context, acpsdk.CreateTerminalRequest) (acpsdk.CreateTerminalResponse, error) {
	return acpsdk.CreateTerminalResponse{}, unsupported()
}
func (adminClient) KillTerminal(context.Context, acpsdk.KillTerminalRequest) (acpsdk.KillTerminalResponse, error) {
	return acpsdk.KillTerminalResponse{}, unsupported()
}
func (adminClient) TerminalOutput(context.Context, acpsdk.TerminalOutputRequest) (acpsdk.TerminalOutputResponse, error) {
	return acpsdk.TerminalOutputResponse{}, unsupported()
}
func (adminClient) ReleaseTerminal(context.Context, acpsdk.ReleaseTerminalRequest) (acpsdk.ReleaseTerminalResponse, error) {
	return acpsdk.ReleaseTerminalResponse{}, unsupported()
}
func (adminClient) WaitForTerminalExit(context.Context, acpsdk.WaitForTerminalExitRequest) (acpsdk.WaitForTerminalExitResponse, error) {
	return acpsdk.WaitForTerminalExitResponse{}, unsupported()
}
func (adminClient) RequestPermission(context.Context, acpsdk.RequestPermissionRequest) (acpsdk.RequestPermissionResponse, error) {
	return acpsdk.RequestPermissionResponse{}, unsupported()
}
func (adminClient) UnstableCreateElicitation(context.Context, acpsdk.UnstableCreateElicitationRequest) (acpsdk.UnstableCreateElicitationResponse, error) {
	return acpsdk.UnstableCreateElicitationResponse{}, unsupported()
}

// AdminConn dials Goose and completes the initialize handshake for
// session-free custom methods (tool permissions, MCP extensions, skills,
// schedules — see spikes/goose-acp-config-surface/ownership-map.md). It
// does not call session/new. Callers must Close the returned Conn.
// Lifetime is meant to match one PocketBase-side request: dial, make
// whichever calls that request needs, close — not a standing connection.
func (c *Coordinator) AdminConn(ctx context.Context) (acp.Conn, error) {
	conn, err := c.config.Dial(ctx, adminClient{})
	if err != nil {
		return nil, err
	}
	if _, err := conn.Initialize(ctx, initializeRequest()); err != nil {
		_ = conn.Close()
		return nil, err
	}
	return conn, nil
}
```

Check the exact name of `unsupported()` and `conn.Close()`/`conn.Initialize()` method signatures against `run.go`/`websocket.go` before writing — `unsupported()` is already used at `run.go:384,387,390,393,396,399,402` for `sessionClient`'s unimplemented methods, reuse it verbatim rather than redefining. If `acp.Conn` doesn't already expose `Initialize`/`Close` under those exact names, use whatever names `run.go`'s existing dial call sites (`run.go:534,713`) actually use immediately after dialing.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/... -run TestAdminConn -v`
Expected: PASS.

- [ ] **Step 5: Full package verification**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/admin.go services/pocketbase/internal/agent/coordinator/admin_test.go
git commit -m "feat(agent): add Coordinator.AdminConn for session-free Goose calls"
```

---

### Task 3: Real `PerSessionApplier` — live provider/model/system-prompt delivery

**Files:**
- Modify: `services/pocketbase/internal/agent/coordinator/profile.go`
- Test: `services/pocketbase/internal/agent/coordinator/profile_test.go`

**Interfaces:**
- Consumes: `SessionProfile{Model, Provider, Instructions, Cwd string; ...; Mode acpsdk.SessionModeId}` (existing, unchanged shape), `conn.CallExtension` (Task 1), `acpsdk.SetSessionConfigOptionRequest`/`ValueId` (existing SDK type, confirmed shape in Global Constraints).
- Produces: `PerSessionApplier.Apply` now actually delivers `Provider`, `Model`, and `Instructions` in addition to `Mode` (which `GlobalConfigApplier` already handles and `PerSessionApplier` already delegates to). `selectApplier` always returns `PerSessionApplier` — no capability gate, since v1.43.0 (the pinned version) is confirmed to support all three live.

- [ ] **Step 1: Write the failing tests**

Uses `fakeConn`'s real capture-field style (added in Task 2 Step 1 — `lastSetConfigOption`, `setConfigOptionCalls`, `lastExtensionMethod`, `lastExtensionParams`, `callExtensionCalls`), not callback hooks:

```go
func TestPerSessionApplierDeliversProviderLive(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Provider: "anthropic"})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if fc.lastSetConfigOption.ValueId == nil || fc.lastSetConfigOption.ValueId.ConfigId != "provider" || fc.lastSetConfigOption.ValueId.Value != "anthropic" {
		t.Errorf("expected configId=provider value=anthropic, got %+v", fc.lastSetConfigOption)
	}
}

func TestPerSessionApplierDeliversModelLive(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Model: "claude-opus"})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	found := false
	for _, c := range fc.setConfigOptionCalls {
		if c.ValueId != nil && c.ValueId.ConfigId == "model" && c.ValueId.Value == "claude-opus" {
			found = true
		}
	}
	if !found {
		t.Errorf("expected a configId=model value=claude-opus call, got %+v", fc.setConfigOptionCalls)
	}
}

func TestPerSessionApplierDeliversInstructionsViaCustomMethod(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Instructions: "You are a terse assistant."})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if fc.lastExtensionMethod != "_goose/unstable/session/system-prompt/set" {
		t.Errorf("expected the system-prompt custom method, got %q", fc.lastExtensionMethod)
	}
	params, ok := fc.lastExtensionParams.(systemPromptSetParams)
	if !ok {
		t.Fatalf("expected systemPromptSetParams, got %T", fc.lastExtensionParams)
	}
	if params.SessionID != "sess-1" || params.SystemPrompt != "You are a terse assistant." {
		t.Errorf("unexpected params: %+v", params)
	}
}

func TestPerSessionApplierSkipsEmptyFields(t *testing.T) {
	fc := &fakeConn{}
	// Empty SessionProfile — GlobalConfigApplier already returns nil for
	// empty Mode (profile.go:76); PerSessionApplier must not call Goose
	// at all for Provider/Model/Instructions when they're empty either.
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if len(fc.setConfigOptionCalls) != 0 || fc.callExtensionCalls != 0 {
		t.Errorf("expected zero Goose calls for an empty profile, got %d config calls, %d extension calls", len(fc.setConfigOptionCalls), fc.callExtensionCalls)
	}
}

func TestSelectApplierAlwaysReturnsPerSessionApplier(t *testing.T) {
	applier := selectApplier(&acpsdk.InitializeResponse{})
	if _, ok := applier.(PerSessionApplier); !ok {
		t.Errorf("expected PerSessionApplier, got %T", applier)
	}
}
```

**Also delete the pre-existing `TestSelectApplier_DefaultsToGlobalToday` test** (`profile_test.go:22-26`) — it asserts `selectApplier` returns `GlobalConfigApplier`, exactly the behavior this task removes. Leaving it in place makes `go test ./...` fail once `selectApplier` always returns `PerSessionApplier`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/... -run TestPerSessionApplier -v`
Expected: FAIL — `PerSessionApplier.Apply` only delegates to `GlobalConfigApplier{}.Apply` today (profile.go:88-90), so Provider/Model/Instructions are silently dropped; `TestPerSessionApplierDeliversProviderLive` etc. fail with no config-option/extension call observed. `TestSelectApplierAlwaysReturnsPerSessionApplier` fails because `selectApplier` currently always returns `GlobalConfigApplier{}` (profile.go:97).

- [ ] **Step 3: Implement**

Replace `profile.go`'s `PerSessionApplier`/`selectApplier` (the existing `L83-98` block) with:

```go
// systemPromptSetParams mirrors Goose's SetSessionSystemPromptRequest
// (goose-sdk-types/src/custom_requests.rs) — no typed Go SDK support
// exists for this custom method, so the shape is hand-rolled and must be
// kept in sync with that Rust struct if Goose's wire format changes.
type systemPromptSetParams struct {
	SessionID    string `json:"sessionId"`
	SystemPrompt string `json:"systemPrompt"`
}

// PerSessionApplier delivers model/provider/instructions live, in addition
// to mode. Confirmed against Goose v1.43.0 source
// (spikes/goose-acp-config-surface/README.md items 1-3): provider and
// model are standard ACP session/set_config_option calls with configId
// "provider"/"model"; instructions go through Goose's custom
// _goose/unstable/session/system-prompt/set method via CallExtension,
// since no typed SDK support exists for it.
type PerSessionApplier struct{}

func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	if err := (GlobalConfigApplier{}).Apply(ctx, conn, sessionID, p); err != nil {
		return err
	}
	if p.Provider != "" {
		if _, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
			ValueId: &acpsdk.SetSessionConfigOptionValueId{
				SessionId: acpsdk.SessionId(sessionID),
				ConfigId:  "provider",
				Value:     acpsdk.SessionConfigValueId(p.Provider),
			},
		}); err != nil {
			return fmt.Errorf("apply provider: %w", err)
		}
	}
	if p.Model != "" {
		if _, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
			ValueId: &acpsdk.SetSessionConfigOptionValueId{
				SessionId: acpsdk.SessionId(sessionID),
				ConfigId:  "model",
				Value:     acpsdk.SessionConfigValueId(p.Model),
			},
		}); err != nil {
			return fmt.Errorf("apply model: %w", err)
		}
	}
	if p.Instructions != "" {
		if _, err := conn.CallExtension(ctx, "_goose/unstable/session/system-prompt/set", systemPromptSetParams{
			SessionID:    sessionID,
			SystemPrompt: p.Instructions,
		}); err != nil {
			return fmt.Errorf("apply instructions: %w", err)
		}
	}
	return nil
}

// selectApplier always returns PerSessionApplier. Provider/model/prompt
// live delivery is confirmed present in the pinned Goose version
// (v1.43.0) — see spikes/goose-acp-config-surface/README.md — so, unlike
// the prior comment on this function ("Goose #7596 unshipped"), there is
// no capability gate to check.
func selectApplier(init *acpsdk.InitializeResponse) ProfileApplier {
	return PerSessionApplier{}
}
```

Add `"fmt"` to `profile.go`'s imports if not already present (the original file has no error wrapping, so it almost certainly isn't) — `"encoding/json"` is NOT needed here, since `CallExtension` is called with a typed `systemPromptSetParams` struct, not a manually marshaled value; adding it would be an unused import.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/... -run TestPerSessionApplier -v && go test ./internal/agent/coordinator/... -run TestSelectApplier -v`
Expected: PASS, all five tests.

- [ ] **Step 5: Full backend verification**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: all green — this requires having already deleted `TestSelectApplier_DefaultsToGlobalToday` per Step 1's note, or this step fails on that leftover assertion. Also run `go test ./internal/agent/coordinator/... -run TestGlobalConfigApplier -v` to confirm the existing mode-only test still passes unchanged (this task must not regress it).

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/profile.go services/pocketbase/internal/agent/coordinator/profile_test.go
git commit -m "feat(agent): deliver provider/model/instructions live over ACP, not just mode"
```

---

### Task 4: PocketBase migration — drop the six dead legacy collections

**Files:**
- Create: `services/pocketbase/pb_migrations/1753000000_prune_legacy_ai_config.go`
- Test: manual verification (PocketBase migrations don't have a unit-test harness in this repo per the existing migration files — verify via the model-generation pipeline in Step 3 instead)

**Interfaces:**
- Consumes: nothing.
- Produces: `ai_agents`, `ai_prompts`, `ai_models`, `llm_keys`, `llm_providers`, `model_selection` no longer exist in the schema. `tool_permissions.agent` (a relation to the now-deleted `ai_agents`) must be dropped from `tool_permissions` in the same migration, or the collection becomes invalid (a relation field can't point at a nonexistent collection).

- [ ] **Step 1: Write the migration**

Follow `1752000000_prune_legacy_runtime.go`'s exact shape (forward-only prune, no meaningful down-migration) — read that file first for the precise PocketBase Go migration API calls used (`app.FindCollectionByNameOrId`, `app.Delete`, field removal pattern), then write:

Every existing file in `pb_migrations/` declares `package pb_migrations` (confirmed in `1752000000_prune_legacy_runtime.go:19` and `1752000100_poco_config_mode.go:19`) with an unaliased `migrations` import — match that exactly, not a different package name, or the directory fails to build (a Go directory can only contain one package):

```go
package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Drops the pre-Goose-migration AI/LLM config schema
// (ai_agents/ai_prompts/ai_models/llm_keys/llm_providers/model_selection).
// Nothing in Go has read these since the ACP/AG-UI rewrite — they were
// only still reachable through two Flutter screens
// (agent_management_screen.dart, llm_management_screen.dart) that wrote to
// them with zero effect on Goose. See
// spikes/goose-acp-config-surface/{README.md,ownership-map.md} for the
// full audit. tool_permissions.agent (a relation into ai_agents) is
// dropped first since a collection can't keep a relation field pointing
// at a collection that no longer exists.
func init() {
	migrations.Register(func(app core.App) error {
		toolPerms, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil {
			return err
		}
		toolPerms.Fields.RemoveByName("agent")
		if err := app.Save(toolPerms); err != nil {
			return err
		}

		for _, name := range []string{
			"ai_agents", "ai_prompts", "ai_models",
			"llm_keys", "llm_providers", "model_selection",
		} {
			col, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				return err
			}
			if err := app.Delete(col); err != nil {
				return err
			}
		}
		return nil
	}, func(app core.App) error {
		// Forward-only prune, matching 1752000000_prune_legacy_runtime.go's
		// precedent — recreating six collections' full historical field
		// sets is not worth maintaining for a rollback path nothing has
		// needed so far.
		return nil
	})
}
```

Verify the exact method names (`FindCollectionByNameOrId`, `Fields.RemoveByName`, `app.Save`, `app.Delete`) against `1752000000_prune_legacy_runtime.go`'s real usage before finalizing — copy its precise API calls rather than guessing at the PocketBase Go SDK surface.

- [ ] **Step 2: Run the model-generation pipeline (root CLAUDE.md)**

```bash
docker compose build pocketbase
docker compose up -d pocketbase
scripts/export_schema.sh
cd client/packages/pocketcoder_flutter
python3 scripts/generate_models.py
```

Expected: `pb_schema.json` no longer contains `ai_agents`/`ai_prompts`/`ai_models`/`llm_keys`/`llm_providers`/`model_selection`; `generate_models.py` removes the corresponding entries from `lib/domain/models/collections.dart`'s `Collections` class and deletes (or the script flags for manual deletion — check its actual behavior on a removed collection) the now-orphaned `AiAgent`/`AiPrompt`/`AiModel`/`LlmKey`/`LlmProvider`/`ModelSelection` model files under `lib/domain/models/`.

**Note:** this regen also picks up the `mode` field on `poco_configs`, from the pre-existing `1752000100_poco_config_mode.go` migration (already merged, predates this plan) — the currently checked-in `pb_schema.json`/`poco_config.dart` predate that migration and don't have it yet. This is what makes `PocoConfig.mode` available for Task 11's mode picker; if this step is skipped, Task 11 has no field to bind the mode picker to.

- [ ] **Step 3: Confirm Go builds clean against the pruned schema**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: all green — nothing in Go referenced these collections (confirmed by the research pass), so this should be a no-op for the backend.

- [ ] **Step 4: Commit**

```bash
git add services/pocketbase/pb_migrations/1753000000_prune_legacy_ai_config.go client/packages/pocketcoder_flutter/assets/pb_schema.json client/packages/pocketcoder_flutter/lib/domain/models/
git commit -m "chore(schema): drop dead ai_agents/ai_prompts/ai_models/llm_keys/llm_providers/model_selection"
```

Note: this task deliberately runs before the Flutter deletion task (Task 10) so that by the time the dead Flutter code is deleted, the generated models it depended on are already gone — deleting Dart source that references types the generator just removed will show up as real compile errors in Task 10, not silently.

---

### Task 5: Flutter — `PocoConfigDao` and `PromptDao`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/agent_config/agent_config_daos.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/agent_config/agent_config_daos_test.dart`

**Interfaces:**
- Consumes: `PocoConfig`/`Prompt` (existing generated models, confirmed present at `lib/domain/models/poco_config.dart`/`prompt.dart`), `BaseDao<T>` (existing base class — same one `McpServerDao` uses), `Collections.pocoConfigs`/`Collections.prompts` (existing constants, confirmed present in `collections.dart`).
- Produces: `PocoConfigDao`, `PromptDao`, both `@lazySingleton`, both `extends BaseDao<T>`.

- [ ] **Step 1: Write the failing test**

Model this directly on however the existing DAO tests are structured — find `test/infrastructure/mcp/` or `test/infrastructure/ai_config/` (if one exists) for the pattern first. If DAOs in this codebase are tested via a fake/in-memory PocketBase client:

```dart
void main() {
  group('PocoConfigDao', () {
    test('watches Collections.pocoConfigs', () {
      final pb = FakePocketBase(); // reuse whatever fake the existing McpServerDao test uses
      final dao = PocoConfigDao(pb);
      expect(dao.collectionName, Collections.pocoConfigs);
    });
  });

  group('PromptDao', () {
    test('watches Collections.prompts', () {
      final pb = FakePocketBase();
      final dao = PromptDao(pb);
      expect(dao.collectionName, Collections.prompts);
    });
  });
}
```

Adjust to whatever `BaseDao`'s actual testable surface is (it may not expose `collectionName` directly — check `base_dao.dart` and copy the exact pattern the closest existing DAO test uses, e.g. for `McpServerDao`).

- [ ] **Step 2: Run to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/agent_config/agent_config_daos_test.dart`
Expected: FAIL — `PocoConfigDao`/`PromptDao` undefined.

- [ ] **Step 3: Implement**

`BaseDao`'s constructor (`lib/infrastructure/core/base_dao.dart:14-18`) takes `(this._pb, this._collection, this._fromJson)` — `_pb` is a private field name, so the `super.pb` shorthand doesn't bind to it. Follow the real pattern already used by `McpServerDao` (`lib/infrastructure/mcp/mcp_daos.dart:9-10`, `McpServerDao(PocketBase pb) : super(pb, Collections.mcpServers, McpServer.fromJson)`) — an explicit typed parameter, passed positionally:

```dart
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class PocoConfigDao extends BaseDao<PocoConfig> {
  PocoConfigDao(PocketBase pb)
      : super(pb, Collections.pocoConfigs, PocoConfig.fromJson);
}

@lazySingleton
class PromptDao extends BaseDao<Prompt> {
  PromptDao(PocketBase pb) : super(pb, Collections.prompts, Prompt.fromJson);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/agent_config/agent_config_daos_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/agent_config/ client/packages/pocketcoder_flutter/test/infrastructure/agent_config/
git commit -m "feat(flutter): add PocoConfigDao and PromptDao"
```

---

### Task 6: Flutter — `HarnesseDao`, `ModelDao`, `HarnessModelDao`, `ProviderKeyDao`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/provider/provider_daos.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/provider/provider_daos_test.dart`

**Interfaces:**
- Consumes: `Harnesse`/`Model`/`HarnessModel`/`ProviderKey` (existing generated models — note the model class is literally named `Harnesse`, not `Harness`, per the generator's naming from the `harnesses` collection singular-ization; do not "fix" this spelling, it must match the generated file exactly or `build_runner` conflicts), `Collections.harnesses`/`.models`/`.harnessModels`/`.providerKeys` (existing constants).
- Produces: `HarnesseDao`, `ModelDao`, `HarnessModelDao`, `ProviderKeyDao`, all `@lazySingleton extends BaseDao<T>`.

- [ ] **Step 1: Write the failing test** (same shape as Task 5 Step 1, one `group` per DAO)

- [ ] **Step 2: Run to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/provider/provider_daos_test.dart`
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement**

Same `BaseDao(this._pb, ...)` constraint as Task 5 — use an explicit typed `PocketBase pb` parameter, not `super.pb` shorthand:

```dart
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class HarnesseDao extends BaseDao<Harnesse> {
  HarnesseDao(PocketBase pb) : super(pb, Collections.harnesses, Harnesse.fromJson);
}

@lazySingleton
class ModelDao extends BaseDao<Model> {
  ModelDao(PocketBase pb) : super(pb, Collections.models, Model.fromJson);
}

@lazySingleton
class HarnessModelDao extends BaseDao<HarnessModel> {
  HarnessModelDao(PocketBase pb)
      : super(pb, Collections.harnessModels, HarnessModel.fromJson);
}

@lazySingleton
class ProviderKeyDao extends BaseDao<ProviderKey> {
  ProviderKeyDao(PocketBase pb)
      : super(pb, Collections.providerKeys, ProviderKey.fromJson);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/provider/provider_daos_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/provider/ client/packages/pocketcoder_flutter/test/infrastructure/provider/
git commit -m "feat(flutter): add Harnesse/Model/HarnessModel/ProviderKey DAOs"
```

---

### Task 7: Flutter — `AgentConfigRepository` (poco_configs + prompts)

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/domain/agent_config/i_agent_config_repository.dart`
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/agent_config/agent_config_repository.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/agent_config/agent_config_repository_test.dart`

**Interfaces:**
- Consumes: `PocoConfigDao`, `PromptDao` (Task 5).
- Produces:

```dart
abstract class IAgentConfigRepository {
  Stream<List<PocoConfig>> watchConfigs();
  Stream<List<Prompt>> watchPrompts();
  Future<void> saveConfig(PocoConfig config);
  Future<void> deleteConfig(String id);
  Future<void> savePrompt(Prompt prompt);
  Future<void> deletePrompt(String id);
}
```

- [ ] **Step 1: Write the failing test**

Follow `mcp_repository_test.dart`'s exact pattern (the cleanest existing repo test — copy its fake-DAO/PocketBase setup style):

```dart
void main() {
  late AgentConfigRepository repo;
  late FakePocoConfigDao configDao; // or whatever mocking approach mcp_repository_test.dart uses — Mocktail per pubspec deps
  late FakePromptDao promptDao;

  setUp(() {
    configDao = FakePocoConfigDao();
    promptDao = FakePromptDao();
    repo = AgentConfigRepository(configDao, promptDao);
  });

  test('saveConfig calls configDao.save and wraps failures in AgentConfigException', () async {
    configDao.saveError = Exception('boom');
    expect(
      () => repo.saveConfig(testPocoConfig),
      throwsA(isA<AgentConfigException>()),
    );
  });

  test('watchConfigs forwards configDao.watchAll', () {
    expect(repo.watchConfigs(), emits(configDao.testConfigs));
  });

  // Mirror for watchPrompts/savePrompt/deletePrompt/deleteConfig.
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/agent_config/agent_config_repository_test.dart`
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement**

`i_agent_config_repository.dart`:
```dart
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';

abstract class IAgentConfigRepository {
  Stream<List<PocoConfig>> watchConfigs();
  Stream<List<Prompt>> watchPrompts();
  Future<void> saveConfig(PocoConfig config);
  Future<void> deleteConfig(String id);
  Future<void> savePrompt(Prompt prompt);
  Future<void> deletePrompt(String id);
}
```

`agent_config_repository.dart` — follow `McpRepository`'s exact `tryMethod` wrapping pattern:
```dart
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions/agent_config_exception.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';

@LazySingleton(as: IAgentConfigRepository)
class AgentConfigRepository implements IAgentConfigRepository {
  AgentConfigRepository(this._configDao, this._promptDao);

  final PocoConfigDao _configDao;
  final PromptDao _promptDao;

  @override
  Stream<List<PocoConfig>> watchConfigs() => _configDao.watchAll();

  @override
  Stream<List<Prompt>> watchPrompts() => _promptDao.watchAll();

  @override
  Future<void> saveConfig(PocoConfig config) => tryMethod(
        () => _configDao.save(config.id, config.toJson()),
        AgentConfigException.new,
        'saveConfig',
      );

  @override
  Future<void> deleteConfig(String id) => tryMethod(
        () => _configDao.delete(id),
        AgentConfigException.new,
        'deleteConfig',
      );

  @override
  Future<void> savePrompt(Prompt prompt) => tryMethod(
        () => _promptDao.save(prompt.id, prompt.toJson()),
        AgentConfigException.new,
        'savePrompt',
      );

  @override
  Future<void> deletePrompt(String id) => tryMethod(
        () => _promptDao.delete(id),
        AgentConfigException.new,
        'deletePrompt',
      );
}
```

Add `AgentConfigException` as its own file, `lib/domain/exceptions/agent_config_exception.dart`, following the existing per-file convention already used in that directory (e.g. `lib/domain/exceptions/permission_exception.dart`) — a simple `implements Exception` class with `message`/`cause` fields and a `toString()` override. (Note: `McpException` itself lives in the older shared `lib/domain/exceptions.dart` file alongside `AiException`/`ChatException`/etc., not a standalone `mcp_exception.dart` — that file doesn't exist; don't go looking for it.) `BaseDao.save(String? id, Map<String, dynamic> data, {RequestPolicy? requestPolicy})` (`base_dao.dart:98-101`) takes an id + a field map, not a whole model object — pass `model.id, model.toJson()` as shown above, matching `McpRepository`'s real usage (`_mcpServerDao.save(id, {...})`, `mcp_repository.dart:24,38`).

- [ ] **Step 4: Run to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/agent_config/agent_config_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/agent_config/ client/packages/pocketcoder_flutter/lib/infrastructure/agent_config/agent_config_repository.dart client/packages/pocketcoder_flutter/lib/domain/exceptions/agent_config_exception.dart client/packages/pocketcoder_flutter/test/infrastructure/agent_config/agent_config_repository_test.dart
git commit -m "feat(flutter): add AgentConfigRepository for poco_configs + prompts"
```

---

### Task 8: Flutter — `ProviderRepository` (harnesses/models/harness_models read + provider_keys CRUD)

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/domain/provider/i_provider_repository.dart`
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/provider/provider_repository.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/provider/provider_repository_test.dart`

**Interfaces:**
- Consumes: `HarnesseDao`, `ModelDao`, `HarnessModelDao`, `ProviderKeyDao` (Task 6).
- Produces:

```dart
abstract class IProviderRepository {
  Stream<List<Harnesse>> watchHarnesses();
  Stream<List<Model>> watchModels();
  Stream<List<HarnessModel>> watchHarnessModels();
  Stream<List<ProviderKey>> watchProviderKeys();
  Future<void> saveProviderKey(ProviderKey key);
  Future<void> deleteProviderKey(String id);
}
```

`harnesses`/`models`/`harness_models` are read-only from Flutter — they're deployment-level catalog data seeded by migrations (which harness/model pairs this deployment supports), not something an end user creates. Only `provider_keys` (a user's own API key for a provider) gets write methods.

- [ ] **Step 1: Write the failing test** (same shape as Task 7 Step 1)

- [ ] **Step 2: Run to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/provider/provider_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** (same `tryMethod` pattern as Task 7; read-only methods for harnesses/models/harnessModels just forward `dao.watchAll()` with no wrapping needed since there's nothing to fail beyond what the stream itself surfaces — match whichever of `McpRepository`'s read methods, e.g. `watchServers()`, is unwrapped vs wrapped, and mirror that exactly. `saveProviderKey`/`deleteProviderKey` follow Task 7's corrected pattern: `_providerKeyDao.save(key.id, key.toJson())`, not `_providerKeyDao.save(key)` — `BaseDao.save` takes an id + field map, per `base_dao.dart:98-101`.)

- [ ] **Step 4: Run to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/provider/provider_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/provider/ client/packages/pocketcoder_flutter/lib/infrastructure/provider/provider_repository.dart client/packages/pocketcoder_flutter/test/infrastructure/provider/provider_repository_test.dart
git commit -m "feat(flutter): add ProviderRepository for harnesses/models/provider_keys"
```

---

### Task 9: Flutter — `AgentConfigCubit` + `AgentConfigState`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/application/agent_config/agent_config_state.dart`
- Create: `client/packages/pocketcoder_flutter/lib/application/agent_config/agent_config_cubit.dart`
- Test: `client/packages/pocketcoder_flutter/test/application/agent_config/agent_config_cubit_test.dart`

**Interfaces:**
- Consumes: `IAgentConfigRepository` (Task 7).
- Produces: `AgentConfigCubit extends AppCubit<AgentConfigState>` with `watchAll()`, `saveConfig(PocoConfig)`, `deleteConfig(String)`, `savePrompt(Prompt)`, `deletePrompt(String)`.

- [ ] **Step 1: Write the failing test**

Follow `McpCubit`'s test file pattern exactly (freezed-union state, `bloc_test` package per existing conventions):

```dart
void main() {
  late MockAgentConfigRepository repo;

  setUp(() => repo = MockAgentConfigRepository());

  blocTest<AgentConfigCubit, AgentConfigState>(
    'watchAll emits loaded with configs and prompts',
    build: () {
      when(() => repo.watchConfigs()).thenAnswer((_) => Stream.value([testConfig]));
      when(() => repo.watchPrompts()).thenAnswer((_) => Stream.value([testPrompt]));
      return AgentConfigCubit(repo);
    },
    act: (cubit) => cubit.watchAll(),
    expect: () => [
      isA<AgentConfigState>()
          .having((s) => s.status, 'status', UiFlowStatus.success)
          .having((s) => s.configs, 'configs', [testConfig])
          .having((s) => s.prompts, 'prompts', [testPrompt]),
    ],
  );

  blocTest<AgentConfigCubit, AgentConfigState>(
    'saveConfig calls repo.saveConfig',
    build: () {
      when(() => repo.saveConfig(any())).thenAnswer((_) async {});
      return AgentConfigCubit(repo);
    },
    act: (cubit) => cubit.saveConfig(testConfig),
    verify: (_) => verify(() => repo.saveConfig(testConfig)).called(1),
  );
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/agent_config/agent_config_cubit_test.dart`
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement**

`agent_config_state.dart` — follow whichever of the existing state shapes CLAUDE.md actually wants (the flat `status`/`error` + data fields shape, matching `AiConfigState`'s style since that one already complies with `AppCubit`, rather than `McpState`'s union style which uses plain `Cubit` — this task's cubit must extend `AppCubit<T>` per CLAUDE.md, so the flat-record `IUiFlowState` shape is the correct template to copy, not `McpState`'s union). `UiFlowStatus` (from `cubit_ui_flow`) only has four members codebase-wide: `idle`, `loading`, `success`, `failure` — there is no `.initial`; `AiConfigState` itself (`ai_config_state.dart:14`) defaults to `UiFlowStatus.idle`, use the same:

```dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';

part 'agent_config_state.freezed.dart';

@freezed
class AgentConfigState with _$AgentConfigState implements IUiFlowState {
  const factory AgentConfigState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<PocoConfig> configs,
    @Default([]) List<Prompt> prompts,
    Object? error,
  }) = _AgentConfigState;
}
```

`agent_config_cubit.dart`:
```dart
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

@injectable
class AgentConfigCubit extends AppCubit<AgentConfigState> {
  AgentConfigCubit(this._repo) : super(const AgentConfigState());

  final IAgentConfigRepository _repo;

  Future<void> watchAll() => tryOperation(() async {
        final configs = await _repo.watchConfigs().first;
        final prompts = await _repo.watchPrompts().first;
        emit(state.copyWith(
          configs: configs,
          prompts: prompts,
          status: UiFlowStatus.success,
        ));
      });

  Future<void> saveConfig(PocoConfig config) =>
      tryOperation(() => _repo.saveConfig(config));

  Future<void> deleteConfig(String id) =>
      tryOperation(() => _repo.deleteConfig(id));

  Future<void> savePrompt(Prompt prompt) =>
      tryOperation(() => _repo.savePrompt(prompt));

  Future<void> deletePrompt(String id) =>
      tryOperation(() => _repo.deletePrompt(id));
}
```

Confirm `tryOperation`'s exact signature (does it auto-set `status: UiFlowStatus.success` on the emitted state after a successful save, or does the CLAUDE.md warning "you MUST set status: UiFlowStatus.success — the library does not auto-set it" mean every `tryOperation` body needs an explicit `emit` with that status?) against `AiConfigCubit`'s real `saveAgent`/existing methods before finalizing — copy its exact pattern for the write methods, not just the read method shown above.

- [ ] **Step 4: Run to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/agent_config/agent_config_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Regenerate freezed code and run the full test suite**

```bash
cd client/packages/pocketcoder_flutter
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: clean analyze, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/application/agent_config/ client/packages/pocketcoder_flutter/test/application/agent_config/
git commit -m "feat(flutter): add AgentConfigCubit"
```

---

### Task 10: Flutter — `ProviderCubit` + `ProviderState`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/application/provider/provider_state.dart`
- Create: `client/packages/pocketcoder_flutter/lib/application/provider/provider_cubit.dart`
- Test: `client/packages/pocketcoder_flutter/test/application/provider/provider_cubit_test.dart`

**Interfaces:**
- Consumes: `IProviderRepository` (Task 8).
- Produces: `ProviderCubit extends AppCubit<ProviderState>` with `watchAll()`, `saveProviderKey(ProviderKey)`, `deleteProviderKey(String)`.

Same shape as Task 9 — `ProviderState{status, harnesses, models, harnessModels, providerKeys, error}`, `ProviderCubit` reading all four streams in `watchAll()` and exposing write methods only for `providerKeys`. Same `@Default(UiFlowStatus.idle)` correction from Task 9 applies here — there is no `.initial` member.

- [ ] **Step 1: Write the failing test** (mirror Task 9 Step 1)
- [ ] **Step 2: Run to verify it fails**
- [ ] **Step 3: Implement** (mirror Task 9 Step 3's structure exactly, four data fields instead of two)
- [ ] **Step 4: Run to verify it passes**
- [ ] **Step 5: Regenerate freezed code and run the full test suite** (same commands as Task 9 Step 5)
- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/application/provider/ client/packages/pocketcoder_flutter/test/application/provider/
git commit -m "feat(flutter): add ProviderCubit"
```

---

### Task 11: Flutter — `AgentConfigScreen`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/agent_config/agent_config_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/agent_config/agent_config_screen_test.dart`

**Interfaces:**
- Consumes: `AgentConfigCubit` (Task 9), `PocketCoderShell`/`BiosFrame`/`BiosListTile`/`TerminalButton` (existing design-system widgets, same ones `agent_management_screen.dart` and `mcp_management_screen.dart` already use). The mode picker requires `PocoConfig.mode` to be present in the generated model, which Task 4 Step 2's schema regen provides (see the note there) — this field does not exist in today's checked-in model, only after that regen runs.
- Produces: a screen listing `poco_configs` (name, which harness_model, is_default badge), with working create/edit (name, harness_model picker sourced from `ProviderCubit`'s `harnessModels`, system_prompt picker sourced from `AgentConfigCubit`'s `prompts` with an inline "new prompt" option, mode picker, is_default toggle) and delete. Unlike `agent_management_screen.dart`'s stubs, every button here must actually work — no `// TODO` placeholders.

- [ ] **Step 1: Write the failing test**

Follow `mcp_management_screen`'s widget test pattern (the closest working reference — `_wrap`/`_settle` helpers per the earlier Flutter migration's established pattern) or `agent_widgets_test.dart`'s general style:

```dart
void main() {
  testWidgets('AgentConfigScreen lists configs and ADD NEW opens the editor', (tester) async {
    final cubit = FakeAgentConfigCubit(
      state: AgentConfigState(
        status: UiFlowStatus.success,
        configs: [testPocoConfig],
        prompts: [testPrompt],
      ),
    );
    await tester.pumpWidget(_wrap(
      BlocProvider<AgentConfigCubit>.value(
        value: cubit,
        child: const AgentConfigView(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(testPocoConfig.name), findsOneWidget);

    await tester.tap(find.text(context.l10n.agentConfigAddNew)); // exact l10n key TBD in Step 3
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsWidgets); // the edit dialog actually opened, unlike the old screen's no-op
  });

  testWidgets('saving a config calls cubit.saveConfig', (tester) async {
    // ... fill the form, tap save, verify(() => cubit.saveConfig(any())).called(1)
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/agent_config/agent_config_screen_test.dart`
Expected: FAIL — `AgentConfigScreen`/`AgentConfigView` undefined.

- [ ] **Step 3: Implement**

Structure directly on `agent_management_screen.dart`'s existing `AgentManagementScreen`/`AgentManagementView`/`_showEditAgentDialog` shape (237 lines — reuse its `PocketCoderShell`/`BiosFrame`/`BiosListTile` composition wholesale), with three concrete fixes over the original: (1) the "ADD NEW" button actually opens `_showEditAgentDialog(context, null, state)` — an empty/new `PocoConfig` — instead of an empty `onTap`; (2) the prompt picker and harness_model picker actually render a list drawn from `AgentConfigCubit`'s `prompts` / a `BlocBuilder<ProviderCubit, ProviderState>`'s `harnessModels`, with the selected id written back onto the `PocoConfig` being edited, instead of `// TODO`; (3) every user-facing string goes through `context.l10n.*` — add the new keys to the project's ARB files (find `lib/l10n/*.arb`, follow the existing dot-notation → camelCase convention, e.g. `agentConfig.title` → `agentConfigTitle`) rather than hardcoding, unlike the original screen's few hardcoded strings.

- [ ] **Step 4: Run to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/agent_config/agent_config_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Full analyze + test pass**

```bash
cd client/packages/pocketcoder_flutter
flutter analyze
flutter test
```
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/agent_config/ client/packages/pocketcoder_flutter/test/presentation/agent_config/ client/packages/pocketcoder_flutter/lib/l10n/
git commit -m "feat(flutter): add AgentConfigScreen, a real replacement for the stubbed agent editor"
```

---

### Task 12: Flutter — `ProviderScreen`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/provider/provider_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/provider/provider_screen_test.dart`

**Interfaces:**
- Consumes: `ProviderCubit` (Task 10).
- Produces: a screen listing available `harness_models` (read-only — name/provider/model, sourced from the seeded `harnesses`/`models` catalog) and the user's `provider_keys` (add/edit/delete an API key per provider, masked display, same UX intent as `llm_management_screen.dart`'s `_maskKeyPreview` but against the real collection).

- [ ] **Step 1: Write the failing test** (mirror Task 11 Step 1's shape — list renders, add-key dialog actually calls `cubit.saveProviderKey`)
- [ ] **Step 2: Run to verify it fails**
- [ ] **Step 3: Implement** — structure on `llm_management_screen.dart`'s existing `_buildActiveModel`/`_buildProviderList`/`_buildKeyList` composition, swapping `LlmCubit`/`LlmState` for `ProviderCubit`/`ProviderState` and the real DAOs underneath, l10n-compliant per Task 11's same rule
- [ ] **Step 4: Run to verify it passes**
- [ ] **Step 5: Full analyze + test pass** (same commands as Task 11 Step 5)
- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/provider/ client/packages/pocketcoder_flutter/test/presentation/provider/
git commit -m "feat(flutter): add ProviderScreen, a real replacement for the dead LLM screen"
```

---

### Task 13: Flutter — wire routes and settings menu, then delete the dead screens/cubits/repos/DAOs

**Files:**
- Modify: `lib/app_router.dart`, `lib/domain/exceptions.dart` (remove the now-orphaned `LlmException`)
- Delete: `lib/presentation/settings/agent_management_screen.dart`, `lib/presentation/llm/llm_management_screen.dart`, `lib/application/ai/ai_config_cubit.dart`, `lib/application/ai/ai_config_state.dart` (+ generated), `lib/domain/ai_config/i_ai_config_repository.dart`, `lib/infrastructure/ai_config/ai_config_daos.dart`, `lib/infrastructure/ai_config/ai_config_repository.dart`, `lib/application/llm/llm_cubit.dart`, `lib/application/llm/llm_state.dart` (+ generated), `lib/domain/llm/i_llm_repository.dart`, `lib/infrastructure/llm/llm_daos.dart`, `lib/infrastructure/llm/llm_repository.dart`, `lib/domain/exceptions/ai_model_exception.dart` (already orphaned, unrelated to this plan but cleared out here)
- Test: `flutter analyze` + `flutter test` (no new test file — this task's correctness is "everything still compiles and every existing test still passes with these types gone")

**Interfaces:**
- Consumes: `AgentConfigScreen` (Task 11), `ProviderScreen` (Task 12).
- Produces: `AppRoutes.configureAi` now points at `AgentConfigScreen`, `AppRoutes.configureLlm` now points at `ProviderScreen` (route path/name constants unchanged — only the screen widget behind them changes, so the legacy `/settings/ai` redirect and `settings_screen.dart`'s menu tuples need no edits beyond what's already correct).

- [ ] **Step 1: Repoint the two existing routes**

In `lib/app_router.dart`, change the two `GoRoute`s (confirmed at the `configureAi`/`configureLlm` entries) from:
```dart
child: const AgentManagementScreen(),
```
```dart
child: const AgentConfigScreen(),
```
and
```dart
child: const LlmManagementScreen(),
```
```dart
child: const ProviderScreen(),
```
Update the corresponding imports at the top of the file (remove the two old screen imports, add `agent_config_screen.dart`/`provider_screen.dart`). `settings_screen.dart`'s menu entries and `_navigateTo` switch need no changes — they already route by the `configureAi`/`configureLlm` route-key strings, which are unchanged.

- [ ] **Step 2: Delete the dead source files**

```bash
git rm client/packages/pocketcoder_flutter/lib/presentation/settings/agent_management_screen.dart
git rm client/packages/pocketcoder_flutter/lib/presentation/llm/llm_management_screen.dart
git rm -r client/packages/pocketcoder_flutter/lib/application/ai/
git rm -r client/packages/pocketcoder_flutter/lib/domain/ai_config/
git rm -r client/packages/pocketcoder_flutter/lib/infrastructure/ai_config/
git rm -r client/packages/pocketcoder_flutter/lib/application/llm/
git rm -r client/packages/pocketcoder_flutter/lib/domain/llm/
git rm -r client/packages/pocketcoder_flutter/lib/infrastructure/llm/
```

Do NOT delete `lib/infrastructure/communication/communication_daos.dart`'s duplicate `SandboxAgentDao` or anything under it — `sandbox_agents`/`sandbox_configs` are explicitly out of scope for this plan (Global Constraints).

Also delete `client/packages/pocketcoder_flutter/lib/domain/exceptions/ai_model_exception.dart` — already orphaned today (zero consumers, confirmed via `grep -rln "AiModelException" lib/` matching only its own definition), independent of this plan but worth clearing out while touching this area. Then, in the shared `lib/domain/exceptions.dart` file, remove the `LlmException` class (currently lines 82-84) — its only consumer, `llm_repository.dart`, is deleted in this same task, so it becomes fully orphaned. **Do not remove `AiException`** (same file, around line 47) — it has an unrelated consumer, `lib/infrastructure/feedback/exception_mapper.dart`, and must stay.

- [ ] **Step 3: Regenerate DI and freezed code**

```bash
cd client/packages/pocketcoder_flutter
dart run build_runner build --delete-conflicting-outputs
```
Expected: `bootstrap.config.dart` (the injectable-generated DI registration file) drops the `AiConfigCubit`/`LlmCubit` factory registrations automatically and gains `AgentConfigCubit`/`ProviderCubit` ones — confirm both by diffing the file after this command, don't hand-edit it.

- [ ] **Step 4: Full analyze + test pass**

```bash
flutter analyze
flutter test
```
Expected: clean — this is the real proof the deletion had zero live blast radius beyond the two screens themselves (confirmed via the earlier research pass: zero test files reference any of the deleted types).

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/app_router.dart client/packages/pocketcoder_flutter/lib/domain/exceptions.dart
git commit -m "chore(flutter): remove dead AI/LLM config screens, cubits, and repos

Replaced by AgentConfigScreen/ProviderScreen (this plan's Tasks 11-12),
which write to the schema Goose's config pipeline actually reads
(poco_configs/harness_models/provider_keys/prompts) instead of the
pre-Goose-migration ai_agents/llm_keys tables nothing in Go has read
since the ACP/AG-UI rewrite."
```

---

### Task 14: Manual verification (required before calling this done — backend + UI change)

Per this project's standing rule for frontend changes, and because this task also changes live backend delivery behavior: start a real backend and actually exercise the feature.

```bash
docker compose build pocketbase goose
docker compose --profile agent up -d pocketbase goose
./client/scripts/run_chrome_incognito.sh
```

Walk through, against a real or locally-run backend with a valid provider API key:

1. Open Settings → the two menu entries that used to open the dead screens now open `AgentConfigScreen`/`ProviderScreen`. Confirm they render real data (not empty stubs).
2. In `ProviderScreen`, add a `provider_keys` row for your configured provider. Confirm it saves (check PocketBase admin UI or `docker logs pocketcoder-goose` for the restart this still triggers, per Global Constraints — this task doesn't remove that).
3. In `AgentConfigScreen`, create a new `poco_configs` row (name, pick a harness_model, write/pick a system prompt, pick a mode, no need to set is_default). Confirm the "ADD NEW" and picker flows actually work end-to-end — this is the concrete fix over the old screen's `// TODO` stubs.
4. Start a chat using that new agent config (however chats currently pick a `poco_config` — check `chats.poco_config` wiring; if there's no UI for that yet, set it directly via PocketBase admin for this verification pass). Confirm in the running chat that the model/provider actually in use matches what you configured — this is the real proof Task 3's live `PerSessionApplier` delivery works, not just that it compiles. Cross-check by watching `docker logs pocketcoder-goose` during session start for the `session/set_config_option` calls, or by asking the agent "what model are you" if the provider surfaces that.
5. Edit that same `poco_configs` row's system prompt while a chat using it is *already open*, save, then send another message in that same chat without restarting anything. Confirm the new instructions take effect — this is the "live, no restart" property this whole plan exists to deliver, and the one thing a passing test suite can't prove by itself.

If any of these don't hold, do not mark this plan complete — file what's broken and fix it before moving on.
