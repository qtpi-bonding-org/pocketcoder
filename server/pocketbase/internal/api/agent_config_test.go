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
	"testing"

	"github.com/pocketbase/pocketbase/core"
)

// Exercises PersistModelOverride directly rather than through
// SetChatConfigOption, since it needs no live run/ACP connection.
func TestSetChatConfigOptionPersistsModelOverride(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "model-persist@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)

	provider, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}

	modelsColl, err := app.FindCollectionByNameOrId("models")
	if err != nil {
		t.Fatal(err)
	}
	model1 := core.NewRecord(modelsColl)
	model1.Set("name", "claude-3.5-sonnet")
	model1.Set("provider", provider.Id)
	if err := app.Save(model1); err != nil {
		t.Fatal(err)
	}

	model2 := core.NewRecord(modelsColl)
	model2.Set("name", "claude-3-opus")
	model2.Set("provider", provider.Id)
	if err := app.Save(model2); err != nil {
		t.Fatal(err)
	}

	hmColl, err := app.FindCollectionByNameOrId("harness_models")
	if err != nil {
		t.Fatal(err)
	}

	hm1 := core.NewRecord(hmColl)
	hm1.Set("harness", harness.Id)
	hm1.Set("model", model1.Id)
	hm1.Set("harness_model_id", "claude-3.5-sonnet")
	if err := app.Save(hm1); err != nil {
		t.Fatal(err)
	}

	hm2 := core.NewRecord(hmColl)
	hm2.Set("harness", harness.Id)
	hm2.Set("model", model2.Id)
	hm2.Set("harness_model_id", "claude-3-opus")
	if err := app.Save(hm2); err != nil {
		t.Fatal(err)
	}

	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})
	if chat.GetString("harness_model_override") != "" {
		t.Fatal("chat should start with no harness_model_override")
	}

	PersistModelOverride(app, chat.Id, "claude-3-opus")

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	override := reloaded.GetString("harness_model_override")
	if override != hm2.Id {
		t.Fatalf("harness_model_override = %q, want %q (hm2.Id)", override, hm2.Id)
	}
}

func TestPersistModelOverrideNoMatchingRow(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "non-model-config@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)

	provider, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}

	modelsColl, err := app.FindCollectionByNameOrId("models")
	if err != nil {
		t.Fatal(err)
	}
	model1 := core.NewRecord(modelsColl)
	model1.Set("name", "claude-3.5-sonnet")
	model1.Set("provider", provider.Id)
	if err := app.Save(model1); err != nil {
		t.Fatal(err)
	}

	hmColl, err := app.FindCollectionByNameOrId("harness_models")
	if err != nil {
		t.Fatal(err)
	}
	hm1 := core.NewRecord(hmColl)
	hm1.Set("harness", harness.Id)
	hm1.Set("model", model1.Id)
	hm1.Set("harness_model_id", "claude-3.5-sonnet")
	if err := app.Save(hm1); err != nil {
		t.Fatal(err)
	}

	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})

	PersistModelOverride(app, chat.Id, "nonexistent-model-id")

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("harness_model_override") != "" {
		t.Fatal("harness_model_override should not be set when model is not found")
	}
}
