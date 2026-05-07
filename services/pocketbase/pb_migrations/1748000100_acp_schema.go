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

		return nil
	}, func(app core.App) error {
		// down: drop all new collections in reverse order
		for _, name := range []string{
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
