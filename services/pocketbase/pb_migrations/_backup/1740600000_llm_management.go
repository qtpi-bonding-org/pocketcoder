package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		// =====================================================================
		// 1. LLM_KEYS — API keys per provider per user
		// =====================================================================
		llmKeys := core.NewCollection(core.CollectionTypeBase, "llm_keys")
		llmKeys.Id = "pc_llm_keys"
		llmKeys.Fields.Add(&core.TextField{Name: "provider_id", Required: true})
		llmKeys.Fields.Add(&core.JSONField{Name: "env_vars"})
		llmKeys.Fields.Add(&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1})

		llmKeys.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		llmKeys.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmKeys.Indexes = []string{
			"CREATE UNIQUE INDEX idx_llm_keys_provider_user ON llm_keys (provider_id, user)",
		}
		if err := app.Save(llmKeys); err != nil {
			return err
		}

		// =====================================================================
		// 2. LLM_CONFIG — active model selection (per-chat or global default)
		// =====================================================================
		llmConfig := core.NewCollection(core.CollectionTypeBase, "llm_config")
		llmConfig.Id = "pc_llm_config"
		llmConfig.Fields.Add(&core.TextField{Name: "model", Required: true})
		llmConfig.Fields.Add(&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1})
		llmConfig.Fields.Add(&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1})

		llmConfig.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		llmConfig.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		llmConfig.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		llmConfig.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmConfig.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		llmConfig.Indexes = []string{
			"CREATE UNIQUE INDEX idx_llm_config_user_chat ON llm_config (user, chat)",
		}
		if err := app.Save(llmConfig); err != nil {
			return err
		}

		// =====================================================================
		// 3. LLM_PROVIDERS — provider catalog synced from OpenCode by interface
		// =====================================================================
		llmProviders := core.NewCollection(core.CollectionTypeBase, "llm_providers")
		llmProviders.Id = "pc_llm_providers"
		llmProviders.Fields.Add(&core.TextField{Name: "provider_id", Required: true})
		llmProviders.Fields.Add(&core.TextField{Name: "name", Required: true})
		llmProviders.Fields.Add(&core.JSONField{Name: "env_vars"})
		llmProviders.Fields.Add(&core.JSONField{Name: "models"})
		llmProviders.Fields.Add(&core.BoolField{Name: "is_connected"})

		llmProviders.ListRule = ptr("@request.auth.id != ''")
		llmProviders.ViewRule = ptr("@request.auth.id != ''")
		llmProviders.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		llmProviders.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		llmProviders.DeleteRule = ptr("@request.auth.role = 'admin'")
		llmProviders.Indexes = []string{
			"CREATE UNIQUE INDEX idx_llm_providers_provider_id ON llm_providers (provider_id)",
		}
		if err := app.Save(llmProviders); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		// Down migration — drop collections in reverse order
		if c, _ := app.FindCollectionByNameOrId("llm_providers"); c != nil {
			if err := app.Delete(c); err != nil {
				return err
			}
		}
		if c, _ := app.FindCollectionByNameOrId("llm_config"); c != nil {
			if err := app.Delete(c); err != nil {
				return err
			}
		}
		if c, _ := app.FindCollectionByNameOrId("llm_keys"); c != nil {
			if err := app.Delete(c); err != nil {
				return err
			}
		}
		return nil
	})
}
