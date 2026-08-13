package hooks

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestChatsHarnessPinRejectsChangeAfterSessionExists(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	RegisterChatsHarnessPinHook(app)

	// Create test harnesses
	harnesses, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	harnessA := core.NewRecord(harnesses)
	harnessA.Set("name", "Harness A")
	harnessA.Set("cli_id", "harness-a")
	harnessA.Set("acp_transport", "websocket")
	if err := app.Save(harnessA); err != nil {
		t.Fatal(err)
	}

	harnessB := core.NewRecord(harnesses)
	harnessB.Set("name", "Harness B")
	harnessB.Set("cli_id", "harness-b")
	harnessB.Set("acp_transport", "websocket")
	if err := app.Save(harnessB); err != nil {
		t.Fatal(err)
	}

	// Create test user
	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("test-harness-pin-1@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	// Create test chat with harness A
	chats, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	chat := core.NewRecord(chats)
	chat.Set("user", user.Id)
	chat.Set("title", "Test Chat")
	chat.Set("harness", harnessA.Id)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}

	// Create agent session for this chat
	agentSessions, err := app.FindCollectionByNameOrId("agent_sessions")
	if err != nil {
		t.Fatal(err)
	}
	session := core.NewRecord(agentSessions)
	session.Set("chat", chat.Id)
	session.Set("user", user.Id)
	session.Set("acp_session_id", "session-123")
	if err := app.Save(session); err != nil {
		t.Fatal(err)
	}

	// Try to change harness — should fail
	chat.Set("harness", harnessB.Id)
	err = app.Save(chat)
	if err == nil {
		t.Fatal("expected rejection of a harness change once a session exists")
	}
}

func TestChatsHarnessPinAllowsChangeBeforeSessionExists(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	RegisterChatsHarnessPinHook(app)

	// Create test harnesses
	harnesses, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	harnessA := core.NewRecord(harnesses)
	harnessA.Set("name", "Harness A")
	harnessA.Set("cli_id", "harness-a")
	harnessA.Set("acp_transport", "websocket")
	if err := app.Save(harnessA); err != nil {
		t.Fatal(err)
	}

	harnessB := core.NewRecord(harnesses)
	harnessB.Set("name", "Harness B")
	harnessB.Set("cli_id", "harness-b")
	harnessB.Set("acp_transport", "websocket")
	if err := app.Save(harnessB); err != nil {
		t.Fatal(err)
	}

	// Create test user
	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("test-harness-pin-2@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	// Create test chat with harness A
	chats, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	chat := core.NewRecord(chats)
	chat.Set("user", user.Id)
	chat.Set("title", "Test Chat")
	chat.Set("harness", harnessA.Id)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}

	// Change harness without a goose session — should succeed
	chat.Set("harness", harnessB.Id)
	if err := app.Save(chat); err != nil {
		t.Fatalf("expected the change to be allowed before any session exists, got %v", err)
	}
}

func TestChatsHarnessPinRejectsWorkspaceOverrideOutsideRoot(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	RegisterChatsHarnessPinHook(app)

	// Create test user
	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("test-harness-pin-3@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	// Create test chat with invalid workspace override
	chats, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	chat := core.NewRecord(chats)
	chat.Set("user", user.Id)
	chat.Set("title", "Test Chat")
	chat.Set("workspace_override", []string{"/etc/passwd"})

	if err := app.Save(chat); err == nil {
		t.Fatal("expected rejection of workspace_override outside /workspace")
	}
}
