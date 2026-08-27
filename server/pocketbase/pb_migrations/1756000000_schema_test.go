package pb_migrations_test

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestFinalSchemaCollectionsExist(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	expected := map[string][]string{
		"users":                  {"role"},
		"chats":                  {"title", "user", "agent_profile", "harness_model_override", "ollama_model_override", "monitored"},
		"sandbox_agents":         {"sandbox_agent_id", "delegating_agent_id", "chat"},
		"permission_modes":       {"name", "description", "base_session_mode", "user", "is_system", "is_default"},
		"permission_mode_tools":  {"tool", "pattern", "action", "permission_mode"},
		"healthchecks":           {"name", "status"},
		"mcp_servers":            {"name", "status", "config"},
		"devices":                {"user", "push_token", "push_service", "created", "updated", "platform", "push_to_start_token"},
		"live_activities":        {"device", "chat", "user", "platform", "status", "content_state_version"},
		"notification_rules":     {"user", "rules"},
		"harnesses":              {"name", "cli_id", "acp_transport", "provider_fanout"},
		"models":                 {"name", "provider"},
		"providers":              {"provider_id", "name", "api_key_env", "api_key_envs"},
		"harness_models":         {"harness", "model", "harness_model_id"},
		"harness_providers":      {"harness", "provider", "supports_oauth", "oauth_authenticator", "api_key_env_override", "is_pinned"},
		"provider_api_keys":      {"owner", "provider", "api_key", "base_url", "extra_env", "last_verified"},
		"harness_oauth_accounts": {"harness", "provider", "owner", "name", "visibility", "status", "last_error"},
		"credential_selections":  {"user", "harness", "provider", "mode", "oauth_account"},
		"prompts":                {"name", "body", "user", "is_system"},
		"agent_profiles":         {"name", "user", "is_system", "system_prompt", "permission_mode"},
		"skills":                 {"user", "is_system", "name", "description", "content", "metadata", "active"},
		"agent_sessions":         {"chat", "user", "acp_session_id"},
		"schedule_owners":        {"user", "display_name", "cron", "prompt", "paused", "last_run"},
		"harness_oauth_attempts": {"account", "status", "expires_at"},
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

	for _, name := range []string{
		"ai_agents",
		"ai_prompts",
		"ai_models",
		"cron_jobs",
		"messages",
		"cognee_config",
		"harness_auth_bindings",
		"harness_account_members",
		"ssh_keys",
	} {
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
