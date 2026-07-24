package pb_migrations_test

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestFinalSchemaCollectionsExist(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	expected := map[string][]string{
		"users":              {"role"},
		"chats":              {"title", "user", "poco_config", "harness_model_override"},
		"sandbox_agents":     {"sandbox_agent_id", "delegating_agent_id", "chat"},
		"ssh_keys":           {"user", "public_key", "fingerprint"},
		"tool_permissions":   {"tool", "pattern", "action", "poco_config", "sandbox_config"},
		"healthchecks":       {"name", "status"},
		"mcp_servers":        {"name", "status", "config"},
		"proposals":          {"name", "content", "authored_by", "status"},
		"sops":               {"name", "content", "signature", "proposal"},
		"questions":          {"chat", "question", "status"},
		"devices":            {"user", "push_token", "push_service"},
		"notification_rules": {"user", "rules"},
		"harnesses":          {"name", "cli_id", "acp_transport"},
		"models":             {"name", "provider"},
		"harness_models":     {"harness", "model", "harness_model_id"},
		"provider_keys":      {"user", "provider", "env_vars"},
		"harness_auth":       {"user", "harness", "auth_type", "status"},
		"prompts":            {"name", "body"},
		"poco_configs":       {"name", "harness_model", "system_prompt"},
		"sandbox_configs":    {"name", "harness_model", "system_prompt"},
		"goose_sessions":     {"chat", "user", "goose_session_id"},
		"schedule_owners":    {"user", "goose_schedule_id", "display_name"},
	}

	for name, fields := range expected {
		col, err := app.FindCollectionByNameOrId(name)
		if err != nil {
			t.Errorf("collection %q not found: %v", name, err)
			continue
		}
		for _, f := range fields {
			if col.Fields.GetByName(f) == nil {
				t.Errorf("collection %q missing field %q", name, f)
			}
		}
	}
}

func TestDeadCollectionsDoNotExist(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	for _, name := range []string{"ai_agents", "ai_prompts", "ai_models", "cron_jobs", "messages"} {
		if _, err := app.FindCollectionByNameOrId(name); err == nil {
			t.Errorf("collection %q should not exist but was found", name)
		}
	}
}

func TestScheduleOwnersUniqueGooseScheduleId(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	col, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	usersCol, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(usersCol)
	user.SetEmail("scheduler-owner@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	rec := core.NewRecord(col)
	rec.Set("user", user.Id)
	rec.Set("goose_schedule_id", "abc123")
	rec.Set("display_name", "My Schedule")
	if err := app.Save(rec); err != nil {
		t.Fatalf("save schedule_owners record: %v", err)
	}

	dup := core.NewRecord(col)
	dup.Set("user", user.Id)
	dup.Set("goose_schedule_id", "abc123")
	dup.Set("display_name", "Duplicate")
	if err := app.Save(dup); err == nil {
		t.Fatal("expected unique-index violation for duplicate goose_schedule_id")
	}
}

func TestGooseSessionsUniqueIndexes(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	chatsCol, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	usersCol, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	sessCol, err := app.FindCollectionByNameOrId("goose_sessions")
	if err != nil {
		t.Fatal(err)
	}

	user := core.NewRecord(usersCol)
	user.SetEmail("goose-user@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	chat := core.NewRecord(chatsCol)
	chat.Set("title", "t")
	chat.Set("user", user.Id)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}

	sess := core.NewRecord(sessCol)
	sess.Set("chat", chat.Id)
	sess.Set("user", user.Id)
	sess.Set("goose_session_id", "gs-1")
	if err := app.Save(sess); err != nil {
		t.Fatalf("save goose_sessions record: %v", err)
	}

	dup := core.NewRecord(sessCol)
	dup.Set("chat", chat.Id)
	dup.Set("user", user.Id)
	dup.Set("goose_session_id", "gs-2")
	if err := app.Save(dup); err == nil {
		t.Fatal("expected unique-index violation for duplicate chat")
	}
}
