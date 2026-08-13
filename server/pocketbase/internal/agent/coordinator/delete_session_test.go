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

package coordinator

import (
	"context"
	"fmt"
	"math/rand"
	"testing"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

// randomSuffixForTest generates a random string for unique test data.
func randomSuffixForTest() string {
	return fmt.Sprintf("%d", rand.Int63())
}

// testUserForTest creates a test user in the _pb_users_auth_ collection.
func testUserForTest(t *testing.T, app core.App, email string) *core.Record {
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

// createTestChatForTest creates a chat record with optional fields.
func createTestChatForTest(t *testing.T, app core.App, fields map[string]any) *core.Record {
	t.Helper()
	uniqueSuffix := randomSuffixForTest()
	user := testUserForTest(t, app, "testchat-"+uniqueSuffix+"@example.com")

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

// seedAgentSessionWithInstance creates a agent_sessions row for a chat with the specified Target.
func seedAgentSessionWithInstance(t *testing.T, app core.App, chatID string, userID string, target Target) {
	t.Helper()

	// First, create a harness and harness_instance with the specified endpoint
	harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}

	harness := core.NewRecord(harnessesColl)
	harness.Set("name", "test-harness")
	harness.Set("cli_id", "test-harness-"+randomSuffixForTest())
	harness.Set("acp_transport", "websocket")
	harness.Set("supports_session_delete", true)
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
	instance.Set("container_name", "test-container-"+randomSuffixForTest())
	instance.Set("acp_endpoint", target.URL)
	instance.Set("secret", target.Secret)
	instance.Set("status", "running")
	instance.Set("managed", false)
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}

	// Create an agent_sessions row with the harness_instance set
	sessionsColl, err := app.FindCollectionByNameOrId("agent_sessions")
	if err != nil {
		t.Fatal(err)
	}
	session := core.NewRecord(sessionsColl)
	session.Set("chat", chatID)
	session.Set("user", userID)
	session.Set("acp_session_id", "sess-"+randomSuffixForTest())
	session.Set("harness_instance", instance.Id)
	if err := app.Save(session); err != nil {
		t.Fatal(err)
	}
}

// TestDeleteSessionDialsPinnedInstance verifies that DeleteSession resolves
// and dials the Target from the pinned harness_instance.
func TestDeleteSessionDialsPinnedInstance(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	f := newFakeConn()
	var dialedTarget Target
	c, err := New(Config{
		Workspace: "/w",
		Clock:     NewFakeClock(time.Unix(0, 0)),
		Dial: func(ctx context.Context, client acpsdk.Client, t Target) (acp.Conn, error) {
			dialedTarget = t
			f.mu.Lock()
			f.client = client
			f.mu.Unlock()
			return f, nil
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	chat := createTestChatForTest(t, app, nil)
	seedAgentSessionWithInstance(t, app, chat.Id, chat.GetString("user"), Target{URL: "ws://pinned-instance/acp", Secret: "pinned-secret"})

	if err := c.DeleteSession(context.Background(), app, chat.Id); err != nil {
		t.Fatal(err)
	}
	if dialedTarget.URL != "ws://pinned-instance/acp" {
		t.Errorf("dialed URL %q, want ws://pinned-instance/acp — expected to dial the pinned instance", dialedTarget.URL)
	}
	if dialedTarget.Secret != "pinned-secret" {
		t.Errorf("dialed Secret %q, want pinned-secret", dialedTarget.Secret)
	}
}
