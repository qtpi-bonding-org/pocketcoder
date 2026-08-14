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

package sessionprofile_test

import (
	"context"
	"errors"
	"fmt"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/pocoprompt"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/sessionprofile"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

// testApp spins up a fresh in-memory PocketBase test app with this repo's
// migrations applied, and registers cleanup.
func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	ensureTestPoco(t, app)
	return app
}

func ensureTestPoco(t *testing.T, app core.App) *core.Record {
	t.Helper()
	if poco, err := app.FindFirstRecordByFilter("agent_profiles", "name = 'Poco' && is_system = true", nil); err == nil {
		poco.Set("is_default", true)
		if err := app.Save(poco); err != nil {
			t.Fatal(err)
		}
		if !poco.GetBool("is_default") {
			t.Fatal("test Poco is_default was not persisted")
		}
		return poco
	}
	collection, err := app.FindCollectionByNameOrId("agent_profiles")
	if err != nil {
		t.Fatal(err)
	}
	poco := core.NewRecord(collection)
	poco.Set("name", "Poco")
	poco.Set("is_system", true)
	poco.Set("is_default", true)
	if err := app.Save(poco); err != nil {
		t.Fatal(err)
	}
	if !poco.GetBool("is_default") {
		t.Fatal("test Poco is_default was not persisted")
	}
	return poco
}

// waitForHarnessProvisioning drains the asynchronous provisioning started by
// Build before the test app is cleaned up. Without this, the
// background goroutine can continue using PocketBase after app.Cleanup closes
// its database, producing a nil-pointer panic in PocketBase's record hooks.
func waitForHarnessProvisioning(t *testing.T, app core.App, harnessID, userID string) *core.Record {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		rec, err := app.FindFirstRecordByFilter(
			"harness_instances",
			"harness = {:h} && user = {:u}",
			map[string]any{"h": harnessID, "u": userID},
		)
		if err == nil && rec != nil && rec.GetString("status") != "pending" {
			return rec
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("harness provisioning did not reach a terminal status within 2s")
	return nil
}

// createTestHarness inserts a harnesses row with sane defaults, overridden
// by whatever fields the caller supplies. Unlike seedTestHarnessAndInstance
// below, this deliberately does NOT create a harness_instances row — it's
// for tests exercising the "no instance yet" / provisioning path.
func createTestHarness(t *testing.T, app core.App, overrides map[string]any) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("name", "Test Harness")
	rec.Set("cli_id", "test-harness-"+randomSuffix())
	rec.Set("acp_transport", "websocket")
	for k, v := range overrides {
		rec.Set(k, v)
	}
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

// randomSuffix generates a random string for unique test data.
func randomSuffix() string {
	return fmt.Sprintf("%d", rand.Int63())
}

// testUser creates a test user in the _pb_users_auth_ collection.
func testUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(col)
	u.SetEmail(email)
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func testHarnessAccountID(t *testing.T, app core.App, userID, harnessID string) string {
	t.Helper()
	account, err := harnessaccount.EnsureDefaultPersonal(app, userID, harnessID)
	if err != nil {
		t.Fatal(err)
	}
	return account.Id
}

// seedTestHarnessAndInstance creates a harness and its default harness_instance.
// It uses a unique suffix to avoid conflicts with other tests using the same name.
func seedTestHarnessAndInstance(t *testing.T, app core.App, harnessName string, supportsLive bool, userID string) (*core.Record, *core.Record) {
	t.Helper()
	harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}

	// Use a unique ID suffix to allow multiple calls with the same name
	uniqueSuffix := randomSuffix()
	cliID := harnessName + "-" + uniqueSuffix

	harness := core.NewRecord(harnessesColl)
	harness.Set("name", harnessName)
	harness.Set("cli_id", cliID)
	harness.Set("acp_transport", "websocket")
	harness.Set("supports_live_config", supportsLive)
	harness.Set("supports_additional_directories", true)
	if err := app.Save(harness); err != nil {
		t.Fatal(err)
	}

	instancesColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	instance := core.NewRecord(instancesColl)
	instance.Set("harness", harness.Id)
	instance.Set("launch_key", "")
	instance.Set("container_name", "pocketcoder-"+harnessName+"-"+uniqueSuffix)
	instance.Set("acp_endpoint", "")
	instance.Set("secret", "")
	instance.Set("status", "running")
	instance.Set("managed", false)
	if userID != "" {
		instance.Set("user", userID)
		account, err := harnessaccount.EnsureDefaultPersonal(app, userID, harness.Id)
		if err != nil {
			t.Fatal(err)
		}
		instance.Set("harness_account", account.Id)
	}
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}

	return harness, instance
}

