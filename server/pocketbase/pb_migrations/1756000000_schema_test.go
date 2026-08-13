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
		"users":                 {"role"},
		"chats":                 {"title", "user", "agent_profile", "harness_model_override", "ollama_model_override"},
		"sandbox_agents":        {"sandbox_agent_id", "delegating_agent_id", "chat"},
		"ssh_keys":              {"user", "public_key", "fingerprint"},
		"permission_modes":      {"name", "description", "base_session_mode", "user", "is_system", "is_default"},
		"permission_mode_tools": {"tool", "pattern", "action", "permission_mode"},
		"healthchecks":          {"name", "status"},
		"mcp_servers":           {"name", "status", "config"},
		"devices":               {"user", "push_token", "push_service"},
		"notification_rules":    {"user", "rules"},
		"harnesses":             {"name", "cli_id", "acp_transport"},
		"models":                {"name", "provider"},
		"harness_models":        {"harness", "model", "harness_model_id"},
		"provider_keys":         {"user", "provider", "env_vars"},
		"prompts":               {"name", "body", "user", "is_system"},
		"agent_profiles":        {"name", "user", "is_system", "system_prompt", "permission_mode"},
		"skills":                {"user", "is_system", "name", "description", "content", "metadata", "active"},
		"agent_sessions":        {"chat", "user", "acp_session_id"},
		"schedule_owners":       {"user", "display_name", "cron", "prompt", "paused", "last_run"},
		"harness_auth_bindings": {"scope_kind", "scope_id", "harness", "credential_mode", "status", "provider_key"},
		"harness_auth_attempts": {"scope_kind", "scope_id", "harness", "binding", "provider", "status", "expires_at"},
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

func TestAgentSessionsUniqueIndexes(t *testing.T) {
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
	sessCol, err := app.FindCollectionByNameOrId("agent_sessions")
	if err != nil {
		t.Fatal(err)
	}

	user := core.NewRecord(usersCol)
	user.SetEmail("agent-session-user@example.com")
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
	sess.Set("acp_session_id", "gs-1")
	if err := app.Save(sess); err != nil {
		t.Fatalf("save agent_sessions record: %v", err)
	}

	dup := core.NewRecord(sessCol)
	dup.Set("chat", chat.Id)
	dup.Set("user", user.Id)
	dup.Set("acp_session_id", "gs-2")
	if err := app.Save(dup); err == nil {
		t.Fatal("expected unique-index violation for duplicate chat")
	}
}

func TestHarnessAuthBindingsUniqueScope(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	usersCol, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	harnessesCol, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	bindingsCol, err := app.FindCollectionByNameOrId("harness_auth_bindings")
	if err != nil {
		t.Fatal(err)
	}

	user := core.NewRecord(usersCol)
	user.SetEmail("harness-auth-binding-owner@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	harness := core.NewRecord(harnessesCol)
	harness.Set("name", "Auth Harness")
	harness.Set("cli_id", "auth-binding-cli")
	harness.Set("acp_transport", "websocket")
	if err := app.Save(harness); err != nil {
		t.Fatal(err)
	}

	first := core.NewRecord(bindingsCol)
	first.Set("scope_kind", "user")
	first.Set("scope_id", user.Id)
	first.Set("harness", harness.Id)
	first.Set("credential_mode", "account")
	first.Set("status", "disconnected")
	if err := app.Save(first); err != nil {
		t.Fatalf("save harness_auth_binding: %v", err)
	}

	dup := core.NewRecord(bindingsCol)
	dup.Set("scope_kind", "user")
	dup.Set("scope_id", user.Id)
	dup.Set("harness", harness.Id)
	dup.Set("credential_mode", "account")
	dup.Set("status", "disconnected")
	if err := app.Save(dup); err == nil {
		t.Fatal("expected unique-index violation for duplicate harness_auth_bindings scope pair")
	}
}
