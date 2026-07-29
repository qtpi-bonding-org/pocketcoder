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

package api

import (
	"fmt"
	"math/rand"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

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

// seedTestHarnessAndInstance creates a harness and its default harness_instance.
// It uses a unique suffix to avoid conflicts with other tests using the same name.
func seedTestHarnessAndInstance(t *testing.T, app core.App, harnessName string, supportsLive, supportsGoose, singleConnOnly bool) (*core.Record, *core.Record) {
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
	harness.Set("supports_goose_extensions", supportsGoose)
	harness.Set("single_connection_only", singleConnOnly)
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

// createTestPocoConfig creates a poco_config record with optional fields.
func createTestPocoConfig(t *testing.T, app core.App, fields map[string]any) *core.Record {
	t.Helper()
	// Create a test harness and harness_model first
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, true, false)
	hm := createTestHarnessModel(t, app, harness)

	pocoColl, err := app.FindCollectionByNameOrId("poco_configs")
	if err != nil {
		t.Fatal(err)
	}
	poco := core.NewRecord(pocoColl)
	poco.Set("name", "test-poco-"+randomSuffix())
	poco.Set("is_default", false)
	poco.Set("harness_model", hm.Id) // Set the required harness_model

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

// TestBuildSessionProfileResolvesChatFieldsWithNoPocoConfig verifies that
// chat-level fields (harness, workspace_override) are read BEFORE checking
// for a poco_config, fixing the early-return bug.
func TestBuildSessionProfileResolvesChatFieldsWithNoPocoConfig(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

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

// TestBuildSessionProfileWorkspaceOverrideKeepsPocoAdditionalDirectories
// verifies that when a chat has workspace_override, it becomes the Cwd,
// but the poco_config's additional folders are still preserved in
// AdditionalDirectories (§5.7).
func TestBuildSessionProfileWorkspaceOverrideKeepsPocoAdditionalDirectories(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	poco := createTestPocoConfig(t, app, map[string]any{
		"workspace_folders": []string{"/workspace/project", "/workspace/tools"},
	})
	chat := createTestChat(t, app, map[string]any{
		"poco_config":        poco.Id,
		"workspace_override": []string{"/workspace/other"},
	})

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
	_, err = buildSessionProfile(app, chat.Id)
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
	_, err = buildSessionProfile(app, chat.Id)
	if err == nil {
		t.Fatal("expected rejection of a workspace_override containing .. traversal")
	}
}