// createTestChat creates a chat record with optional fields.
func createTestChat(t *testing.T, app core.App, fields map[string]any) *core.Record {
	t.Helper()
	uniqueSuffix := randomSuffix()
	user := testUser(t, app, "testchat-"+uniqueSuffix+"@example.com")

	chatsColl, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	chat := core.NewRecord(chatsColl)
	chat.Set("user", user.Id)
	chat.Set("title", "Test Chat")
	chat.Set("archived", false)

	if fields != nil {
		for k, v := range fields {
			chat.Set(k, v)
		}
	}

	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}
	return chat
}

// createTestHarnessModel creates a harness_model record.
func createTestHarnessModel(t *testing.T, app core.App, harness *core.Record) *core.Record {
	t.Helper()
	// First create a model
	modelsColl, err := app.FindCollectionByNameOrId("models")
	if err != nil {
		t.Fatal(err)
	}
	model := core.NewRecord(modelsColl)
	model.Set("name", "test-model-"+randomSuffix())
	model.Set("provider", "anthropic")
	if err := app.Save(model); err != nil {
		t.Fatal(err)
	}

	// Then create a harness_model linking to the harness and model
	hmColl, err := app.FindCollectionByNameOrId("harness_models")
	if err != nil {
		t.Fatal(err)
	}
	hm := core.NewRecord(hmColl)
	hm.Set("harness", harness.Id)
	hm.Set("model", model.Id)
	hm.Set("harness_model_id", "test-model-id-"+randomSuffix())
	if err := app.Save(hm); err != nil {
		t.Fatal(err)
	}
	return hm
}

// createTestPocoConfig creates an agent_profile record with optional fields.
func createTestPocoConfig(t *testing.T, app core.App, fields map[string]any, userID string) *core.Record {
	t.Helper()
	// Create a test harness first; agent profiles are harness-independent.
	seedTestHarnessAndInstance(t, app, "test-harness", true, userID)

	pocoColl, err := app.FindCollectionByNameOrId("agent_profiles")
	if err != nil {
		t.Fatal(err)
	}
	poco := core.NewRecord(pocoColl)
	poco.Set("name", "test-poco-"+randomSuffix())
	poco.Set("is_default", false)

	if fields != nil {
		for k, v := range fields {
			poco.Set(k, v)
		}
	}

	if err := app.Save(poco); err != nil {
		t.Fatal(err)
	}
	return poco
}

// TestBuildSessionProfileResolvesChatFieldsWithDefaultPoco verifies that
// chat-level fields (harness, workspace_override) are read BEFORE checking
// for an explicit agent_profile, and that seeded Poco supplies identity.
func TestBuildSessionProfileResolvesChatFieldsWithDefaultPoco(t *testing.T) {
	app := testApp(t)

	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, instance := seedTestHarnessAndInstance(t, app, "goose", true, userID)
	chat := createTestChat(t, app, map[string]any{"user": userID, "harness": harness.Id})
	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err != nil {
		t.Fatal(err)
	}
	if profile.ResolvedInstanceID != instance.Id {
		t.Errorf("ResolvedInstanceID = %q, want %q — the early-return bug regression", profile.ResolvedInstanceID, instance.Id)
	}
	if profile.Instructions != pocoprompt.Default {
		t.Error("profile without an explicit prompt must use Poco's built-in prompt")
	}
	if profile.AccountID != userID || profile.AgentProfileID == "" || profile.AgentName != "Poco" {
		t.Fatalf("memory identity = %q/%q/%q, want %q/<Poco id>/Poco", profile.AccountID, profile.AgentProfileID, profile.AgentName, userID)
	}
	for _, server := range profile.McpServers {
		if server.Http != nil && server.Http.Name == "memory" {
			return
		}
	}
	t.Fatal("expected profile.McpServers to contain attributed memory HTTP entry")
}

