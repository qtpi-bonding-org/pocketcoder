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
	"context"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

// TestSaveAgentSessionStampsHarnessInstance verifies that saveAgentSession
// correctly stamps the harness_instance field on the agent_sessions row.
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

	if err := saveAgentSession(context.Background(), app, chat.Id, userID, "session-abc", instance.Id); err != nil {
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
