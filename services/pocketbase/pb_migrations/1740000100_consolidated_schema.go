package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// --- HELPERS ---
		getOrCreateCollection := func(id, name, typeStr string) (*core.Collection, error) {
			collection, _ := app.FindCollectionByNameOrId(name)
			if collection != nil {
				return collection, nil
			}
			c := core.NewCollection(typeStr, name)
			c.Id = id
			return c, nil
		}

		addFields := func(c *core.Collection, fields ...core.Field) {
			for _, f := range fields {
				if existing := c.Fields.GetByName(f.GetName()); existing == nil {
					c.Fields.Add(f)
				}
			}
		}

		// =========================================================================
		// 1. USERS COLLECTION (Enhance)
		// =========================================================================
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil { return err }
		if f := users.Fields.GetByName("role"); f == nil {
			users.Fields.Add(&core.SelectField{Name: "role", MaxSelect: 1, Values: []string{"admin", "agent", "user"}})
		}
		if err := app.Save(users); err != nil { return err }

		// =========================================================================
		// 2. AI REGISTRY
		// =========================================================================
		prompts, _ := getOrCreateCollection("pc_ai_prompts", "ai_prompts", core.CollectionTypeBase)
		addFields(prompts,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "body", Required: true},
		)
		prompts.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(prompts); err != nil { return err }

		models, _ := getOrCreateCollection("pc_ai_models", "ai_models", core.CollectionTypeBase)
		addFields(models,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "identifier", Required: true},
		)
		models.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(models); err != nil { return err }

		agents, _ := getOrCreateCollection("pc_ai_agents", "ai_agents", core.CollectionTypeBase)
		addFields(agents,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "description"},
			&core.SelectField{Name: "mode", Values: []string{"primary", "sandbox_agent"}},
			&core.NumberField{Name: "temperature"},
			&core.BoolField{Name: "is_init"},
			&core.RelationField{Name: "prompt", CollectionId: prompts.Id, MaxSelect: 1},
			&core.RelationField{Name: "model", CollectionId: models.Id, MaxSelect: 1},
		)
		agents.ListRule = ptr("@request.auth.id != ''")
		agents.ViewRule = ptr("@request.auth.id != ''")
		agents.Indexes = []string{
			"CREATE UNIQUE INDEX idx_ai_agents_name ON ai_agents (name)",
		}
		if err := app.Save(agents); err != nil { return err }

		// =========================================================================
		// 3. CHATS & MESSAGES
		// =========================================================================
		chats, _ := getOrCreateCollection("pc_chats", "chats", core.CollectionTypeBase)
		addFields(chats,
			&core.TextField{Name: "title", Required: true},
			&core.TextField{Name: "ai_engine_session_id"},
			&core.SelectField{Name: "engine_type", MaxSelect: 1, Values: []string{"opencode", "claude-code", "cursor", "custom"}},
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1},
			&core.RelationField{Name: "agent", CollectionId: agents.Id, MaxSelect: 1},
			&core.DateField{Name: "last_active"},
			&core.TextField{Name: "preview"},
			&core.SelectField{Name: "turn", MaxSelect: 1, Values: []string{"user", "assistant"}},
			&core.TextField{Name: "description"},
			&core.BoolField{Name: "archived"},
			&core.TextField{Name: "tags"},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		chats.ListRule = ptr("@request.auth.id != '' && (user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')")
		chats.ViewRule = ptr("@request.auth.id != '' && (user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')")
		chats.CreateRule = ptr("@request.auth.id != ''")
		chats.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		chats.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		chats.Indexes = []string{
			"CREATE INDEX idx_chats_ai_engine_session_id ON chats (ai_engine_session_id)",
		}
		if err := app.Save(chats); err != nil { return err }

		messages, _ := getOrCreateCollection("pc_messages", "messages", core.CollectionTypeBase)
		addFields(messages,
			&core.RelationField{Name: "chat", Required: true, CollectionId: chats.Id, MaxSelect: 1, CascadeDelete: true},
			&core.SelectField{Name: "role", Required: true, MaxSelect: 1, Values: []string{"user", "assistant", "system"}},
			&core.SelectField{Name: "engine_message_status", MaxSelect: 1, Values: []string{"processing", "completed", "failed", "aborted"}},
			&core.SelectField{Name: "user_message_status", MaxSelect: 1, Values: []string{"pending", "sending", "delivered", "failed"}},
			&core.TextField{Name: "ai_engine_message_id"},
			&core.TextField{Name: "parent_id"},
			&core.JSONField{Name: "parts"},
			&core.SelectField{Name: "error_domain", MaxSelect: 1, Values: []string{"infrastructure", "provider"}},
			&core.JSONField{Name: "error_payload", MaxSize: 1048576},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		messages.ListRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user = @request.auth.id)")
		messages.ViewRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user = @request.auth.id)")
		messages.CreateRule = ptr("@request.auth.id != ''")
		messages.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		messages.DeleteRule = ptr("@request.auth.role = 'admin'")
		messages.Indexes = []string{
			"CREATE INDEX idx_messages_ai_engine_message_id ON messages (ai_engine_message_id)",
		}
		if err := app.Save(messages); err != nil { return err }

		// =========================================================================
		// 4. PERMISSIONS
		// =========================================================================
		permissions, _ := getOrCreateCollection("pc_permissions", "permissions", core.CollectionTypeBase)
		addFields(permissions,
			&core.TextField{Name: "ai_engine_permission_id", Required: true},
			&core.TextField{Name: "session_id", Required: true},
			&core.TextField{Name: "permission", Required: true},
			&core.JSONField{Name: "patterns"},
			&core.JSONField{Name: "metadata"},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"draft", "authorized", "denied"}},
			&core.TextField{Name: "message"},
			&core.TextField{Name: "source"},
			&core.TextField{Name: "message_id"},
			&core.TextField{Name: "call_id"},
			&core.TextField{Name: "challenge"},
			&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1},
			&core.RelationField{Name: "approved_by", CollectionId: users.Id, MaxSelect: 1},
			&core.DateField{Name: "approved_at"},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		permissions.ListRule = ptr("@request.auth.id != ''")
		permissions.ViewRule = ptr("@request.auth.id != ''")
		permissions.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		permissions.UpdateRule = ptr("((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft')")
		permissions.DeleteRule = ptr("@request.auth.id != ''")
		if err := app.Save(permissions); err != nil { return err }

		// =========================================================================
		// 5. SANDBOX AGENTS
		// =========================================================================
		sandboxAgents, _ := getOrCreateCollection("pc_sandbox_agents", "sandbox_agents", core.CollectionTypeBase)
		addFields(sandboxAgents,
			&core.TextField{Name: "sandbox_agent_id", Required: true},
			&core.TextField{Name: "delegating_agent_id", Required: true},
			&core.NumberField{Name: "tmux_window_id"},
			&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1},
			&core.RelationField{Name: "delegating_agent", CollectionId: agents.Id, MaxSelect: 1},
		)
		sandboxAgents.ListRule = ptr("@request.auth.id != ''")
		sandboxAgents.ViewRule = ptr("@request.auth.id != ''")
		sandboxAgents.CreateRule = ptr("@request.auth.id != ''")
		sandboxAgents.UpdateRule = ptr("@request.auth.id != ''")
		sandboxAgents.DeleteRule = ptr("@request.auth.id != ''")
		sandboxAgents.Indexes = []string{
			"CREATE UNIQUE INDEX idx_sandbox_agent_id_unique ON sandbox_agents (sandbox_agent_id)",
		}
		if err := app.Save(sandboxAgents); err != nil { return err }

		// =========================================================================
		// 6. INFRASTRUCTURE (SSH)
		// =========================================================================
		sshKeys, _ := getOrCreateCollection("pc_ssh_keys", "ssh_keys", core.CollectionTypeBase)
		addFields(sshKeys,
			&core.RelationField{Name: "user", CollectionId: users.Id, MaxSelect: 1},
			&core.TextField{Name: "public_key", Required: true},
			&core.TextField{Name: "device_name"},
			&core.TextField{Name: "fingerprint", Required: true},
			&core.TextField{Name: "algorithm"},
			&core.NumberField{Name: "key_size"},
			&core.TextField{Name: "comment"},
			&core.DateField{Name: "expires_at"},
			&core.DateField{Name: "last_used"},
			&core.BoolField{Name: "is_active"},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		sshKeys.ListRule = ptr("@request.auth.id != ''")
		sshKeys.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		sshKeys.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		sshKeys.UpdateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		sshKeys.DeleteRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		if err := app.Save(sshKeys); err != nil { return err }

		toolPerms, _ := getOrCreateCollection("pc_tool_permissions", "tool_permissions", core.CollectionTypeBase)
		addFields(toolPerms,
			&core.RelationField{Name: "agent", CollectionId: agents.Id, MaxSelect: 1},
			&core.TextField{Name: "tool", Required: true},
			&core.TextField{Name: "pattern", Required: true},
			&core.SelectField{Name: "action", Required: true, MaxSelect: 1, Values: []string{"allow", "ask", "deny"}},
			&core.BoolField{Name: "active"},
		)
		toolPerms.ListRule = ptr("@request.auth.id != ''")
		toolPerms.ViewRule = ptr("@request.auth.id != ''")
		toolPerms.CreateRule = ptr("@request.auth.role = 'admin'")
		toolPerms.UpdateRule = ptr("@request.auth.role = 'admin'")
		toolPerms.DeleteRule = ptr("@request.auth.role = 'admin'")
		toolPerms.Indexes = []string{
			"CREATE UNIQUE INDEX idx_tool_perms_agent_tool_pattern ON tool_permissions (agent, tool, pattern)",
		}
		if err := app.Save(toolPerms); err != nil { return err }

		// =========================================================================
		// 7. HEALTHCHECKS
		// =========================================================================
		healthchecks, _ := getOrCreateCollection("pc_healthchecks", "healthchecks", core.CollectionTypeBase)
		addFields(healthchecks,
			&core.TextField{Name: "name", Required: true},
			&core.SelectField{
				Name:      "status",
				Required:  true,
				MaxSelect: 1,
				Values:    []string{"starting", "ready", "degraded", "offline", "error"},
			},
			&core.DateField{Name: "last_ping"},
		)
		healthchecks.ListRule = ptr("@request.auth.id != ''")
		healthchecks.ViewRule = ptr("@request.auth.id != ''")
		healthchecks.UpdateRule = ptr("")
		healthchecks.CreateRule = ptr("")
		healthchecks.DeleteRule = ptr("")
		if err := app.Save(healthchecks); err != nil { return err }

		// =========================================================================
		// 8. MCP SERVERS
		// =========================================================================
		mcpServers, _ := getOrCreateCollection("pc_mcp_servers", "mcp_servers", core.CollectionTypeBase)
		addFields(mcpServers,
			&core.TextField{Name: "name", Required: true},
			&core.SelectField{
				Name:      "status",
				Required:  true,
				MaxSelect: 1,
				Values:    []string{"pending", "approved", "denied", "revoked"},
			},
			&core.TextField{Name: "requested_by"},
			&core.RelationField{Name: "approved_by", CollectionId: users.Id, MaxSelect: 1},
			&core.DateField{Name: "approved_at"},
			&core.JSONField{Name: "config"},
			&core.TextField{Name: "catalog"},
			&core.TextField{Name: "reason"},
			&core.TextField{Name: "image"},
			&core.JSONField{Name: "config_schema"},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		mcpServers.ListRule = ptr("@request.auth.id != ''")
		mcpServers.ViewRule = ptr("@request.auth.id != ''")
		mcpServers.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		mcpServers.UpdateRule = ptr("@request.auth.role = 'admin'")
		mcpServers.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(mcpServers); err != nil { return err }

		// =========================================================================
		// 9. PROPOSALS & SOPS
		// =========================================================================
		proposals, _ := getOrCreateCollection("pc_proposals", "proposals", core.CollectionTypeBase)
		addFields(proposals,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "description"},
			&core.TextField{Name: "content", Required: true},
			&core.SelectField{
				Name:     "authored_by",
				Required: true,
				Values:   []string{"human", "poco"},
			},
			&core.SelectField{
				Name:     "status",
				Required: true,
				Values:   []string{"draft", "approved"},
			},
		)
		proposals.ListRule = ptr("@request.auth.id != ''")
		proposals.ViewRule = ptr("@request.auth.id != ''")
		proposals.CreateRule = ptr("@request.auth.id != ''")
		proposals.UpdateRule = ptr("@request.auth.id != ''")
		proposals.DeleteRule = ptr("@request.auth.id != ''")
		if err := app.Save(proposals); err != nil { return err }

		sops, _ := getOrCreateCollection("pc_sops", "sops", core.CollectionTypeBase)
		addFields(sops,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "description", Required: true},
			&core.TextField{Name: "content", Required: true},
			&core.TextField{Name: "signature", Required: true},
			&core.DateField{Name: "approved_at"},
			&core.RelationField{Name: "proposal", CollectionId: proposals.Id, MaxSelect: 1},
			&core.DateField{Name: "sealed_at"},
			&core.TextField{Name: "sealed_by"},
			&core.NumberField{Name: "version"},
		)
		sops.ListRule = ptr("@request.auth.id != ''")
		sops.ViewRule = ptr("@request.auth.id != ''")
		sops.CreateRule = ptr("")
		sops.UpdateRule = ptr("")
		sops.DeleteRule = ptr("@request.auth.id != ''")
		sops.Indexes = []string{
			"CREATE UNIQUE INDEX idx_sops_name ON sops (name)",
		}
		if err := app.Save(sops); err != nil { return err }

		// =========================================================================
		// 10. QUESTIONS (HITL)
		// =========================================================================
		questions, _ := getOrCreateCollection("pc_questions", "questions", core.CollectionTypeBase)
		addFields(questions,
			&core.RelationField{Name: "chat", Required: true, CollectionId: chats.Id, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "question", Required: true},
			&core.JSONField{Name: "choices"},
			&core.TextField{Name: "reply"},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"asked", "replied", "rejected"}},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		questions.ListRule = ptr("@request.auth.id != ''")
		questions.ViewRule = ptr("@request.auth.id != ''")
		questions.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		questions.UpdateRule = ptr("@request.auth.id != ''")
		questions.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(questions); err != nil { return err }

		// =========================================================================
		// 11. DEVICES (Push Notifications)
		// =========================================================================
		devices, _ := getOrCreateCollection("pc_devices", "devices", core.CollectionTypeBase)
		addFields(devices,
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "push_token", Required: true},
			&core.SelectField{Name: "push_service", Required: true, MaxSelect: 1, Values: []string{"fcm", "unifiedpush"}},
			&core.BoolField{Name: "is_active"},
		)
		devices.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.UpdateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.DeleteRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		if err := app.Save(devices); err != nil { return err }

		// =========================================================================
		// 12. LLM MANAGEMENT
		// =========================================================================
		llmKeys, _ := getOrCreateCollection("pc_llm_keys", "llm_keys", core.CollectionTypeBase)
		addFields(llmKeys,
			&core.TextField{Name: "provider_id", Required: true},
			&core.JSONField{Name: "env_vars"},
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1},
		)
		llmKeys.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		llmKeys.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.Indexes = []string{
			"CREATE UNIQUE INDEX idx_llm_keys_provider_user ON llm_keys (provider_id, user)",
		}
		if err := app.Save(llmKeys); err != nil { return err }

		modelSelection, _ := getOrCreateCollection("pc_model_selection", "model_selection", core.CollectionTypeBase)
		addFields(modelSelection,
			&core.TextField{Name: "model", Required: true},
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1},
			&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1},
		)
		modelSelection.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		modelSelection.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		modelSelection.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		modelSelection.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		modelSelection.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		modelSelection.Indexes = []string{
			"CREATE UNIQUE INDEX idx_model_selection_user_chat ON model_selection (user, chat)",
		}
		if err := app.Save(modelSelection); err != nil { return err }

		llmProviders, _ := getOrCreateCollection("pc_llm_providers", "llm_providers", core.CollectionTypeBase)
		addFields(llmProviders,
			&core.TextField{Name: "provider_id", Required: true},
			&core.TextField{Name: "name", Required: true},
			&core.JSONField{Name: "env_vars"},
			&core.JSONField{Name: "models"},
			&core.BoolField{Name: "is_connected"},
		)
		llmProviders.ListRule = ptr("@request.auth.id != ''")
		llmProviders.ViewRule = ptr("@request.auth.id != ''")
		llmProviders.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		llmProviders.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		llmProviders.DeleteRule = ptr("@request.auth.role = 'admin'")
		llmProviders.Indexes = []string{
			"CREATE UNIQUE INDEX idx_llm_providers_provider_id ON llm_providers (provider_id)",
		}
		if err := app.Save(llmProviders); err != nil { return err }

		// =========================================================================
		// 13. NOTIFICATION RULES
		// =========================================================================
		notifRules, _ := getOrCreateCollection("pc_notification_rules", "notification_rules", core.CollectionTypeBase)
		addFields(notifRules,
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.JSONField{Name: "rules"},
		)
		notifRules.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		notifRules.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		notifRules.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		notifRules.UpdateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		notifRules.DeleteRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		notifRules.AddIndex("idx_notification_rules_user", true, "user", "")
		if err := app.Save(notifRules); err != nil { return err }

		// Fix turn state
		_, err = app.DB().NewQuery("UPDATE chats SET turn = 'user' WHERE turn = '' OR turn IS NULL").Execute()
		return err
	}, func(app core.App) error {
		return nil
	})
}

func ptr(s string) *string {
	return &s
}