func TestBuildSessionProfileUsesExplicitAgentAsMemoryAuthor(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, _ := seedTestHarnessAndInstance(t, app, "goose", true, userID)
	agent := createTestPocoConfig(t, app, map[string]any{
		"name": "Amélie 🌱",
		"user": userID,
	}, userID)
	chat := createTestChat(t, app, map[string]any{
		"user": userID, "harness": harness.Id, "agent_profile": agent.Id,
	})

	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err != nil {
		t.Fatal(err)
	}
	if profile.AccountID != userID || profile.AgentProfileID != agent.Id || profile.AgentName != "Amélie 🌱" {
		t.Fatalf("memory identity = %q/%q/%q", profile.AccountID, profile.AgentProfileID, profile.AgentName)
	}
}

func TestBuildSessionProfileResolvesVirtualOllamaTagWithoutCatalogRows(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/tags" {
			t.Fatalf("path = %q, want /api/tags", r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"models":[{"name":"qwen2.5:0.5b"}]}`))
	}))
	defer server.Close()

	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	instances, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	instance := core.NewRecord(instances)
	instance.Set("harness", harness.Id)
	instance.Set("user", userID)
	instance.Set("harness_account", testHarnessAccountID(t, app, userID, harness.Id))
	instance.Set("launch_key", "")
	instance.Set("container_name", "pocketcoder-goose-"+randomSuffix())
	instance.Set("status", "running")
	instance.Set("managed", false)
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}
	chat := createTestChat(t, app, map[string]any{
		"user":                  userID,
		"harness":               harness.Id,
		"ollama_model_override": "qwen2.5:0.5b",
	})

	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), server.URL)
	if err != nil {
		t.Fatal(err)
	}
	if profile.Provider != "ollama" || profile.Model != "qwen2.5:0.5b" {
		t.Fatalf("profile provider/model = %q/%q, want ollama/qwen2.5:0.5b", profile.Provider, profile.Model)
	}
	models, err := app.FindRecordsByFilter("models", "provider = 'ollama'", "", 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(models) != 0 {
		t.Fatalf("virtual Ollama choice created %d catalog records, want none", len(models))
	}
}

func TestBuildSessionProfileRejectsVirtualOllamaOnUnsupportedHarness(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, _ := seedTestHarnessAndInstance(t, app, "codex", true, userID)
	chat := createTestChat(t, app, map[string]any{
		"user":                  userID,
		"harness":               harness.Id,
		"ollama_model_override": "qwen2.5:0.5b",
	})

	_, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err == nil || !strings.Contains(err.Error(), "does not support local Ollama") {
		t.Fatalf("err = %v, want unsupported local Ollama harness error", err)
	}
}

// TestBuildSessionProfileWorkspaceOverrideKeepsPocoAdditionalDirectories
// verifies that when a chat has workspace_override, it becomes the Cwd,
// but the agent_profile's additional folders are still preserved in
// AdditionalDirectories (§5.7).
func TestBuildSessionProfileWorkspaceOverrideKeepsPocoAdditionalDirectories(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, _ := seedTestHarnessAndInstance(t, app, "goose", true, userID)
	poco := createTestPocoConfig(t, app, map[string]any{
		"workspace_folders": []string{"/workspace/project", "/workspace/tools"},
	}, userID)
	chat := createTestChat(t, app, map[string]any{
		"user":               userID,
		"harness":            harness.Id,
		"agent_profile":      poco.Id,
		"workspace_override": []string{"/workspace/other"},
	})

	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
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

// TestBuildSessionProfileRejectsWorkspaceOverrideOutsideRoot verifies that
// a workspace_override path outside /workspace is rejected.
func TestBuildSessionProfileRejectsWorkspaceOverrideOutsideRoot(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	chat := createTestChat(t, app, map[string]any{
		"workspace_override": []string{"/goose/config"},
	})
	_, err = sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err == nil {
		t.Fatal("expected rejection of a workspace_override outside /workspace")
	}
}

// TestBuildSessionProfileRejectsTraversal verifies that a workspace_override
// containing ".." path traversal is rejected.
func TestBuildSessionProfileRejectsTraversal(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	chat := createTestChat(t, app, map[string]any{
		"workspace_override": []string{"/workspace/../etc"},
	})
	_, err = sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err == nil {
		t.Fatal("expected rejection of a workspace_override containing .. traversal")
	}
}

// TestBuildSessionProfileTriggersProvisioningWhenInstanceMissing verifies
// that when no harness_instances row exists yet for the resolved harness,
// Build kicks off background provisioning (Task 6) and
// returns sessionprofile.ErrProvisioning instead of silently proceeding with an
// empty dial target.
func TestBuildSessionProfileTriggersProvisioningWhenInstanceMissing(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{"cli_id": "new-harness", "container_image": "x"})
	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})
	userID := chat.GetString("user")
	// deliberately: no harness_instances row exists yet for this harness

	_, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if !errors.Is(err, sessionprofile.ErrProvisioning) {
		t.Fatalf("expected sessionprofile.ErrProvisioning, got %v", err)
	}

	// Provisioning is kicked off in a background goroutine. Drain it before
	// this test's app cleanup can close PocketBase underneath that goroutine.
	rec := waitForHarnessProvisioning(t, app, harness.Id, userID)
	// Build's production wiring hands ProvisionHarnessInstance
	// the REAL dockerapi.New() client (only Task 6's own tests can inject a
	// fake docker client) — so outside a live docker-compose network, where
	// "docker-socket-proxy-write" resolves and self-inspecting
	// "pocketcoder-pocketbase" succeeds, ResolveWorkspaceVolumeAndNetwork
	// fails immediately and the row can race straight from "pending" to
	// "error" before this test's first poll ever observes "pending". What
	// THIS task is responsible for is that provisioning was triggered at
	// all (a row exists) and Build reported
	// sessionprofile.ErrProvisioning — not that the docker calls it kicks off
	// succeed, which is Task 6/8's concern and depends on real infra.
	switch rec.GetString("status") {
	case "pending", "running", "error":
	default:
		t.Errorf("status = %q, want pending, running, or error (provisioning was at least attempted)", rec.GetString("status"))
	}
}

// TestBuildSessionProfileReturnsHarnessFailedForErrorStatusInstance verifies
// that a resolved harness_instances row with status="error" is reported via
// the sessionprofile.ErrHarnessFailed sentinel (not sessionprofile.ErrProvisioning, and not a bare
// unwrapped error) so callers can distinguish "harness failed to start"
// from "harness still starting" via errors.Is.
func TestBuildSessionProfileReturnsHarnessFailedForErrorStatusInstance(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{"cli_id": "failed-harness"})
	instColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	inst := core.NewRecord(instColl)
	inst.Set("user", userID)
	inst.Set("harness", harness.Id)
	inst.Set("harness_account", testHarnessAccountID(t, app, userID, harness.Id))
	inst.Set("launch_key", "")
	inst.Set("container_name", "pocketcoder-failed-"+randomSuffix())
	inst.Set("secret", "s")
	inst.Set("status", "error")
	inst.Set("last_error", "image pull failed")
	inst.Set("managed", true)
	if err := app.Save(inst); err != nil {
		t.Fatal(err)
	}
	chat := createTestChat(t, app, map[string]any{
		"harness": harness.Id,
		"user":    userID,
	})

	_, err = sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if !errors.Is(err, sessionprofile.ErrHarnessFailed) {
		t.Fatalf("expected sessionprofile.ErrHarnessFailed, got %v", err)
	}
	if errors.Is(err, sessionprofile.ErrProvisioning) {
		t.Errorf("sessionprofile.ErrHarnessFailed must not also match sessionprofile.ErrProvisioning: %v", err)
	}
}

// TestProfileErrorClassificationForSyncShortCircuit is a table test over
// the sentinel classification agent.go's HTTP handlers use to decide
// whether a Build error should short-circuit synchronously
// (sessionprofile.ErrProvisioning / sessionprofile.ErrHarnessFailed — the two error conditions
// this task introduces) or fall through unchanged to the pre-existing
// async RUN_ERROR SSE path (everything else, e.g. a workspace-path
// rejection that predates this task). Guards against re-widening the
// pre-check to swallow error types it was never meant to touch.
func TestProfileErrorClassificationForSyncShortCircuit(t *testing.T) {
	app := testApp(t)

	// Case 1: no harness_instances row yet -> sessionprofile.ErrProvisioning, which
	// SHOULD short-circuit synchronously.
	harness := createTestHarness(t, app, map[string]any{"cli_id": "classify-missing"})
	provisioningChat := createTestChat(t, app, map[string]any{"harness": harness.Id})
	provisioningUserID := provisioningChat.GetString("user")
	{
		// Build fires the background provisioning goroutine
		// (Task 6's ProvisionHarnessInstance) as a side effect of resolving
		// this case's error below. Drain it to a terminal status here,
		// BEFORE the table runs, the same way
		// TestBuildSessionProfileTriggersProvisioningWhenInstanceMissing
		// does — otherwise testApp's t.Cleanup(app.Cleanup) can tear the
		// app down while that goroutine is still mid-flight, which
		// panics (observed: nil-pointer dereference in RecordQuery after
		// Cleanup closes the underlying DB).
		if _, err := sessionprofile.Build(app, provisioningChat.Id, context.Background(), ollama.DefaultURL); !errors.Is(err, sessionprofile.ErrProvisioning) {
			t.Fatalf("setup: expected sessionprofile.ErrProvisioning, got %v", err)
		}
		waitForHarnessProvisioning(t, app, harness.Id, provisioningUserID)
	}

	// Case 2: harness_instances row with status="error" -> sessionprofile.ErrHarnessFailed,
	// which SHOULD also short-circuit synchronously.
	failedHarness := createTestHarness(t, app, map[string]any{"cli_id": "classify-failed"})
	failedUserID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	instColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	inst := core.NewRecord(instColl)
	inst.Set("user", failedUserID)
	inst.Set("harness", failedHarness.Id)
	inst.Set("harness_account", testHarnessAccountID(t, app, failedUserID, failedHarness.Id))
	inst.Set("launch_key", "")
	inst.Set("container_name", "pocketcoder-classify-"+randomSuffix())
	inst.Set("secret", "s")
	inst.Set("status", "error")
	inst.Set("last_error", "boom")
	inst.Set("managed", true)
	if err := app.Save(inst); err != nil {
		t.Fatal(err)
	}
	failedChat := createTestChat(t, app, map[string]any{
		"harness": failedHarness.Id,
		"user":    failedUserID,
	})

	// Case 3: a pre-existing, non-provisioning error type (workspace path
	// outside /workspace) -> should NOT match either sentinel, so it must
	// keep falling through to StartPrompt / the async SSE path unchanged.
	rejectedChat := createTestChat(t, app, map[string]any{
		"workspace_override": []string{"/goose/config"},
	})

	tests := []struct {
		name          string
		chatID        string
		wantSyncShort bool
	}{
		{"missing instance (provisioning)", provisioningChat.Id, true},
		{"instance status=error (harness failed)", failedChat.Id, true},
		{"pre-existing workspace rejection", rejectedChat.Id, false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := sessionprofile.Build(app, tc.chatID, context.Background(), ollama.DefaultURL)
			if err == nil {
				t.Fatal("expected Build to return an error")
			}
			gotSyncShort := errors.Is(err, sessionprofile.ErrProvisioning) || errors.Is(err, sessionprofile.ErrHarnessFailed)
			if gotSyncShort != tc.wantSyncShort {
				t.Errorf("err = %v: sync-short-circuit-worthy = %v, want %v", err, gotSyncShort, tc.wantSyncShort)
			}
		})
	}
}

// runningInstanceFor creates a "running" harness_instances row for the given
// harness, matching the shape Build requires to resolve past
// the provisioning check.
func runningInstanceFor(t *testing.T, app core.App, harness *core.Record, userID string) *core.Record {
	t.Helper()
	instColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	inst := core.NewRecord(instColl)
	inst.Set("user", userID)
	inst.Set("harness", harness.Id)
	inst.Set("harness_account", testHarnessAccountID(t, app, userID, harness.Id))
	inst.Set("launch_key", "")
	inst.Set("container_name", "pocketcoder-"+harness.GetString("cli_id")+"-"+randomSuffix())
	inst.Set("secret", "s")
	inst.Set("status", "running")
	inst.Set("managed", true)
	if err := app.Save(inst); err != nil {
		t.Fatal(err)
	}
	return inst
}

// TestBuildSessionProfileAttachesMcpGatewayForPeerHarness verifies a peer
// stdio harness gets the gateway through the common ACP session path.
func TestBuildSessionProfileAttachesMcpGatewayForPeerHarness(t *testing.T) {
	t.Setenv("MCP_GATEWAY_AUTH_TOKEN", "test-token-123")

	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'claude-code'", nil)
	if err != nil {
		t.Fatal(err)
	}
	runningInstanceFor(t, app, harness, userID)
	chat := createTestChat(t, app, map[string]any{"harness": harness.Id, "user": userID})

	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err != nil {
		t.Fatal(err)
	}

	var found bool
	for _, m := range profile.McpServers {
		if m.Http != nil && m.Http.Name == "gateway" {
			found = true
			if len(m.Http.Headers) != 1 || m.Http.Headers[0].Value != "Bearer test-token-123" {
				t.Errorf("gateway headers = %+v, want a single Bearer test-token-123 Authorization header", m.Http.Headers)
			}
		}
	}
	if !found {
		t.Fatal("expected profile.McpServers to contain the gateway HTTP entry for a peer harness")
	}
}

// TestBuildSessionProfileAttachesMcpGatewayForGoose verifies Goose receives
// the gateway through the same standard ACP session path as every peer.
func TestBuildSessionProfileAttachesMcpGatewayForGoose(t *testing.T) {
	t.Setenv("MCP_GATEWAY_AUTH_TOKEN", "test-token-123")

	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	runningInstanceFor(t, app, harness, userID)
	chat := createTestChat(t, app, map[string]any{"harness": harness.Id, "user": userID})

	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err != nil {
		t.Fatal(err)
	}

	for _, m := range profile.McpServers {
		if m.Http != nil && m.Http.Name == "gateway" {
			return
		}
	}
	t.Fatal("expected Goose session to receive the gateway via McpServers")
}

// TestBuildSessionProfileOmitsMcpGatewayWithoutToken verifies a peer harness
// session omits the gateway entirely (rather than sending an unauthenticated
// one the gateway would reject) when MCP_GATEWAY_AUTH_TOKEN isn't set.
func TestBuildSessionProfileOmitsMcpGatewayWithoutToken(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "testchat-"+randomSuffix()+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'claude-code'", nil)
	if err != nil {
		t.Fatal(err)
	}
	runningInstanceFor(t, app, harness, userID)
	chat := createTestChat(t, app, map[string]any{"harness": harness.Id, "user": userID})

	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), ollama.DefaultURL)
	if err != nil {
		t.Fatal(err)
	}

	for _, m := range profile.McpServers {
		if m.Http != nil && m.Http.Name == "gateway" {
			t.Fatal("expected no gateway entry when MCP_GATEWAY_AUTH_TOKEN is unset")
		}
	}
}

func TestSaveAgentSessionStampsHarnessInstance(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	chat := createTestChat(t, app, nil)
	userID := chat.GetString("user")

	// First, create a harness_instances row to reference
	harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	harness := core.NewRecord(harnessesColl)
	harness.Set("name", "test-harness")
	harness.Set("cli_id", "test-cli-123")
	harness.Set("acp_transport", "websocket")
	if err := app.Save(harness); err != nil {
		t.Fatal(err)
	}

	instancesColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	instance := core.NewRecord(instancesColl)
	instance.Set("harness", harness.Id)
	instance.Set("launch_key", "")
	instance.Set("container_name", "test-container")
	instance.Set("acp_endpoint", "")
	instance.Set("secret", "")
	instance.Set("status", "running")
	instance.Set("managed", false)
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}

	if err := sessionprofile.SaveSession(context.Background(), app, chat.Id, userID, "session-abc", instance.Id); err != nil {
		t.Fatal(err)
	}
	rec, err := app.FindFirstRecordByFilter("agent_sessions", "chat = {:c}", map[string]any{"c": chat.Id})
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("harness_instance") != instance.Id {
		t.Errorf("harness_instance = %q, want %q", rec.GetString("harness_instance"), instance.Id)
	}
}
