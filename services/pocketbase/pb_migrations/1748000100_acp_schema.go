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

package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		addFields := func(c *core.Collection, fields ...core.Field) {
			for _, f := range fields {
				if existing := c.Fields.GetByName(f.GetName()); existing == nil {
					c.Fields.Add(f)
				}
			}
		}
		getOrCreate := func(id, name string) (*core.Collection, error) {
			if c, _ := app.FindCollectionByNameOrId(name); c != nil {
				return c, nil
			}
			c := core.NewBaseCollection(name)
			c.Id = id
			return c, nil
		}
		authOnly := ptr("@request.auth.id != ''")

		// =========================================================================
		// 1. HARNESSES
		// =========================================================================
		harnesses, err := getOrCreate("pc_harnesses", "harnesses")
		if err != nil {
			return err
		}
		addFields(harnesses,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "cli_id", Required: true},
			&core.TextField{Name: "version"},
			&core.TextField{Name: "description"},
			&core.SelectField{Name: "acp_transport", Required: true, MaxSelect: 1, Values: []string{"websocket", "stdio", "http"}},
		)
		harnesses.ListRule = authOnly
		harnesses.ViewRule = authOnly
		harnesses.Indexes = []string{
			"CREATE UNIQUE INDEX idx_harnesses_cli_id ON harnesses (cli_id)",
		}
		if err := app.Save(harnesses); err != nil {
			return err
		}

		// =========================================================================
		// 2. MODELS
		// =========================================================================
		models, err := getOrCreate("pc_models", "models")
		if err != nil {
			return err
		}
		addFields(models,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "display_name"},
			&core.TextField{Name: "provider", Required: true},
			&core.NumberField{Name: "context_window"},
			&core.TextField{Name: "description"},
		)
		models.ListRule = authOnly
		models.ViewRule = authOnly
		if err := app.Save(models); err != nil {
			return err
		}

		// =========================================================================
		// 3. HARNESS MODELS
		// =========================================================================
		harnessModels, err := getOrCreate("pc_harness_models", "harness_models")
		if err != nil {
			return err
		}
		addFields(harnessModels,
			&core.RelationField{Name: "harness", CollectionId: harnesses.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "model", CollectionId: models.Id, Required: true, MaxSelect: 1},
			&core.TextField{Name: "harness_model_id", Required: true},
			&core.BoolField{Name: "is_default"},
		)
		harnessModels.ListRule = authOnly
		harnessModels.ViewRule = authOnly
		harnessModels.Indexes = []string{
			"CREATE UNIQUE INDEX idx_harness_models_pair ON harness_models (harness, model)",
		}
		if err := app.Save(harnessModels); err != nil {
			return err
		}

		// =========================================================================
		// 4. PROVIDER KEYS
		// =========================================================================
		users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
		if err != nil {
			return err
		}
		providerKeys, err := getOrCreate("pc_provider_keys", "provider_keys")
		if err != nil {
			return err
		}
		addFields(providerKeys,
			&core.RelationField{Name: "user", CollectionId: users.Id, Required: true, MaxSelect: 1},
			&core.TextField{Name: "provider", Required: true},
			&core.JSONField{Name: "env_vars"},
		)
		providerKeys.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		providerKeys.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		providerKeys.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		providerKeys.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		providerKeys.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		providerKeys.Indexes = []string{
			"CREATE UNIQUE INDEX idx_provider_keys_user_provider ON provider_keys (user, provider)",
		}
		if err := app.Save(providerKeys); err != nil {
			return err
		}

		// =========================================================================
		// 5. HARNESS AUTH
		// =========================================================================
		harnessAuth, err := getOrCreate("pc_harness_auth", "harness_auth")
		if err != nil {
			return err
		}
		addFields(harnessAuth,
			&core.RelationField{Name: "user", CollectionId: users.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "harness", CollectionId: harnesses.Id, Required: true, MaxSelect: 1},
			&core.SelectField{Name: "auth_type", Required: true, MaxSelect: 1, Values: []string{"api_key", "oauth"}},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"unauthenticated", "pending", "authenticated", "expired"}},
			&core.TextField{Name: "auth_url"},
			&core.DateField{Name: "expires_at"},
		)
		harnessAuth.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		harnessAuth.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		harnessAuth.CreateRule = authOnly
		harnessAuth.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		harnessAuth.Indexes = []string{
			"CREATE UNIQUE INDEX idx_harness_auth_user_harness ON harness_auth (user, harness)",
		}
		if err := app.Save(harnessAuth); err != nil {
			return err
		}

		// =========================================================================
		// 6. PROMPTS
		// =========================================================================
		prompts, err := getOrCreate("pc_prompts", "prompts")
		if err != nil {
			return err
		}
		addFields(prompts,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "body", Required: true},
		)
		prompts.ListRule = authOnly
		prompts.ViewRule = authOnly
		if err := app.Save(prompts); err != nil {
			return err
		}

		// =========================================================================
		// 7. SKILLS
		// =========================================================================
		skills, err := getOrCreate("pc_skills", "skills")
		if err != nil {
			return err
		}
		addFields(skills,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "description"},
			&core.TextField{Name: "body", Required: true},
			&core.TextField{Name: "tags"},
			&core.BoolField{Name: "active"},
		)
		skills.ListRule = authOnly
		skills.ViewRule = authOnly
		skills.Indexes = []string{
			"CREATE UNIQUE INDEX idx_skills_name ON skills (name)",
		}
		if err := app.Save(skills); err != nil {
			return err
		}

		// =========================================================================
		// 8. POCO CONFIGS
		// =========================================================================
		pocoConfigs, err := getOrCreate("pc_poco_configs", "poco_configs")
		if err != nil {
			return err
		}
		addFields(pocoConfigs,
			&core.TextField{Name: "name", Required: true},
			&core.RelationField{Name: "harness_model", CollectionId: harnessModels.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "system_prompt", CollectionId: prompts.Id, MaxSelect: 1},
			&core.JSONField{Name: "workspace_folders"},
			&core.JSONField{Name: "acp_mcp_servers"},
			&core.BoolField{Name: "is_default"},
		)
		pocoConfigs.ListRule = authOnly
		pocoConfigs.ViewRule = authOnly
		pocoConfigs.Indexes = []string{
			"CREATE UNIQUE INDEX idx_poco_configs_name ON poco_configs (name)",
		}
		if err := app.Save(pocoConfigs); err != nil {
			return err
		}

		// =========================================================================
		// 9. SANDBOX CONFIGS
		// =========================================================================
		sandboxConfigs, err := getOrCreate("pc_sandbox_configs", "sandbox_configs")
		if err != nil {
			return err
		}
		addFields(sandboxConfigs,
			&core.TextField{Name: "name", Required: true},
			&core.RelationField{Name: "harness_model", CollectionId: harnessModels.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "system_prompt", CollectionId: prompts.Id, MaxSelect: 1},
		)
		sandboxConfigs.ListRule = authOnly
		sandboxConfigs.ViewRule = authOnly
		sandboxConfigs.Indexes = []string{
			"CREATE UNIQUE INDEX idx_sandbox_configs_name ON sandbox_configs (name)",
		}
		if err := app.Save(sandboxConfigs); err != nil {
			return err
		}

		// =========================================================================
		// ACP LAYER — modifications to existing collections + new acp_terminals
		// =========================================================================

		// 10. CHATS — add ACP fields
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		addFields(chats,
			&core.TextField{Name: "acp_session_id"},
			&core.RelationField{Name: "poco_config", CollectionId: pocoConfigs.Id, MaxSelect: 1},
			&core.RelationField{Name: "harness_model_override", CollectionId: harnessModels.Id, MaxSelect: 1},
		)
		chats.Indexes = append(chats.Indexes,
			"CREATE INDEX idx_chats_acp_session_id ON chats (acp_session_id)",
		)
		if err := app.Save(chats); err != nil {
			return err
		}

		// 11. MESSAGES — add ACP fields
		messages, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}
		addFields(messages,
			&core.JSONField{Name: "content"},
			&core.SelectField{Name: "acp_status", MaxSelect: 1, Values: []string{"streaming", "completed", "failed", "cancelled"}},
			&core.JSONField{Name: "usage"},
			&core.JSONField{Name: "cost"},
		)
		if err := app.Save(messages); err != nil {
			return err
		}

		// 12. PERMISSIONS — add ACP fields
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}
		addFields(permissions,
			&core.TextField{Name: "acp_request_id"},
			&core.TextField{Name: "acp_session_id"},
			&core.TextField{Name: "tool_name"},
			&core.JSONField{Name: "tool_input"},
			&core.TextField{Name: "description"},
			&core.JSONField{Name: "permission_options"},
			&core.SelectField{Name: "acp_status", MaxSelect: 1, Values: []string{"pending", "allow_once", "allow_always", "deny"}},
			&core.TextField{Name: "selected_option_id"},
			&core.TextField{Name: "acp_message_id"},
			&core.TextField{Name: "tool_call_id"},
		)
		permissions.Indexes = append(permissions.Indexes,
			"CREATE UNIQUE INDEX idx_permissions_acp_request_id ON permissions (acp_request_id)",
			"CREATE INDEX idx_permissions_acp_session_id ON permissions (acp_session_id)",
		)
		if err := app.Save(permissions); err != nil {
			return err
		}

		// 13. ACP TERMINALS — new collection
		agentOrAdmin := ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		acpTerminals, err := getOrCreate("pc_acp_terminals", "acp_terminals")
		if err != nil {
			return err
		}
		addFields(acpTerminals,
			&core.TextField{Name: "acp_terminal_id", Required: true},
			&core.TextField{Name: "acp_session_id", Required: true},
			&core.TextField{Name: "name"},
			&core.TextField{Name: "cwd"},
			&core.NumberField{Name: "exit_code"},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"running", "exited", "killed"}},
			&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1},
			&core.NumberField{Name: "tmux_window_id"},
		)
		acpTerminals.ListRule = authOnly
		acpTerminals.ViewRule = authOnly
		acpTerminals.CreateRule = agentOrAdmin
		acpTerminals.UpdateRule = agentOrAdmin
		acpTerminals.Indexes = []string{
			"CREATE UNIQUE INDEX idx_acp_terminals_terminal_id ON acp_terminals (acp_terminal_id)",
			"CREATE INDEX idx_acp_terminals_session_id ON acp_terminals (acp_session_id)",
		}
		if err := app.Save(acpTerminals); err != nil {
			return err
		}

		// 14. TOOL PERMISSIONS — add poco_config and sandbox_config fields
		toolPermissions, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil {
			return err
		}
		addFields(toolPermissions,
			&core.RelationField{Name: "poco_config", CollectionId: pocoConfigs.Id, MaxSelect: 1},
			&core.RelationField{Name: "sandbox_config", CollectionId: sandboxConfigs.Id, MaxSelect: 1},
		)
		if err := app.Save(toolPermissions); err != nil {
			return err
		}

		// 15. CRON JOBS — add poco_config field
		cronJobs, err := app.FindCollectionByNameOrId("cron_jobs")
		if err != nil {
			return err
		}
		addFields(cronJobs,
			&core.RelationField{Name: "poco_config", CollectionId: pocoConfigs.Id, MaxSelect: 1},
		)
		if err := app.Save(cronJobs); err != nil {
			return err
		}

		// 16. MCP SERVERS — add acp_transport field
		mcpServers, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			return err
		}
		addFields(mcpServers,
			&core.SelectField{Name: "acp_transport", MaxSelect: 1, Values: []string{"http", "sse", "stdio"}},
		)
		if err := app.Save(mcpServers); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		// down: drop all new collections in reverse order
		for _, name := range []string{
			"acp_terminals",
			"sandbox_configs",
			"poco_configs",
			"skills",
			"prompts",
			"harness_auth",
			"provider_keys",
			"harness_models",
			"models",
			"harnesses",
		} {
			if c, _ := app.FindCollectionByNameOrId(name); c != nil {
				if err := app.Delete(c); err != nil {
					return err
				}
			}
		}
		return nil
	})
}
