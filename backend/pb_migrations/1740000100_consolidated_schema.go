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
			&core.SelectField{Name: "mode", Values: []string{"primary", "subagent"}},
			&core.NumberField{Name: "temperature"},
			&core.BoolField{Name: "is_init"},
			&core.RelationField{Name: "prompt", CollectionId: prompts.Id, MaxSelect: 1},
			&core.RelationField{Name: "model", CollectionId: models.Id, MaxSelect: 1},
			&core.JSONField{Name: "tools"},
			&core.JSONField{Name: "permissions"},
		)
		agents.ListRule = ptr("@request.auth.id != ''")
		agents.ViewRule = ptr("@request.auth.id != ''")
		agents.Indexes = []string{
			"CREATE UNIQUE INDEX idx_ai_agents_name ON ai_agents (name)",
		}
		if err := app.Save(agents); err != nil { return err }

		// =========================================================================
		// 3. CHATS & MESSAGES (WITH SCHEMA IMPROVEMENTS)
		// =========================================================================
		chats, _ := getOrCreateCollection("pc_chats", "chats", core.CollectionTypeBase)
		addFields(chats,
			&core.TextField{Name: "title", Required: true},
			&core.TextField{Name: "ai_engine_session_id"}, // RENAMED from agent_id
			&core.SelectField{Name: "engine_type", MaxSelect: 1, Values: []string{"opencode", "claude-code", "cursor", "custom"}}, // NEW
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1},
			&core.RelationField{Name: "agent", CollectionId: agents.Id, MaxSelect: 1},
			&core.DateField{Name: "last_active"},
			&core.TextField{Name: "preview"},
			&core.SelectField{Name: "turn", MaxSelect: 1, Values: []string{"user", "assistant"}},
			&core.TextField{Name: "description"}, // NEW - for organization
			&core.BoolField{Name: "archived"}, // NEW - for soft delete
			&core.TextField{Name: "tags"}, // NEW - JSON array for organization
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
			&core.SelectField{Name: "engine_message_status", MaxSelect: 1, Values: []string{"processing", "completed", "failed", "aborted"}}, // RENAMED from status
			&core.SelectField{Name: "user_message_status", MaxSelect: 1, Values: []string{"pending", "sending", "delivered", "failed"}}, // RENAMED from delivery
			&core.TextField{Name: "ai_engine_message_id"}, // RENAMED from agent_message_id
			&core.TextField{Name: "parent_id"},
			&core.TextField{Name: "agent_name"}, // RENAMED from agent
			&core.TextField{Name: "provider_name"}, // RENAMED from provider_id
			&core.TextField{Name: "model_name"}, // RENAMED from model_id
			&core.NumberField{Name: "cost"},
			&core.JSONField{Name: "tokens"},
			&core.JSONField{Name: "error"},
			&core.TextField{Name: "finish_reason"},
			&core.JSONField{Name: "parts"},
			&core.JSONField{Name: "metadata"},
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
		// 4. PERMISSIONS (WITH SCHEMA IMPROVEMENTS)
		// =========================================================================
		permissions, _ := getOrCreateCollection("pc_permissions", "permissions", core.CollectionTypeBase)
		addFields(permissions,
			&core.TextField{Name: "ai_engine_permission_id", Required: true}, // RENAMED from agent_permission_id
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
			&core.RelationField{Name: "approved_by", CollectionId: users.Id, MaxSelect: 1}, // NEW - audit field
			&core.DateField{Name: "approved_at"}, // NEW - audit field
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		permissions.ListRule = ptr("@request.auth.id != ''")
		permissions.ViewRule = ptr("@request.auth.id != ''")
		permissions.UpdateRule = ptr("((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft')")
		if err := app.Save(permissions); err != nil { return err }

		// =========================================================================
		// 5. SUBAGENTS (WITH SCHEMA IMPROVEMENTS)
		// =========================================================================
		subagents, _ := getOrCreateCollection("pc_subagents", "subagents", core.CollectionTypeBase)
		addFields(subagents,
			&core.TextField{Name: "subagent_id", Required: true},
			&core.TextField{Name: "delegating_agent_id", Required: true}, // Keep as string for OpenCode compatibility
			&core.NumberField{Name: "tmux_window_id"},
			&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1}, // RESTORED - referential integrity
			&core.RelationField{Name: "delegating_agent", CollectionId: agents.Id, MaxSelect: 1}, // NEW - proper relation
		)
		subagents.ListRule = ptr("@request.auth.id != ''")
		subagents.ViewRule = ptr("@request.auth.id != ''")
		subagents.CreateRule = ptr("@request.auth.id != ''")
		subagents.UpdateRule = ptr("@request.auth.id != ''")
		subagents.DeleteRule = ptr("@request.auth.id != ''")
		subagents.Indexes = []string{
			"CREATE UNIQUE INDEX idx_subagent_id_unique ON subagents (subagent_id)",
		}
		if err := app.Save(subagents); err != nil { return err }

		// =========================================================================
		// 6. INFRASTRUCTURE (SSH, Whitelists)
		// =========================================================================
		sshKeys, _ := getOrCreateCollection("pc_ssh_keys", "ssh_keys", core.CollectionTypeBase)
		addFields(sshKeys,
			&core.RelationField{Name: "user", CollectionId: users.Id, MaxSelect: 1},
			&core.TextField{Name: "public_key", Required: true},
			&core.TextField{Name: "device_name"},
			&core.TextField{Name: "fingerprint", Required: true},
			&core.TextField{Name: "algorithm"}, // NEW - RSA, ED25519, ECDSA
			&core.NumberField{Name: "key_size"}, // NEW - 2048, 4096, 256
			&core.TextField{Name: "comment"}, // NEW - from public key
			&core.DateField{Name: "expires_at"}, // NEW - expiration date
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

		// Whitelist Targets: Defines allowed file/directory patterns
		// pattern field: Glob pattern format (e.g., '/workspace/src/**', '/workspace/tests/*')
		// Supports: *, ** (recursive), ?, [abc], {a,b,c}
		wlTargets, _ := getOrCreateCollection("pc_whitelist_targets", "whitelist_targets", core.CollectionTypeBase)
		addFields(wlTargets, 
			&core.TextField{Name: "name", Required: true}, 
			&core.TextField{Name: "pattern", Required: true}, // Glob pattern format (e.g., '/workspace/src/**')
			&core.BoolField{Name: "active"},
		)
		if err := app.Save(wlTargets); err != nil { return err }

		// Whitelist Actions: Defines allowed operations (verbs)
		// kind field semantics:
		//   - "strict": Exact match only (e.g., specific command ID) - DEPRECATED, use pattern matching
		//   - "pattern": Glob pattern matching (e.g., '/workspace/src/**' for bash commands)
		// value field:
		//   - For kind="pattern": Glob pattern to match (e.g., "git *", "npm *", "*" for all)
		//   - For kind="strict": Command ID or exact value - NOT USED
		wlActions, _ := getOrCreateCollection("pc_whitelist_actions", "whitelist_actions", core.CollectionTypeBase)
		addFields(wlActions, 
			&core.TextField{Name: "permission", Required: true}, 
			&core.SelectField{Name: "kind", Values: []string{"strict", "pattern"}, MaxSelect: 1}, // strict=exact match (deprecated), pattern=glob
			&core.TextField{Name: "value"}, 
			&core.BoolField{Name: "active"},
		)
		if err := app.Save(wlActions); err != nil { return err }

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
				Values:    []string{"starting", "ready", "degraded", "offline", "error"}, // COMPLETED enum
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
		)
		mcpServers.ListRule = ptr("@request.auth.id != ''")
		mcpServers.ViewRule = ptr("@request.auth.id != ''")
		mcpServers.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		mcpServers.UpdateRule = ptr("@request.auth.role = 'admin'")
		mcpServers.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(mcpServers); err != nil { return err }

		// =========================================================================
		// 9. PROPOSALS & SOPS (WITH SCHEMA IMPROVEMENTS)
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
			&core.RelationField{Name: "proposal", CollectionId: proposals.Id, MaxSelect: 1}, // NEW - lineage
			&core.DateField{Name: "sealed_at"}, // NEW - when SOP was sealed
			&core.TextField{Name: "sealed_by"}, // NEW - who sealed it
			&core.NumberField{Name: "version"}, // NEW - version tracking
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
