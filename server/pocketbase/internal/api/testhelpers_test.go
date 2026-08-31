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
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

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

func randomSuffix() string {
	return fmt.Sprintf("%d", rand.Int63())
}

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
		instance.Set("oauth_account", "")
	}
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}

	return harness, instance
}

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
