package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// --- HELPERS ---
		// getOrCreate simplifies our migration by handling both fresh and existing DBs
		getOrCreateCollection := func(name string, typeStr string) (*core.Collection, error) {
			collection, _ := app.FindCollectionByNameOrId(name)
			if collection != nil {
				return collection, nil
			}
			return core.NewCollection(typeStr, name), nil
		}
		
		// Helper to safely add fields (Moved to a more global scope)
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
		if err != nil {
			return err
		}
		if f := users.Fields.GetByName("role"); f == nil {
			users.Fields.Add(&core.SelectField{
				Name:      "role",
				MaxSelect: 1,
				Values:    []string{"admin", "agent", "user"},
			})
		}
		if err := app.Save(users); err != nil {
			return err
		}


		// =========================================================================
		// 2. CHATS COLLECTION
		// =========================================================================
		chats, _ := getOrCreateCollection("chats", core.CollectionTypeBase)
		if f := chats.Fields.GetByName("title"); f == nil {
			chats.Fields.Add(&core.TextField{Name: "title", Required: true})
		}
		if f := chats.Fields.GetByName("opencode_id"); f == nil {
			chats.Fields.Add(&core.TextField{Name: "opencode_id"})
		}
		if f := chats.Fields.GetByName("user"); f == nil {
			chats.Fields.Add(&core.RelationField{
				Name:         "user",
				Required:     true,
				CollectionId: users.Id,
				MaxSelect:    1,
			})
		}
		if f := chats.Fields.GetByName("agent"); f == nil {
			chats.Fields.Add(&core.RelationField{
				Name:         "agent",
				CollectionId: "ai_agents", // Using ID name since it's created later in file but name works if it exists
				MaxSelect:    1,
			})
		}
		addFields(chats,
			&core.DateField{Name: "last_active"},
			&core.TextField{Name: "preview"},
			&core.SelectField{
				Name:      "turn",
				MaxSelect: 1,
				Values:    []string{"user", "assistant"},
			},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)

		chats.ListRule = ptr("@request.auth.id != '' && (user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')")
		chats.ViewRule = ptr("@request.auth.id != '' && (user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')")
		chats.CreateRule = ptr("@request.auth.id != ''")
		chats.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		chats.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")

		if err := app.Save(chats); err != nil {
			return err
		}

		// =========================================================================
		// 3. MESSAGES COLLECTION
		// =========================================================================
		messages, _ := getOrCreateCollection("messages", core.CollectionTypeBase)
		


		addFields(messages, 
			&core.RelationField{Name: "chat", Required: true, CollectionId: chats.Id, MaxSelect: 1},
			&core.SelectField{Name: "role", Required: true, MaxSelect: 1, Values: []string{"user", "assistant", "system"}},
			&core.SelectField{Name: "status", MaxSelect: 1, Values: []string{"processing", "completed", "failed", "aborted"}},
			&core.TextField{Name: "opencode_id"},
			&core.TextField{Name: "parent_id"},
			&core.TextField{Name: "agent"},
			&core.TextField{Name: "provider_id"},
			&core.TextField{Name: "model_id"},
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

		if err := app.Save(messages); err != nil {
			return err
		}

		// =========================================================================
		// 4. USAGES COLLECTION
		// =========================================================================
		usages, _ := getOrCreateCollection("usages", core.CollectionTypeBase)
		addFields(usages,
			&core.TextField{Name: "message_id"},
			&core.TextField{Name: "part_id"},
			&core.TextField{Name: "model"},
			&core.NumberField{Name: "tokens_prompt"},
			&core.NumberField{Name: "tokens_completion"},
			&core.NumberField{Name: "tokens_reasoning"},
			&core.NumberField{Name: "cost"},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"in-progress", "completed", "error"}},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)
		
		usages.ListRule = ptr("@request.auth.id != ''")
		usages.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")

		if err := app.Save(usages); err != nil {
			return err
		}

		// =========================================================================
		// 5. PERMISSIONS COLLECTION
		// =========================================================================
		permissions, _ := getOrCreateCollection("permissions", core.CollectionTypeBase)
		addFields(permissions,
			&core.TextField{Name: "opencode_id", Required: true},
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
			&core.RelationField{Name: "usage", CollectionId: usages.Id, MaxSelect: 1},
			&core.DateField{Name: "created"},
			&core.DateField{Name: "updated"},
		)

		permissions.ListRule = ptr("@request.auth.id != ''")
		permissions.UpdateRule = ptr("((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft')")

		if err := app.Save(permissions); err != nil {
			return err
		}

		// =========================================================================
		// 6. SSH KEYS COLLECTION
		// =========================================================================
		sshKeys, _ := getOrCreateCollection("ssh_keys", core.CollectionTypeBase)
		addFields(sshKeys,
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1},
			&core.TextField{Name: "public_key", Required: true},
			&core.TextField{Name: "device_name"},
			&core.TextField{Name: "fingerprint", Required: true},
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

		if err := app.Save(sshKeys); err != nil {
			return err
		}

		// =========================================================================
		// 7. AI REGISTRY & WHITELISTS
		// =========================================================================
		
		// AI Prompts
		prompts, _ := getOrCreateCollection("ai_prompts", core.CollectionTypeBase)
		addFields(prompts,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "body", Required: true},
		)
		prompts.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(prompts); err != nil { return err }

		// AI Models
		models, _ := getOrCreateCollection("ai_models", core.CollectionTypeBase)
		addFields(models,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "identifier", Required: true},
		)
		models.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(models); err != nil { return err }

		// AI Agents
		agents, _ := getOrCreateCollection("ai_agents", core.CollectionTypeBase)
		addFields(agents,
			&core.TextField{Name: "name", Required: true},
			&core.BoolField{Name: "is_init"},
			&core.RelationField{Name: "prompt", CollectionId: prompts.Id, MaxSelect: 1},
			&core.RelationField{Name: "model", CollectionId: models.Id, MaxSelect: 1},
			&core.TextField{Name: "config"},
		)
		agents.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(agents); err != nil { return err }

		// Whitelists
		wlTargets, _ := getOrCreateCollection("whitelist_targets", core.CollectionTypeBase)
		addFields(wlTargets,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "pattern", Required: true},
			&core.BoolField{Name: "active"},
		)
		wlTargets.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(wlTargets); err != nil { return err }

		wlActions, _ := getOrCreateCollection("whitelist_actions", core.CollectionTypeBase)
		addFields(wlActions,
			&core.TextField{Name: "permission", Required: true},
			&core.SelectField{Name: "kind", Values: []string{"strict", "pattern"}, MaxSelect: 1},
			&core.TextField{Name: "value"},
			&core.BoolField{Name: "active"},
		)
		wlActions.ListRule = ptr("@request.auth.id != ''")
		if err := app.Save(wlActions); err != nil { return err }

		// 8. INITIALIZE TURN STATE
		_, err = app.DB().NewQuery("UPDATE chats SET turn = 'user' WHERE turn = '' OR turn IS NULL").Execute()
		return err
	}, func(app core.App) error {
		return nil
	})
}

func ptr(s string) *string {
	return &s
}
