package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// =========================================================================
		// 1. CHATS COLLECTION
		// =========================================================================
		chats := core.NewCollection(core.CollectionTypeBase, "chats")
		chats.Name = "chats"
		
		// Fetch users collection to get ID
		usersCollection, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		chats.Fields.Add(&core.TextField{Name: "title", Required: true})
		chats.Fields.Add(&core.RelationField{
			Name:         "user",
			Required:     true,
			CollectionId: usersCollection.Id,
			MaxSelect:    1,
		})

		chats.ListRule = ptr("@request.auth.id = user.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		chats.ViewRule = ptr("@request.auth.id = user.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		chats.CreateRule = ptr("@request.auth.id != ''")
		chats.UpdateRule = ptr("@request.auth.id = user.id || @request.auth.role = 'admin'")
		chats.DeleteRule = ptr("@request.auth.id = user.id || @request.auth.role = 'admin'")

		if err := app.Save(chats); err != nil {
			return err
		}

		// =========================================================================
		// 2. MESSAGES COLLECTION
		// =========================================================================
		messages := core.NewCollection(core.CollectionTypeBase, "messages")
		messages.Name = "messages"

		messages.Fields.Add(&core.RelationField{
			Name:         "chat",
			Required:     true,
			CollectionId: chats.Id,
			MaxSelect:    1,
		})
		
		messages.Fields.Add(&core.SelectField{
			Name:      "role",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"user", "assistant", "system"},
		})

		messages.Fields.Add(&core.JSONField{Name: "parts", Required: true})
		messages.Fields.Add(&core.JSONField{Name: "metadata"})
		messages.AddIndex("idx_messages_chat", false, "chat", "")

		messages.ListRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user.id = @request.auth.id)")
		messages.ViewRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user.id = @request.auth.id)")
		messages.CreateRule = ptr("@request.auth.id != ''")
		messages.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		messages.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(messages); err != nil {
			return err
		}

		// =========================================================================
		// 3. USAGES COLLECTION (Sovereign Usage Ledger)
		// =========================================================================
		usages := core.NewCollection(core.CollectionTypeBase, "usages")
		usages.Name = "usages"
		usages.Fields.Add(&core.TextField{Name: "message_id"})
		usages.Fields.Add(&core.TextField{Name: "part_id"})
		usages.Fields.Add(&core.TextField{Name: "model"})
		usages.Fields.Add(&core.NumberField{Name: "tokens_prompt"})
		usages.Fields.Add(&core.NumberField{Name: "tokens_completion"})
		usages.Fields.Add(&core.NumberField{Name: "tokens_reasoning"})
		usages.Fields.Add(&core.NumberField{Name: "cost"})
		usages.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"in-progress", "completed", "error"},
		})
		usages.AddIndex("idx_usages_message_id", false, "message_id", "")
		
		usages.ListRule = ptr("@request.auth.id != ''")
		usages.ViewRule = ptr("@request.auth.id != ''")
		usages.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		usages.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		usages.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(usages); err != nil {
			return err
		}

		// =========================================================================
		// 4. PERMISSIONS COLLECTION
		// =========================================================================
		permissions := core.NewCollection(core.CollectionTypeBase, "permissions")
		permissions.Name = "permissions"

		permissions.Fields.Add(&core.TextField{Name: "opencode_id", Required: true})
		permissions.Fields.Add(&core.TextField{Name: "session_id", Required: true})
		permissions.Fields.Add(&core.TextField{Name: "permission", Required: true})
		permissions.Fields.Add(&core.JSONField{Name: "patterns"})
		permissions.Fields.Add(&core.JSONField{Name: "metadata"})
		permissions.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"draft", "authorized", "denied"},
		})
		permissions.Fields.Add(&core.TextField{Name: "message"})
		
		// Relation to Usage (Optional)
		permissions.Fields.Add(&core.RelationField{
			Name:         "usage",
			Required:     false,
			CollectionId: usages.Id,
			MaxSelect:    1,
		})

		permissions.AddIndex("idx_permissions_opencode_id", true, "opencode_id", "")
		
		permissions.ListRule = ptr("@request.auth.id != ''")
		permissions.ViewRule = ptr("@request.auth.id != ''")
		permissions.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		permissions.UpdateRule = ptr("((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft')")
		permissions.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(permissions); err != nil {
			return err
		}
		
		// Update Executions with Relation to Permission (Optional, if Collection exists? Assuming 'permissions' is enough for now)
		// We skipped 'executions' in the consolidated file unless strictly needed. Assuming 'permissions' covers the need for now as per plan.
		// Actually, let's include 'executions' if it was there before, but simpler.
		executions := core.NewCollection(core.CollectionTypeBase, "executions")
		executions.Name = "executions"
		executions.Fields.Add(&core.TextField{Name: "command", Required: true})
		executions.Fields.Add(&core.TextField{Name: "output"})
		executions.Fields.Add(&core.NumberField{Name: "exit_code"})
		executions.Fields.Add(&core.RelationField{
			Name:         "permission",
			Required:     false,
			CollectionId: permissions.Id,
			MaxSelect:    1,
		})
		executions.ListRule = ptr("@request.auth.role = 'admin'")
		executions.ViewRule = ptr("@request.auth.role = 'admin'")
		executions.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		
		if err := app.Save(executions); err != nil {
			return err
		}


		// =========================================================================
		// 5. AI REGISTRY
		// =========================================================================
		// AI Prompts
		prompts := core.NewCollection(core.CollectionTypeBase, "ai_prompts")
		prompts.Name = "ai_prompts"
		prompts.Fields.Add(&core.TextField{Name: "name", Required: true})
		prompts.Fields.Add(&core.TextField{Name: "body", Required: true})
		prompts.ListRule = ptr("@request.auth.id != ''")
		prompts.ViewRule = ptr("@request.auth.id != ''")
		prompts.CreateRule = ptr("@request.auth.role = 'admin'")
		prompts.UpdateRule = ptr("@request.auth.role = 'admin'")
		prompts.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(prompts); err != nil { return err }

		// AI Models
		models := core.NewCollection(core.CollectionTypeBase, "ai_models")
		models.Name = "ai_models"
		models.Fields.Add(&core.TextField{Name: "name", Required: true})
		models.Fields.Add(&core.TextField{Name: "identifier", Required: true})
		models.ListRule = ptr("@request.auth.id != ''")
		models.ViewRule = ptr("@request.auth.id != ''")
		models.CreateRule = ptr("@request.auth.role = 'admin'")
		models.UpdateRule = ptr("@request.auth.role = 'admin'")
		models.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(models); err != nil { return err }

		// AI Agents
		agents := core.NewCollection(core.CollectionTypeBase, "ai_agents")
		agents.Name = "ai_agents"
		agents.Fields.Add(&core.TextField{Name: "name", Required: true})
		agents.Fields.Add(&core.TextField{Name: "description"})
		agents.Fields.Add(&core.BoolField{Name: "is_init"})
		agents.Fields.Add(&core.SelectField{Name: "mode", Values: []string{"primary", "subagent", "all"}})
		agents.Fields.Add(&core.RelationField{Name: "prompt", CollectionId: prompts.Id, MaxSelect: 1})
		agents.Fields.Add(&core.RelationField{Name: "model", CollectionId: models.Id, MaxSelect: 1})
		agents.Fields.Add(&core.NumberField{Name: "steps"})
		agents.Fields.Add(&core.TextField{Name: "config"})
		agents.ListRule = ptr("@request.auth.id != ''")
		agents.ViewRule = ptr("@request.auth.id != ''")
		agents.CreateRule = ptr("@request.auth.role = 'admin'")
		agents.UpdateRule = ptr("@request.auth.role = 'admin'")
		agents.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(agents); err != nil { return err }

		// AI Permission Rules
		rules := core.NewCollection(core.CollectionTypeBase, "ai_permission_rules")
		rules.Name = "ai_permission_rules"
		rules.Fields.Add(&core.RelationField{Name: "agent", CollectionId: agents.Id, MaxSelect: 1})
		rules.Fields.Add(&core.TextField{Name: "pattern", Required: true})
		rules.Fields.Add(&core.SelectField{Name: "action", Values: []string{"allow", "ask", "deny"}})
		rules.ListRule = ptr("@request.auth.id != ''")
		rules.ViewRule = ptr("@request.auth.id != ''")
		rules.CreateRule = ptr("@request.auth.role = 'admin'")
		rules.UpdateRule = ptr("@request.auth.role = 'admin'")
		rules.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(rules); err != nil { return err }

		// =========================================================================
		// 6. WHITELISTS (NEW Phase 3)
		// =========================================================================
		// Whitelist Targets (e.g. Approved Git Repos, Domains)
		wlTargets := core.NewCollection(core.CollectionTypeBase, "whitelist_targets")
		wlTargets.Name = "whitelist_targets"
		wlTargets.Fields.Add(&core.TextField{Name: "name", Required: true})
		wlTargets.Fields.Add(&core.TextField{Name: "pattern", Required: true}) // e.g. "github.com/myorg/*"
		wlTargets.Fields.Add(&core.SelectField{Name: "type", Values: []string{"domain", "repo", "path"}})
		wlTargets.ListRule = ptr("@request.auth.id != ''")
		wlTargets.ViewRule = ptr("@request.auth.id != ''")
		wlTargets.CreateRule = ptr("@request.auth.role = 'admin'")
		wlTargets.UpdateRule = ptr("@request.auth.role = 'admin'")
		wlTargets.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(wlTargets); err != nil { return err }

		// Whitelist Actions (e.g. "git clone", "curl")
		wlActions := core.NewCollection(core.CollectionTypeBase, "whitelist_actions")
		wlActions.Name = "whitelist_actions"
		wlActions.Fields.Add(&core.TextField{Name: "command", Required: true}) // e.g. "git clone"
		wlActions.Fields.Add(&core.RelationField{Name: "target", CollectionId: wlTargets.Id, MaxSelect: 1})
		wlActions.Fields.Add(&core.BoolField{Name: "is_active"})
		wlActions.ListRule = ptr("@request.auth.id != ''")
		wlActions.ViewRule = ptr("@request.auth.id != ''")
		wlActions.CreateRule = ptr("@request.auth.role = 'admin'")
		wlActions.UpdateRule = ptr("@request.auth.role = 'admin'")
		wlActions.DeleteRule = ptr("@request.auth.role = 'admin'")
		if err := app.Save(wlActions); err != nil { return err }

		return nil
	}, func(app core.App) error {
		// Flattened rollback is destructive - removing everything.
		names := []string{"whitelist_actions", "whitelist_targets", "ai_permission_rules", "ai_agents", "ai_models", "ai_prompts", "executions", "permissions", "usages", "messages", "chats"}
		for _, name := range names {
			if c, _ := app.FindCollectionByNameOrId(name); c != nil {
				app.Delete(c)
			}
		}
		return nil
	})
}

func ptr(s string) *string {
	return &s
}
